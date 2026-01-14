import 'dart:convert';
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
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/goal_detail_screen.dart';
import 'package:pdh/design_system/app_components.dart';

class AlertsNudgesScreen extends StatefulWidget {
  final bool embedded;

  const AlertsNudgesScreen({super.key, this.embedded = false});

  @override
  State<AlertsNudgesScreen> createState() => _AlertsNudgesScreenState();
}

class _AlertsNudgesScreenState extends State<AlertsNudgesScreen> {
  List<Map<String, dynamic>>? _predictiveRisks;
  bool _isLoadingRisks = false;
  bool _isRiskAlertsExpanded = false;
  List<Alert>? _cachedAlerts;

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

    return AppScaffold(
      title: 'Alerts & Nudges',
      showAppBar: false,
      embedded: widget.embedded,
      items: SidebarConfig.employeeItems,
      currentRouteName: '/alerts_nudges',
      tutorialStepIndex: tutorialParams['tutorialStepIndex'] as int?,
      sidebarTutorialKeys:
          tutorialParams['sidebarTutorialKeys'] as List<GlobalKey>?,
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(AppColors.activeColor),
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
          if (alert.actionText != null &&
              (!isManagerNudge || hasGoal)) ...[
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
    final actionRoute = alert.actionRoute;

    if (actionRoute == '/my_goal_workspace') {
      final goalId = alert.actionData != null
          ? (alert.actionData!['goalId'] as String?)
          : alert.relatedGoalId;
      if (goalId != null && goalId.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('goals')
              .doc(goalId)
              .get();
          if (!mounted) return;
          if (doc.exists) {
            final goal = Goal.fromFirestore(doc);
            navigator.push(
              MaterialPageRoute(
                builder: (context) => GoalDetailScreen(goal: goal),
              ),
            );
            return;
          }
        } catch (_) {}
      }
      // No goal available; do not navigate
      return;
    }

    if (actionRoute != null) {
      var route = actionRoute;
      if (route == '/team_challenges_seasons') {
        route = '/season_challenges';
      }
      navigator.pushNamed(route);
    }
  }

  Future<void> _showManagerNudgeDialog(Alert alert) async {
    final responseController = TextEditingController();
    String? selectedReaction;
    bool sendingReaction = false;
    bool sendingResponse = false;

    Future<void> _sendReaction(
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
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not record reaction. Please try again.'),
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

    Future<void> _sendResponse(
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
              content: const Text('Response sent to your manager'),
              backgroundColor: AppColors.activeColor,
            ),
          );
        }
        if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
          Navigator.of(dialogContext).pop();
        }
      } catch (_) {
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
          final managerName = alert.fromUserName ?? 'Manager';
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
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                title: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          AppColors.activeColor.withValues(alpha: 0.15),
                      child: Text(
                        managerName.isNotEmpty
                            ? managerName[0].toUpperCase()
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
                            'Nudge from $managerName',
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
                                _sendReaction(reaction, setDialogState),
                            selectedColor:
                                AppColors.activeColor.withValues(alpha: 0.2),
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
                  if (alert.actionRoute == '/my_goal_workspace' && _hasGoal(alert)) ...[
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
                      : () => _sendResponse(setDialogState, dialogContext),
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
                      final navigator = Navigator.of(context);
                      final actionRoute = alert.actionRoute;

                      // Mark as read when action is taken
                      await AlertService.markAsRead(alert.id);

                      if (!mounted) return;

                      // Special handling: If the action is to view a specific goal, open GoalDetailScreen
                      if (actionRoute == '/my_goal_workspace') {
                        final goalId = alert.actionData != null
                            ? (alert.actionData!['goalId'] as String?)
                            : alert.relatedGoalId;
                        if (goalId != null && goalId.isNotEmpty) {
                          try {
                            final doc = await FirebaseFirestore.instance
                                .collection('goals')
                                .doc(goalId)
                                .get();
                            if (!mounted) return;
                            if (doc.exists) {
                              final goal = Goal.fromFirestore(doc);
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      GoalDetailScreen(goal: goal),
                                ),
                              );
                              return;
                            }
                          } catch (_) {
                            // Fallback to workspace navigation below
                          }
                        }
                      }

                      // Default: Navigate to the provided route if any
                      if (actionRoute != null) {
                        var route = actionRoute;
                        if (route == '/team_challenges_seasons') {
                          route = '/season_challenges';
                        }
                        navigator.pushNamed(route);
                      }
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
