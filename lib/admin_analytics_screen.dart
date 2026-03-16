import 'package:flutter/material.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  final bool embedded;
  final void Function(String route)? onNavigate;

  const AdminAnalyticsScreen({
    super.key,
    this.embedded = false,
    this.onNavigate,
  });

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  String _adminName = 'Admin';
  late Stream<List<EmployeeData>> _managersStream;
  final Stopwatch _loadWatch = Stopwatch()..start();
  String _selectedTimePeriod = '7 days';

  @override
  void initState() {
    super.initState();
    _loadAdminName();
    _managersStream = ManagerRealtimeService.getManagersDataStream();
    _loadWatch
      ..reset()
      ..start();
  }

  Future<void> _loadAdminName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String name = 'Admin';
      if (user != null) {
        final profile = await DatabaseService.getUserProfile(user.uid);
        final display = profile.displayName.trim();
        if (display.isNotEmpty) {
          name = display.split(' ').first;
        } else if ((user.displayName ?? '').isNotEmpty) {
          name = user.displayName!.split(' ').first;
        } else if ((user.email ?? '').isNotEmpty) {
          name = user.email!.split('@').first;
        }
      }
      if (!mounted) return;
      setState(() {
        _adminName = name;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: StreamBuilder<List<EmployeeData>>(
        stream: _managersStream,
        builder: (context, managersSnap) {
          if (managersSnap.hasError) {
            return Center(
              child: Text('Error loading managers: ${managersSnap.error}'),
            );
          }
          if (!managersSnap.hasData) {
            final timedOut = _loadWatch.elapsed > const Duration(seconds: 12);
            if (timedOut) {
              return _buildTimedOutState();
            }
            return const SizedBox(
              height: 360,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.activeColor,
                  ),
                ),
              ),
            );
          }

          final managers = managersSnap.data!;
          if (_loadWatch.isRunning) {
            _loadWatch.stop();
          }
          final analytics = _computeAnalyticsMetrics(managers);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: AppSpacing.xl),
              _buildTimePeriodSelector(),
              const SizedBox(height: AppSpacing.xl),
              _buildAnalyticsOverview(analytics),
              const SizedBox(height: AppSpacing.xl),
              _buildManagerPerformanceGrid(managers),
              const SizedBox(height: AppSpacing.xl),
              _buildActivityTrends(managers),
              const SizedBox(height: AppSpacing.xl),
              _buildGoalAnalytics(managers),
              const SizedBox(height: AppSpacing.xl),
              _buildTeamHealthOverview(managers),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/khono_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: content,
    );
  }

  Widget _buildTimedOutState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppComponents.card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Still loading…',
                  style: AppTypography.heading4,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We couldn\'t load manager analytics. This is usually caused by a connection issue or missing Firestore permissions.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _managersStream =
                              ManagerRealtimeService.getManagersDataStream();
                          _loadWatch
                            ..reset()
                            ..start();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.activeColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await AuthService().signOut();
                        if (mounted) {
                          navigator.pushNamedAndRemoveUntil(
                            '/sign_in',
                            (route) => false,
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }

  Widget _buildWelcomeCard() {
    final greeting = _getTimeBasedGreeting();
    return _card(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.analytics_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, ${_resolveAdminName()}!',
                  style: AppTypography.heading4,
                ),
                const SizedBox(height: 4),
                Text(
                  'Analytics overview of all managers across the organization.',
                  style: AppTypography.bodyMedium.copyWith(
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

  Widget _buildTimePeriodSelector() {
    return _card(
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: AppColors.activeColor, size: 20),
          const SizedBox(width: 12),
          Text(
            'Time Period:',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: DropdownButton<String>(
                value: _selectedTimePeriod,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedTimePeriod = newValue;
                    });
                  }
                },
                dropdownColor: Colors.black.withValues(alpha: 0.9),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                underline: const SizedBox.shrink(),
                isExpanded: true,
                items: const ['7 days', '30 days', '90 days', 'All time']
                    .map((value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsOverview(AnalyticsMetrics metrics) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analytics Overview', style: AppTypography.heading2),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricTile('Total Managers', metrics.totalManagers.toString()),
              _metricTile('Active Managers', metrics.activeManagers.toString()),
              _metricTile('Avg Goals', metrics.avgGoalLoad.toStringAsFixed(1)),
              _metricTile(
                'Overall Engagement',
                '${metrics.overallEngagement.toStringAsFixed(0)}%',
              ),
              _metricTile(
                'Goals Completed',
                metrics.totalGoalsCompleted.toString(),
              ),
              _metricTile(
                'Overdue Goals',
                metrics.totalOverdueGoals.toString(),
                color: metrics.totalOverdueGoals > 0
                    ? AppColors.warningColor
                    : null,
              ),
              _metricTile(
                'Pending Approvals',
                metrics.totalPendingApprovals.toString(),
              ),
              _metricTile(
                'Avg Progress',
                '${metrics.avgProgress.toStringAsFixed(0)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagerPerformanceGrid(List<EmployeeData> managers) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manager Performance', style: AppTypography.heading2),
          const SizedBox(height: 8),
          Text(
            'Tap a manager to view more detail.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...managers.map(
            (manager) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildManagerCard(manager),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagerCard(EmployeeData manager) {
    final engagement = manager.engagementScore;
    final progress = manager.avgProgress;
    final overdue = manager.overdueGoalsCount;
    final goalLoad = manager.goals.length;

    return InkWell(
      onTap: () => _showManagerDetailsDialog(manager),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              child: Text(
                manager.profile.displayName.isNotEmpty
                    ? manager.profile.displayName[0].toUpperCase()
                    : 'M',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manager.profile.displayName,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Goals: $goalLoad • Progress: ${progress.toStringAsFixed(0)}%',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Engagement ${engagement.toStringAsFixed(0)}%',
                  style: AppTypography.caption.copyWith(
                    color: _engagementColor(engagement),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (overdue > 0)
                  Text(
                    '$overdue overdue',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warningColor,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTrends(List<EmployeeData> managers) {
    final activityData = _getActivityData(managers);
    final maxCount = activityData.isEmpty
        ? 1
        : activityData
            .map((e) => e.count)
            .reduce((a, b) => a > b ? a : b);
    final safeMax = maxCount == 0 ? 1 : maxCount;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: AppColors.activeColor, size: 22),
              const SizedBox(width: 8),
              Text(
                'Activity Trends ($_selectedTimePeriod)',
                style: AppTypography.heading2,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Daily activity generated by manager users.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: activityData.map((data) {
                final heightFactor = (data.count / safeMax).clamp(0.08, 1.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          data.count.toString(),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 140 * heightFactor,
                          decoration: BoxDecoration(
                            color: AppColors.activeColor.withValues(alpha: 0.85),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data.label,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalAnalytics(List<EmployeeData> managers) {
    int totalGoals = 0;
    int completedGoals = 0;
    int overdueGoals = 0;
    int pendingApprovals = 0;

    for (final manager in managers) {
      totalGoals += manager.goals.length;
      completedGoals += manager.completedGoalsCount;
      overdueGoals += manager.overdueGoalsCount;
      for (final goal in manager.goals) {
        if (goal.approvalStatus == GoalApprovalStatus.pending) {
          pendingApprovals++;
        }
      }
    }

    final approvedGoals = completedGoals - pendingApprovals;
    final inProgressGoals =
        (totalGoals - completedGoals - overdueGoals).clamp(0, totalGoals);
    final completionRate =
        totalGoals > 0 ? completedGoals / totalGoals : 0.0;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.track_changes, color: AppColors.activeColor, size: 22),
              const SizedBox(width: 8),
              Text('Goal Analytics', style: AppTypography.heading2),
            ],
          ),
          const SizedBox(height: 16),
          _buildBreakdownRow(
            label: 'Completed',
            value: approvedGoals,
            total: totalGoals,
            color: AppColors.successColor,
          ),
          const SizedBox(height: 12),
          _buildBreakdownRow(
            label: 'In Progress',
            value: inProgressGoals,
            total: totalGoals,
            color: AppColors.activeColor,
          ),
          const SizedBox(height: 12),
          _buildBreakdownRow(
            label: 'Pending Approval',
            value: pendingApprovals,
            total: totalGoals,
            color: AppColors.warningColor,
          ),
          const SizedBox(height: 12),
          _buildBreakdownRow(
            label: 'Overdue',
            value: overdueGoals,
            total: totalGoals,
            color: AppColors.dangerColor,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricTile('Total Goals', totalGoals.toString()),
              _metricTile('Completed', completedGoals.toString()),
              _metricTile(
                'Completion Rate',
                '${(completionRate * 100).toStringAsFixed(0)}%',
              ),
              _metricTile('Pending', pendingApprovals.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamHealthOverview(List<EmployeeData> managers) {
    int healthyTeams = 0;
    int atRiskTeams = 0;
    int criticalTeams = 0;

    for (final manager in managers) {
      if (manager.engagementScore >= 70 && manager.overdueGoalsCount == 0) {
        healthyTeams++;
      } else if (manager.engagementScore >= 40 ||
          manager.overdueGoalsCount <= 2) {
        atRiskTeams++;
      } else {
        criticalTeams++;
      }
    }

    final total = managers.isEmpty ? 1 : managers.length;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.health_and_safety,
                color: AppColors.activeColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text('Team Health Overview', style: AppTypography.heading2),
            ],
          ),
          const SizedBox(height: 16),
          _buildBreakdownRow(
            label: 'Healthy',
            value: healthyTeams,
            total: total,
            color: AppColors.successColor,
          ),
          const SizedBox(height: 12),
          _buildBreakdownRow(
            label: 'At Risk',
            value: atRiskTeams,
            total: total,
            color: AppColors.warningColor,
          ),
          const SizedBox(height: 12),
          _buildBreakdownRow(
            label: 'Critical',
            value: criticalTeams,
            total: total,
            color: AppColors.dangerColor,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow({
    required String label,
    required int value,
    required int total,
    required Color color,
  }) {
    final ratio = total > 0 ? value / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 72,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: AppTypography.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricTile(String label, String value, {Color? color}) {
    return SizedBox(
      width: 160,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTypography.heading4.copyWith(
                color: color ?? AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTypography.muted),
          ],
        ),
      ),
    );
  }

  void _showManagerDetailsDialog(EmployeeData manager) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          manager.profile.displayName,
          style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogMetric('Goals', '${manager.goals.length}'),
            _dialogMetric(
              'Completed Goals',
              '${manager.completedGoalsCount}',
            ),
            _dialogMetric(
              'Overdue Goals',
              '${manager.overdueGoalsCount}',
            ),
            _dialogMetric(
              'Average Progress',
              '${manager.avgProgress.toStringAsFixed(0)}%',
            ),
            _dialogMetric(
              'Engagement',
              '${manager.engagementScore.toStringAsFixed(0)}%',
            ),
            _dialogMetric('Points', '${manager.totalPoints}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _dialogMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _engagementColor(double engagement) {
    if (engagement > 70) return AppColors.successColor;
    if (engagement > 40) return AppColors.warningColor;
    return AppColors.dangerColor;
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _resolveAdminName() {
    if (_adminName.isNotEmpty && _adminName != 'Admin') {
      return _adminName.split(' ').first;
    }
    final authUser = FirebaseAuth.instance.currentUser;
    final display = (authUser?.displayName ?? '').trim();
    if (display.isNotEmpty) return display.split(' ').first;
    final email = (authUser?.email ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'Admin';
  }

  AnalyticsMetrics _computeAnalyticsMetrics(List<EmployeeData> managers) {
    final totalManagers = managers.length;
    final activeManagers = managers.where((m) => m.engagementScore > 0).length;
    int totalGoalLoad = 0;
    double totalEngagement = 0.0;
    int totalGoalsCompleted = 0;
    int totalOverdueGoals = 0;
    int totalPendingApprovals = 0;
    double totalProgress = 0.0;

    for (final manager in managers) {
      totalGoalLoad += manager.goals.length;
      totalEngagement += manager.engagementScore;
      totalGoalsCompleted += manager.completedGoalsCount;
      totalOverdueGoals += manager.overdueGoalsCount;
      totalProgress += manager.avgProgress;
      for (final goal in manager.goals) {
        if (goal.approvalStatus == GoalApprovalStatus.pending) {
          totalPendingApprovals++;
        }
      }
    }

    return AnalyticsMetrics(
      totalManagers: totalManagers,
      activeManagers: activeManagers,
      avgGoalLoad: totalManagers > 0 ? totalGoalLoad / totalManagers : 0.0,
      overallEngagement:
          totalManagers > 0 ? totalEngagement / totalManagers : 0.0,
      totalGoalsCompleted: totalGoalsCompleted,
      totalOverdueGoals: totalOverdueGoals,
      totalPendingApprovals: totalPendingApprovals,
      avgProgress: totalManagers > 0 ? totalProgress / totalManagers : 0.0,
    );
  }

  List<ActivityData> _getActivityData(List<EmployeeData> managers) {
    final now = DateTime.now();
    final daysToLookBack = _getDaysFromPeriod(_selectedTimePeriod);
    final today = DateTime(now.year, now.month, now.day);
    final activityCounts = <DateTime, int>{};

    for (int i = daysToLookBack - 1; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      activityCounts[date] = 0;
    }

    for (final manager in managers) {
      for (final activity in manager.recentActivities) {
        final activityDate = DateTime(
          activity.timestamp.year,
          activity.timestamp.month,
          activity.timestamp.day,
        );
        if (activityCounts.containsKey(activityDate)) {
          activityCounts[activityDate] =
              (activityCounts[activityDate] ?? 0) + 1;
        }
      }
    }

    final sortedDates = activityCounts.keys.toList()..sort();
    return sortedDates
        .map(
          (date) => ActivityData(
            label: _getDayLabel(date),
            count: activityCounts[date] ?? 0,
          ),
        )
        .toList();
  }

  String _getDayLabel(DateTime date) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[date.weekday - 1];
  }

  int _getDaysFromPeriod(String period) {
    switch (period) {
      case '7 days':
        return 7;
      case '30 days':
        return 30;
      case '90 days':
        return 90;
      case 'All time':
        return 365;
      default:
        return 7;
    }
  }
}

class AnalyticsMetrics {
  final int totalManagers;
  final int activeManagers;
  final double avgGoalLoad;
  final double overallEngagement;
  final int totalGoalsCompleted;
  final int totalOverdueGoals;
  final int totalPendingApprovals;
  final double avgProgress;

  const AnalyticsMetrics({
    required this.totalManagers,
    required this.activeManagers,
    required this.avgGoalLoad,
    required this.overallEngagement,
    required this.totalGoalsCompleted,
    required this.totalOverdueGoals,
    required this.totalPendingApprovals,
    required this.avgProgress,
  });
}

class ActivityData {
  final String label;
  final int count;

  const ActivityData({required this.label, required this.count});
}
