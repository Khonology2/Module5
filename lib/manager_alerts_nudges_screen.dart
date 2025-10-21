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
  
  const ManagerAlertsNudgesScreen({
    super.key,
    this.embedded = false,
  });

  @override
  State<ManagerAlertsNudgesScreen> createState() => _ManagerAlertsNudgesScreenState();
}

class _ManagerAlertsNudgesScreenState extends State<ManagerAlertsNudgesScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  AlertPriority? _selectedPriority;
  final Set<String> _expandedApprovals = <String>{};
  bool _inboxPersonal = true; // true = Personal, false = Team
  String? _inboxTypeFilter; // null=All, 'alert' | 'nudge' | 'approval_request'
  bool _inboxUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _redirectIfManager();
  }

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

  Future<void> _rescheduleGoal(BuildContext context, String goalId, EmployeeData employee) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;

    final noteController = TextEditingController();
    final note = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Reschedule Note'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(labelText: 'Optional note'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Skip')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, noteController.text.trim()), child: const Text('Save')),
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
        message: 'Your goal has been rescheduled to ${picked.day}/${picked.month}/${picked.year}.',
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal rescheduled successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reschedule goal: $e')),
        );
      }
    }
  }

  Widget _buildApprovalsTab(List<EmployeeData> employees) {
    final manager = FirebaseAuth.instance.currentUser;
    if (manager == null) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Text(
            'Please sign in to view approvals',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return StreamBuilder<List<Alert>>(
      stream: AlertService.getUserAlertsStream(manager.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snapshot.data ?? const <Alert>[];
        // Filter to approval requests and de-duplicate by relatedGoalId (keep latest)
        final rawApprovals = all
            .where((a) => a.type == AlertType.goalApprovalRequested)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final Map<String, Alert> byGoal = {};
        for (final a in rawApprovals) {
          final key = a.relatedGoalId ?? a.id;
          if (!byGoal.containsKey(key)) {
            byGoal[key] = a; // since sorted desc, first is latest
          }
        }
        final approvals = byGoal.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (approvals.isEmpty) {
          return Center(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Text(
                'No pending approvals',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: AppSpacing.screenPadding,
          itemCount: approvals.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final alert = approvals[index];
            final expanded = _expandedApprovals.contains(alert.id);

            return Container(
              decoration: BoxDecoration(
                color: AppColors.elevatedBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.fact_check_outlined, color: AppColors.activeColor),
                    title: Text(
                      alert.title,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      alert.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (alert.relatedGoalId != null)
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance.collection('goals').doc(alert.relatedGoalId).snapshots(),
                            builder: (context, snap) {
                              final data = snap.data;
                              GoalApprovalStatus? status;
                              if (data != null && data.exists) {
                                try {
                                  final g = Goal.fromFirestore(data);
                                  status = g.approvalStatus;
                                } catch (_) {}
                              }
                              final isApproved = status == GoalApprovalStatus.approved;
                              final isRejected = status == GoalApprovalStatus.rejected;
                              if (isRejected) {
                                return ElevatedButton(
                                  onPressed: null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.dangerColor,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Rejected'),
                                );
                              }
                              return ElevatedButton(
                                onPressed: isApproved
                                    ? null
                                    : () async {
                                        final emp = employees.firstWhere(
                                          (e) => e.goals.any((g) => g.id == alert.relatedGoalId),
                                          orElse: () => employees.isNotEmpty ? employees.first : EmployeeData.fromMap({'profile': {}}, id: ''),
                                        );
                                        await _approveGoal(alert.relatedGoalId!, emp);
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isApproved ? AppColors.successColor : AppColors.activeColor,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(isApproved ? 'Approved' : 'Approve'),
                              );
                            },
                          ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'reject':
                                if (alert.relatedGoalId != null) {
                                  final emp = employees.firstWhere(
                                    (e) => e.goals.any((g) => g.id == alert.relatedGoalId),
                                    orElse: () => employees.isNotEmpty ? employees.first : EmployeeData.fromMap({'profile': {}}, id: ''),
                                  );
                                  await _rejectGoal(context, alert.relatedGoalId!, emp);
                                }
                                break;
                              case 'mark_read':
                                _markAlertAsRead(alert.id);
                                break;
                              case 'nudge':
                                if (employees.isNotEmpty) {
                                  _showSendNudgeDialog(employee: employees.first);
                                }
                                break;
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(value: 'reject', child: Text('Reject')),
                            PopupMenuItem(value: 'mark_read', child: Text('Mark Read')),
                            PopupMenuItem(value: 'nudge', child: Text('Send Nudge')),
                          ],
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              if (expanded) {
                                _expandedApprovals.remove(alert.id);
                              } else {
                                _expandedApprovals.add(alert.id);
                              }
                            });
                          },
                          icon: Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        if (expanded) {
                          _expandedApprovals.remove(alert.id);
                        } else {
                          _expandedApprovals.add(alert.id);
                        }
                      });
                    },
                  ),
                  if (expanded) ...[
                    const Divider(height: 1, color: Color(0x1FFFFFFF)),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          alert.message,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _approveGoal(String goalId, EmployeeData employee) async {
    try {
      final manager = FirebaseAuth.instance.currentUser;
      final managerName = manager?.displayName ?? 'Manager';
      await DatabaseService.approveGoal(
        goalId: goalId,
        managerId: manager?.uid ?? '',
        managerName: managerName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal approved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve goal: $e')),
        );
      }
    }
  }

  Future<void> _rejectGoal(BuildContext context, String goalId, EmployeeData employee) async {
    final controller = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Goal'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)'
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Reject')),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal rejected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject goal: $e')),
        );
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
          navigator.pushNamedAndRemoveUntil(
            '/sign_in',
            (route) => false,
          );
        }
      },
      content: StreamBuilder<List<EmployeeData>>(
        stream: ManagerRealtimeService.getTeamDataStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final employees = snapshot.data ?? [];

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.backgroundColor,
                  AppColors.backgroundColor.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Team Alerts & Nudges',
                              style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showSendNudgeDialog(),
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('Send Nudge'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.activeColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildStatsRow(employees),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.activeColor,
                    labelColor: AppColors.textPrimary,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Approvals', icon: Icon(Icons.fact_check_outlined, size: 20)),
                      Tab(text: 'Team Alerts', icon: Icon(Icons.notifications, size: 20)),
                      Tab(text: 'Send Nudges', icon: Icon(Icons.message_outlined, size: 20)),
                      Tab(text: 'Analytics', icon: Icon(Icons.analytics_outlined, size: 20)),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildApprovalsTab(employees),
                      _buildTeamAlertsTab(employees),
                      _buildSendNudgesTab(employees),
                      _buildAnalyticsTab(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(List<EmployeeData> employees) {
    final totalAlerts = employees.fold<int>(0, (sum, emp) => sum + emp.recentAlerts.length);
    final urgentAlerts = employees.fold<int>(0, (sum, emp) => 
      sum + emp.recentAlerts.where((a) => a.priority == AlertPriority.urgent).length);
    final overdueGoals = employees.fold<int>(0, (sum, emp) => sum + emp.overdueGoalsCount);

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

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
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
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
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
            priority: inactivityDays >= 7 ? AlertPriority.high : AlertPriority.medium,
            title: 'Employee Inactive',
            message: '${e.profile.displayName} inactive for $inactivityDays days',
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
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
      slivers: [
        SliverPadding(
          padding: AppSpacing.screenPadding,
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Team Alerts (${alerts.length})',
                    style: AppTypography.heading3.copyWith(color: AppColors.textPrimary)),
                if (alerts.any((alert) => !alert.isRead))
                  TextButton(
                    onPressed: () => _markAllAlertsAsRead(alerts),
                    child: Text('Mark All Read',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.activeColor)),
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
                (context, index) {
                  final alert = alerts[index];
                  final employee = employeesById[alert.userId] ?? (employees.isNotEmpty ? employees.first : employees.first);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _buildTeamAlertCard(alert, employee),
                  );
                },
                childCount: alerts.length,
              ),
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
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert.isRead ? AppColors.borderColor : alertColor.withValues(alpha: 0.3),
          width: alert.isRead ? 1 : 2,
        ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.activeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 6,
                                backgroundColor: alertColor.withValues(alpha: 0.1),
                                child: Text(
                                  employee.profile.displayName.isNotEmpty 
                                      ? employee.profile.displayName[0].toUpperCase()
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    onPressed: () => _handleAlertAction(alert, employee),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: alertColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(alert.actionText!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _markAlertAsRead(alert.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Mark Read'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showSendNudgeDialog(employee: employee),
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Nudge'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ],
            ),
          ],
          if (alert.type == AlertType.goalApprovalRequested && alert.relatedGoalId != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _approveGoal(alert.relatedGoalId!, employee),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Approve Goal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _rejectGoal(context, alert.relatedGoalId!, employee),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Reject Goal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dangerColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (alert.type == AlertType.goalOverdue && alert.relatedGoalId != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _rescheduleGoal(context, alert.relatedGoalId!, employee),
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
                    onPressed: () => _extendGoalDeadline(context, alert.relatedGoalId!, employee),
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
                    onPressed: () => _markGoalBurnout(alert.relatedGoalId!, employee),
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

  Future<void> _extendGoalDeadline(BuildContext context, String goalId, EmployeeData employee) async {
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
        message: 'Your goal deadline has been extended to ${picked.day}/${picked.month}/${picked.year}. You got this!',
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deadline extended successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to extend deadline: $e')),
        );
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
        message: 'Your goal has been paused by your manager. Take the time you need.',
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
        message: 'We noticed signs of burnout on a goal. It has been marked accordingly. Let’s regroup and plan a healthier path.',
        goalId: goalId,
      );
    } catch (e) {
      // Silent error
    }
  }

  Widget _buildSendNudgesTab(List<EmployeeData> employees) {
    final filteredEmployees = _filterEmployees(employees);

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send Team Nudges',
            style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search team members...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
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
              ),
              const SizedBox(width: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: () => _showBulkNudgeDialog(employees),
                icon: const Icon(Icons.group, size: 18),
                label: const Text('Bulk Nudge'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warningColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (filteredEmployees.isEmpty)
            _buildNoEmployeesState()
          else
            ...filteredEmployees.map((employee) => 
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _buildEmployeeNudgeCard(employee),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmployeeNudgeCard(EmployeeData employee) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _getStatusColor(employee.status).withValues(alpha: 0.1),
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
                  color: _getStatusColor(employee.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getStatusColor(employee.status).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getStatusIcon(employee.status), color: _getStatusColor(employee.status), size: 14),
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
                presetMessage: 'Hope you\'re doing well! How is your progress on your current goals?',
              ),
            ),
            _buildQuickNudgeButton(
              'Need Help?',
              Icons.support_agent,
              () => _showSendNudgeDialog(
                employee: employee,
                presetMessage: 'Is there anything I can help you with regarding your goals or work?',
              ),
            ),
            _buildQuickNudgeButton(
              'Great Work!',
              Icons.celebration,
              () => _showSendNudgeDialog(
                employee: employee,
                presetMessage: 'Great work on your recent progress! Keep it up!',
              ),
            ),
            _buildQuickNudgeButton(
              'Schedule Chat',
              Icons.chat,
              () => _showSendNudgeDialog(
                employee: employee,
                presetMessage: 'Let\'s catch up about your goals and any challenges you might be facing.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickNudgeButton(String text, IconData icon, VoidCallback onPressed) {
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

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nudge Analytics',
            style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Coming Soon',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.elevatedBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Analytics Dashboard',
                  style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track nudge effectiveness, response rates, and team engagement patterns.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAlertsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
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
           style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
         ),
         const SizedBox(height: 8),
         Text(
           'Your team doesn\'t have any alerts right now.',
           style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
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
       color: AppColors.elevatedBackground,
       borderRadius: BorderRadius.circular(12),
       border: Border.all(color: AppColors.borderColor),
     ),
     child: Column(
       children: [
         Icon(
           Icons.people_outline,
           size: 48,
           color: AppColors.textSecondary,
         ),
         const SizedBox(height: 16),
         Text(
           'No Team Members',
           style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
         ),
         const SizedBox(height: 8),
         Text(
           'You don\'t have any team members to send nudges to.',
           style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
           textAlign: TextAlign.center,
         ),
      ],
     ),
   );
 }

 // Helper methods

 List<EmployeeData> _filterEmployees(List<EmployeeData> employees) {
   if (_searchQuery.isEmpty) return employees;
   
   return employees.where((emp) => 
     emp.profile.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
     emp.profile.jobTitle.toLowerCase().contains(_searchQuery.toLowerCase())
   ).toList();
 }

 Color _getAlertColor(AlertPriority priority) {
   switch (priority) {
     case AlertPriority.urgent: return AppColors.dangerColor;
     case AlertPriority.high: return AppColors.warningColor;
     case AlertPriority.medium: return AppColors.activeColor;
     case AlertPriority.low: return AppColors.successColor;
   }
 }

 IconData _getAlertIcon(AlertType type) {
   switch (type) {
     case AlertType.managerNudge: return Icons.message;
     case AlertType.goalOverdue: return Icons.warning;
     case AlertType.goalDueSoon: return Icons.schedule;
     case AlertType.goalCompleted: return Icons.check_circle;
     default: return Icons.notifications;
   }
 }

 Color _getStatusColor(EmployeeStatus status) {
   switch (status) {
     case EmployeeStatus.onTrack: return AppColors.successColor;
     case EmployeeStatus.atRisk: return AppColors.warningColor;
     case EmployeeStatus.overdue: return AppColors.dangerColor;
     case EmployeeStatus.inactive: return AppColors.textSecondary;
   }
 }

 IconData _getStatusIcon(EmployeeStatus status) {
   switch (status) {
     case EmployeeStatus.onTrack: return Icons.check_circle;
     case EmployeeStatus.atRisk: return Icons.warning;
     case EmployeeStatus.overdue: return Icons.error_outline;
     case EmployeeStatus.inactive: return Icons.pause_circle_outline;
   }
 }

 String _getStatusText(EmployeeStatus status) {
   switch (status) {
     case EmployeeStatus.onTrack: return 'On Track';
     case EmployeeStatus.atRisk: return 'At Risk';
     case EmployeeStatus.overdue: return 'Overdue';
     case EmployeeStatus.inactive: return 'Inactive';
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
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Error: $e'),
           backgroundColor: AppColors.dangerColor,
         ),
       );
     }
   }
 }

 void _markAlertAsRead(String alertId) async {
   try {
     await AlertService.markAsRead(alertId);
   } catch (e) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Error: $e'),
           backgroundColor: AppColors.dangerColor,
         ),
       );
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
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Error: $e'),
           backgroundColor: AppColors.dangerColor,
         ),
       );
     }
   }
 }

 void _showSendNudgeDialog({EmployeeData? employee, String? presetMessage}) {
   showDialog(
     context: context,
     builder: (context) => _NudgeDialog(
       employee: employee,
       presetMessage: presetMessage,
       onSendNudge: (employeeId, goalId, message) => _sendNudgeToEmployee(employeeId, goalId, message),
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

 void _sendNudgeToEmployee(String employeeId, String goalId, String message) async {
   try {
     await ManagerRealtimeService.sendNudgeToEmployee(
       employeeId: employeeId,
       goalId: goalId,
       message: message,
     );

     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: const Text('Nudge sent successfully!'),
           backgroundColor: AppColors.successColor,
         ),
       );
     }
   } catch (e) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Error sending nudge: $e'),
           backgroundColor: AppColors.dangerColor,
         ),
       );
     }
   }
 }

 void _sendBulkNudge(List<EmployeeData> employees, String message) async {
   int successCount = 0;
   int errorCount = 0;

   for (final employee in employees) {
     try {
       // Use first active goal or create a general nudge
       final goalId = employee.goals.isNotEmpty ? employee.goals.first.id : 'general';
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
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Bulk nudge sent: $successCount successes, $errorCount errors'),
         backgroundColor: successCount > errorCount ? AppColors.successColor : AppColors.warningColor,
       ),
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
    _messageController = TextEditingController(text: widget.presetMessage ?? '');
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
            : 'Send Nudge'
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.employee != null && widget.employee!.goals.isNotEmpty) ...[
              Text(
                'Related Goal:',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a message'),
          backgroundColor: AppColors.warningColor,
        ),
      );
      return;
    }

    final goalId = _selectedGoal?.id ?? 'general';
    widget.onSendNudge(widget.employee!.profile.uid, goalId, _messageController.text.trim());
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
                          backgroundColor: AppColors.activeColor.withValues(alpha: 0.1),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a message'),
          backgroundColor: AppColors.warningColor,
        ),
      );
      return;
    }

    widget.onSendBulkNudge(_messageController.text.trim());
    Navigator.pop(context);
  }
}
