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
  // ignore: unused_field
  Future<NudgeAnalyticsSummary>? _analyticsFuture;
  // ignore: unused_field, prefer_final_fields
  bool _showNudgeTrend = true;
  bool _isLoadingInsights = false;
  Map<String, dynamic>? _teamInsights;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
                  tabs: [
                    Tab(
                      text: 'Approvals',
                      icon: Image.asset(
                        'assets/Data_Approval/Approval_Red Badge_White.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Tab(
                      text: 'Team Alerts',
                      icon: Image.asset(
                        'assets/red_bell.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Tab(
                      text: 'Send Nudges',
                      icon: Image.asset(
                        'assets/Send_Paper_Plane/Send_Plane_Red_Badge_White.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Tab(
                      text: 'Analytics',
                      icon: Image.asset(
                        'assets/Project Management/Project_Red Badge_White.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                );

                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: AppSpacing.screenPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatsRow(employees),
                          const SizedBox(height: AppSpacing.md),
                          _buildMarkAllAsReadButton(employees),
                        ],
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
    final allAlerts = employees.expand((emp) => emp.recentAlerts).toList();
    final unreadAlerts = allAlerts.where((a) => !a.isRead).length;
    final totalAlerts = allAlerts.length;
    final urgentAlerts = employees.fold<int>(
      0,
      (acc, emp) =>
          acc +
          emp.recentAlerts
              .where((a) => a.priority == AlertPriority.urgent && !a.isRead)
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
            'Unread Alerts',
            unreadAlerts.toString(),
            AppColors.activeColor,
            Icons.notifications,
            subtitle: totalAlerts > 0 ? 'of $totalAlerts total' : null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatCard(
            'Urgent',
            urgentAlerts.toString(),
            AppColors.dangerColor,
            null,
            imageAsset:
                'assets/Information_Detail/Information_Red_Badge_White.png',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatCard(
            'Overdue Goals',
            overdueGoals.toString(),
            AppColors.warningColor,
            null,
            imageAsset:
                'assets/Time_Allocation_Approval/Allocation_Red Badge_White.png',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatCard(
            'Team Members',
            employees.length.toString(),
            AppColors.successColor,
            null,
            imageAsset: 'assets/Team_Meeting/Meeting_Red Badge_White.png',
          ),
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
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          if (imageAsset != null)
            Image.asset(imageAsset, width: 24, height: 24, fit: BoxFit.contain)
          else if (icon != null)
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
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarkAllAsReadButton(List<EmployeeData> employees) {
    // Collect all alerts from all employees
    final allAlerts = <Alert>[];
    for (final e in employees) {
      allAlerts.addAll(e.recentAlerts);
    }

    // Filter out synthetic alerts
    final realAlerts = allAlerts
        .where((a) => !a.id.startsWith('synthetic_'))
        .toList();
    final unreadCount = realAlerts.where((a) => !a.isRead).length;

    // Always show button when there are employees (even if no alerts yet)
    if (employees.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mark All Alerts as Read',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                realAlerts.isEmpty
                    ? 'No alerts to mark as read'
                    : unreadCount > 0
                    ? 'Mark all $unreadCount unread alert${unreadCount == 1 ? '' : 's'} as read across all tabs'
                    : 'All ${realAlerts.length} alert${realAlerts.length == 1 ? '' : 's'} are already read',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: (realAlerts.isNotEmpty && unreadCount > 0)
                ? () => _markAllAlertsAsRead(realAlerts)
                : null,
            icon: const Icon(Icons.done_all, size: 18),
            label: Text(
              realAlerts.isEmpty
                  ? 'No Alerts'
                  : unreadCount > 0
                  ? 'Mark All as Read'
                  : 'All Read',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: (realAlerts.isNotEmpty && unreadCount > 0)
                  ? AppColors.activeColor
                  : AppColors.textSecondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Team Alerts (${alerts.length})',
                      style: AppTypography.heading3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _loadTeamInsights(employees, alerts),
                      icon: _isLoadingInsights
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.insights, size: 18),
                      label: const Text('AI Team Insights'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.activeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_teamInsights != null) _buildTeamInsightsWidget(),
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
              delegate: SliverChildBuilderDelegate((context, index) {
                final alert = alerts[index];
                final employee =
                    employeesById[alert.userId] ??
                    (employees.isNotEmpty ? employees.first : null);
                if (employee == null) {
                  return const SizedBox.shrink();
                }
                return _buildTeamAlertCard(alert, employee);
              }, childCount: alerts.length),
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
            color: AppColors.textSecondary,
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
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goal.title,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
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
                  color: AppColors.textSecondary,
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
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
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
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoUrgentGoalsState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No urgent goals right now',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You’ll see employees appear here when a goal is overdue or due within two days.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
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
      // Filter out synthetic alerts (like inactivity) that don't exist in Firestore
      final realAlerts = alerts
          .where((a) => !a.id.startsWith('synthetic_'))
          .toList();
      final unreadAlerts = realAlerts.where((a) => !a.isRead).toList();

      if (unreadAlerts.isEmpty) {
        if (mounted) {
          await _showCenterNotice(context, 'All alerts are already read');
        }
        return;
      }

      for (final alert in unreadAlerts) {
        try {
          await AlertService.markAsRead(alert.id);
        } catch (e) {
          // Silently skip alerts that can't be marked as read (might not exist in Firestore)
        }
      }

      if (mounted) {
        await _showCenterNotice(
          context,
          'Marked ${unreadAlerts.length} alert${unreadAlerts.length == 1 ? '' : 's'} as read',
        );
      }
    } catch (e) {
      if (mounted) {
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
          ...employee.recentAlerts,
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
        color: Colors.black.withValues(alpha: 0.4),
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
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.textSecondary,
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
                color: AppColors.textPrimary,
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
                                color: AppColors.textPrimary,
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
                                      color: AppColors.textSecondary,
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
                color: AppColors.textPrimary,
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
                                color: AppColors.textPrimary,
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
                          color: AppColors.textSecondary,
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
