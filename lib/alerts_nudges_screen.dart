import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/employee_tutorial_service.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/one_on_one_meeting.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/goal_detail_screen.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/services/one_on_one_meeting_service.dart';
import 'package:pdh/badges_v2/badge_category_detail_screen.dart';
import 'package:pdh/models/badge.dart' as badge_model;
import 'package:pdh/utils/firestore_safe.dart';

class AlertsNudgesScreen extends StatefulWidget {
  final bool embedded;

  /// When true, use manager sidebar and [managerGwMenuRoute] (for manager Goal Workspace menu).
  final bool forManagerGwMenu;
  final String? managerGwMenuRoute;
  final bool forAdminOversight;
  final String? selectedManagerId;

  const AlertsNudgesScreen({
    super.key,
    this.embedded = false,
    this.forManagerGwMenu = false,
    this.managerGwMenuRoute,
    this.forAdminOversight = false,
    this.selectedManagerId,
  });

  @override
  State<AlertsNudgesScreen> createState() => _AlertsNudgesScreenState();
}

class _AlertsNudgesScreenState extends State<AlertsNudgesScreen> {
  List<Map<String, dynamic>>? _predictiveRisks;
  bool _isLoadingRisks = false;
  bool _isRiskAlertsExpanded = false;
  List<Alert>? _cachedAlerts;
  List<OneOnOneMeeting>? _cachedMeetings;
  final Map<String, String> _userNameCache = {};
  static const Duration _defaultMeetingDuration = Duration(hours: 1);

  @override
  void initState() {
    super.initState();
    // Ensure role is loaded before building
    RoleService.instance.ensureRoleLoaded();
    // Check for new alerts when screen loads
    AlertService.checkAndCreateGoalAlerts();
    // Load predictive risk alerts
    _loadPredictiveRisks();
  }

  Future<void> _loadPredictiveRisks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoadingRisks = true);

    try {
      final goals = await DatabaseService.getUserGoals(user.uid);
      if (goals.isEmpty) {
        setState(() {
          _predictiveRisks = [];
          _isLoadingRisks = false;
        });
        return;
      }

      // Analyze goals for potential risks
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        systemInstruction: Content.text(
          'You are an AI assistant specialized in analyzing personal development goals and predicting potential risks. '
          'Analyze goal data and identify goals that are at risk of missing deadlines, have low progress rates, or show concerning patterns. '
          'For each at-risk goal, provide:\n'
          '1. Goal title\n'
          '2. Risk level (high, medium, low)\n'
          '3. Risk description (why it\'s at risk)\n'
          '4. Recommended action\n\n'
          'Respond ONLY with a JSON array in this exact format (no other text):\n'
          '[{"goalTitle": "Goal name", "riskLevel": "high|medium|low", "riskDescription": "Why it\'s at risk", "recommendedAction": "What to do"}]',
        ),
      );

      final progressData = goals
          .map((g) {
            final daysUntilDeadline = g.targetDate
                .difference(DateTime.now())
                .inDays;
            final progressRate = g.progress / 100.0;
            final timeElapsed = DateTime.now().difference(g.createdAt).inDays;
            final totalDuration = g.targetDate.difference(g.createdAt).inDays;
            final timeProgress = totalDuration > 0
                ? timeElapsed / totalDuration
                : 0.0;

            return 'Goal: ${g.title}\n'
                'Progress: ${g.progress}%\n'
                'Status: ${g.status.name}\n'
                'Days until deadline: $daysUntilDeadline\n'
                'Time progress: ${(timeProgress * 100).toStringAsFixed(1)}%\n'
                'Progress rate: ${(progressRate * 100).toStringAsFixed(1)}%\n'
                'Priority: ${g.priority.name}\n';
          })
          .join('\n---\n');

      final prompt = [
        Content.text(
          'Analyze these goals and identify which ones are at risk:\n\n$progressData\n\n'
          'Focus on goals with:\n'
          '- Low progress relative to time elapsed\n'
          '- Approaching deadlines with insufficient progress\n'
          '- Stagnant or declining progress patterns\n'
          '- High priority goals that are behind schedule',
        ),
      ];

      final response = await model.generateContent(prompt);
      final responseText = response.text?.replaceAll('*', '').trim() ?? '';

      // Parse JSON response
      String jsonText = responseText.trim();
      if (jsonText.contains('```json')) {
        jsonText = jsonText.split('```json')[1].split('```')[0].trim();
      } else if (jsonText.contains('```')) {
        jsonText = jsonText.split('```')[1].split('```')[0].trim();
      }

      final jsonMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(jsonText);
      if (jsonMatch != null) {
        final jsonString = jsonMatch.group(0) ?? '[]';
        try {
          final risks = (jsonDecode(jsonString) as List)
              .map((r) => r as Map<String, dynamic>)
              .toList();
          if (mounted) {
            setState(() {
              _predictiveRisks = risks;
              _isLoadingRisks = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _predictiveRisks = [];
              _isLoadingRisks = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _predictiveRisks = [];
            _isLoadingRisks = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _predictiveRisks = [];
          _isLoadingRisks = false;
        });
      }
    }
  }

  Future<String> _getEmployeeDisplayName(User user) async {
    final fromAuth = (user.displayName ?? '').trim();
    if (fromAuth.isNotEmpty) return fromAuth;
    try {
      final profile = await DatabaseService.getUserProfile(user.uid);
      if (profile.displayName.isNotEmpty) {
        return profile.displayName;
      }
    } catch (_) {
      // Best-effort; fall back below.
    }
    return user.email ?? user.uid;
  }

  @override
  Widget build(BuildContext context) {
    // Get tutorial state from global service and update context
    final tutorialService = EmployeeTutorialService.instance;
    if (tutorialService.isTutorialActive) {
      tutorialService.setCurrentContext(context);
    }
    final tutorialParams = tutorialService.getTutorialParams();

    final sidebarItems = widget.forManagerGwMenu && widget.managerGwMenuRoute != null
        ? SidebarConfig.managerItems
        : SidebarConfig.employeeItems;
    final routeName =
        widget.forManagerGwMenu && widget.managerGwMenuRoute != null
            ? widget.managerGwMenuRoute!
            : '/alerts_nudges';
    return AppScaffold(
      title: 'Alerts & Nudges',
      showAppBar: false,
      embedded: widget.embedded,
      items: sidebarItems,
      currentRouteName: routeName,
      tutorialStepIndex: tutorialParams['tutorialStepIndex'] as int?,
      sidebarTutorialKeys: null,
      onTutorialNext: tutorialParams['onTutorialNext'] as VoidCallback?,
      onTutorialSkip: tutorialParams['onTutorialSkip'] as VoidCallback?,
      onNavigate: (route) {
        final current = ModalRoute.of(context)?.settings.name;
        if (current != route) {
          Navigator.pushNamed(context, route);
        }
      },
      onLogout: () async {
        final navigator = Navigator.of(context);
        await AuthService().signOut();
        if (mounted) {
          navigator.pushNamedAndRemoveUntil('/sign_in', (route) => false);
        }
      },
      content: AppComponents.backgroundWithImage(
        imagePath: 'assets/khono_bg.png',
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          physics: const AlwaysScrollableScrollPhysics(),
          child: StreamBuilder<String?>(
            stream: RoleService.instance.roleStream(),
            initialData: RoleService.instance.cachedRole ?? 'employee',
            builder: (context, roleSnapshot) {
              // role stream is observed to ensure auth context is alive; defaulting prevents spinners
              // Role is available via roleSnapshot.data or cachedRole if needed

              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                return Center(
                  child: Text(
                    'Please sign in to view alerts',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StreamBuilder<List<Alert>>(
                    stream: AlertService.getUserAlertsStream(user.uid),
                    initialData: _cachedAlerts,
                    builder: (context, alertsSnapshot) {
                      final streamedAlerts = alertsSnapshot.data;
                      // Update cache when fresh data arrives
                      if (streamedAlerts != null &&
                          streamedAlerts != _cachedAlerts) {
                        _cachedAlerts = streamedAlerts;
                      }

                      // Prefer cached alerts to avoid spinner on transient errors
                      if (alertsSnapshot.hasError && _cachedAlerts == null) {
                        final errorMessage = alertsSnapshot.error.toString();

                        // Check if it's a permission error
                        if (errorMessage.contains('permission-denied') ||
                            errorMessage.contains(
                              'Missing or insufficient permissions',
                            )) {
                          return _buildPermissionErrorState();
                        }

                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: AppColors.dangerColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading alerts',
                                style: AppTypography.heading4.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please try again later',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      final alerts = streamedAlerts ?? _cachedAlerts ?? [];

                      if (alerts.isEmpty &&
                          alertsSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          _cachedAlerts == null) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.activeColor,
                            ),
                          ),
                        );
                      }

                      // Filter: hide overdue goal alerts in this view
                      final filtered = alerts
                          .where((a) => a.type != AlertType.goalOverdue)
                          .toList();

                      return Column(
                        children: [
                          _buildAlertSummary(filtered),
                          const SizedBox(height: AppSpacing.lg),
                          _buildPredictiveRiskAlerts(),
                          const SizedBox(height: AppSpacing.lg),
                          _buildOneOnOneMeetingsSection(employeeId: user.uid),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Alerts',
                                style: AppTypography.heading3.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showAIChatAssistant(context, filtered),
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 18,
                                ),
                                label: const Text('AI Assistant'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.activeColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _buildAlertsList(filtered),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOneOnOneMeetingsSection({required String employeeId}) {
    return StreamBuilder<List<OneOnOneMeeting>>(
      stream: OneOnOneMeetingService.streamForEmployee(employeeId),
      initialData: _cachedMeetings,
      builder: (context, snapshot) {
        final incoming = snapshot.data;
        if (incoming != null && incoming != _cachedMeetings) {
          _cachedMeetings = incoming;
        }
        final meetings =
            incoming ?? _cachedMeetings ?? const <OneOnOneMeeting>[];

        // Show only relevant meetings:
        // - hide cancelled
        // - hide meetings whose time window has already passed
        // - keep unconfirmed/action-needed at the top
        final now = DateTime.now();
        final visible =
            meetings
                .where((m) => m.status != OneOnOneMeetingStatus.cancelled)
                .where((m) => !_isMeetingPast(m, now))
                .toList()
              ..sort((a, b) => _compareMeetingsForDisplay(a, b, now));

        // Keep this section compact.
        final top = visible.take(5).toList();

        if (top.isEmpty) {
          return const SizedBox.shrink();
        }

        return AppComponents.card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event, color: AppColors.activeColor),
                    const SizedBox(width: 8),
                    Text(
                      '1:1 Meetings',
                      style: AppTypography.heading4.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...top.map(_buildMeetingTile),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isMeetingPast(OneOnOneMeeting m, DateTime now) {
    // If we don't have a scheduled time yet, treat it as "unconfirmed" and keep it.
    final start = m.proposedStartDateTime;
    if (start == null) return false;

    // Prefer explicit end time; otherwise assume a reasonable default duration.
    final end = m.proposedEndDateTime ?? start.add(_defaultMeetingDuration);

    // Consider it "past" only once the end time has elapsed.
    return end.isBefore(now);
  }

  bool _needsEmployeeAction(OneOnOneMeeting m) {
    if (m.waitingOn != OneOnOneWaitingOn.employee) return false;
    // Employee needs to respond/ack in these states.
    return m.status == OneOnOneMeetingStatus.requested ||
        m.status == OneOnOneMeetingStatus.proposed ||
        m.status == OneOnOneMeetingStatus.rescheduled;
  }

  int _displayPriorityGroup(OneOnOneMeeting m) {
    // Lower is higher priority in the list.
    if (_needsEmployeeAction(m)) return 0; // unconfirmed + action needed
    if (m.waitingOn == OneOnOneWaitingOn.manager) return 1; // pending manager
    if (m.waitingOn == OneOnOneWaitingOn.none &&
        m.status == OneOnOneMeetingStatus.accepted) {
      return 2; // confirmed upcoming
    }
    return 3; // anything else
  }

  int _compareMeetingsForDisplay(
    OneOnOneMeeting a,
    OneOnOneMeeting b,
    DateTime now,
  ) {
    final g = _displayPriorityGroup(a).compareTo(_displayPriorityGroup(b));
    if (g != 0) return g;

    // Within same group, prefer earliest upcoming meetings first.
    final aStart = a.proposedStartDateTime;
    final bStart = b.proposedStartDateTime;

    if (aStart == null && bStart == null) {
      // Fall back to most recently updated first.
      return b.updatedAt.compareTo(a.updatedAt);
    }
    if (aStart == null) return 1; // no time goes after timed items
    if (bStart == null) return -1;
    return aStart.compareTo(bStart);
  }

  String _humanMeetingStatus(OneOnOneMeeting m) {
    switch (m.status) {
      case OneOnOneMeetingStatus.requested:
        return m.waitingOn == OneOnOneWaitingOn.manager
            ? 'Waiting for manager'
            : 'Waiting for your response';
      case OneOnOneMeetingStatus.proposed:
        return m.waitingOn == OneOnOneWaitingOn.employee
            ? 'Time proposed'
            : 'Waiting for manager';
      case OneOnOneMeetingStatus.accepted:
        return 'Confirmed';
      case OneOnOneMeetingStatus.rescheduled:
        return 'Reschedule requested';
      case OneOnOneMeetingStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _formatMeetingTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _formatMeetingRange(DateTime start, DateTime end) {
    String two(int n) => n.toString().padLeft(2, '0');
    String date(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
    String time(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    if (sameDay) return '${date(start)} ${time(start)} - ${time(end)}';
    return '${date(start)} ${time(start)} - ${date(end)} ${time(end)}';
  }

  Widget _buildMeetingTile(OneOnOneMeeting m) {
    final statusText = _humanMeetingStatus(m);
    final start = m.proposedStartDateTime;
    final end = m.proposedEndDateTime;
    final timeText = start == null
        ? null
        : (end != null
              ? _formatMeetingRange(start, end)
              : _formatMeetingTime(start));

    final canRespond =
        m.waitingOn == OneOnOneWaitingOn.employee &&
        (m.status == OneOnOneMeetingStatus.requested ||
            m.status == OneOnOneMeetingStatus.proposed);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FutureBuilder<String>(
                  future: _userDisplayName(m.managerId),
                  builder: (context, snap) {
                    final label = (snap.data != null && snap.data!.isNotEmpty)
                        ? snap.data!
                        : 'Manager';
                    return Text(
                      'From: $label',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.activeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.activeColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  statusText,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.activeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if ((m.agenda ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              m.agenda!.trim(),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (timeText != null) ...[
            const SizedBox(height: 6),
            Text(
              (m.status == OneOnOneMeetingStatus.accepted)
                  ? 'Confirmed: $timeText'
                  : 'Proposed: $timeText',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (canRespond) ...[
            const SizedBox(height: 10),
            _buildMeetingActions(m),
          ],
        ],
      ),
    );
  }

  Future<String> _userDisplayName(String uid) async {
    final cached = _userNameCache[uid];
    if (cached != null) return cached;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = snap.data();
      final name = (data?['displayName'] ?? data?['name'] ?? '')
          .toString()
          .trim();
      final resolved = name.isNotEmpty ? name : 'Manager';
      _userNameCache[uid] = resolved;
      return resolved;
    } catch (_) {
      return 'Manager';
    }
  }

  Widget _buildMeetingActions(OneOnOneMeeting m) {
    final isProposed = m.status == OneOnOneMeetingStatus.proposed;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: isProposed
                ? () => _acceptMeeting(m)
                : () => _ackRequest(m),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.activeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Text(isProposed ? 'Accept' : 'Acknowledge'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _suggestNewTime(m),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: Text(
              isProposed ? 'Suggest a different time' : 'Suggest a time',
            ),
          ),
        ),
      ],
    );
  }

  Future<String> _currentUserDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Employee';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snap.data();
      final name = (data?['displayName'] ?? data?['name'] ?? '')
          .toString()
          .trim();
      return name.isNotEmpty ? name : (user.displayName ?? 'Employee');
    } catch (_) {
      return user.displayName ?? 'Employee';
    }
  }

  Future<void> _acceptMeeting(OneOnOneMeeting m) async {
    try {
      await OneOnOneMeetingService.employeeAccept(meetingId: m.meetingId);
      await AlertService.createOneOnOneAcceptedAlertToManager(
        managerId: m.managerId,
        employeeId: m.employeeId,
        meetingId: m.meetingId,
        acceptedStartDateTime: m.proposedStartDateTime,
        acceptedEndDateTime: m.proposedEndDateTime,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Meeting accepted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not accept: $e')));
    }
  }

  Future<void> _suggestNewTime(OneOnOneMeeting m) async {
    try {
      final now = DateTime.now();
      final pickedDate = await showDatePicker(
        context: context,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
        initialDate: now.add(const Duration(days: 1)),
      );
      if (pickedDate == null) return;
      if (!mounted) return;

      final pickedStartTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      );
      if (pickedStartTime == null) return;
      if (!mounted) return;

      final proposedStart = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedStartTime.hour,
        pickedStartTime.minute,
      );

      final suggestedEnd = proposedStart.add(const Duration(minutes: 60));
      final pickedEndTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(suggestedEnd),
      );
      if (pickedEndTime == null) return;
      if (!mounted) return;

      final proposedEnd = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedEndTime.hour,
        pickedEndTime.minute,
      );

      if (!proposedEnd.isAfter(proposedStart)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time.')),
        );
        return;
      }

      await OneOnOneMeetingService.employeeSuggestNewTime(
        meetingId: m.meetingId,
        proposedStartDateTime: proposedStart,
        proposedEndDateTime: proposedEnd,
      );
      await AlertService.createOneOnOneRescheduledAlertToManager(
        managerId: m.managerId,
        employeeId: m.employeeId,
        meetingId: m.meetingId,
        proposedStartDateTime: proposedStart,
        proposedEndDateTime: proposedEnd,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reschedule sent to manager.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not suggest time: $e')));
    }
  }

  Future<void> _ackRequest(OneOnOneMeeting m) async {
    try {
      await OneOnOneMeetingService.employeeAcknowledgeRequest(
        meetingId: m.meetingId,
      );
      final employeeName = await _currentUserDisplayName();
      await AlertService.createGeneralAlert(
        userId: m.managerId,
        title: '1:1 Acknowledged',
        message:
            '$employeeName acknowledged your 1:1 request. Propose a time when you’re ready.',
        type: AlertType.oneOnOneRequested,
        priority: AlertPriority.low,
        actionText: 'View',
        actionRoute: '/manager_review_team_dashboard',
        actionData: {'meetingId': m.meetingId, 'employeeId': m.employeeId},
        fromUserId: m.employeeId,
        fromUserName: employeeName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Acknowledged.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not acknowledge: $e')));
    }
  }

  Widget _buildAlertSummary(List<Alert> alerts) {
    final unreadCount = alerts.where((alert) => !alert.isRead).length;
    final urgentCount = alerts
        .where((alert) => alert.priority == AlertPriority.urgent)
        .length;
    final dueSoonCount = alerts
        .where((alert) => alert.type == AlertType.goalDueSoon)
        .length;
    final overdueCount = alerts
        .where((alert) => alert.type == AlertType.goalOverdue)
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryChip(
            'Unread',
            unreadCount.toString(),
            AppColors.activeColor,
            icon: Icons.notifications,
            iconWidget: SizedBox(
              width: 45, // Match the size of other summary chip icons
              height: 45,
              child: Image.asset(
                'Email_Notification/Notification_Red_White.png', // Corrected path and filename
                fit: BoxFit.contain,
              ),
            ), // Replaced icon with iconWidget
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildSummaryChip(
            'Urgent',
            urgentCount.toString(),
            AppColors.dangerColor,
            iconWidget: SizedBox(
              width: 45, // Match the size of other summary chip icons
              height: 45,
              child: Image.asset(
                'Task_Management/Urgent.png',
                fit: BoxFit.contain,
              ),
            ), // Replaced icon with iconWidget
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildSummaryChip(
            'Due Soon',
            dueSoonCount.toString(),
            AppColors.warningColor,
            iconWidget: SizedBox(
              width: 45, // Match the size of other summary chip icons
              height: 45,
              child: Image.asset(
                'Calendar_Date_Picker/Date_Picker_Red_Badge_White.png', // Corrected path and filename
                fit: BoxFit.contain,
              ),
            ), // Replaced icon with iconWidget
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildSummaryChip(
            'Overdue',
            overdueCount.toString(),
            AppColors.dangerColor,
            iconWidget: SizedBox(
              width: 45, // Match the size of other summary chip icons
              height: 45,
              child: Image.asset(
                'Information_Detail/Information_Red_Badge_White.png', // Corrected path and filename
                fit: BoxFit.contain,
              ),
            ), // Replaced icon with iconWidget
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryChip(
    String label,
    String count,
    Color color, {
    IconData? icon,
    Widget? iconWidget,
  }) {
    return _HoverableSummaryChip(
      label: label,
      count: count,
      color: color,
      icon: icon,
      iconWidget: iconWidget,
    );
  }

  Widget _buildPredictiveRiskAlerts() {
    if (_isLoadingRisks) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.activeColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Analyzing goals for potential risks...',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_predictiveRisks == null || _predictiveRisks!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warningColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warningColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Predictive Risk Alerts',
                style: AppTypography.heading4.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _loadPredictiveRisks,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.activeColor,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isRiskAlertsExpanded = !_isRiskAlertsExpanded;
                  });
                },
                icon: Icon(
                  _isRiskAlertsExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                ),
                tooltip: _isRiskAlertsExpanded ? 'Collapse' : 'Expand',
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(_isRiskAlertsExpanded
                  ? _predictiveRisks!
                  : _predictiveRisks!.take(1))
              .map((risk) {
                final riskLevel =
                    risk['riskLevel']?.toString().toLowerCase() ?? 'medium';
                Color riskColor;
                if (riskLevel == 'high') {
                  riskColor = AppColors.dangerColor;
                } else if (riskLevel == 'medium') {
                  riskColor = AppColors.warningColor;
                } else {
                  riskColor = AppColors.infoColor;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: riskColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: riskColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                riskLevel.toUpperCase(),
                                style: AppTypography.bodySmall.copyWith(
                                  color: riskColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                risk['goalTitle']?.toString() ?? 'Unknown Goal',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          risk['riskDescription']?.toString() ??
                              'No description available',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.activeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: AppColors.activeColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  risk['recommendedAction']?.toString() ??
                                      'Review this goal',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.activeColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          if (!_isRiskAlertsExpanded && _predictiveRisks!.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${_predictiveRisks!.length - 1} more risk${_predictiveRisks!.length - 1 == 1 ? '' : 's'} identified',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertsList(List<Alert> alerts) {
    if (alerts.isEmpty) {
      return _buildEmptyAlertsState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (alerts.any((alert) => !alert.isRead))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await AlertService.markAllAsRead(user.uid);
                }
              },
              child: Text(
                'Mark All Read',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.activeColor,
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        ...alerts.map((alert) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildAlertCard(alert),
          );
        }),
      ],
    );
  }

  Widget _buildEmptyAlertsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Alerts Yet',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see notifications about your goals, achievements, and team updates here.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/my_goal_workspace');
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Your First Goal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.activeColor,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _removeEmojis(String text) {
    // Remove emojis using regex pattern
    return text
        .replaceAll(
          RegExp(
            r'[\u{1F300}-\u{1F9FF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F900}-\u{1F9FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{1F191}-\u{1F251}]|[\u{2934}-\u{2935}]|[\u{2B05}-\u{2B07}]|[\u{2B1B}-\u{2B1C}]|[\u{3297}-\u{3299}]|[\u{303D}]|[\u{00A9}]|[\u{00AE}]|[\u{203C}]|[\u{2049}]|[\u{2122}]|[\u{2139}]|[\u{2194}-\u{2199}]|[\u{21A9}-\u{21AA}]|[\u{231A}-\u{231B}]|[\u{2328}]|[\u{23CF}]|[\u{23E9}-\u{23F3}]|[\u{23F8}-\u{23FA}]|[\u{24C2}]|[\u{25AA}-\u{25AB}]|[\u{25B6}]|[\u{25C0}]|[\u{25FB}-\u{25FE}]|[\u{2600}-\u{2604}]|[\u{260E}]|[\u{2611}]|[\u{2614}-\u{2615}]|[\u{2618}]|[\u{261D}]|[\u{2620}]|[\u{2622}-\u{2623}]|[\u{2626}]|[\u{262A}]|[\u{262E}-\u{262F}]|[\u{2638}-\u{263A}]|[\u{2640}]|[\u{2642}]|[\u{2648}-\u{2653}]|[\u{2660}]|[\u{2663}]|[\u{2665}-\u{2666}]|[\u{2668}]|[\u{267B}]|[\u{267F}]|[\u{2692}-\u{2697}]|[\u{2699}]|[\u{269B}-\u{269C}]|[\u{26A0}-\u{26A1}]|[\u{26AA}-\u{26AB}]|[\u{26B0}-\u{26B1}]|[\u{26BD}-\u{26BE}]|[\u{26C4}-\u{26C5}]|[\u{26C8}]|[\u{26CE}-\u{26CF}]|[\u{26D1}]|[\u{26D3}-\u{26D4}]|[\u{26E9}-\u{26EA}]|[\u{26F0}-\u{26F5}]|[\u{26F7}-\u{26FA}]|[\u{26FD}]|[\u{2702}]|[\u{2705}]|[\u{2708}-\u{270D}]|[\u{270F}]|[\u{2712}]|[\u{2714}]|[\u{2716}]|[\u{271D}]|[\u{2721}]|[\u{2728}]|[\u{2733}-\u{2734}]|[\u{2744}]|[\u{2747}]|[\u{274C}]|[\u{274E}]|[\u{2753}-\u{2755}]|[\u{2757}]|[\u{2763}-\u{2764}]|[\u{2795}-\u{2797}]|[\u{27A1}]|[\u{27B0}]|[\u{27BF}]|[\u{2934}-\u{2935}]|[\u{2B05}-\u{2B07}]|[\u{2B1B}-\u{2B1C}]|[\u{2B50}]|[\u{2B55}]|[\u{3030}]|[\u{303D}]|[\u{3297}]|[\u{3299}]',
            unicode: true,
          ),
          '',
        )
        .trim();
  }

  Widget _buildAlertTitleWithIcon(String title, AlertType type) {
    final cleanTitle = _removeEmojis(title);
    final isBadgeEarned =
        type == AlertType.badgeEarned ||
        cleanTitle.toLowerCase().contains('badges earned') ||
        cleanTitle.toLowerCase().contains('badge earned');

    if (isBadgeEarned) {
      return Row(
        children: [
          Icon(Icons.emoji_events, size: 18, color: AppColors.warningColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              cleanTitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      cleanTitle,
      style: AppTypography.bodyMedium.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildAlertCard(Alert alert) {
    final alertColor = _getAlertColor(alert.type, alert.priority);
    final alertIcon = _getAlertIcon(alert.type);
    final isManagerNudge = alert.type == AlertType.managerNudge;
    final hasGoal = _hasGoal(alert);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: alert.isRead
              ? Colors.white.withValues(alpha: 0.2)
              : alertColor.withValues(alpha: 0.3),
          width: alert.isRead ? 1 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: alertIcon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildAlertTitleWithIcon(
                            alert.title,
                            alert.type,
                          ),
                        ),
                        if (!alert.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.activeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _removeEmojis(alert.message),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _getTimeAgo(alert.createdAt),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        if (alert.fromUserName != null) ...[
                          Text(
                            ' • from ${alert.fromUserName}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: alertColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            alert.priority.name.toUpperCase(),
                            style: AppTypography.bodySmall.copyWith(
                              color: alertColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (alert.actionText != null && (!isManagerNudge || hasGoal)) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await AlertService.markAsRead(alert.id);

                      if (!mounted) return;

                      if (alert.type == AlertType.managerNudge) {
                        await _showManagerNudgeDialog(alert);
                        return;
                      }

                      await _handleAlertNavigation(alert);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: alertColor,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(alert.actionText!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await AlertService.dismissAlert(alert.id);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleAlertNavigation(Alert alert) async {
    final navigator = Navigator.of(context);

    if (alert.type == AlertType.badgeEarned) {
      final opened = await _openBadgeFromAlert(alert);
      if (opened) return;
    }

    // Check if this alert is goal-related (has relatedGoalId or goalId in actionData)
    final goalId = alert.actionData != null
        ? (alert.actionData!['goalId'] as String?)
        : null;
    final relatedGoalId = alert.relatedGoalId;
    final targetGoalId = goalId ?? relatedGoalId;
    final actionRoute = alert.actionRoute;

    Future<void> openRouteIfAny() async {
      if (actionRoute != null) {
        var route = actionRoute;
        if (route == '/team_challenges_seasons') {
          route = '/season_challenges';
        }
        // Never send users to the goal creation workspace as a fallback for
        // goal-related alerts. If we couldn't open the goal detail, take them
        // to the employee dashboard where goals are listed.
        if (route == '/my_goal_workspace' &&
            targetGoalId != null &&
            targetGoalId.isNotEmpty) {
          route = '/employee_dashboard';
        }
        navigator.pushNamed(route);
      }
    }

    // Helper to navigate to goal detail when doc exists
    Future<bool> openGoalDetail(String gid) async {
      try {
        DocumentSnapshot<Map<String, dynamic>>? doc;
        try {
          doc = await FirebaseFirestore.instance
              .collection('goals')
              .doc(gid)
              .get();
        } on FirebaseException catch (fe) {
          // Some deployments mistakenly allow queries (list) but deny direct get.
          // If that happens, try an owner-scoped query as a fallback.
          if (fe.code == 'permission-denied') {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null && uid.isNotEmpty) {
              final q = await FirebaseFirestore.instance
                  .collection('goals')
                  .where('userId', isEqualTo: uid)
                  .where(FieldPath.documentId, isEqualTo: gid)
                  .limit(1)
                  .get();
              if (q.docs.isNotEmpty) {
                doc = q.docs.first;
              } else {
                rethrow;
              }
            } else {
              rethrow;
            }
          } else {
            rethrow;
          }
        }
        if (!mounted) return true; // stop further work
        if (!doc.exists) {
          return false;
        }

        final data = doc.data();
        final approvalStatus = (data?['approvalStatus'] ?? '')
            .toString()
            .toLowerCase();
        if (approvalStatus == GoalApprovalStatus.rejected.name.toLowerCase()) {
          final reason = (data?['rejectionReason'] ?? '').toString().trim();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  reason.isNotEmpty
                      ? 'This goal was rejected and cannot be viewed. Reason: $reason'
                      : 'This goal was rejected and cannot be viewed.',
                ),
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return true; // handled
        }

        late final Goal goal;
        try {
          goal = Goal.fromFirestore(doc);
        } catch (_) {
          // Fallback to tolerate older/odd schemas
          final raw = doc.data();
          if (raw is Map<String, dynamic>) {
            goal = Goal.fromMap(raw, id: doc.id);
          } else {
            return false;
          }
        }
        navigator.push(
          MaterialPageRoute(builder: (context) => GoalDetailScreen(goal: goal)),
        );
        return true;
      } catch (e) {
        if (e is FirebaseException && e.code == 'permission-denied') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'You don’t have access to view this goal right now.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return false;
        }
        developer.log('Error navigating to goal: $e');
      }
      return false;
    }

    // If we have a goalId, always try to open the detail screen
    if (targetGoalId != null && targetGoalId.isNotEmpty) {
      // If the alert itself is a rejection notice, don't open details.
      if (alert.type == AlertType.goalApprovalRejected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                alert.message.isNotEmpty
                    ? alert.message
                    : 'This goal was rejected and cannot be viewed.',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final opened = await openGoalDetail(targetGoalId);
      if (opened) return;

      // Could not open goal detail; show notice then go to a safe screen
      // (never to the goal creation workspace).
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open goal (id: $targetGoalId). Please retry or update the goal list.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      if (mounted) {
        navigator.pushNamed('/employee_dashboard');
      }
      return;
    }

    // No goal id available: fall back to route-based navigation if provided.
    if (actionRoute != null) {
      await openRouteIfAny();
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No goal linked to this alert.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  badge_model.BadgeCategory? _employeeCategoryFromName(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    try {
      final c = badge_model.BadgeCategory.values.firstWhere((e) => e.name == s);
      switch (c) {
        case badge_model.BadgeCategory.goalMastery:
        case badge_model.BadgeCategory.consistency:
        case badge_model.BadgeCategory.growth:
        case badge_model.BadgeCategory.milestones:
        case badge_model.BadgeCategory.collaboration:
          return c;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  String _employeeCategoryTitle(badge_model.BadgeCategory c) {
    switch (c) {
      case badge_model.BadgeCategory.goalMastery:
        return 'Goal Mastery';
      case badge_model.BadgeCategory.consistency:
        return 'Consistency';
      case badge_model.BadgeCategory.growth:
        return 'Growth';
      case badge_model.BadgeCategory.milestones:
        return 'Milestones';
      case badge_model.BadgeCategory.collaboration:
        return 'Collaboration';
      default:
        return 'Badges';
    }
  }

  Future<bool> _openBadgeFromAlert(Alert alert) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return false;

      final data = alert.actionData ?? const <String, dynamic>{};
      final badgeId = (data['badgeId'] ?? data['badgeDocId'] ?? '')
          .toString()
          .trim();
      if (badgeId.isEmpty) return false;

      String? categoryName = data['badgeCategory']?.toString().trim();
      if (categoryName == null || categoryName.isEmpty) {
        try {
          final doc = await FirestoreSafe.getDoc(
            FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('badges')
                .doc(badgeId),
          );
          categoryName = doc.data()?['category']?.toString().trim();
        } catch (_) {}
      }
      if (categoryName == null || categoryName.isEmpty) {
        // Fallback for alerts that store a base badge id (e.g. season badges)
        // where the actual doc id differs.
        try {
          final q = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('badges')
              .where('criteria.badgeId', isEqualTo: badgeId)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            categoryName = q.docs.first.data()['category']?.toString().trim();
          }
        } catch (_) {}
      }

      final category = _employeeCategoryFromName(categoryName);
      if (category == null) return false;

      if (!mounted) return false;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BadgeCategoryDetailScreen(
            category: category,
            title: _employeeCategoryTitle(category),
            embedded: widget.embedded,
            initialBadgeId: badgeId,
          ),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showManagerNudgeDialog(Alert alert) async {
    final responseController = TextEditingController();
    String? selectedReaction;
    bool sendingReaction = false;
    bool sendingResponse = false;

    Future<void> sendReaction(
      String reaction,
      StateSetter setDialogState,
    ) async {
      if (sendingReaction) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      setDialogState(() {
        selectedReaction = reaction;
        sendingReaction = true;
      });

      try {
        final employeeName = await _getEmployeeDisplayName(user);
        await ManagerRealtimeService.recordEmployeeActivity(
          employeeId: user.uid,
          activityType: 'nudge_reaction',
          description: 'Reacted "$reaction" to manager nudge',
          metadata: {
            'alertId': alert.id,
            // Sender-first metadata works for admin->manager workspace and
            // manager->employee flows alike.
            'senderId': alert.fromUserId,
            'senderName': alert.fromUserName,
            'senderNameLower': (alert.fromUserName ?? '').trim().toLowerCase(),
            // Backward compatibility for existing inbox filters/analytics.
            'managerId': alert.fromUserId,
            'managerName': alert.fromUserName,
            'managerNameLower': (alert.fromUserName ?? '').trim().toLowerCase(),
            'employeeName': employeeName,
            'employeeNameLower': employeeName.toLowerCase(),
            'reaction': reaction,
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Reaction recorded'),
              backgroundColor: AppColors.activeColor,
            ),
          );
        }
      } catch (e, st) {
        developer.log(
          'Failed to send nudge reaction for alert ${alert.id}: $e',
          stackTrace: st,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not record reaction. Please try again.',
              ),
              backgroundColor: AppColors.dangerColor,
            ),
          );
        }
      } finally {
        setDialogState(() {
          sendingReaction = false;
        });
      }
    }

    Future<void> sendResponse(
      StateSetter setDialogState,
      BuildContext dialogContext,
    ) async {
      final response = responseController.text.trim();
      if (response.isEmpty || sendingResponse) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (dialogContext.mounted) {
        setDialogState(() {
          sendingResponse = true;
        });
      }

      try {
        final employeeName = await _getEmployeeDisplayName(user);
        await ManagerRealtimeService.recordEmployeeActivity(
          employeeId: user.uid,
          activityType: 'nudge_response',
          description: 'Responded to manager nudge',
          metadata: {
            'alertId': alert.id,
            // Sender-first metadata works for admin->manager workspace and
            // manager->employee flows alike.
            'senderId': alert.fromUserId,
            'senderName': alert.fromUserName,
            'senderNameLower': (alert.fromUserName ?? '').trim().toLowerCase(),
            // Backward compatibility for existing inbox filters/analytics.
            'managerId': alert.fromUserId,
            'managerName': alert.fromUserName,
            'managerNameLower': (alert.fromUserName ?? '').trim().toLowerCase(),
            'employeeName': employeeName,
            'employeeNameLower': employeeName.toLowerCase(),
            'response': response,
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Response sent'),
              backgroundColor: AppColors.activeColor,
            ),
          );
        }
        if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
          Navigator.of(dialogContext).pop();
        }
      } catch (e, st) {
        developer.log(
          'Failed to send nudge response for alert ${alert.id}: $e',
          stackTrace: st,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not send response. Please try again.'),
              backgroundColor: AppColors.dangerColor,
            ),
          );
        }
        if (dialogContext.mounted) {
          setDialogState(() {
            sendingResponse = false;
          });
        }
      }
    }

    try {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (dialogContext) {
          final senderName = alert.fromUserName ?? 'Admin / Manager';
          final reactions = <String>[
            '👍 On it',
            '🙏 Thanks',
            '✅ Done',
            '❓ Need help',
          ];

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: Colors.black.withValues(alpha: 0.75),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                title: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.activeColor.withValues(
                        alpha: 0.15,
                      ),
                      child: Text(
                        senderName.isNotEmpty
                            ? senderName[0].toUpperCase()
                            : 'M',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.activeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nudge from $senderName',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _getTimeAgo(alert.createdAt),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          _removeEmojis(alert.message),
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Quick reaction',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: reactions.map((reaction) {
                          final isSelected = selectedReaction == reaction;
                          return ChoiceChip(
                            label: Text(reaction),
                            selected: isSelected,
                            onSelected: (_) =>
                                sendReaction(reaction, setDialogState),
                            selectedColor: AppColors.activeColor.withValues(
                              alpha: 0.2,
                            ),
                            labelStyle: AppTypography.bodySmall.copyWith(
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Respond to your manager',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: responseController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Share an update or ask for support...',
                          hintStyle: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: AppColors.activeColor,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        enabled: !sendingResponse,
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (_hasGoal(alert)) ...[
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _handleAlertNavigation(alert);
                      },
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: const Text('View Goal'),
                    ),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                  ElevatedButton.icon(
                    onPressed: sendingResponse
                        ? null
                        : () => sendResponse(setDialogState, dialogContext),
                    icon: sendingResponse
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.textPrimary,
                              ),
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: Text(
                      sendingResponse ? 'Sending...' : 'Send Response',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.activeColor,
                      foregroundColor: AppColors.textPrimary,
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      responseController.dispose();
    }
  }

  Color _getAlertColor(AlertType type, AlertPriority priority) {
    switch (priority) {
      case AlertPriority.urgent:
        return AppColors.dangerColor;
      case AlertPriority.high:
        return AppColors.warningColor;
      case AlertPriority.medium:
        return AppColors.activeColor;
      case AlertPriority.low:
        return AppColors.successColor;
    }
  }

  bool _hasGoal(Alert alert) {
    final goalId = alert.actionData != null
        ? (alert.actionData!['goalId'] as String?)
        : alert.relatedGoalId;
    return goalId != null && goalId.isNotEmpty;
  }

  Widget _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.goalCreated:
        return SizedBox(
          width: 45,
          height: 45,
          child: Image.asset(
            'Business_Growth_Development/Growth_Development_Red.png',
            fit: BoxFit.contain,
          ),
        );
      case AlertType.goalCompleted:
        return Icon(Icons.check_circle);
      case AlertType.goalApprovalRequested:
        return Icon(Icons.pending_actions);
      case AlertType.goalApprovalApproved:
        return Icon(Icons.check_circle_outline);
      case AlertType.goalApprovalRejected:
        return Icon(Icons.cancel);
      case AlertType.goalDueSoon:
        return Icon(Icons.schedule);
      case AlertType.goalOverdue:
        return Icon(Icons.warning);
      case AlertType.inactivity:
        return Icon(Icons.notifications_active_outlined);
      case AlertType.milestoneRisk:
        return Icon(Icons.warning_amber_outlined);
      case AlertType.pointsEarned:
        return Icon(Icons.stars);
      case AlertType.levelUp:
        return Icon(Icons.trending_up);
      case AlertType.badgeEarned:
        return Icon(Icons.workspace_premium);
      case AlertType.teamAssigned:
        return Icon(Icons.group_add);
      case AlertType.managerNudge:
        return Icon(Icons.notifications_active);
      case AlertType.achievementUnlocked:
        return Icon(Icons.emoji_events);
      case AlertType.streakMilestone:
        return Icon(Icons.local_fire_department);
      case AlertType.deadlineReminder:
        return Icon(Icons.access_time);
      case AlertType.teamGoalAvailable:
        return Icon(Icons.group_work);
      case AlertType.employeeJoinedTeamGoal:
        return Icon(Icons.group_add);
      case AlertType.seasonJoined:
        return Icon(Icons.flag_circle);
      case AlertType.seasonProgressUpdate:
        return Icon(Icons.timeline);
      case AlertType.seasonCompleted:
        return Icon(Icons.emoji_events_outlined);
      case AlertType.goalMilestoneCompleted:
        return Icon(Icons.fact_check);
      case AlertType.milestoneDeletionRequest:
        return Icon(Icons.info_outline);
      case AlertType.milestoneDeleted:
        return Icon(Icons.info_outline);
      case AlertType.milestoneDeletionRejected:
        return Icon(Icons.block);
      case AlertType.managerGeneral:
        return Icon(Icons.notifications);
      case AlertType.oneOnOneRequested:
        return Icon(Icons.event_note);
      case AlertType.oneOnOneProposed:
        return Icon(Icons.event_available);
      case AlertType.oneOnOneAccepted:
        return Icon(Icons.event_available_outlined);
      case AlertType.oneOnOneRescheduled:
        return Icon(Icons.event_repeat);
      case AlertType.oneOnOneCancelled:
        return Icon(Icons.event_busy);
      case AlertType.recognition:
        return Icon(Icons.emoji_events);
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildPermissionErrorState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.security, size: 48, color: AppColors.warningColor),
          const SizedBox(height: 16),
          Text(
            'Alerts Setup Required',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The alerts system needs to be configured by your administrator. In the meantime, you can still use all other features of the app.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'You\'ll be notified when alerts are available!',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.warningColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAIChatAssistant(
    BuildContext context,
    List<Alert> alerts,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get user profile for profile picture
    UserProfile? userProfile;
    try {
      userProfile = await DatabaseService.getUserProfile(user.uid);
    } catch (e) {
      // Continue without profile if fetch fails
    }

    final TextEditingController messageController = TextEditingController();
    final TextEditingController editController = TextEditingController();
    final List<Map<String, String>> chatHistory = [];
    bool isGenerating = false;
    int? editingIndex;
    final String? profilePhotoUrl = userProfile?.profilePhotoUrl;

    await showDialog<void>(
      // ignore: use_build_context_synchronously
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendMessage(
              String message, {
              int? replaceIndex,
            }) async {
              if (message.trim().isEmpty || isGenerating) return;

              if (replaceIndex != null && replaceIndex < chatHistory.length) {
                // Replace existing message (edit) and remove AI response that followed
                setDialogState(() {
                  chatHistory[replaceIndex] = {
                    'role': 'user',
                    'content': message,
                  };
                  // Remove AI response that came after this message (if any)
                  if (replaceIndex + 1 < chatHistory.length &&
                      chatHistory[replaceIndex + 1]['role'] == 'assistant') {
                    chatHistory.removeAt(replaceIndex + 1);
                  }
                  editingIndex = null;
                  editController.clear();
                  isGenerating = true;
                });
              } else {
                // Add new message
                setDialogState(() {
                  chatHistory.add({'role': 'user', 'content': message});
                  isGenerating = true;
                });
              }

              try {
                // Get goals for context
                final goals = await DatabaseService.getUserGoals(user.uid);
                final goalsContext = goals
                    .map((g) {
                      final daysUntilDeadline = g.targetDate
                          .difference(DateTime.now())
                          .inDays;
                      // ignore: unnecessary_brace_in_string_interps
                      return '${g.title}: ${g.progress}% complete, ${daysUntilDeadline} days until deadline, ${g.status.name}';
                    })
                    .join('\n');

                final alertsContext = alerts
                    .map((a) {
                      return '${a.title}: ${a.message} (${a.priority.name} priority, ${a.type.name})';
                    })
                    .join('\n');

                final model = FirebaseAI.googleAI().generativeModel(
                  model: 'gemini-2.5-flash',
                  systemInstruction: Content.text(
                    'You are an AI assistant specialized in helping users understand, prioritize, and act on their alerts and goals. '
                    'You have access to the user\'s alerts and goals data. '
                    'Help users by:\n'
                    '1. Explaining what their alerts mean\n'
                    '2. Suggesting which alerts to prioritize\n'
                    '3. Recommending actions based on alerts\n'
                    '4. Answering questions about their goals and progress\n'
                    '5. Providing context and insights about their alert patterns\n\n'
                    'Be conversational, helpful, and actionable. Keep responses concise but informative.',
                  ),
                );

                final conversationHistory = chatHistory
                    .where(
                      (msg) =>
                          msg['role'] == 'user' || msg['role'] == 'assistant',
                    )
                    .map((msg) => Content.text(msg['content'] ?? ''))
                    .toList();

                final prompt = [
                  Content.text(
                    'User\'s Current Alerts:\n$alertsContext\n\n'
                    'User\'s Goals:\n$goalsContext\n\n'
                    'User Question: $message\n\n'
                    'Please help the user understand and act on their alerts and goals.',
                  ),
                  ...conversationHistory,
                ];

                final response = await model.generateContent(prompt);
                final assistantMessage =
                    response.text?.replaceAll('*', '').trim() ??
                    'I apologize, but I couldn\'t generate a response. Please try again.';

                setDialogState(() {
                  chatHistory.add({
                    'role': 'assistant',
                    'content': assistantMessage,
                  });
                  isGenerating = false;
                });
              } catch (e) {
                setDialogState(() {
                  chatHistory.add({
                    'role': 'assistant',
                    'content':
                        'Sorry, I encountered an error. Please try again.',
                  });
                  isGenerating = false;
                });
              }
            }

            return AlertDialog(
              backgroundColor: Colors.black.withValues(alpha: 0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              content: SizedBox(
                width: 500,
                height: 400,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: chatHistory.isEmpty ? 1 : chatHistory.length,
                        itemBuilder: (context, index) {
                          if (chatHistory.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  ClipOval(
                                    child: Image.asset(
                                      'assets/videos/Ai_Avatar.gif',
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Ask me anything about your alerts!',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'I can help you understand, prioritize, and act on your alerts and goals.',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }

                          final message = chatHistory[index];
                          final isUser = message['role'] == 'user';
                          final isEditing = editingIndex == index && isUser;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: isEditing
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: editController,
                                          autofocus: true,
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                              ),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: AppColors.activeColor
                                                .withValues(alpha: 0.3),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: Colors.white.withValues(
                                                  alpha: 0.1,
                                                ),
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: Colors.white.withValues(
                                                  alpha: 0.1,
                                                ),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: AppColors.activeColor,
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.all(12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () {
                                          final editedText = editController.text
                                              .trim();
                                          if (editedText.isNotEmpty) {
                                            sendMessage(
                                              editedText,
                                              replaceIndex: index,
                                            );
                                          } else {
                                            setDialogState(() {
                                              editingIndex = null;
                                              editController.clear();
                                            });
                                          }
                                        },
                                        icon: Image.asset(
                                          'assets/Send_Paper_Plane/Send_Plane_Red_Badge_White.png',
                                          width: 24,
                                          height: 24,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          setDialogState(() {
                                            editingIndex = null;
                                            editController.clear();
                                          });
                                        },
                                        icon: Icon(
                                          Icons.close,
                                          color: AppColors.textSecondary,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: isUser
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (!isUser) ...[
                                        ClipOval(
                                          child: Image.asset(
                                            'assets/videos/Ai_Avatar.gif',
                                            width: 32,
                                            height: 32,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Flexible(
                                        child: GestureDetector(
                                          onLongPress: () {
                                            // Copy to clipboard
                                            Clipboard.setData(
                                              ClipboardData(
                                                text: message['content'] ?? '',
                                              ),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  isUser
                                                      ? 'Message copied'
                                                      : 'Response copied',
                                                ),
                                                duration: const Duration(
                                                  seconds: 2,
                                                ),
                                                backgroundColor:
                                                    AppColors.activeColor,
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isUser
                                                  ? AppColors.activeColor
                                                        .withValues(alpha: 0.3)
                                                  : Colors.black.withValues(
                                                      alpha: 0.4,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.1,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    message['content'] ?? '',
                                                    style: AppTypography
                                                        .bodyMedium
                                                        .copyWith(
                                                          color: AppColors
                                                              .textPrimary,
                                                        ),
                                                  ),
                                                ),
                                                if (isUser) ...[
                                                  const SizedBox(width: 8),
                                                  PopupMenuButton<String>(
                                                    icon: Icon(
                                                      Icons.more_vert,
                                                      color: AppColors
                                                          .textSecondary,
                                                      size: 16,
                                                    ),
                                                    onSelected: (value) {
                                                      if (value == 'copy') {
                                                        Clipboard.setData(
                                                          ClipboardData(
                                                            text:
                                                                message['content'] ??
                                                                '',
                                                          ),
                                                        );
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: const Text(
                                                              'Message copied',
                                                            ),
                                                            duration:
                                                                const Duration(
                                                                  seconds: 2,
                                                                ),
                                                            backgroundColor:
                                                                AppColors
                                                                    .activeColor,
                                                          ),
                                                        );
                                                      } else if (value ==
                                                          'edit') {
                                                        setDialogState(() {
                                                          editingIndex = index;
                                                          editController.text =
                                                              message['content'] ??
                                                              '';
                                                        });
                                                      }
                                                    },
                                                    itemBuilder: (context) => [
                                                      const PopupMenuItem(
                                                        value: 'copy',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons.copy,
                                                              size: 18,
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text('Copy'),
                                                          ],
                                                        ),
                                                      ),
                                                      const PopupMenuItem(
                                                        value: 'edit',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons.edit,
                                                              size: 18,
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text('Edit'),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ] else ...[
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    icon: Icon(
                                                      Icons.copy,
                                                      color: AppColors
                                                          .textSecondary,
                                                      size: 16,
                                                    ),
                                                    onPressed: () {
                                                      Clipboard.setData(
                                                        ClipboardData(
                                                          text:
                                                              message['content'] ??
                                                              '',
                                                        ),
                                                      );
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: const Text(
                                                            'Response copied',
                                                          ),
                                                          duration:
                                                              const Duration(
                                                                seconds: 2,
                                                              ),
                                                          backgroundColor:
                                                              AppColors
                                                                  .activeColor,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (isUser) ...[
                                        const SizedBox(width: 8),
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: AppColors.activeColor
                                              .withValues(alpha: 0.2),
                                          backgroundImage:
                                              (profilePhotoUrl != null &&
                                                  profilePhotoUrl.isNotEmpty)
                                              ? NetworkImage(profilePhotoUrl)
                                              : null,
                                          child:
                                              (profilePhotoUrl == null ||
                                                  profilePhotoUrl.isEmpty)
                                              ? Icon(
                                                  Icons.person,
                                                  color: AppColors.activeColor,
                                                  size: 18,
                                                )
                                              : null,
                                        ),
                                      ],
                                    ],
                                  ),
                          );
                        },
                      ),
                    ),
                    if (isGenerating)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.activeColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI is thinking...',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: messageController,
                            enabled: !isGenerating && editingIndex == null,
                            decoration: InputDecoration(
                              hintText: 'Ask about your alerts...',
                              hintStyle: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: AppColors.activeColor,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            onSubmitted: (value) {
                              sendMessage(value);
                              messageController.clear();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: isGenerating || editingIndex != null
                              ? null
                              : () {
                                  final message = messageController.text.trim();
                                  if (message.isNotEmpty) {
                                    sendMessage(message);
                                    messageController.clear();
                                  }
                                },
                          icon: Image.asset(
                            'assets/Send_Paper_Plane/Send_Plane_Red_Badge_White.png',
                            width: 24,
                            height: 24,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.activeColor.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Close',
                    style: TextStyle(color: AppColors.activeColor),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _HoverableSummaryChip extends StatefulWidget {
  final String label;
  final String count;
  final Color color;
  final IconData? icon;
  final Widget? iconWidget;

  const _HoverableSummaryChip({
    required this.label,
    required this.count,
    required this.color,
    this.icon,
    this.iconWidget,
  });

  @override
  State<_HoverableSummaryChip> createState() => _HoverableSummaryChipState();
}

class _HoverableSummaryChipState extends State<_HoverableSummaryChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isHovered
              ? widget.color.withValues(alpha: 0.2)
              : widget.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.5)
                : widget.color.withValues(alpha: 0.3),
            width: _isHovered ? 2 : 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Transform.translate(
          offset: _isHovered ? const Offset(0, -2) : Offset.zero,
          child: Column(
            children: [
              AnimatedScale(
                scale: _isHovered ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child:
                    widget.iconWidget ??
                    Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(height: 4),
              Text(
                widget.count,
                style: AppTypography.heading4.copyWith(
                  color: widget.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.label,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildEmptyAlertsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Alerts Yet',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see notifications about your goals, achievements, and team updates here.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/my_goal_workspace');
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Your First Goal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.activeColor,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildAlertCard(Alert alert) {
    final alertColor = _getAlertColor(alert.type, alert.priority);
    final alertIcon = _getAlertIcon(alert.type);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: alert.isRead
              ? Colors.white.withValues(alpha: 0.2)
              : alertColor.withValues(alpha: 0.3),
          width: alert.isRead ? 1 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: alertIcon, // Directly use the returned widget
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!alert.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.activeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _getTimeAgo(alert.createdAt),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        if (alert.fromUserName != null) ...[
                          Text(
                            ' • from ${alert.fromUserName}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: alertColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            alert.priority.name.toUpperCase(),
                            style: AppTypography.bodySmall.copyWith(
                              color: alertColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (alert.actionText != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Mark as read when action is taken
                      await AlertService.markAsRead(alert.id);

                      if (!mounted) return;

                      final navigator = Navigator.of(context);
                      final goalId = alert.actionData != null
                          ? (alert.actionData!['goalId'] as String?)
                          : null;
                      final relatedGoalId = alert.relatedGoalId;
                      final targetGoalId = goalId ?? relatedGoalId;

                      // For rejection alerts: report and stop.
                      if (alert.type == AlertType.goalApprovalRejected) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                alert.message.isNotEmpty
                                    ? alert.message
                                    : 'This goal was rejected and cannot be viewed.',
                              ),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                        return;
                      }

                      // If we have a goal id, attempt to open its detail view.
                      if (targetGoalId != null && targetGoalId.isNotEmpty) {
                        try {
                          final doc = await FirebaseFirestore.instance
                              .collection('goals')
                              .doc(targetGoalId)
                              .get();
                          if (!mounted) return;
                          if (doc.exists) {
                            late final Goal goal;
                            try {
                              goal = Goal.fromFirestore(doc);
                            } catch (_) {
                              final raw = doc.data();
                              if (raw is Map<String, dynamic>) {
                                goal = Goal.fromMap(raw, id: doc.id);
                              } else {
                                throw Exception('Invalid goal data');
                              }
                            }

                            if (goal.approvalStatus ==
                                GoalApprovalStatus.rejected) {
                              final reason = (goal.rejectionReason ?? '')
                                  .trim();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    reason.isNotEmpty
                                        ? 'This goal was rejected and cannot be viewed. Reason: $reason'
                                        : 'This goal was rejected and cannot be viewed.',
                                  ),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                              return;
                            }

                            navigator.push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    GoalDetailScreen(goal: goal),
                              ),
                            );
                            return;
                          }
                        } catch (_) {
                          // Fall through to route navigation below
                        }
                      }

                      // Fallback to route-based navigation if provided.
                      final actionRoute = alert.actionRoute;
                      if (actionRoute != null) {
                        var route = actionRoute;
                        if (route == '/team_challenges_seasons') {
                          route = '/season_challenges';
                        }
                        navigator.pushNamed(route);
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No goal linked to this alert.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: alertColor,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(alert.actionText!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await AlertService.dismissAlert(alert.id);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getAlertColor(AlertType type, AlertPriority priority) {
    switch (priority) {
      case AlertPriority.urgent:
        return AppColors.dangerColor;
      case AlertPriority.high:
        return AppColors.warningColor; // Amber for due soon / milestone risk
      case AlertPriority.medium:
        return AppColors.activeColor; // Inactivity, informational
      case AlertPriority.low:
        return AppColors.successColor;
    }
  }

  Widget _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.goalCreated:
        return SizedBox(
          width: 45, // Set a consistent size for the image
          height: 45,
          child: Image.asset(
            'Business_Growth_Development/Growth_Development_Red.png',
            fit: BoxFit.contain,
          ),
        );
      case AlertType.goalCompleted:
        return Icon(Icons.check_circle);
      case AlertType.goalApprovalRequested:
        return Icon(Icons.pending_actions);
      case AlertType.goalApprovalApproved:
        return Icon(Icons.check_circle_outline);
      case AlertType.goalApprovalRejected:
        return Icon(Icons.cancel);
      case AlertType.goalDueSoon:
        return Icon(Icons.schedule);
      case AlertType.goalOverdue:
        return Icon(Icons.warning);
      case AlertType.inactivity:
        return Icon(Icons.notifications_active_outlined);
      case AlertType.milestoneRisk:
        return Icon(Icons.warning_amber_outlined);
      case AlertType.pointsEarned:
        return Icon(Icons.stars);
      case AlertType.levelUp:
        return Icon(Icons.trending_up);
      case AlertType.badgeEarned:
        return Icon(Icons.workspace_premium);
      case AlertType.teamAssigned:
        return Icon(Icons.group_add);
      case AlertType.managerNudge:
        return Icon(Icons.notifications_active);
      case AlertType.achievementUnlocked:
        return Icon(Icons.emoji_events);
      case AlertType.streakMilestone:
        return Icon(Icons.local_fire_department);
      case AlertType.deadlineReminder:
        return Icon(Icons.access_time);
      case AlertType.teamGoalAvailable:
        return Icon(Icons.group_work);
      case AlertType.oneOnOneRequested:
        return Icon(Icons.event_note);
      case AlertType.oneOnOneProposed:
        return Icon(Icons.event_available);
      case AlertType.oneOnOneAccepted:
        return Icon(Icons.event_available_outlined);
      case AlertType.oneOnOneRescheduled:
        return Icon(Icons.event_repeat);
      case AlertType.oneOnOneCancelled:
        return Icon(Icons.event_busy);
      case AlertType.recognition:
        return Icon(Icons.emoji_events);
      case AlertType.employeeJoinedTeamGoal:
        return Icon(Icons.group_add);
      case AlertType.seasonJoined:
        return Icon(Icons.flag_circle);
      case AlertType.seasonProgressUpdate:
        return Icon(Icons.timeline);
      case AlertType.seasonCompleted:
        return Icon(Icons.emoji_events_outlined);
      case AlertType.goalMilestoneCompleted:
        return Icon(Icons.fact_check);
      case AlertType.milestoneDeletionRequest:
        return Icon(Icons.info_outline);
      case AlertType.milestoneDeleted:
        return Icon(Icons.info_outline);
      case AlertType.milestoneDeletionRejected:
        return Icon(Icons.block);
      case AlertType.managerGeneral:
        return Icon(Icons.notifications);
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

// Drawer removed; persistent sidebar via MainLayout
