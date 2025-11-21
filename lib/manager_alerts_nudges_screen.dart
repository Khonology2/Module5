// ignore_for_file: unused_element

import 'dart:math' as math;

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

class ManagerAlertsNudgesScreen extends StatefulWidget {
  final bool embedded;

  const ManagerAlertsNudgesScreen({super.key, this.embedded = false});

  @override
  State<ManagerAlertsNudgesScreen> createState() =>
      _ManagerAlertsNudgesScreenState();
}

class _ManagerAlertsNudgesScreenState extends State<ManagerAlertsNudgesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  // true = Personal, false = Team
  // null=All, 'alert' | 'nudge' | 'approval_request'
  // SMART rubric state per goalId
  // ignore: unused_field
  final _approvalsStatusFilter = 'all'; // 'all' | 'approved' | 'rejected'
  // ignore: unused_field
  final Set<String> _expandedApprovals = <String>{};
  AlertPriority? _selectedPriority;
  Future<NudgeAnalyticsSummary>? _analyticsFuture;
  bool _showNudgeTrend = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _analyticsFuture = ManagerRealtimeService.fetchManagerNudgeAnalytics();
    _redirectIfManager();
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safety: if hot reload preserved an older controller with wrong length, recreate it
    if (_tabController.length != 4) {
      _tabController.dispose();
      _tabController = TabController(length: 4, vsync: this);
    }
  }

  Future<void> _redirectIfManager() async {
    try {
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

  Future<void> _refreshAnalytics() async {
    setState(() {
      _analyticsFuture = ManagerRealtimeService.fetchManagerNudgeAnalytics();
    });
    try {
      await _analyticsFuture;
    } catch (_) {
      // ignore refresh errors; UI will show current snapshot or error message
    }
  }

  Future<void> _showCenterNotice(BuildContext context, String message) async {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          content: Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
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
      builder: (ctx) => AlertDialog(
        title: const Text('Add Reschedule Note'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(labelText: 'Optional note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, noteController.text.trim()),
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
    // Build a view-only list of approved/rejected goals across the team
    final items = <Map<String, dynamic>>[];
    for (final emp in employees) {
      for (final g in emp.goals) {
        if (g.approvalStatus == GoalApprovalStatus.approved ||
            g.approvalStatus == GoalApprovalStatus.rejected) {
          items.add({'employee': emp, 'goal': g});
        }
      }
    }
    items.sort((a, b) {
      final ga = (a['goal'] as Goal).targetDate;
      final gb = (b['goal'] as Goal).targetDate;
      return gb.compareTo(ga);
    });

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Text(
            'No approved or rejected goals',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
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
              return Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    isApproved
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    color: color,
                  ),
                  title: Text(
                    g.title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${emp.profile.displayName} • ${_fmtDate(g.targetDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Team Alerts & Nudges',
      showAppBar: false,
      embedded: widget.embedded,
      items: SidebarConfig.getItemsForRole('manager'),
      currentRouteName: '/manager_alerts_nudges',
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
      content: StreamBuilder<List<EmployeeData>>(
        stream: ManagerRealtimeService.getTeamDataStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.activeColor,
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final employees = snapshot.data ?? [];

          return Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/khono_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                final tabBar = TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.activeColor,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(
                      text: 'Approvals',
                      icon: Icon(Icons.fact_check_outlined, size: 20),
                    ),
                    Tab(
                      text: 'Team Alerts',
                      icon: Icon(Icons.notifications, size: 20),
                    ),
                    Tab(
                      text: 'Send Nudges',
                      icon: Icon(Icons.message_outlined, size: 20),
                    ),
                    Tab(
                      text: 'Analytics',
                      icon: Icon(Icons.analytics_outlined, size: 20),
                    ),
                  ],
                );

                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: AppSpacing.screenPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [_buildStatsRow(employees)],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    floating: false,
                    delegate: _TabBarHeaderDelegate(
                      tabBar: tabBar,
                      margin: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md / 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                physics: const ClampingScrollPhysics(),
                children: [
                  _buildApprovalsTab(employees),
                  _buildTeamAlertsTab(employees),
                  _buildSendNudgesTab(employees),
                  _buildAnalyticsTab(employees),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // removed skeleton placeholders

  Widget _buildStatsRow(List<EmployeeData> employees) {
    final totalAlerts = employees.fold<int>(
      0,
      (acc, emp) => acc + emp.recentAlerts.length,
    );
    final urgentAlerts = employees.fold<int>(
      0,
      (acc, emp) =>
          acc +
          emp.recentAlerts
              .where((a) => a.priority == AlertPriority.urgent)
              .length,
    );
    final overdueGoals = employees.fold<int>(
      0,
      (acc, emp) => acc + emp.overdueGoalsCount,
    );

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Alerts',
            totalAlerts.toString(),
            AppColors.activeColor,
            Icons.notifications,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatCard(
            'Urgent',
            urgentAlerts.toString(),
            AppColors.dangerColor,
            Icons.priority_high,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatCard(
            'Overdue Goals',
            overdueGoals.toString(),
            AppColors.warningColor,
            Icons.schedule,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatCard(
            'Team Members',
            employees.length.toString(),
            AppColors.successColor,
            Icons.people_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
            'Please sign in to view team alerts',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final Map<String, EmployeeData> employeesById = {
      for (final e in employees) e.profile.uid: e,
    };

    final allAlerts = <Alert>[];
    for (final e in employees) {
      allAlerts.addAll(e.recentAlerts);
    }

    final now = DateTime.now();
    for (final e in employees) {
      final inactivityDays = now.difference(e.lastActivity).inDays;
      if (inactivityDays >= 3) {
        allAlerts.add(
          Alert(
            id: 'synthetic_inactivity_${e.profile.uid}',
            userId: e.profile.uid,
            type: AlertType.inactivity,
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
    }

    final filteredAlerts = allAlerts.where((a) {
      return a.type == AlertType.goalOverdue ||
          a.type == AlertType.inactivity ||
          a.type == AlertType.seasonJoined ||
          a.type == AlertType.seasonCompleted ||
          a.type == AlertType.seasonProgressUpdate;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final Map<String, Alert> dedup = {};
    for (final a in filteredAlerts) {
      final key = '${a.type.name}__${a.relatedGoalId ?? a.id}';
      if (!dedup.containsKey(key)) {
        dedup[key] = a;
      }
    }
    final alerts = dedup.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: AppSpacing.screenPadding,
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Team Alerts (${alerts.length})',
                  style: AppTypography.heading3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (alerts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: _buildEmptyAlertsState(),
            ),
          )
        else
          SliverPadding(
            padding: AppSpacing.screenPadding,
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildTeamAlertCard(
                  alerts[index],
                  employeesById[alerts[index].userId] ?? employees.first,
                ),
                childCount: alerts.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search alerts...',
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
              ),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: DropdownButton<AlertPriority?>(
            value: _selectedPriority,
            underline: const SizedBox(),
            hint: Text(
              'Priority',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            onChanged: (priority) =>
                setState(() => _selectedPriority = priority),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All Priorities'),
              ),
              ...AlertPriority.values.map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text(p.name.toUpperCase()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamAlertCard(Alert alert, EmployeeData employee) {
    final alertColor = _getAlertColor(alert.priority);
    final alertIcon = _getAlertIcon(alert.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                                  color: AppColors.textSecondary,
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
                            color: AppColors.textSecondary,
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
                    onPressed: () => _rescheduleGoal(
                      context,
                      alert.relatedGoalId!,
                      employee,
                    ),
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
                    onPressed: () => _extendGoalDeadline(
                      context,
                      alert.relatedGoalId!,
                      employee,
                    ),
                    icon: const Icon(Icons.schedule),
                    label: const Text('Extend Deadline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pauseGoal(alert.relatedGoalId!, employee),
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Pause Goal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _markGoalBurnout(alert.relatedGoalId!, employee),
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
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search team members...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textSecondary,
                    ),
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
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _buildEmployeeNudgeCard(filteredEmployees[index]),
                    ),
                    childCount: filteredEmployees.length,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmployeeNudgeCard(EmployeeData employee) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${employee.goals.where((g) => g.status == GoalStatus.inProgress).length} active goals • ${employee.avgProgress.toStringAsFixed(1)}% progress',
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
            color: AppColors.textSecondary,
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

  Widget _buildAnalyticsTab(List<EmployeeData> employees) {
    return StreamBuilder<List<ManagerAction>>(
      stream: ManagerRealtimeService.getManagerActionsStream(limit: 250),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.activeColor,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Text(
                'Analytics unavailable: ${snapshot.error}',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.redAccent,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final actions = snapshot.data ?? [];
        return _buildAnalyticsContent(employees, actions);
      },
    );
  }

  Widget _buildAnalyticsContent(
    List<EmployeeData> employees,
    List<ManagerAction> actions,
  ) {
    final managerId = FirebaseAuth.instance.currentUser?.uid;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final weeklyNudges = actions.where((action) {
      return action.actionType == ManagementAction.sendNudge &&
          action.createdAt.isAfter(sevenDaysAgo);
    }).toList();

    final uniqueEmployeesNudged = weeklyNudges
        .map((action) => action.employeeId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;

    final followUpActions = actions.where((action) {
      return action.createdAt.isAfter(sevenDaysAgo) &&
          action.actionType != ManagementAction.sendNudge;
    }).toList();

    final nudgeAlerts = employees.expand((e) => e.recentAlerts).where((alert) {
      if (alert.type != AlertType.managerNudge) return false;
      if (managerId == null || alert.fromUserId == null) return true;
      return alert.fromUserId == managerId;
    }).toList();

    final openedNudges = nudgeAlerts
        .where((alert) => alert.isRead && !alert.isDismissed)
        .length;
    final dismissedNudges = nudgeAlerts
        .where((alert) => alert.isDismissed)
        .length;
    final pendingNudges = nudgeAlerts.length - openedNudges - dismissedNudges;

    final responseRate = nudgeAlerts.isNotEmpty
        ? (openedNudges / nudgeAlerts.length) * 100
        : 0.0;

    final dailyBuckets = List.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final count = weeklyNudges
          .where(
            (action) =>
                action.createdAt.isAfter(dayStart) &&
                action.createdAt.isBefore(dayEnd),
          )
          .length;
      return _DailyNudgeBucket(label: _weekdayLabel(day.weekday), count: count);
    });

    final followUpSummary = <ManagementAction, int>{};
    for (final action in followUpActions) {
      followUpSummary.update(
        action.actionType,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final topFollowUps = followUpSummary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final attentionItems = _buildAttentionItems(
      employees: employees,
      managerId: managerId,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: AppSpacing.screenPadding,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nudge Analytics',
                      style: AppTypography.heading3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.activeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.activeColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Response Rate: ${responseRate.toStringAsFixed(0)}%',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.activeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildAnalyticsStatGrid(
                  totalNudges: weeklyNudges.length,
                  uniqueEmployees: uniqueEmployeesNudged,
                  opened: openedNudges,
                  pending: pendingNudges,
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: AppSpacing.screenPadding.copyWith(top: 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResponseBreakdown(
                  opened: openedNudges,
                  pending: pendingNudges,
                  dismissed: dismissedNudges,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Show 7-Day Nudge Trend',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Switch.adaptive(
                      value: _showNudgeTrend,
                      activeTrackColor: AppColors.activeColor,
                      onChanged: (value) {
                        setState(() => _showNudgeTrend = value);
                      },
                    ),
                  ],
                ),
                if (_showNudgeTrend) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildNudgeTrendSection(dailyBuckets),
                  const SizedBox(height: AppSpacing.lg),
                ] else
                  const SizedBox(height: AppSpacing.lg),
                _buildFollowUpSection(topFollowUps),
                const SizedBox(height: AppSpacing.lg),
                _buildAttentionSection(attentionItems),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsStatGrid({
    required int totalNudges,
    required int uniqueEmployees,
    required int opened,
    required int pending,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.8,
      children: [
        _buildAnalyticsStatCard(
          title: 'Nudges Sent (7d)',
          value: totalNudges.toString(),
          icon: Icons.campaign_outlined,
          color: AppColors.activeColor,
          subtitle: totalNudges == 0
              ? 'No nudges this week'
              : 'Avg ${(totalNudges / 7).toStringAsFixed(1)} per day',
        ),
        _buildAnalyticsStatCard(
          title: 'Unique Employees',
          value: uniqueEmployees.toString(),
          icon: Icons.groups_outlined,
          color: AppColors.infoColor,
          subtitle: uniqueEmployees == 0
              ? 'No recent outreach'
              : '$uniqueEmployees reached in 7 days',
        ),
        _buildAnalyticsStatCard(
          title: 'Opened Nudges',
          value: opened.toString(),
          icon: Icons.mark_email_read_outlined,
          color: AppColors.successColor,
          subtitle: 'Team members engaged',
        ),
        _buildAnalyticsStatCard(
          title: 'Pending Nudges',
          value: pending.toString(),
          icon: Icons.pending_actions_outlined,
          color: AppColors.warningColor,
          subtitle: pending == 0 ? 'All nudges viewed' : 'Needs follow-up',
        ),
      ],
    );
  }

  Widget _buildAnalyticsStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Icon(
                Icons.trending_up,
                size: 16,
                color: color.withValues(alpha: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResponseBreakdown({
    required int opened,
    required int pending,
    required int dismissed,
  }) {
    final total = opened + pending + dismissed;
    final openedPct = total == 0 ? 0.0 : opened / total;
    final pendingPct = total == 0 ? 0.0 : pending / total;
    final dismissedPct = total == 0 ? 0.0 : dismissed / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights_outlined,
                color: AppColors.activeColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Nudge Response Breakdown',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBreakdownRow(
            label: 'Opened',
            value: opened,
            percentage: openedPct,
            color: AppColors.successColor,
          ),
          const SizedBox(height: 12),
          _buildBreakdownRow(
            label: 'Pending',
            value: pending,
            percentage: pendingPct,
            color: AppColors.warningColor,
          ),
          const SizedBox(height: 12),
          _buildBreakdownRow(
            label: 'Dismissed',
            value: dismissed,
            percentage: dismissedPct,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow({
    required String label,
    required int value,
    required double percentage,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              value.toString(),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(percentage * 100).toStringAsFixed(0)}%',
              style: AppTypography.bodySmall.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage.clamp(0.0, 1.0),
            backgroundColor: AppColors.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildNudgeTrendSection(List<_DailyNudgeBucket> buckets) {
    final maxCount = buckets.isEmpty
        ? 1
        : math.max(1, buckets.map((b) => b.count).reduce(math.max));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline_outlined,
                color: AppColors.infoColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '7-Day Nudge Trend',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...buckets.map((bucket) {
            final normalized = maxCount == 0 ? 0.0 : bucket.count / maxCount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      bucket.label,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: normalized.isNaN ? 0.0 : normalized,
                        backgroundColor: AppColors.borderColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.activeColor,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    bucket.count.toString(),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          Text(
            'Keep your outreach consistent. A steady cadence of nudges builds accountability and momentum.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpSection(
    List<MapEntry<ManagementAction, int>> followUps,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.follow_the_signs_outlined,
                color: AppColors.warningColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Follow-up Actions (7d)',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (followUps.isEmpty)
            Text(
              'No follow-up actions recorded in the past 7 days. Turn nudges into coaching moments with 1:1s, recognition, or support.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            Column(
              children: followUps.take(3).map((entry) {
                final actionLabel = _formatManagementAction(entry.key);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _iconForManagementAction(entry.key),
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          actionLabel,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.activeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${entry.value}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.activeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  Widget _buildAttentionSection(List<_AttentionItem> items) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                  color: AppColors.textPrimary,
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
                color: AppColors.textSecondary,
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
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                    ),
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
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${item.urgentAlerts} urgent alerts • ${item.unreadNudges} unread nudges',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
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
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.daysInactive > 0
                                ? 'Inactive ${item.daysInactive}d'
                                : 'Active today',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
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

  String _formatManagementAction(ManagementAction action) {
    switch (action) {
      case ManagementAction.sendNudge:
        return 'Sent Nudge';
      case ManagementAction.scheduleMeeting:
        return 'Scheduled 1:1';
      case ManagementAction.assignGoal:
        return 'Assigned Goal';
      case ManagementAction.reassignGoal:
        return 'Reassigned Goal';
      case ManagementAction.giveRecognition:
        return 'Gave Recognition';
      case ManagementAction.provideFeedback:
        return 'Provided Feedback';
      case ManagementAction.escalateIssue:
        return 'Escalated Issue';
      case ManagementAction.adjustWorkload:
        return 'Adjusted Workload';
      case ManagementAction.offerSupport:
        return 'Offered Support';
    }
  }

  IconData _iconForManagementAction(ManagementAction action) {
    switch (action) {
      case ManagementAction.sendNudge:
        return Icons.notifications_active_outlined;
      case ManagementAction.scheduleMeeting:
        return Icons.event_available_outlined;
      case ManagementAction.assignGoal:
        return Icons.flag_outlined;
      case ManagementAction.reassignGoal:
        return Icons.swap_horiz_outlined;
      case ManagementAction.giveRecognition:
        return Icons.emoji_events_outlined;
      case ManagementAction.provideFeedback:
        return Icons.feedback_outlined;
      case ManagementAction.escalateIssue:
        return Icons.warning_amber_outlined;
      case ManagementAction.adjustWorkload:
        return Icons.tune_outlined;
      case ManagementAction.offerSupport:
        return Icons.volunteer_activism_outlined;
    }
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
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
            Icons.notifications_off,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Team Alerts',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your team doesn\'t have any alerts right now.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
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
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No Team Members',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any team members to send nudges to.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
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
        return AppColors.textSecondary;
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
        Navigator.pushNamed(context, alert.actionRoute!);
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
      for (final alert in alerts.where((a) => !a.isRead)) {
        await AlertService.markAsRead(alert.id);
      }
    } catch (e) {
      if (mounted) {
        await _showCenterNotice(context, 'Error: $e');
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

  void _sendBulkNudge(List<EmployeeData> employees, String message) async {
    int successCount = 0;
    int errorCount = 0;

    for (final employee in employees) {
      try {
        // Use first active goal or create a general nudge
        final goalId = employee.goals.isNotEmpty
            ? employee.goals.first.id
            : 'general';
        await ManagerRealtimeService.sendNudgeToEmployee(
          employeeId: employee.profile.uid,
          goalId: goalId,
          message: message,
        );
        successCount++;
      } catch (e) {
        errorCount++;
      }
    }

    if (mounted) {
      await _showCenterNotice(
        context,
        'Bulk nudge sent: $successCount successes, $errorCount errors',
      );
    }
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
                  color: AppColors.textPrimary,
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
                    color: AppColors.textPrimary,
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
                color: AppColors.textPrimary,
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
                color: AppColors.textPrimary,
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
                color: AppColors.textPrimary,
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
                              color: AppColors.textPrimary,
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
                color: AppColors.textPrimary,
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
                color: AppColors.textPrimary,
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

  _TabBarHeaderDelegate({
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
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        margin != oldDelegate.margin ||
        decoration != oldDelegate.decoration;
  }
}

class _DailyNudgeBucket {
  final String label;
  final int count;

  const _DailyNudgeBucket({required this.label, required this.count});
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
