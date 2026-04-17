// ignore_for_file: unused_element, unused_field

import 'dart:math' as math;
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/manager_badge_evaluator.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/manager_employee_detail_screen.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';

class ManagerAlertsNudgesScreen extends StatefulWidget {
  final bool embedded;

  /// When true, admin is viewing; show managers only (no employees).
  final bool forAdminOversight;

  /// When set with [forAdminOversight], show data for this manager only.
  final String? selectedManagerId;

  const ManagerAlertsNudgesScreen({
    super.key,
    this.embedded = false,
    this.forAdminOversight = false,
    this.selectedManagerId,
  });

  @override
  State<ManagerAlertsNudgesScreen> createState() =>
      _ManagerAlertsNudgesScreenState();
}

class _ManagerAlertsNudgesScreenState extends State<ManagerAlertsNudgesScreen> {
  String _searchQuery = '';
  // true = Personal, false = Team
  // null=All, 'alert' | 'nudge' | 'approval_request'
  // SMART rubric state per goalId

  final _approvalsStatusFilter = 'all'; // 'all' | 'approved' | 'rejected'

  final Set<String> _expandedApprovals = <String>{};

  // New supervision filters
  String?
  _alertTypeFilter; // null=All, 'inactive', 'overdue', 'performance', 'risk'
  String _sortBy = 'newest'; // 'newest', 'oldest', 'priority'

  // Track alerts marked as read locally for optimistic updates
  final Set<String> _locallyMarkedAsRead = <String>{};

  /// Which supervision alert sections are expanded (Show All). Key: section id.
  final Map<String, bool> _supervisionSectionExpanded = <String, bool>{};

  Future<NudgeAnalyticsSummary>? _analyticsFuture;
  final bool _showNudgeTrend = true;
  bool _isLoadingInsights = false;
  Map<String, dynamic>? _teamInsights;

  // Cache the last known-good enriched employee list so the UI
  // does not flash or show placeholder-only data when the stream
  // re-emits (e.g., after sending a nudge).
  List<EmployeeData> _lastEmployees = const [];

  @override
  void initState() {
    super.initState();
    _redirectIfManager();
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  Future<void> _redirectIfManager() async {
    try {
      if (widget.forAdminOversight) return; // Admin context: no redirect.
      final role = await RoleService.instance.getRole();
      if (!mounted) return;
      if (role == 'manager') {
        if (widget.embedded) {
          // Already inside Manager Portal; stay here.
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final current = ModalRoute.of(context)?.settings.name;
          if (current != '/manager_portal') {
            Navigator.pushReplacementNamed(
              context,
              '/manager_portal',
              arguments: {'initialRoute': '/manager_alerts_nudges'},
            );
          }
        });
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _showCenterNotice(BuildContext context, String message) async {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: DashboardChrome.cardFill,
          content: Text(
            message,
            style: AppTypography.bodyMedium.copyWith(color: DashboardChrome.fg),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'OK',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.activeColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String? _normalizeGoalId(dynamic raw) {
    final s = raw?.toString().trim();
    if (s == null || s.isEmpty) return null;
    if (s.contains('/')) {
      final parts = s.split('/').where((p) => p.trim().isNotEmpty).toList();
      if (parts.isEmpty) return null;
      final last = parts.last.trim();
      return last.isEmpty ? null : last;
    }
    return s;
  }

  bool _isEmployeePersonaAlertType(AlertType type) {
    switch (type) {
      case AlertType.goalCreated:
      case AlertType.goalCompleted:
      case AlertType.goalDueSoon:
      case AlertType.goalApprovalApproved:
      case AlertType.goalApprovalRejected:
      case AlertType.pointsEarned:
      case AlertType.levelUp:
      case AlertType.badgeEarned:
      case AlertType.teamAssigned:
      case AlertType.achievementUnlocked:
      case AlertType.streakMilestone:
      case AlertType.deadlineReminder:
      case AlertType.teamGoalAvailable:
      case AlertType.recognition:
      case AlertType.oneOnOneRequested:
      case AlertType.oneOnOneProposed:
        return true;
      default:
        return false;
    }
  }

  /// Keep manager workspace focused on manager-role alerts.
  /// This removes alerts that are meant for the same user as an employee.
  bool _shouldShowInManagerWorkspace(Alert alert, String managerId) {
    if (alert.userId != managerId) return true;

    if (_isEmployeePersonaAlertType(alert.type)) return false;

    // Goal overdue can be employee-persona or manager-supervision.
    if (alert.type == AlertType.goalOverdue) {
      final title = alert.title.toLowerCase();
      final msg = alert.message.toLowerCase();
      final isManagerScoped =
          alert.audience == AlertAudience.team ||
          title.contains('employee') ||
          msg.contains('review and decide next step');
      return isManagerScoped;
    }

    return true;
  }

  bool _isAdminOversightTeamAlert(Alert alert) {
    // In admin oversight, only show team/supervision signals.
    if (alert.audience == AlertAudience.team) return true;
    switch (alert.type) {
      case AlertType.inactivity:
      case AlertType.goalOverdue:
      case AlertType.milestoneRisk:
      case AlertType.seasonJoined:
      case AlertType.seasonProgressUpdate:
      case AlertType.seasonCompleted:
      case AlertType.goalMilestoneCompleted:
      case AlertType.milestoneDeletionRequest:
        return true;
      default:
        return false;
    }
  }

  /// Hide persisted [AlertType.goalOverdue] rows when the goal is no longer
  /// overdue-relevant (e.g. manager-acknowledged) or is missing from the
  /// employee's active goal set.
  bool _isSuppressedStaleGoalOverdueAlert(Alert a, EmployeeData e) {
    if (a.type != AlertType.goalOverdue) return false;
    final rid = a.relatedGoalId?.trim();
    if (rid == null || rid.isEmpty) return false;
    if (e.isPlaceholder) return false;
    Goal? match;
    for (final g in e.goals) {
      if (g.id == rid) {
        match = g;
        break;
      }
    }
    if (match == null) return true;
    final now = DateTime.now();
    if (!match.isEligibleForOverdueTeamAlert) return true;
    if (!match.targetDate.isBefore(now)) return true;
    return false;
  }

  Future<void> _rescheduleGoal(
    BuildContext context,
    String goalId,
    EmployeeData employee,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;

    final noteController = TextEditingController();
    if (!context.mounted) return;
    final note = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Reschedule Note'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(labelText: 'Optional note'),
          autofocus: true,
          onSubmitted: (value) {
            Navigator.of(ctx).pop(value.trim().isEmpty ? null : value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              final noteText = noteController.text.trim();
              Navigator.of(ctx).pop(noteText.isEmpty ? null : noteText);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    try {
      await FirebaseFirestore.instance.collection('goals').doc(goalId).update({
        'targetDate': Timestamp.fromDate(picked),
        'status': GoalStatus.inProgress.name,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await AlertService.createMotivationalAlert(
        userId: employee.profile.uid,
        message:
            'Your goal has been rescheduled to ${picked.day}/${picked.month}/${picked.year}.',
        goalId: goalId,
      );

      final manager = FirebaseAuth.instance.currentUser;
      if (manager != null) {
        await ManagerBadgeEvaluator.logReplanHelped(
          managerId: manager.uid,
          goalId: goalId,
          note: (note != null && note.isNotEmpty)
              ? 'Rescheduled: $note'
              : 'Rescheduled from Team Alerts',
        );
        await ManagerBadgeEvaluator.evaluate(manager.uid);
      }

      if (context.mounted) {
        await _showCenterNotice(context, 'Goal rescheduled successfully');
      }
    } catch (e) {
      if (context.mounted) {
        await _showCenterNotice(context, 'Failed to reschedule goal: $e');
      }
    }
  }

  Widget _buildApprovalsTab(List<EmployeeData> employees) {
    final managerId = FirebaseAuth.instance.currentUser?.uid;
    if (managerId == null || managerId.isEmpty) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Text(
            'Sign in to view approvals.',
            style: AppTypography.bodyMedium.copyWith(color: DashboardChrome.fg),
          ),
        ),
      );
    }

    // Build a view-only list of approved/rejected goals that were decided by THIS manager
    final items = <Map<String, dynamic>>[];
    for (final emp in employees) {
      for (final g in emp.goals) {
        final decided =
            g.approvalStatus == GoalApprovalStatus.approved ||
            g.approvalStatus == GoalApprovalStatus.rejected;
        final decidedByMe = (g.approvedByUserId ?? '') == managerId;
        if (decided && decidedByMe) {
          items.add({'employee': emp, 'goal': g});
        }
      }
    }
    items.sort((a, b) {
      final ga =
          (a['goal'] as Goal).approvedAt ?? (a['goal'] as Goal).targetDate;
      final gb =
          (b['goal'] as Goal).approvedAt ?? (b['goal'] as Goal).targetDate;
      return gb.compareTo(ga);
    });

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Text(
            'No approvals yet',
            style: AppTypography.bodyMedium.copyWith(color: DashboardChrome.fg),
          ),
        ),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: AppSpacing.screenPadding,
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final emp = items[index]['employee'] as EmployeeData;
              final g = items[index]['goal'] as Goal;
              final isApproved =
                  g.approvalStatus == GoalApprovalStatus.approved;
              final color = isApproved
                  ? AppColors.successColor
                  : AppColors.dangerColor;
              final statusLabel = isApproved ? 'Approved' : 'Rejected';
              final decisionDate = g.approvedAt ?? g.targetDate;
              return Container(
                decoration: BoxDecoration(
                  color: DashboardChrome.cardFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DashboardChrome.border),
                ),
                child: ListTile(
                  leading: isApproved
                      ? Image.asset(
                          'assets/Approved_Tick/Approve_2.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                        )
                      : Icon(Icons.cancel_outlined, color: color),
                  title: Text(
                    g.title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: DashboardChrome.fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${emp.profile.displayName} • ${_fmtDate(decisionDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: DashboardChrome.fg,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      statusLabel,
                      style: AppTypography.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  onTap: () {},
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _rejectGoal(
    BuildContext context,
    String goalId,
    EmployeeData employee,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Goal'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    try {
      final manager = FirebaseAuth.instance.currentUser;
      final managerName = manager?.displayName ?? 'Manager';
      await DatabaseService.rejectGoal(
        goalId: goalId,
        managerId: manager?.uid ?? '',
        managerName: managerName,
        reason: reason.isEmpty ? null : reason,
      );
      if (context.mounted) {
        await _showCenterNotice(context, 'Goal rejected');
      }
    } catch (e) {
      if (context.mounted) {
        await _showCenterNotice(context, 'Failed to reject goal: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Team Supervision Dashboard',
      showAppBar: false,
      embedded: widget.embedded,
      items: SidebarConfig.getItemsForRole('manager'),
      currentRouteName: '/manager_alerts_nudges',
      onNavigate: (route) {
        // Keep manager navigation inside the portal so sidebar order changes
        // don't break content routing.
        if (widget.embedded) return;
        Navigator.pushReplacementNamed(
          context,
          '/manager_portal',
          arguments: {'initialRoute': route},
        );
      },
      onLogout: () async {
        final navigator = Navigator.of(context);
        await AuthService().signOut();
        if (mounted) {
          navigator.pushNamedAndRemoveUntil('/landing', (route) => false);
        }
      },
      content: StreamBuilder<List<EmployeeData>>(
        key: ValueKey(
          'team_data_stream_${widget.forAdminOversight}_${widget.selectedManagerId}',
        ),
        stream: widget.forAdminOversight
            ? ManagerRealtimeService.getManagersDataStreamForAdmin(
                selectedManagerId: widget.selectedManagerId,
              )
            : ManagerRealtimeService.getTeamDataStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.dangerColor,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading team data',
                      style: AppTypography.bodyMedium.copyWith(
                        color: DashboardChrome.fg,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: AppTypography.bodySmall.copyWith(
                        color: DashboardChrome.fg,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final incoming = snapshot.data;
          final hasPlaceholderBatch =
              incoming != null &&
              incoming.isNotEmpty &&
              incoming.every((e) => e.isPlaceholder);

          // Keep last known-good enriched list so the UI does not
          // "flash empty" or show placeholder-only data when the
          // stream re-emits (for example, after sending a nudge).
          if (snapshot.hasData &&
              (snapshot.data?.isNotEmpty ?? false) &&
              !hasPlaceholderBatch) {
            _lastEmployees = snapshot.data!;
          }

          // If we only have placeholders and no enriched cache yet,
          // still show employees immediately (for stats/alerts), but
          // rely on the subsequent enriched payload to refine data.
          final employees = hasPlaceholderBatch
              ? incoming
              : (snapshot.data ?? _lastEmployees);

          if ((employees.isEmpty) &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.activeColor,
                ),
              ),
            );
          }

          try {
            return DashboardThemedBackground(
              embedded: widget.embedded,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: AppSpacing.screenPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          employees.isEmpty
                              ? _buildStatsRowSkeleton()
                              : _buildStatsRow(employees),
                          const SizedBox(height: AppSpacing.md),
                          _buildFilterBar(),
                        ],
                      ),
                    ),
                  ),
                  // Direct alert content (no tabs)
                  _buildAllAlertsContent(employees),
                ],
              ),
            );
          } catch (e, stack) {
            developer.log(
              'Manager Alerts screen build error: $e',
              name: 'ManagerAlerts',
            );
            developer.log('Stack: $stack', name: 'ManagerAlerts');
            return Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.dangerColor,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load team alerts',
                      style: AppTypography.bodyMedium.copyWith(
                        color: DashboardChrome.fg,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again.',
                      style: AppTypography.bodySmall.copyWith(
                        color: DashboardChrome.fg,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.activeColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildAllAlertsContent(List<EmployeeData> employees) {
    final manager = FirebaseAuth.instance.currentUser;
    if (manager == null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Text(
              'Please sign in to view team supervision alerts',
              style: AppTypography.bodyMedium.copyWith(
                color: DashboardChrome.fg,
              ),
            ),
          ),
        ),
      );
    }

    // Use the new alert system to get both personal and team alerts
    return StreamBuilder<List<Alert>>(
      stream: AlertService.getUserAlertsStream(manager.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.activeColor,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          developer.log(
            'Alert stream error: ${snapshot.error}',
            name: 'TeamAlerts',
          );
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.dangerColor,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load alerts',
                      style: AppTypography.bodyMedium.copyWith(
                        color: DashboardChrome.fg,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again',
                      style: AppTypography.bodySmall.copyWith(
                        color: DashboardChrome.fg,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {}); // Refresh the stream
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.activeColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final allAlerts = snapshot.data ?? [];
        final managerScopedAlerts = widget.forAdminOversight
            ? <Alert>[]
            : allAlerts
                  .where((a) => _shouldShowInManagerWorkspace(a, manager.uid))
                  .toList();
        developer.log('Loaded ${allAlerts.length} alerts', name: 'TeamAlerts');

        try {
          final Map<String, EmployeeData> employeesById = {
            for (final e in employees) e.profile.uid: e,
          };

          // Build combined list: manager-addressed alerts + alerts that were already in the system
          // (employee alerts) + synthetic inactivity + synthetic overdue so filters show everything.
          final combinedAlerts = <Alert>[];
          combinedAlerts.addAll(managerScopedAlerts);

          // Add each employee's existing alerts (so "All Issues" and type filters show them)
          final seenAlertIds = <String>{};
          for (final a in combinedAlerts) {
            if (a.id.isNotEmpty) seenAlertIds.add(a.id);
          }
          for (final e in employees) {
            final alerts = e.recentAlerts;
            if (alerts.isEmpty) continue;
            for (final a in alerts) {
              if (widget.forAdminOversight && !_isAdminOversightTeamAlert(a)) {
                continue;
              }
              if (_isSuppressedStaleGoalOverdueAlert(a, e)) continue;
              if (a.id.isNotEmpty && seenAlertIds.contains(a.id)) continue;
              if (a.id.isNotEmpty) seenAlertIds.add(a.id);
              combinedAlerts.add(a);
            }
          }

          final now = DateTime.now();
          for (final e in employees) {
            final inactivityDays = now.difference(e.lastActivity).inDays;
            if (inactivityDays >= 3) {
              final id = 'synthetic_inactivity_${e.profile.uid}';
              if (!seenAlertIds.add(id)) continue;
              combinedAlerts.add(
                Alert(
                  id: id,
                  userId: e.profile.uid,
                  type: AlertType.inactivity,
                  audience: AlertAudience.team,
                  priority: inactivityDays >= 7
                      ? AlertPriority.high
                      : AlertPriority.medium,
                  title: 'Employee Inactive',
                  message:
                      '${e.profile.displayName} inactive for $inactivityDays days',
                  createdAt: now.subtract(const Duration(hours: 1)),
                ),
              );
            }
            // Synthetic overdue: one per overdue goal per employee so "Overdue goals" filter shows all
            final goals = e.goals;
            for (final goal in goals) {
              if (!goal.isEligibleForOverdueTeamAlert) continue;
              if (!goal.targetDate.isBefore(now)) continue;
              final id = 'synthetic_overdue_${goal.id}_${e.profile.uid}';
              if (!seenAlertIds.add(id)) continue;
              final daysOverdue = now.difference(goal.targetDate).inDays;
              combinedAlerts.add(
                Alert(
                  id: id,
                  userId: e.profile.uid,
                  type: AlertType.goalOverdue,
                  audience: AlertAudience.team,
                  priority: AlertPriority.urgent,
                  title: 'Goal Overdue',
                  message:
                      '"${goal.title}" is overdue by $daysOverdue day${daysOverdue == 1 ? '' : 's'}.',
                  actionText: 'Reschedule',
                  actionRoute: '/manager_alerts_nudges',
                  actionData: {'goalId': goal.id},
                  createdAt: now.subtract(const Duration(hours: 1)),
                  relatedGoalId: goal.id,
                ),
              );
            }
          }

          // Apply filters in real-time
          var filteredAlerts = _applyFilters(combinedAlerts);

          // Categorize alerts
          final criticalIssues = <Alert>[];
          final performanceConcerns = <Alert>[];
          final monitoring = <Alert>[];

          for (final alert in filteredAlerts) {
            if (alert.priority == AlertPriority.urgent) {
              criticalIssues.add(alert);
            } else if (alert.priority == AlertPriority.high ||
                alert.priority == AlertPriority.medium) {
              performanceConcerns.add(alert);
            } else {
              monitoring.add(alert);
            }
          }

          // Build the categorized alert sections (must be box widgets for SliverList)
          final sections = <Widget>[];
          final firstSectionPadding = EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.md,
            AppSpacing.xxl,
            AppSpacing.xxl,
          );

          // Critical Issues Section
          if (criticalIssues.isNotEmpty) {
            sections.add(
              Padding(
                padding: sections.isEmpty
                    ? firstSectionPadding
                    : AppSpacing.screenPadding,
                child: _buildAlertSection(
                  '🔴 Critical Issues',
                  criticalIssues,
                  employeesById,
                  AppColors.dangerColor,
                  sectionKey: 'critical',
                  isExpanded: _supervisionSectionExpanded['critical'] ?? true,
                  onToggleExpand: () {
                    setState(() {
                      _supervisionSectionExpanded['critical'] =
                          !(_supervisionSectionExpanded['critical'] ?? true);
                    });
                  },
                ),
              ),
            );
          }

          // Performance Concerns Section
          if (performanceConcerns.isNotEmpty) {
            sections.add(
              Padding(
                padding: sections.isEmpty
                    ? firstSectionPadding
                    : AppSpacing.screenPadding,
                child: _buildAlertSection(
                  '🟡 Performance Concerns',
                  performanceConcerns,
                  employeesById,
                  AppColors.warningColor,
                  sectionKey: 'performance',
                  isExpanded:
                      _supervisionSectionExpanded['performance'] ??
                      criticalIssues.isEmpty,
                  onToggleExpand: () {
                    setState(() {
                      _supervisionSectionExpanded['performance'] =
                          !(_supervisionSectionExpanded['performance'] ??
                              criticalIssues.isEmpty);
                    });
                  },
                ),
              ),
            );
          }

          // Monitoring Section
          if (monitoring.isNotEmpty) {
            sections.add(
              Padding(
                padding: sections.isEmpty
                    ? firstSectionPadding
                    : AppSpacing.screenPadding,
                child: _buildAlertSection(
                  '🟢 Monitoring',
                  monitoring,
                  employeesById,
                  AppColors.successColor,
                  sectionKey: 'monitoring',
                  isExpanded:
                      _supervisionSectionExpanded['monitoring'] ??
                      (criticalIssues.isEmpty && performanceConcerns.isEmpty),
                  onToggleExpand: () {
                    setState(() {
                      _supervisionSectionExpanded['monitoring'] =
                          !(_supervisionSectionExpanded['monitoring'] ??
                              (criticalIssues.isEmpty &&
                                  performanceConcerns.isEmpty));
                    });
                  },
                ),
              ),
            );
          }

          // Empty State: return a single sliver (SliverFillRemaining), not inside SliverList
          if (sections.isEmpty) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: _buildEmptySupervisionState(),
              ),
            );
          }

          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => sections[index],
              childCount: sections.length,
            ),
          );
        } catch (e, stack) {
          developer.log('Manager Alerts content error: $e', name: 'TeamAlerts');
          developer.log('Stack: $stack', name: 'TeamAlerts');
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.dangerColor,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load alerts',
                      style: AppTypography.bodyMedium.copyWith(
                        color: DashboardChrome.fg,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again.',
                      style: AppTypography.bodySmall.copyWith(
                        color: DashboardChrome.fg,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.activeColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  // removed skeleton placeholders

  /// Shown while team data is loading so we don't flash 0,0,0 before real data.
  Widget _buildStatsRowSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSupervisionStatCard(
                'Inactive Employees',
                '—',
                AppColors.warningColor,
                Icons.person_off,
                subtitle: '3+ days inactive',
                imageAsset:
                    'assets/Information_Detail/Information_Red_Badge_White.png',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSupervisionStatCard(
                'Overdue Goals',
                '—',
                AppColors.dangerColor,
                Icons.calendar_today,
                subtitle: 'Need attention',
                imageAsset:
                    'assets/Time_Allocation_Approval/Allocation_Red Badge_White.png',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSupervisionStatCard(
                'Performance Risks',
                '—',
                AppColors.warningColor,
                Icons.trending_down,
                subtitle: 'High/Urgent alerts',
                imageAsset: 'assets/red_bell.png',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSupervisionStatCard(
                'Team Health',
                '—',
                DashboardChrome.fg,
                null,
                subtitle: 'Overall score',
                imageAsset: 'assets/Team_Meeting/Meeting_Red Badge_White.png',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(List<EmployeeData> employees) {
    // These metrics are derived from live team data and update as employee
    // performance changes (activity, goals, alerts). Recomputed on every stream emission.
    final now = DateTime.now();
    final inactiveEmployees = employees.where((emp) {
      final inactivityDays = now.difference(emp.lastActivity).inDays;
      return inactivityDays >= 3;
    }).length;

    // Calculate overdue goals
    final overdueGoals = employees.fold<int>(
      0,
      (acc, emp) => acc + emp.overdueGoalsCount,
    );

    // Calculate performance risks (alerts with high/urgent priority)
    final performanceRisks = employees.fold<int>(
      0,
      (acc, emp) =>
          acc +
          emp.recentAlerts
              .where(
                (a) =>
                    a.priority == AlertPriority.urgent ||
                    a.priority == AlertPriority.high,
              )
              .length,
    );

    // Calculate team health score (inverse of issues)
    final totalIssues = inactiveEmployees + overdueGoals + performanceRisks;
    final maxPossibleIssues =
        employees.length * 3; // Each employee can have 3 types of issues
    final teamHealthScore = maxPossibleIssues > 0
        ? ((maxPossibleIssues - totalIssues) / maxPossibleIssues * 100).round()
        : 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Cards Row
        Row(
          children: [
            Expanded(
              child: _buildSupervisionStatCard(
                'Inactive Employees',
                inactiveEmployees.toString(),
                AppColors.warningColor,
                Icons.person_off,
                subtitle: '3+ days inactive',
                imageAsset:
                    'assets/Information_Detail/Information_Red_Badge_White.png',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSupervisionStatCard(
                'Overdue Goals',
                overdueGoals.toString(),
                AppColors.dangerColor,
                Icons.calendar_today,
                subtitle: 'Need attention',
                imageAsset:
                    'assets/Time_Allocation_Approval/Allocation_Red Badge_White.png',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSupervisionStatCard(
                'Performance Risks',
                performanceRisks.toString(),
                AppColors.warningColor,
                Icons.trending_down,
                subtitle: 'High/Urgent alerts',
                imageAsset: 'assets/red_bell.png',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSupervisionStatCard(
                'Team Health',
                '$teamHealthScore%',
                teamHealthScore >= 80
                    ? AppColors.successColor
                    : teamHealthScore >= 60
                    ? AppColors.warningColor
                    : AppColors.dangerColor,
                null,
                subtitle: 'Overall score',
                imageAsset: 'assets/Team_Meeting/Meeting_Red Badge_White.png',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData? icon, {
    String? subtitle,
    String? imageAsset,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardChrome.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageAsset != null)
            Image.asset(imageAsset, width: 24, height: 24, fit: BoxFit.contain)
          else if (icon != null)
            Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.heading3.copyWith(
              color: DashboardChrome.fg,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: AppTypography.bodySmall.copyWith(color: DashboardChrome.fg),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: DashboardChrome.fg,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupervisionStatCard(
    String title,
    String value,
    Color color,
    IconData? icon, {
    String? subtitle,
    String? imageAsset,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardChrome.border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageAsset != null)
            Image.asset(imageAsset, width: 28, height: 28, fit: BoxFit.contain)
          else if (icon != null)
            Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTypography.heading3.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTypography.bodySmall.copyWith(
              color: DashboardChrome.fg,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardChrome.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alert Type Filters Section
          Text(
            'Alert Type',
            style: AppTypography.bodyMedium.copyWith(
              color: DashboardChrome.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                label: 'All Issues',
                selected: _alertTypeFilter == null,
                onSelected: () => setState(() => _alertTypeFilter = null),
              ),
              _buildFilterChip(
                label: 'Inactive Employees',
                selected: _alertTypeFilter == 'inactive',
                onSelected: () => setState(() => _alertTypeFilter = 'inactive'),
              ),
              _buildFilterChip(
                label: 'Overdue Goals',
                selected: _alertTypeFilter == 'overdue',
                onSelected: () => setState(() => _alertTypeFilter = 'overdue'),
              ),
              _buildFilterChip(
                label: 'Performance Anomalies',
                selected: _alertTypeFilter == 'performance',
                onSelected: () =>
                    setState(() => _alertTypeFilter = 'performance'),
              ),
              _buildFilterChip(
                label: 'Team Risk Signals',
                selected: _alertTypeFilter == 'risk',
                onSelected: () => setState(() => _alertTypeFilter = 'risk'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Sort and Search Section
          Text(
            'Sort & Search',
            style: AppTypography.bodyMedium.copyWith(
              color: DashboardChrome.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  initialValue: _sortBy,
                  decoration: InputDecoration(
                    hintText: 'Sort by',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: DashboardChrome.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: DashboardChrome.border),
                    ),
                    filled: true,
                    fillColor: DashboardChrome.cardFill,
                  ),
                  dropdownColor: DashboardChrome.cardFill,
                  style: AppTypography.bodySmall.copyWith(
                    color: DashboardChrome.fg,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'newest',
                      child: Text('Newest first'),
                    ),
                    DropdownMenuItem(
                      value: 'oldest',
                      child: Text('Oldest first'),
                    ),
                    DropdownMenuItem(
                      value: 'priority',
                      child: Text('Priority'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _sortBy = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search employees or goals...',
                    prefixIcon: Icon(Icons.search, color: DashboardChrome.fg),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: DashboardChrome.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: DashboardChrome.border),
                    ),
                    filled: true,
                    fillColor: DashboardChrome.cardFill,
                  ),
                  style: AppTypography.bodySmall.copyWith(
                    color: DashboardChrome.fg,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: selected ? Colors.white : DashboardChrome.fg,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      backgroundColor: DashboardChrome.cardFill,
      selectedColor: AppColors.activeColor,
      side: BorderSide(
        color: selected ? AppColors.activeColor : DashboardChrome.border,
      ),
    );
  }

  Widget _buildTeamAlertsTab(List<EmployeeData> employees) {
    final manager = FirebaseAuth.instance.currentUser;
    if (manager == null) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Text(
            'Please sign in to view team supervision alerts',
            style: AppTypography.bodyMedium.copyWith(color: DashboardChrome.fg),
          ),
        ),
      );
    }

    // Use the new alert system to get team alerts
    return StreamBuilder<List<Alert>>(
      stream: AlertService.getTeamAlertsForManager(manager.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Text(
                'Error loading team alerts: ${snapshot.error}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.dangerColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final teamAlerts = snapshot.data ?? [];
        final Map<String, EmployeeData> employeesById = {
          for (final e in employees) e.profile.uid: e,
        };

        // Same combined list as main content: manager/team alerts + employee alerts already in system
        // + synthetic inactivity + synthetic overdue so filters show everything.
        final allAlerts = <Alert>[];
        allAlerts.addAll(teamAlerts);

        final seenAlertIds = <String>{};
        for (final a in allAlerts) {
          if (a.id.isNotEmpty) seenAlertIds.add(a.id);
        }
        for (final e in employees) {
          for (final a in e.recentAlerts) {
            if (widget.forAdminOversight && !_isAdminOversightTeamAlert(a)) {
              continue;
            }
            if (_isSuppressedStaleGoalOverdueAlert(a, e)) continue;
            if (a.id.isNotEmpty && seenAlertIds.contains(a.id)) continue;
            if (a.id.isNotEmpty) seenAlertIds.add(a.id);
            allAlerts.add(a);
          }
        }

        final now = DateTime.now();
        for (final e in employees) {
          final inactivityDays = now.difference(e.lastActivity).inDays;
          if (inactivityDays >= 3) {
            final id = 'synthetic_inactivity_${e.profile.uid}';
            if (!seenAlertIds.add(id)) continue;
            allAlerts.add(
              Alert(
                id: id,
                userId: e.profile.uid,
                type: AlertType.inactivity,
                audience: AlertAudience.team,
                priority: inactivityDays >= 7
                    ? AlertPriority.high
                    : AlertPriority.medium,
                title: 'Employee Inactive',
                message:
                    '${e.profile.displayName} inactive for $inactivityDays days',
                createdAt: now.subtract(const Duration(hours: 1)),
              ),
            );
          }
          for (final goal in e.goals) {
            if (!goal.isEligibleForOverdueTeamAlert) continue;
            if (!goal.targetDate.isBefore(now)) continue;
            final id = 'synthetic_overdue_${goal.id}_${e.profile.uid}';
            if (!seenAlertIds.add(id)) continue;
            final daysOverdue = now.difference(goal.targetDate).inDays;
            allAlerts.add(
              Alert(
                id: id,
                userId: e.profile.uid,
                type: AlertType.goalOverdue,
                audience: AlertAudience.team,
                priority: AlertPriority.urgent,
                title: 'Goal Overdue',
                message:
                    '"${goal.title}" is overdue by $daysOverdue day${daysOverdue == 1 ? '' : 's'}.',
                actionText: 'Reschedule',
                actionRoute: '/manager_alerts_nudges',
                actionData: {'goalId': goal.id},
                createdAt: now.subtract(const Duration(hours: 1)),
                relatedGoalId: goal.id,
              ),
            );
          }
        }

        // Apply filters
        var filteredAlerts = _applyFilters(allAlerts);

        // Categorize alerts
        final criticalIssues = <Alert>[];
        final performanceConcerns = <Alert>[];
        final monitoring = <Alert>[];

        for (final alert in filteredAlerts) {
          if (alert.priority == AlertPriority.urgent) {
            criticalIssues.add(alert);
          } else if (alert.priority == AlertPriority.high ||
              alert.priority == AlertPriority.medium) {
            performanceConcerns.add(alert);
          } else {
            monitoring.add(alert);
          }
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Critical Issues Section
            if (criticalIssues.isNotEmpty) ...[
              SliverPadding(
                padding: AppSpacing.screenPadding,
                sliver: SliverToBoxAdapter(
                  child: _buildAlertSection(
                    '🔴 Critical Issues',
                    criticalIssues,
                    employeesById,
                    AppColors.dangerColor,
                    isExpanded: true,
                  ),
                ),
              ),
            ],

            // Performance Concerns Section
            if (performanceConcerns.isNotEmpty) ...[
              SliverPadding(
                padding: AppSpacing.screenPadding,
                sliver: SliverToBoxAdapter(
                  child: _buildAlertSection(
                    '🟡 Performance Concerns',
                    performanceConcerns,
                    employeesById,
                    AppColors.warningColor,
                    isExpanded: criticalIssues.isEmpty,
                  ),
                ),
              ),
            ],

            // Monitoring Section
            if (monitoring.isNotEmpty) ...[
              SliverPadding(
                padding: AppSpacing.screenPadding,
                sliver: SliverToBoxAdapter(
                  child: _buildAlertSection(
                    '🟢 Monitoring',
                    monitoring,
                    employeesById,
                    AppColors.successColor,
                    isExpanded:
                        criticalIssues.isEmpty && performanceConcerns.isEmpty,
                  ),
                ),
              ),
            ],

            // Empty State
            if (filteredAlerts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: AppSpacing.screenPadding,
                  child: _buildEmptySupervisionState(),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Alert> _applyFilters(List<Alert> alerts) {
    // When filter is "All Issues", show all notifications (read + unread).
    // When a specific filter is selected, still show all matching alerts so
    // inactive/overdue/performance/risk views show everything that was in the system.
    var filtered = List<Alert>.from(alerts);

    // Apply alert type filter
    if (_alertTypeFilter != null) {
      filtered = filtered.where((a) {
        switch (_alertTypeFilter) {
          case 'inactive':
            return a.type == AlertType.inactivity;
          case 'overdue':
            return a.type == AlertType.goalOverdue ||
                a.title.toLowerCase().contains('overdue') ||
                a.message.toLowerCase().contains('overdue');
          case 'performance':
            return a.type == AlertType.milestoneRisk ||
                a.priority == AlertPriority.urgent ||
                a.priority == AlertPriority.high;
          case 'risk':
            return a.type == AlertType.seasonCompleted ||
                a.type == AlertType.seasonProgressUpdate;
          default:
            return true;
        }
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (a) =>
                a.title.toLowerCase().contains(query) ||
                a.message.toLowerCase().contains(query),
          )
          .toList();
    }

    // Apply sorting. When filter is "All", urgent alerts appear first, then by chosen order.
    final priorityOrder = {
      AlertPriority.urgent: 0,
      AlertPriority.high: 1,
      AlertPriority.medium: 2,
      AlertPriority.low: 3,
    };
    if (_alertTypeFilter == null) {
      // All Issues: sort by priority first (urgent first), then by date
      filtered.sort((a, b) {
        final p = priorityOrder[a.priority]!.compareTo(
          priorityOrder[b.priority]!,
        );
        if (p != 0) return p;
        switch (_sortBy) {
          case 'oldest':
            return a.createdAt.compareTo(b.createdAt);
          case 'priority':
            return 0; // already by priority
          case 'newest':
          default:
            return b.createdAt.compareTo(a.createdAt);
        }
      });
    } else {
      switch (_sortBy) {
        case 'oldest':
          filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case 'priority':
          filtered.sort(
            (a, b) => priorityOrder[a.priority]!.compareTo(
              priorityOrder[b.priority]!,
            ),
          );
          break;
        case 'newest':
        default:
          filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
      }
    }

    return filtered;
  }

  Widget _buildAlertSection(
    String title,
    List<Alert> alerts,
    Map<String, EmployeeData> employeesById,
    Color color, {
    String? sectionKey,
    bool isExpanded = false,
    VoidCallback? onToggleExpand,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardChrome.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$title (${alerts.length})',
                    style: AppTypography.heading3.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (alerts.length > 3)
                  TextButton(
                    onPressed: onToggleExpand,
                    child: Text(
                      isExpanded ? 'Show Less' : 'Show All',
                      style: AppTypography.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Alert Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: alerts.take(isExpanded ? alerts.length : 3).map((
                alert,
              ) {
                final employee = employeesById[alert.userId];
                if (employee == null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildManagerScopedAlertCard(alert),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSupervisionAlertCard(alert, employee),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupervisionAlertCard(Alert alert, EmployeeData employee) {
    final alertColor = _getAlertColor(alert.priority);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alertColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with employee info and alert type
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: alertColor.withValues(alpha: 0.2),
                child: employee.profile.profilePhotoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          employee.profile.profilePhotoUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(Icons.person, color: alertColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.profile.displayName,
                      style: AppTypography.bodyMedium.copyWith(
                        color: DashboardChrome.fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _getAlertTypeDescription(alert.type),
                      style: AppTypography.bodySmall.copyWith(
                        color: DashboardChrome.fg,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: alertColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: alertColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    alert.priority.name.toUpperCase(),
                    style: AppTypography.bodySmall.copyWith(
                      color: alertColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Alert content
          Text(
            alert.title,
            style: AppTypography.bodyMedium.copyWith(
              color: DashboardChrome.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            alert.message,
            style: AppTypography.bodySmall.copyWith(color: DashboardChrome.fg),
          ),

          const SizedBox(height: 12),

          // Time and actions
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: DashboardChrome.fg,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _formatAlertTime(alert.createdAt),
                        style: AppTypography.bodySmall.copyWith(
                          color: DashboardChrome.fg,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(child: _buildQuickActionButtons(alert, employee)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagerScopedAlertCard(Alert alert) {
    final alertColor = _getAlertColor(alert.priority);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alertColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: alertColor.withValues(alpha: 0.2),
                child: Icon(
                  Icons.notifications_active,
                  color: alertColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manager Workspace',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _getAlertTypeDescription(alert.type),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: alertColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  alert.priority.name.toUpperCase(),
                  style: AppTypography.bodySmall.copyWith(
                    color: alertColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alert.title,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            alert.message,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatAlertTime(alert.createdAt),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (alert.actionRoute != null &&
                  alert.actionRoute!.trim().isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      alert.actionRoute!,
                      arguments: alert.actionData,
                    );
                  },
                  icon: const Icon(Icons.visibility),
                  label: Text(alert.actionText ?? 'View Details'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons(Alert alert, EmployeeData employee) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (alert.type == AlertType.inactivity)
          _buildActionButton(
            'Send Nudge',
            Icons.send,
            () => _showSendNudgeDialog(employee: employee),
          ),
        if (alert.type == AlertType.goalOverdue)
          _buildActionButton(
            'Extend Deadline',
            Icons.calendar_today,
            () => _extendAlertGoalDeadline(alert, employee),
          ),
        _buildActionButton(
          'View Details',
          Icons.visibility,
          () => _viewEmployeeDetails(employee),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
        ),
        style: TextButton.styleFrom(
          backgroundColor: AppColors.activeColor.withValues(alpha: 0.1),
          foregroundColor: AppColors.activeColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  String _getAlertTypeDescription(AlertType type) {
    switch (type) {
      case AlertType.inactivity:
        return 'Inactive Employee';
      case AlertType.goalOverdue:
        return 'Overdue Goal';
      case AlertType.managerNudge:
        return 'Manager Nudge';
      case AlertType.goalApprovalRequested:
        return 'Approval Request';
      case AlertType.goalMilestoneCompleted:
        return 'Milestone Completed';
      case AlertType.streakMilestone:
        return 'Streak Milestone';
      default:
        return 'Team Alert';
    }
  }

  String _formatAlertTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _extendAlertGoalDeadline(Alert alert, EmployeeData employee) {
    _showCenterNotice(context, 'Extending deadline for ${alert.title}...');
  }

  void _viewEmployeeDetails(EmployeeData employee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManagerEmployeeDetailScreen(employee: employee),
      ),
    );
  }

  Widget _buildEmptySupervisionState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardChrome.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppColors.successColor,
          ),
          const SizedBox(height: 16),
          Text(
            'All Team Members Are Doing Well!',
            style: AppTypography.heading3.copyWith(
              color: DashboardChrome.fg,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No supervision alerts at this time. Your team is performing well!',
            style: AppTypography.bodyMedium.copyWith(color: DashboardChrome.fg),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTeamAlertCard(Alert alert, EmployeeData employee) {
    final alertColor = _getAlertColor(alert.priority);
    final alertIcon = _getAlertIcon(alert.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardChrome.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(alertIcon, color: alertColor, size: 16),
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
                              color: DashboardChrome.fg,
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
                        color: DashboardChrome.fg,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.activeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 6,
                                backgroundColor: alertColor.withValues(
                                  alpha: 0.1,
                                ),
                                child: Text(
                                  employee.profile.displayName.isNotEmpty
                                      ? employee.profile.displayName[0]
                                            .toUpperCase()
                                      : '?',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: alertColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                employee.profile.displayName,
                                style: AppTypography.bodySmall.copyWith(
                                  color: DashboardChrome.fg,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getTimeAgo(alert.createdAt),
                          style: AppTypography.bodySmall.copyWith(
                            color: DashboardChrome.fg,
                            fontSize: 10,
                          ),
                        ),
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
          if (alert.type == AlertType.goalApprovalRequested &&
              alert.relatedGoalId != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/manager_inbox');
                    },
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Review Goal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.activeColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (alert.type == AlertType.goalOverdue &&
              alert.relatedGoalId != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final gid = _normalizeGoalId(alert.relatedGoalId);
                      if (gid == null) {
                        _showCenterNotice(
                          context,
                          'This alert is missing a valid goal link.',
                        );
                        return;
                      }
                      _rescheduleGoal(context, gid, employee);
                    },
                    icon: const Icon(Icons.update),
                    label: const Text('Reschedule'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warningColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final gid = _normalizeGoalId(alert.relatedGoalId);
                      if (gid == null) {
                        _showCenterNotice(
                          context,
                          'This alert is missing a valid goal link.',
                        );
                        return;
                      }
                      _extendGoalDeadline(context, gid, employee);
                    },
                    icon: const Icon(Icons.schedule),
                    label: const Text('Extend Deadline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final gid = _normalizeGoalId(alert.relatedGoalId);
                      if (gid == null) {
                        _showCenterNotice(
                          context,
                          'This alert is missing a valid goal link.',
                        );
                        return;
                      }
                      _pauseGoal(gid, employee);
                    },
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Pause Goal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final gid = _normalizeGoalId(alert.relatedGoalId);
                      if (gid == null) {
                        _showCenterNotice(
                          context,
                          'This alert is missing a valid goal link.',
                        );
                        return;
                      }
                      _markGoalBurnout(gid, employee);
                    },
                    icon: const Icon(Icons.local_fire_department),
                    label: const Text('Mark Burnout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dangerColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _extendGoalDeadline(
    BuildContext context,
    String goalId,
    EmployeeData employee,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;

    try {
      await FirebaseFirestore.instance.collection('goals').doc(goalId).update({
        'targetDate': Timestamp.fromDate(picked),
        'status': GoalStatus.inProgress.name,
      });

      await AlertService.createMotivationalAlert(
        userId: employee.profile.uid,
        message:
            'Your goal deadline has been extended to ${picked.day}/${picked.month}/${picked.year}. You got this!',
        goalId: goalId,
      );

      final manager = FirebaseAuth.instance.currentUser;
      if (manager != null) {
        await ManagerBadgeEvaluator.logReplanHelped(
          managerId: manager.uid,
          goalId: goalId,
          note: 'Extended deadline from Team Alerts',
        );
        await ManagerBadgeEvaluator.evaluate(manager.uid);
      }

      if (context.mounted) {
        await _showCenterNotice(context, 'Deadline extended successfully');
      }
    } catch (e) {
      if (context.mounted) {
        await _showCenterNotice(context, 'Failed to extend deadline: $e');
      }
    }
  }

  Future<void> _pauseGoal(String goalId, EmployeeData employee) async {
    try {
      await FirebaseFirestore.instance.collection('goals').doc(goalId).update({
        'status': GoalStatus.paused.name,
      });

      await AlertService.createMotivationalAlert(
        userId: employee.profile.uid,
        message:
            'Your goal has been paused by your manager. Take the time you need.',
        goalId: goalId,
      );
    } catch (e) {
      // Silent error; UI shows snackbars in calling context if needed
    }
  }

  Future<void> _markGoalBurnout(String goalId, EmployeeData employee) async {
    try {
      await FirebaseFirestore.instance.collection('goals').doc(goalId).update({
        'status': GoalStatus.burnout.name,
      });

      await AlertService.createMotivationalAlert(
        userId: employee.profile.uid,
        message:
            'We noticed signs of burnout on a goal. It has been marked accordingly. Let’s regroup and plan a healthier path.',
        goalId: goalId,
      );
    } catch (e) {
      // Silent error
    }
  }

  Widget _buildSendNudgesTab(List<EmployeeData> employees) {
    final filteredEmployees = _filterEmployees(employees);
    final normalizedToday = _normalizedToday();

    final employeesNeedingAction = filteredEmployees
        .where(
          (employee) => _getCriticalGoals(employee, normalizedToday).isNotEmpty,
        )
        .toList();
    final remainingEmployees = filteredEmployees
        .where(
          (employee) => _getCriticalGoals(employee, normalizedToday).isEmpty,
        )
        .toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: AppSpacing.screenPadding,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send Team Nudges',
                  style: AppTypography.heading3.copyWith(
                    color: DashboardChrome.fg,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search team members...',
                    prefixIcon: Icon(Icons.search, color: DashboardChrome.fg),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.activeColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: AppSpacing.screenPadding.copyWith(top: AppSpacing.md),
          sliver: filteredEmployees.isEmpty
              ? SliverToBoxAdapter(child: _buildNoEmployeesState())
              : SliverList(
                  delegate: SliverChildListDelegate([
                    if (employeesNeedingAction.isNotEmpty) ...[
                      _buildSectionHeader(
                        title: 'Action Needed',
                        subtitle: 'Goals overdue or due within 2 days',
                      ),
                      const SizedBox(height: 12),
                      ...employeesNeedingAction.map(
                        (employee) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _buildEmployeeNudgeCard(employee),
                        ),
                      ),
                    ] else
                      _buildNoUrgentGoalsState(),
                    if (remainingEmployees.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(title: 'All Team Members'),
                      const SizedBox(height: 12),
                      ...remainingEmployees.map(
                        (employee) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _buildEmployeeNudgeCard(employee),
                        ),
                      ),
                    ],
                  ]),
                ),
        ),
      ],
    );
  }

  Widget _buildEmployeeNudgeCard(EmployeeData employee) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardChrome.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _getStatusColor(
                  employee.status,
                ).withValues(alpha: 0.1),
                child: Text(
                  employee.profile.displayName.isNotEmpty
                      ? employee.profile.displayName[0].toUpperCase()
                      : '?',
                  style: AppTypography.bodyMedium.copyWith(
                    color: _getStatusColor(employee.status),
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
                      employee.profile.displayName,
                      style: AppTypography.bodyMedium.copyWith(
                        color: DashboardChrome.fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${employee.goals.where((g) => g.status == GoalStatus.inProgress).length} active goals • ${employee.avgProgress.toStringAsFixed(1)}% progress',
                      style: AppTypography.bodySmall.copyWith(
                        color: DashboardChrome.fg,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    employee.status,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(
                      employee.status,
                    ).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(employee.status),
                      color: _getStatusColor(employee.status),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getStatusText(employee.status),
                      style: AppTypography.bodySmall.copyWith(
                        color: _getStatusColor(employee.status),
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildQuickNudgeButtons(employee),
          const SizedBox(height: 12),
          _buildGoalDeadlineActions(employee),
        ],
      ),
    );
  }

  Widget _buildQuickNudgeButtons(EmployeeData employee) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Nudges:',
          style: AppTypography.bodySmall.copyWith(
            color: DashboardChrome.fg,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildQuickNudgeButton(
              'Check Progress',
              Icons.trending_up,
              () => _showSendNudgeDialog(
                employee: employee,
                presetMessage:
                    'Hope you\'re doing well! How is your progress on your current goals?',
              ),
            ),
            _buildQuickNudgeButton(
              'Need Help?',
              Icons.support_agent,
              () => _showSendNudgeDialog(
                employee: employee,
                presetMessage:
                    'Is there anything I can help you with regarding your goals or work?',
              ),
            ),
            _buildQuickNudgeButton(
              'Great Work!',
              Icons.celebration,
              () => _showSendNudgeDialog(
                employee: employee,
                presetMessage:
                    'Great work on your recent progress! Keep it up!',
              ),
            ),
            _buildQuickNudgeButton(
              'Schedule Chat',
              Icons.chat,
              () => _showSendNudgeDialog(
                employee: employee,
                presetMessage:
                    'Let\'s catch up about your goals and any challenges you might be facing.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickNudgeButton(
    String text,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(text, style: AppTypography.bodySmall),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.activeColor.withValues(alpha: 0.1),
        foregroundColor: AppColors.activeColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildGoalDeadlineActions(EmployeeData employee) {
    final normalizedToday = _normalizedToday();
    final criticalGoals = _getCriticalGoals(employee, normalizedToday);

    if (criticalGoals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Urgent goal deadlines',
          style: AppTypography.bodySmall.copyWith(
            color: DashboardChrome.fg,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...criticalGoals.map(
          (goal) => _buildGoalDeadlineTile(goal, employee, normalizedToday),
        ),
      ],
    );
  }

  Widget _buildGoalDeadlineTile(
    Goal goal,
    EmployeeData employee,
    DateTime normalizedToday,
  ) {
    final normalizedTarget = DateTime(
      goal.targetDate.year,
      goal.targetDate.month,
      goal.targetDate.day,
    );
    final deltaDays = normalizedTarget.difference(normalizedToday).inDays;
    final bool isDueTomorrow = deltaDays == 1;
    final bool isDueInTwoDays = deltaDays == 2;
    final bool isOverdue = deltaDays <= -1;
    final displayColor = isOverdue
        ? AppColors.dangerColor
        : AppColors.warningColor;
    final dueLabel = _formatDueDate(goal.targetDate);
    final overdueDays = deltaDays.abs();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DashboardChrome.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goal.title,
            style: AppTypography.bodyMedium.copyWith(
              color: DashboardChrome.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 16, color: displayColor),
              const SizedBox(width: 6),
              Text(
                'Due $dueLabel',
                style: AppTypography.bodySmall.copyWith(
                  color: DashboardChrome.fg,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: displayColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOverdue
                      ? 'Overdue ${overdueDays}d'
                      : isDueTomorrow
                      ? 'Due tomorrow'
                      : isDueInTwoDays
                      ? 'Due in 2 days'
                      : 'Due soon',
                  style: AppTypography.bodySmall.copyWith(
                    color: displayColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildGoalActionButton(
                label: 'Extend',
                icon: Icons.schedule_send_outlined,
                onPressed: () =>
                    _extendGoalDeadline(context, goal.id, employee),
              ),
              _buildGoalActionButton(
                label: 'Reschedule',
                icon: Icons.update,
                onPressed: () => _rescheduleGoal(context, goal.id, employee),
              ),
              _buildGoalActionButton(
                label: 'Pause',
                icon: Icons.pause_circle_outline,
                onPressed: () => _pauseGoal(goal.id, employee),
              ),
              _buildGoalActionButton(
                label: 'Mark Burnout',
                icon: Icons.local_fire_department_outlined,
                onPressed: () => _markGoalBurnout(goal.id, employee),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: DashboardChrome.fg,
        side: BorderSide(color: DashboardChrome.border),
      ),
    );
  }

  String _formatDueDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$mm/$dd/$yyyy';
  }

  DateTime _normalizedToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  List<Goal> _getCriticalGoals(
    EmployeeData employee,
    DateTime normalizedToday,
  ) {
    return employee.goals.where((goal) {
      if (goal.status == GoalStatus.completed) return false;
      final normalizedTarget = DateTime(
        goal.targetDate.year,
        goal.targetDate.month,
        goal.targetDate.day,
      );
      final deltaDays = normalizedTarget.difference(normalizedToday).inDays;
      final isDueSoon = deltaDays >= 1 && deltaDays <= 2;
      final isOverdue = deltaDays <= -1;
      return isDueSoon || isOverdue;
    }).toList()..sort((a, b) => a.targetDate.compareTo(b.targetDate));
  }

  Widget _buildSectionHeader({required String title, String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.heading4.copyWith(
            color: DashboardChrome.fg,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(color: DashboardChrome.fg),
          ),
        ],
      ],
    );
  }

  Widget _buildNoUrgentGoalsState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardChrome.border),
      ),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, color: DashboardChrome.fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No urgent goals right now',
                  style: AppTypography.bodyMedium.copyWith(
                    color: DashboardChrome.fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You’ll see employees appear here when a goal is overdue or due within two days.',
                  style: AppTypography.bodySmall.copyWith(
                    color: DashboardChrome.fg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Analytics tab removed - key metrics now shown in Progress Visuals screen

  Widget _buildAttentionSection(List<_AttentionItem> items) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardChrome.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.priority_high_outlined,
                color: AppColors.dangerColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Employees Needing Attention',
                style: AppTypography.bodyMedium.copyWith(
                  color: DashboardChrome.fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text(
              'All clear! No outstanding nudges or urgent alerts require action.',
              style: AppTypography.bodySmall.copyWith(
                color: DashboardChrome.fg,
              ),
            )
          else
            Column(
              children: items.take(5).map((item) {
                final employee = item.employee;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: DashboardChrome.cardFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: DashboardChrome.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.dangerColor.withValues(
                              alpha: 0.15,
                            ),
                            child: Text(
                              employee.profile.displayName.isNotEmpty
                                  ? employee.profile.displayName[0]
                                        .toUpperCase()
                                  : '?',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.dangerColor,
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
                                  employee.profile.displayName,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: DashboardChrome.fg,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${item.urgentAlerts} urgent alerts • ${item.unreadNudges} unread nudges',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: DashboardChrome.fg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.dangerColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Score ${item.score}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.dangerColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: DashboardChrome.fg,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.daysInactive > 0
                                ? 'Inactive ${item.daysInactive}d'
                                : 'Active today',
                            style: AppTypography.bodySmall.copyWith(
                              color: DashboardChrome.fg,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () =>
                                _showSendNudgeDialog(employee: employee),
                            child: const Text('Send Nudge'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  List<_AttentionItem> _buildAttentionItems({
    required List<EmployeeData> employees,
    required String? managerId,
  }) {
    final now = DateTime.now();
    final items = <_AttentionItem>[];

    for (final employee in employees) {
      final urgentAlerts = employee.recentAlerts.where((alert) {
        if (alert.priority != AlertPriority.urgent) return false;
        if (_isSuppressedStaleGoalOverdueAlert(alert, employee)) return false;
        if (managerId == null || alert.fromUserId == null) return true;
        return alert.fromUserId == managerId;
      }).length;

      final unreadNudges = employee.recentAlerts.where((alert) {
        if (alert.type != AlertType.managerNudge) return false;
        if (alert.isRead || alert.isDismissed) return false;
        if (managerId == null || alert.fromUserId == null) return true;
        return alert.fromUserId == managerId;
      }).length;

      final inactivityDays = now.difference(employee.lastActivity).inDays;
      final statusPenalty = switch (employee.status) {
        EmployeeStatus.overdue => 3,
        EmployeeStatus.atRisk => 2,
        EmployeeStatus.inactive => 2,
        EmployeeStatus.onTrack => 0,
      };

      final score =
          urgentAlerts * 3 +
          unreadNudges * 2 +
          (inactivityDays >= 7
              ? 2
              : inactivityDays >= 3
              ? 1
              : 0) +
          statusPenalty;

      if (score == 0) continue;

      items.add(
        _AttentionItem(
          employee: employee,
          score: score,
          urgentAlerts: urgentAlerts,
          unreadNudges: unreadNudges,
          daysInactive: inactivityDays,
        ),
      );
    }

    items.sort((a, b) => b.score.compareTo(a.score));
    return items;
  }

  Widget _buildEmptyAlertsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardChrome.border),
      ),
      child: Column(
        children: [
          Icon(Icons.notifications_off, size: 48, color: DashboardChrome.fg),
          const SizedBox(height: 16),
          Text(
            'No Team Alerts',
            style: AppTypography.heading4.copyWith(color: DashboardChrome.fg),
          ),
          const SizedBox(height: 8),
          Text(
            'Your team doesn\'t have any alerts right now.',
            style: AppTypography.bodyMedium.copyWith(color: DashboardChrome.fg),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoEmployeesState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardChrome.border),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 48, color: DashboardChrome.fg),
          const SizedBox(height: 16),
          Text(
            'No Team Members',
            style: AppTypography.heading4.copyWith(color: DashboardChrome.fg),
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any team members to send nudges to.',
            style: AppTypography.bodyMedium.copyWith(color: DashboardChrome.fg),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper methods

  List<EmployeeData> _filterEmployees(List<EmployeeData> employees) {
    if (_searchQuery.isEmpty) return employees;

    return employees
        .where(
          (emp) =>
              emp.profile.displayName.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              emp.profile.jobTitle.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();
  }

  Color _getAlertColor(AlertPriority priority) {
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

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.managerNudge:
        return Icons.message;
      case AlertType.goalOverdue:
        return Icons.warning;
      case AlertType.goalDueSoon:
        return Icons.schedule;
      case AlertType.goalCompleted:
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Color _getStatusColor(EmployeeStatus status) {
    switch (status) {
      case EmployeeStatus.onTrack:
        return AppColors.successColor;
      case EmployeeStatus.atRisk:
        return AppColors.warningColor;
      case EmployeeStatus.overdue:
        return AppColors.dangerColor;
      case EmployeeStatus.inactive:
        return DashboardChrome.fg;
    }
  }

  IconData _getStatusIcon(EmployeeStatus status) {
    switch (status) {
      case EmployeeStatus.onTrack:
        return Icons.check_circle;
      case EmployeeStatus.atRisk:
        return Icons.warning;
      case EmployeeStatus.overdue:
        return Icons.error_outline;
      case EmployeeStatus.inactive:
        return Icons.pause_circle_outline;
    }
  }

  String _getStatusText(EmployeeStatus status) {
    switch (status) {
      case EmployeeStatus.onTrack:
        return 'On Track';
      case EmployeeStatus.atRisk:
        return 'At Risk';
      case EmployeeStatus.overdue:
        return 'Overdue';
      case EmployeeStatus.inactive:
        return 'Inactive';
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  // Action methods
  void _handleAlertAction(Alert alert, EmployeeData employee) async {
    try {
      await AlertService.markAsRead(alert.id);

      if (alert.actionRoute != null && mounted) {
        final route = alert.actionRoute!;
        Object? args;

        // Deep-link manager meeting alerts into the Review Team Dashboard.
        if (route == '/manager_review_team_dashboard') {
          final data = alert.actionData ?? const <String, dynamic>{};
          final meetingId = data['meetingId']?.toString().trim();
          final employeeId =
              (data['employeeId']?.toString().trim().isNotEmpty ?? false)
              ? data['employeeId']?.toString().trim()
              : employee.profile.uid;

          args = <String, dynamic>{
            'employeeId': employeeId,
            if (meetingId != null && meetingId.isNotEmpty)
              'meetingId': meetingId,
          };
        }

        Navigator.pushNamed(context, route, arguments: args);
      }
    } catch (e) {
      if (mounted) {
        await _showCenterNotice(context, 'Error: $e');
      }
    }
  }

  void _markAlertAsRead(String alertId) async {
    try {
      await AlertService.markAsRead(alertId);
    } catch (e) {
      if (mounted) {
        await _showCenterNotice(context, 'Error: $e');
      }
    }
  }

  void _markAllAlertsAsRead(List<Alert> alerts) async {
    try {
      // Filter out synthetic alerts (like inactivity) that don't exist in Firestore
      final realAlerts = alerts
          .where((a) => !a.id.startsWith('synthetic_'))
          .toList();
      final unreadAlerts = realAlerts
          .where((a) => !a.isRead && !_locallyMarkedAsRead.contains(a.id))
          .toList();

      if (unreadAlerts.isEmpty) {
        if (mounted) {
          await _showCenterNotice(context, 'All alerts are already read');
        }
        return;
      }

      // Optimistically update UI immediately
      if (mounted) {
        setState(() {
          _locallyMarkedAsRead.addAll(unreadAlerts.map((a) => a.id));
        });
      }

      // Mark as read in Firestore
      for (final alert in unreadAlerts) {
        try {
          await AlertService.markAsRead(alert.id);
        } catch (e) {
          // If marking fails, remove from optimistic update
          if (mounted) {
            setState(() {
              _locallyMarkedAsRead.remove(alert.id);
            });
          }
        }
      }

      if (mounted) {
        await _showCenterNotice(
          context,
          'Marked ${unreadAlerts.length} alert${unreadAlerts.length == 1 ? '' : 's'} as read',
        );
      }
    } catch (e) {
      // On error, clear optimistic updates
      if (mounted) {
        setState(() {
          _locallyMarkedAsRead.clear();
        });
        await _showCenterNotice(context, 'Error marking alerts as read: $e');
      }
    }
  }

  void _showSendNudgeDialog({EmployeeData? employee, String? presetMessage}) {
    showDialog(
      context: context,
      builder: (context) => _NudgeDialog(
        employee: employee,
        presetMessage: presetMessage,
        onSendNudge: (employeeId, goalId, message) =>
            _sendNudgeToEmployee(employeeId, goalId, message),
      ),
    );
  }

  void _showBulkNudgeDialog(List<EmployeeData> employees) {
    showDialog(
      context: context,
      builder: (context) => _BulkNudgeDialog(
        employees: employees,
        onSendBulkNudge: (message) => _sendBulkNudge(employees, message),
      ),
    );
  }

  void _sendNudgeToEmployee(
    String employeeId,
    String goalId,
    String message,
  ) async {
    try {
      await ManagerRealtimeService.sendNudgeToEmployee(
        employeeId: employeeId,
        goalId: goalId,
        message: message,
      );
      if (mounted) {
        await _showCenterNotice(context, 'Nudge sent successfully!');
      }
    } catch (e) {
      if (mounted) {
        await _showCenterNotice(context, 'Error sending nudge: $e');
      }
    }
  }

  Future<void> _loadTeamInsights(
    List<EmployeeData> employees,
    List<Alert> alerts,
  ) async {
    if (_isLoadingInsights) return;
    if (employees.isEmpty) {
      if (mounted) {
        await _showCenterNotice(
          context,
          'No employees available for insights yet.',
        );
      }
      return;
    }

    setState(() => _isLoadingInsights = true);

    try {
      final now = DateTime.now();
      final alertsByUser = <String, List<Alert>>{};
      for (final alert in alerts) {
        alertsByUser.putIfAbsent(alert.userId, () => []).add(alert);
      }

      final atRiskMembers = <Map<String, dynamic>>[];

      for (final employee in employees) {
        final reasons = <String>[];
        final recommendations = <String>[];
        final inactivityDays = now.difference(employee.lastActivity).inDays;
        final employeeAlerts = <Alert>[
          ...employee.recentAlerts
              .where((a) => !_isSuppressedStaleGoalOverdueAlert(a, employee)),
          ...alertsByUser[employee.profile.uid] ?? const <Alert>[],
        ];
        final urgentCount = employeeAlerts
            .where((alert) => alert.priority == AlertPriority.urgent)
            .length;
        final overdue = employee.overdueGoalsCount;
        final lowEngagement = employee.engagementScore < 55;
        final weakProgress = employee.avgProgress < 40;
        final lowActivity = employee.weeklyActivityCount <= 1;

        if (inactivityDays >= 5) {
          reasons.add('Inactive for $inactivityDays days');
          recommendations.add('Schedule a quick check-in to uncover blockers.');
        }
        if (overdue > 0) {
          reasons.add('$overdue overdue goal${overdue == 1 ? '' : 's'}');
          recommendations.add('Help reprioritize or rescope overdue goals.');
        }
        if (urgentCount > 0) {
          reasons.add(
            '$urgentCount urgent alert${urgentCount == 1 ? '' : 's'} pending',
          );
          recommendations.add(
            'Review urgent alerts together and clear blockers.',
          );
        }
        if (lowEngagement) {
          reasons.add(
            'Engagement at ${employee.engagementScore.toStringAsFixed(0)}%',
          );
          recommendations.add('Send recognition or a motivational nudge.');
        }
        if (weakProgress) {
          reasons.add(
            'Average progress ${employee.avgProgress.toStringAsFixed(0)}%',
          );
        }
        if (lowActivity) {
          reasons.add(
            '${employee.weeklyActivityCount} check-in${employee.weeklyActivityCount == 1 ? '' : 's'} this week',
          );
        }

        final riskScore = reasons.where((reason) => reason.isNotEmpty).length;
        if (riskScore >= 2) {
          final riskLevel = riskScore >= 3 ? 'high' : 'medium';
          final recommendation = recommendations.isEmpty
              ? 'Schedule a quick sync to plan next steps.'
              : recommendations.join(' ');
          atRiskMembers.add({
            'name': employee.profile.displayName,
            'riskLevel': riskLevel,
            'reasons': reasons,
            'recommendations': recommendation,
          });
        }
      }

      atRiskMembers.sort((a, b) {
        const ranking = {'high': 2, 'medium': 1, 'low': 0};
        final left = ranking[a['riskLevel']] ?? 0;
        final right = ranking[b['riskLevel']] ?? 0;
        return right.compareTo(left);
      });

      final highMomentum =
          employees
              .where((e) => e.engagementScore >= 75 && e.overdueGoalsCount == 0)
              .toList()
            ..sort((a, b) => b.engagementScore.compareTo(a.engagementScore));
      final lowMomentum =
          employees
              .where((e) => e.engagementScore <= 55 || e.overdueGoalsCount > 0)
              .toList()
            ..sort((a, b) {
              final overdueDiff = b.overdueGoalsCount.compareTo(
                a.overdueGoalsCount,
              );
              if (overdueDiff != 0) return overdueDiff;
              return a.engagementScore.compareTo(b.engagementScore);
            });

      final collaborationOpportunities = <Map<String, dynamic>>[];
      final pairLimit = math.min(
        3,
        math.min(highMomentum.length, lowMomentum.length),
      );

      for (var i = 0; i < pairLimit; i++) {
        final mentor = highMomentum[i];
        final mentee = lowMomentum[i];
        if (mentor.profile.uid == mentee.profile.uid) continue;

        final focusArea = mentee.overdueGoalsCount > 0
            ? 'clearing overdue goals'
            : 'building weekly habits';

        collaborationOpportunities.add({
          'member1': mentor.profile.displayName,
          'member2': mentee.profile.displayName,
          'reason': '${mentee.profile.displayName} needs help with $focusArea.',
          'suggestion':
              'Pair them for a quick sync so ${mentor.profile.displayName} can share routines that keep engagement at ${mentor.engagementScore.toStringAsFixed(0)}%.',
        });
      }

      final insights = <String, dynamic>{
        'generatedAt': DateTime.now().toIso8601String(),
        'atRiskMembers': atRiskMembers,
        'collaborationOpportunities': collaborationOpportunities,
      };

      if (!mounted) return;
      setState(() {
        _teamInsights = insights;
      });
    } catch (e) {
      if (mounted) {
        await _showCenterNotice(
          context,
          'Unable to generate insights right now. Please try again shortly.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingInsights = false);
      } else {
        _isLoadingInsights = false;
      }
    }
  }

  Future<void> _sendBulkNudge(
    List<EmployeeData> employees,
    String message,
  ) async {
    var successCount = 0;
    var errorCount = 0;

    for (final employee in employees) {
      try {
        final goalId = employee.goals.isNotEmpty
            ? employee.goals.first.id
            : 'general';
        await ManagerRealtimeService.sendNudgeToEmployee(
          employeeId: employee.profile.uid,
          goalId: goalId,
          message: message,
        );
        successCount++;
      } catch (_) {
        errorCount++;
      }
    }
    if (!mounted) return;

    await _showCenterNotice(
      context,
      'Bulk nudge sent: $successCount successes, $errorCount errors',
    );
  }

  Widget _buildTeamInsightsWidget() {
    if (_teamInsights == null) return const SizedBox.shrink();

    final atRiskMembers =
        _teamInsights!['atRiskMembers'] as List<dynamic>? ?? [];
    final collaborations =
        _teamInsights!['collaborationOpportunities'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.activeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: AppColors.activeColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Team Insights',
                style: AppTypography.heading4.copyWith(
                  color: DashboardChrome.fg,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: DashboardChrome.fg,
                onPressed: () {
                  setState(() => _teamInsights = null);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (atRiskMembers.isNotEmpty) ...[
            Text(
              'At-Risk Team Members',
              style: AppTypography.heading4.copyWith(
                color: DashboardChrome.fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...atRiskMembers.take(5).map((member) {
              final riskLevel =
                  member['riskLevel']?.toString().toLowerCase() ?? 'medium';
              Color riskColor;
              if (riskLevel == 'high') {
                riskColor = AppColors.dangerColor;
              } else if (riskLevel == 'medium') {
                riskColor = AppColors.warningColor;
              } else {
                riskColor = AppColors.infoColor;
              }

              final reasons = member['reasons'] as List<dynamic>? ?? [];
              final recommendations =
                  member['recommendations']?.toString() ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: riskColor.withValues(alpha: 0.3)),
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
                              member['name']?.toString() ?? 'Unknown',
                              style: AppTypography.bodyMedium.copyWith(
                                color: DashboardChrome.fg,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (reasons.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...reasons.map(
                          (reason) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: riskColor,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    reason.toString(),
                                    style: AppTypography.bodySmall.copyWith(
                                      color: DashboardChrome.fg,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (recommendations.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.activeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: AppColors.activeColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  recommendations,
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
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
          if (collaborations.isNotEmpty) ...[
            Text(
              'Collaboration Opportunities',
              style: AppTypography.heading4.copyWith(
                color: DashboardChrome.fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...collaborations.take(5).map((collab) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.successColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            color: AppColors.successColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${collab['member1']} ↔ ${collab['member2']}',
                              style: AppTypography.bodyMedium.copyWith(
                                color: DashboardChrome.fg,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        collab['reason']?.toString() ?? '',
                        style: AppTypography.bodySmall.copyWith(
                          color: DashboardChrome.fg,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.handshake,
                              color: AppColors.successColor,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                collab['suggestion']?.toString() ?? '',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.successColor,
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
          ],
        ],
      ),
    );
  }
}

// Nudge Dialog Widget
class _NudgeDialog extends StatefulWidget {
  final EmployeeData? employee;
  final String? presetMessage;
  final Function(String employeeId, String goalId, String message) onSendNudge;

  const _NudgeDialog({
    this.employee,
    this.presetMessage,
    required this.onSendNudge,
  });

  @override
  State<_NudgeDialog> createState() => _NudgeDialogState();
}

class _NudgeDialogState extends State<_NudgeDialog> {
  late TextEditingController _messageController;
  Goal? _selectedGoal;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: widget.presetMessage ?? '',
    );
    if (widget.employee?.goals.isNotEmpty == true) {
      _selectedGoal = widget.employee!.goals.first;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.employee != null
            ? 'Send Nudge to ${widget.employee!.profile.displayName}'
            : 'Send Nudge',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.employee != null &&
                widget.employee!.goals.isNotEmpty) ...[
              Text(
                'Related Goal:',
                style: AppTypography.bodyMedium.copyWith(
                  color: DashboardChrome.fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.elevatedBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: DropdownButton<Goal>(
                  value: _selectedGoal,
                  underline: const SizedBox(),
                  isExpanded: true,
                  hint: const Text('Select Goal'),
                  style: AppTypography.bodyMedium.copyWith(
                    color: DashboardChrome.fg,
                  ),
                  onChanged: (goal) => setState(() => _selectedGoal = goal),
                  items: widget.employee!.goals.map((goal) {
                    return DropdownMenuItem<Goal>(
                      value: goal,
                      child: Text(goal.title),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Message:',
              style: AppTypography.bodyMedium.copyWith(
                color: DashboardChrome.fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter your nudge message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.activeColor),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _sendNudge,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.activeColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Send'),
        ),
      ],
    );
  }

  void _sendNudge() {
    if (_messageController.text.trim().isEmpty) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: AppColors.cardBackground,
            content: Text(
              'Please enter a message',
              style: AppTypography.bodyMedium.copyWith(
                color: DashboardChrome.fg,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'OK',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.activeColor,
                  ),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    if (widget.employee == null) {
      return;
    }

    final goalId = _selectedGoal?.id ?? 'general';
    widget.onSendNudge(
      widget.employee!.profile.uid,
      goalId,
      _messageController.text.trim(),
    );
    Navigator.pop(context);
  }
}

// Bulk Nudge Dialog Widget
class _BulkNudgeDialog extends StatefulWidget {
  final List<EmployeeData> employees;
  final Function(String message) onSendBulkNudge;

  const _BulkNudgeDialog({
    required this.employees,
    required this.onSendBulkNudge,
  });

  @override
  State<_BulkNudgeDialog> createState() => _BulkNudgeDialogState();
}

class _BulkNudgeDialogState extends State<_BulkNudgeDialog> {
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Bulk Nudge'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipients (${widget.employees.length} team members):',
              style: AppTypography.bodyMedium.copyWith(
                color: DashboardChrome.fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.elevatedBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: ListView.builder(
                itemCount: widget.employees.length,
                itemBuilder: (context, index) {
                  final employee = widget.employees[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.activeColor.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            employee.profile.displayName.isNotEmpty
                                ? employee.profile.displayName[0].toUpperCase()
                                : '?',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.activeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            employee.profile.displayName,
                            style: AppTypography.bodySmall.copyWith(
                              color: DashboardChrome.fg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Message:',
              style: AppTypography.bodyMedium.copyWith(
                color: DashboardChrome.fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter your message for all team members...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.activeColor),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _sendBulkNudge,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.activeColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Send to All'),
        ),
      ],
    );
  }

  void _sendBulkNudge() {
    if (_messageController.text.trim().isEmpty) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: AppColors.cardBackground,
            content: Text(
              'Please enter a message',
              style: AppTypography.bodyMedium.copyWith(
                color: DashboardChrome.fg,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'OK',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.activeColor,
                  ),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    widget.onSendBulkNudge(_messageController.text.trim());
    Navigator.pop(context);
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final PreferredSizeWidget tabBar;
  final EdgeInsets margin;
  final BoxDecoration decoration;

  const _TabBarHeaderDelegate({
    required this.tabBar,
    required this.margin,
    required this.decoration,
  });

  @override
  double get minExtent => tabBar.preferredSize.height + margin.vertical;

  @override
  double get maxExtent => tabBar.preferredSize.height + margin.vertical;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Padding(
      padding: margin,
      child: DecoratedBox(decoration: decoration, child: tabBar),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    if (oldDelegate is _TabBarHeaderDelegate) {
      return tabBar != oldDelegate.tabBar ||
          margin != oldDelegate.margin ||
          decoration != oldDelegate.decoration;
    }
    return true;
  }
}

class _AttentionItem {
  final EmployeeData employee;
  final int score;
  final int urgentAlerts;
  final int unreadNudges;
  final int daysInactive;

  const _AttentionItem({
    required this.employee,
    required this.score,
    required this.urgentAlerts,
    required this.unreadNudges,
    required this.daysInactive,
  });
}
