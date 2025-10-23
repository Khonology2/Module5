import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/role_service.dart';

class ProgressVisualsScreen extends StatefulWidget {
  final bool embedded;

  const ProgressVisualsScreen({super.key, this.embedded = false});

  @override
  State<ProgressVisualsScreen> createState() => _ProgressVisualsScreenState();
}

class _ProgressVisualsScreenState extends State<ProgressVisualsScreen> {
  UserProfile? userProfile;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _redirectIfManagerStandalone();
    _loadUserData();
  }

  Future<void> _redirectIfManagerStandalone() async {
    try {
      final role = await RoleService.instance.getRole();
      if (!mounted) return;
      if (role == 'manager') {
        if (widget.embedded) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final current = ModalRoute.of(context)?.settings.name;
          if (current != '/manager_portal') {
            Navigator.pushReplacementNamed(
              context,
              '/manager_portal',
              arguments: {'initialRoute': '/progress_visuals'},
            );
          }
        });
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await DatabaseService.getUserProfile(user.uid);

        setState(() {
          userProfile = profile;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  bool get isManager => userProfile?.role == 'manager';

  Stream<UserProfile?> _getUserProfileStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return UserProfile.fromFirestore(doc);
        });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _getUserProfileStream(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            ),
          );
        }

        if (profileSnapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.dangerColor,
                ),
                const SizedBox(height: 16),
                Text('Error loading user data', style: AppTypography.heading4),
                const SizedBox(height: 8),
                Text(
                  profileSnapshot.error.toString(),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        userProfile = profileSnapshot.data;

        if (userProfile == null) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            ),
          );
        }

        return Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/khono_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: isManager
                ? ManagerProgressVisualsContent(userProfile: userProfile!)
                : EmployeeProgressVisualsContent(userProfile: userProfile!),
          ),
        );
      },
    );
  }
}

class ManagerProgressVisualsContent extends StatefulWidget {
  final UserProfile userProfile;

  const ManagerProgressVisualsContent({super.key, required this.userProfile});

  @override
  State<ManagerProgressVisualsContent> createState() =>
      _ManagerProgressVisualsContentState();
}

class _ManagerProgressVisualsContentState
    extends State<ManagerProgressVisualsContent> {
  TimeFilter currentTimeFilter = TimeFilter.month;
  String? selectedDepartment;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Team Progress Overview',
                  style: AppTypography.heading2.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _buildFilterDropdown(),
              const SizedBox(width: AppSpacing.md),
              _buildDepartmentDropdown(),
              const SizedBox(width: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _showDebugInfo,
                icon: const Icon(Icons.bug_report, size: 16),
                label: const Text('Debug Data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warningColor,
                  side: BorderSide(color: AppColors.warningColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          StreamBuilder<List<EmployeeData>>(
            stream: ManagerRealtimeService.getTeamDataStream(
              department: selectedDepartment,
              timeFilter: currentTimeFilter,
            ),
            builder: (context, teamSnapshot) {
              if (teamSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.activeColor,
                    ),
                  ),
                );
              }

              if (teamSnapshot.hasError) {
                return _buildErrorState(teamSnapshot.error.toString());
              }

              final employees = teamSnapshot.data ?? [];
              if (employees.isEmpty) {
                return _buildNoDataState();
              }

              final metrics = _calculateTeamMetrics(employees);

              return Column(
                children: [
                  _buildTeamMetricsCards(metrics),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Team Member Progress',
                    style: AppTypography.heading3.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (employees.isEmpty)
                    _buildNoEmployeesState()
                  else
                    Column(
                      children: employees
                          .map(
                            (employee) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: _buildEmployeeCard(employee),
                            ),
                          )
                          .toList(),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  TeamMetrics _calculateTeamMetrics(List<EmployeeData> employees) {
    final now = DateTime.now();
    final activeThreshold = now.subtract(const Duration(days: 7));

    int activeCount = 0;
    int onTrackCount = 0;
    int atRiskCount = 0;
    int overdueCount = 0;
    int totalPoints = 0;
    int totalGoalsCompleted = 0;
    double totalProgress = 0;

    for (final employee in employees) {
      if (employee.lastActivity.isAfter(activeThreshold)) {
        activeCount++;
      }

      switch (employee.status) {
        case EmployeeStatus.onTrack:
          onTrackCount++;
          break;
        case EmployeeStatus.atRisk:
          atRiskCount++;
          break;
        case EmployeeStatus.overdue:
          overdueCount++;
          break;
        case EmployeeStatus.inactive:
          break;
      }

      totalPoints += employee.totalPoints;
      totalGoalsCompleted += employee.completedGoalsCount;
      totalProgress += employee.avgProgress;
    }

    final avgProgress = employees.isNotEmpty
        ? totalProgress / employees.length
        : 0.0;
    final engagement = employees.isNotEmpty
        ? (activeCount / employees.length) * 100
        : 0.0;

    return TeamMetrics(
      totalEmployees: employees.length,
      activeEmployees: activeCount,
      onTrackGoals: onTrackCount,
      atRiskGoals: atRiskCount,
      overdueGoals: overdueCount,
      avgTeamProgress: avgProgress,
      teamEngagement: engagement,
      totalPointsEarned: totalPoints,
      goalsCompleted: totalGoalsCompleted,
      lastUpdated: DateTime.now(),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: DropdownButton<TimeFilter>(
        value: currentTimeFilter,
        underline: const SizedBox(),
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
        onChanged: (TimeFilter? filter) {
          if (filter != null) {
            setState(() {
              currentTimeFilter = filter;
            });
          }
        },
        items: TimeFilter.values.map((filter) {
          return DropdownMenuItem<TimeFilter>(
            value: filter,
            child: Text(filter.name.toUpperCase()),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: DropdownButton<String?>(
        value: selectedDepartment,
        underline: const SizedBox(),
        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
        hint: Text(
          'All Departments',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        onChanged: (String? department) {
          setState(() {
            selectedDepartment = department;
          });
        },
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text('All Departments'),
          ),
          DropdownMenuItem<String?>(
            value: widget.userProfile.department,
            child: Text(
              widget.userProfile.department.isEmpty
                  ? 'Department'
                  : widget.userProfile.department,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMetricsCards(TeamMetrics metrics) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Team Members',
                value: metrics.totalEmployees.toString(),
                icon: Icons.people_outline,
                color: AppColors.activeColor,
                subtitle: '${metrics.activeEmployees} active (7d)',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildMetricCard(
                title: 'Average Progress',
                value: '${metrics.avgTeamProgress.toStringAsFixed(1)}%',
                icon: Icons.trending_up,
                color: metrics.avgTeamProgress >= 70
                    ? AppColors.successColor
                    : metrics.avgTeamProgress >= 40
                    ? AppColors.warningColor
                    : AppColors.dangerColor,
                subtitle: 'Team average',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Goals Completed',
                value: metrics.goalsCompleted.toString(),
                icon: Icons.check_circle_outline,
                color: AppColors.successColor,
                subtitle: 'This period',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildMetricCard(
                title: 'Overdue Goals',
                value: metrics.overdueGoals.toString(),
                icon: Icons.warning_outlined,
                color: AppColors.dangerColor,
                subtitle: 'Needs attention',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Team Engagement',
                value: '${metrics.teamEngagement.toStringAsFixed(1)}%',
                icon: Icons.groups,
                color: metrics.teamEngagement >= 70
                    ? AppColors.successColor
                    : metrics.teamEngagement >= 40
                    ? AppColors.warningColor
                    : AppColors.dangerColor,
                subtitle: 'Active in last 7 days',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildMetricCard(
                title: 'Active Status',
                value: '${metrics.activeEmployees}/${metrics.totalEmployees}',
                icon: Icons.online_prediction,
                color: (metrics.activeEmployees / metrics.totalEmployees) >= 0.8
                    ? AppColors.successColor
                    : (metrics.activeEmployees / metrics.totalEmployees) >= 0.5
                    ? AppColors.warningColor
                    : AppColors.dangerColor,
                subtitle: 'Currently active',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
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
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
      ),
    );
  }

  // ignore: unused_element
  Widget _buildInsightCard(TeamInsight insight) {
    Color priorityColor;
    IconData priorityIcon;

    switch (insight.priority) {
      case InsightPriority.urgent:
        priorityColor = AppColors.dangerColor;
        priorityIcon = Icons.priority_high;
        break;
      case InsightPriority.high:
        priorityColor = AppColors.warningColor;
        priorityIcon = Icons.warning;
        break;
      case InsightPriority.medium:
        priorityColor = AppColors.infoColor;
        priorityIcon = Icons.info_outline;
        break;
      case InsightPriority.low:
        priorityColor = AppColors.successColor;
        priorityIcon = Icons.check_circle_outline;
        break;
    }

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
              Icon(priorityIcon, color: priorityColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                insight.priority.name.toUpperCase(),
                style: AppTypography.bodySmall.copyWith(
                  color: priorityColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: priorityColor, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    insight.actionRequired,
                    style: AppTypography.bodySmall.copyWith(
                      color: priorityColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (insight.priority == InsightPriority.urgent ||
              insight.priority == InsightPriority.high) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sendNudgeToEmployee(insight.employeeName),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Send Nudge'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: priorityColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _scheduleMeeting(insight.employeeName),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Meet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: priorityColor,
                    side: BorderSide(color: priorityColor),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeData employee) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (employee.status) {
      case EmployeeStatus.onTrack:
        statusColor = AppColors.successColor;
        statusIcon = Icons.check_circle;
        statusText = 'On Track';
        break;
      case EmployeeStatus.atRisk:
        statusColor = AppColors.warningColor;
        statusIcon = Icons.warning;
        statusText = 'At Risk';
        break;
      case EmployeeStatus.overdue:
        statusColor = AppColors.dangerColor;
        statusIcon = Icons.error_outline;
        statusText = 'Overdue';
        break;
      case EmployeeStatus.inactive:
        statusColor = AppColors.textSecondary;
        statusIcon = Icons.pause_circle_outline;
        statusText = 'Inactive';
        break;
    }

    // Determine active status
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    bool isActiveToday = employee.lastActivity.isAfter(today);
    bool isActiveThisWeek = employee.lastActivity.isAfter(sevenDaysAgo);

    Color activeStatusColor;
    IconData activeStatusIcon;
    String activeStatusText;

    if (isActiveToday) {
      activeStatusColor = AppColors.successColor;
      activeStatusIcon = Icons.circle;
      activeStatusText = 'Active Today';
    } else if (isActiveThisWeek) {
      activeStatusColor = AppColors.warningColor;
      activeStatusIcon = Icons.circle;
      activeStatusText = 'Active This Week';
    } else {
      activeStatusColor = AppColors.textSecondary;
      activeStatusIcon = Icons.circle_outlined;
      activeStatusText = 'Inactive';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withValues(alpha: 0.1),
                child: Text(
                  employee.profile.displayName.isNotEmpty
                      ? employee.profile.displayName[0].toUpperCase()
                      : '?',
                  style: AppTypography.bodyMedium.copyWith(
                    color: statusColor,
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
                      employee.profile.jobTitle.isNotEmpty
                          ? employee.profile.jobTitle
                          : employee.profile.department,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: AppTypography.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: activeStatusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: activeStatusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          activeStatusIcon,
                          color: activeStatusColor,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          activeStatusText,
                          style: AppTypography.bodySmall.copyWith(
                            color: activeStatusColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildEmployeeMetricChip(
                  icon: Icons.track_changes,
                  label: 'Active Goals',
                  value: employee.goals
                      .where((g) => g.status != GoalStatus.completed)
                      .length
                      .toString(),
                  color: AppColors.activeColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEmployeeMetricChip(
                  icon: Icons.check_circle_outline,
                  label: 'Completed',
                  value: employee.completedGoalsCount.toString(),
                  color: AppColors.successColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEmployeeMetricChip(
                  icon: Icons.access_time,
                  label: 'Progress',
                  value: '${employee.avgProgress.toStringAsFixed(1)}%',
                  color: employee.avgProgress >= 70
                      ? AppColors.successColor
                      : employee.avgProgress >= 40
                      ? AppColors.warningColor
                      : AppColors.dangerColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Show last activity information
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: AppColors.textSecondary, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Last active: ${_formatLastActivity(employee.lastActivity)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${employee.weeklyActivityCount} activities this week',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (employee.goals.isNotEmpty) ...[
            Text(
              'Goals',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...employee.goals
                .take(3)
                .map(
                  (goal) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildGoalRow(goal),
                  ),
                ),
            if (employee.goals.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${employee.goals.length - 3} more goals',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.activeColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No goals yet',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewEmployeeDetails(employee),
                  icon: const Icon(Icons.person_outline, size: 16),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.activeColor,
                    side: BorderSide(color: AppColors.activeColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _sendNudgeToEmployee(employee.profile.displayName),
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Send Nudge'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalRow(Goal goal) {
    Color priorityColor = _getPriorityColor(goal.priority);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: priorityColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  goal.title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: LinearProgressIndicator(
                  value: goal.progress / 100.0,
                  backgroundColor: AppColors.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(priorityColor),
                  minHeight: 4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${goal.progress}%',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) =>
                      GoalTrendDialog(goalId: goal.id, goalTitle: goal.title),
                );
              },
              icon: const Icon(
                Icons.show_chart,
                size: 14,
                color: AppColors.activeColor,
              ),
              label: Text(
                'View Trend',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.activeColor,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.high:
        return AppColors.dangerColor;
      case GoalPriority.medium:
        return AppColors.warningColor;
      case GoalPriority.low:
        return AppColors.successColor;
    }
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.dangerColor),
          const SizedBox(height: 16),
          Text(
            'Error loading team data',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
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
            'No team data available',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Team metrics and insights will appear here once employees start using the system.',
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
          Icon(Icons.groups_outlined, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No team members found',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure your team members have been added to your department or check your filter settings.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _sendNudgeToEmployee(String employeeName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nudge sent to $employeeName'),
        backgroundColor: AppColors.activeColor,
      ),
    );
  }

  void _viewEmployeeDetails(EmployeeData employee) {
    Navigator.pushNamed(
      context,
      '/employee_profile_detail',
      arguments: employee.profile.uid,
    );
  }

  String _formatLastActivity(DateTime? lastActivity) {
    if (lastActivity == null) return 'Never';

    try {
      final now = DateTime.now();

      // Check if the date is valid (not in the future or too far in the past)
      if (lastActivity.isAfter(now) || lastActivity.year < 2000) {
        return 'Unknown';
      }

      final difference = now.difference(lastActivity);

      if (difference.inDays > 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      // Handle any unexpected errors when formatting the date
      return 'Unknown';
    }
  }

  Future<void> _showDebugInfo() async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final FirebaseAuth auth = FirebaseAuth.instance;

      // Get manager info
      final managerDoc = await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .get();
      final managerData = managerDoc.data();

      // Get all employees the manager is allowed to view
      // Prefer same department if set; otherwise fallback to all employees
      Query<Map<String, dynamic>> employeesQueryRef = firestore
          .collection('users')
          .where('role', isEqualTo: 'employee');
      if ((managerData?['department'] as String?)?.isNotEmpty == true) {
        employeesQueryRef = employeesQueryRef.where(
          'department',
          isEqualTo: managerData!['department'],
        );
      }
      final employeesQuery = await employeesQueryRef.get();

      // Get Angel specifically if she exists
      final angelQuery = await firestore
          .collection('users')
          .where('displayName', isEqualTo: 'Angel')
          .get();

      // Get activities only for these employees (avoid cross-user reads)
      final employeeIds = employeesQuery.docs.map((d) => d.id).toList();
      // Avoid composite index by not combining whereIn with orderBy. Sort in-memory.
      final activitiesBaseRef = firestore.collection('activities');
      final activitiesSnapshot = employeeIds.isEmpty
          ? await activitiesBaseRef
                .orderBy('timestamp', descending: true)
                .limit(10)
                .get()
          : await activitiesBaseRef
                .where('userId', whereIn: employeeIds.take(10).toList())
                .limit(25)
                .get();
      // Sort and trim after fetch
      final activitiesDocs = activitiesSnapshot.docs
        ..sort((a, b) {
          final at =
              (a.data()['timestamp'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bt =
              (b.data()['timestamp'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
        });

      // Get goals only for these employees
      final goalsBaseRef = firestore.collection('goals');
      final goalsSnapshot = employeeIds.isEmpty
          ? await goalsBaseRef
                .orderBy('createdAt', descending: true)
                .limit(10)
                .get()
          : await goalsBaseRef
                .where('userId', whereIn: employeeIds.take(10).toList())
                .limit(25)
                .get();
      final goalsDocs = goalsSnapshot.docs
        ..sort((a, b) {
          final at =
              (a.data()['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bt =
              (b.data()['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
        });

      // Get employee activity summary
      final employeeActivitySummary = <String, Map<String, dynamic>>{};
      for (final empDoc in employeesQuery.docs) {
        final empData = empDoc.data();
        final empId = empDoc.id;
        final empName = empData['displayName'] ?? 'Unknown';

        // Count activities for this employee
        final empActivities = activitiesDocs
            .where((act) => act.data()['userId'] == empId)
            .length;

        // Count goals for this employee
        final empGoals = goalsDocs
            .where((goal) => goal.data()['userId'] == empId)
            .length;

        // Get last activity time
        final lastActivity = activitiesDocs
            .where((act) => act.data()['userId'] == empId)
            .map((act) => (act.data()['timestamp'] as Timestamp?)?.toDate())
            .where((date) => date != null)
            .cast<DateTime>()
            .fold<DateTime?>(
              null,
              (latest, current) =>
                  latest == null || current.isAfter(latest) ? current : latest,
            );

        employeeActivitySummary[empName] = {
          'activities': empActivities,
          'goals': empGoals,
          'lastActivity': lastActivity?.toString() ?? 'Never',
          'department': empData['department'] ?? 'No Department',
        };
      }

      String debugInfo =
          '''
DEBUG INFORMATION:

MANAGER:
- UID: ${auth.currentUser!.uid}
- Department: ${managerData?['department'] ?? 'NULL'}
- Display Name: ${managerData?['displayName'] ?? 'NULL'}

ALL EMPLOYEES (${employeesQuery.docs.length}):
${employeesQuery.docs.map((doc) {
            final data = doc.data();
            return '- ${data['displayName'] ?? 'Unknown'}: Department=${data['department'] ?? 'NULL'}, Role=${data['role'] ?? 'NULL'}';
          }).join('\n')}

EMPLOYEE ACTIVITY SUMMARY:
${employeeActivitySummary.entries.map((entry) {
            final empName = entry.key;
            final summary = entry.value;
            return '- $empName: ${summary['activities']} activities, ${summary['goals']} goals, Last active: ${summary['lastActivity']}, Dept: ${summary['department']}';
          }).join('\n')}

ANGEL SPECIFICALLY:
${angelQuery.docs.isNotEmpty ? 'FOUND Angel: ${angelQuery.docs.first.data()}' : 'Angel NOT FOUND in employees collection!'}

RECENT ACTIVITIES (${activitiesDocs.length}):
${activitiesDocs.map((doc) {
            final data = doc.data();
            return '- User: ${data['userId']}, Type: ${data['activityType']}, Description: ${data['description']}';
          }).join('\n')}

RECENT GOALS (${goalsDocs.length}):
${goalsDocs.map((doc) {
            final data = doc.data();
            return '- User: ${data['userId']}, Title: ${data['title']}, Progress: ${data['progress']}%';
          }).join('\n')}
      ''';

      if (!mounted) return; // Add this line here
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          // Capture dialogContext here
          title: const Text('Debug Information'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  debugInfo,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(), // Use dialogContext
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return; // Re-added
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Debug Error: $e')));
    }
  }

  void _scheduleMeeting(String employeeName) {}
}

class EmployeeProgressVisualsContent extends StatelessWidget {
  final UserProfile userProfile;

  const EmployeeProgressVisualsContent({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Progress Overview',
            style: AppTypography.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          StreamBuilder<List<Goal>>(
            stream: _getUserGoalsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.activeColor,
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }

              final goals = snapshot.data ?? [];

              return Column(children: [_buildPersonalOverview(goals)]);
            },
          ),
        ],
      ),
    );
  }

  Stream<List<Goal>> _getUserGoalsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('goals')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final goals = snapshot.docs.map((doc) {
            final data = doc.data();
            return Goal(
              id: doc.id,
              userId: data['userId'] ?? user.uid,
              title: data['title'] ?? '',
              description: data['description'] ?? '',
              category: GoalCategory.values.firstWhere(
                (e) => e.name == (data['category'] ?? 'personal'),
                orElse: () => GoalCategory.personal,
              ),
              priority: GoalPriority.values.firstWhere(
                (e) => e.name == (data['priority'] ?? 'medium'),
                orElse: () => GoalPriority.medium,
              ),
              status: GoalStatus.values.firstWhere(
                (e) => e.name == (data['status'] ?? 'notStarted'),
                orElse: () => GoalStatus.notStarted,
              ),
              progress: (data['progress'] ?? 0) as int,
              createdAt:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              targetDate:
                  (data['targetDate'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              points: (data['points'] ?? 0) as int,
            );
          }).toList();

          goals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return goals;
        });
  }

  Widget _buildPersonalOverview(List<Goal> goals) {
    final totalGoals = goals.length;
    final completedGoals = goals
        .where(
          (goal) => goal.status == GoalStatus.completed || goal.progress >= 100,
        )
        .length;
    final activeGoals = goals
        .where(
          (goal) => goal.status != GoalStatus.completed && goal.progress < 100,
        )
        .length;
    final overallProgress = totalGoals > 0
        ? (completedGoals / totalGoals)
        : 0.0;

    return Row(
      children: [
        Expanded(
          child: _buildOverviewCard(
            title: 'Completion Rate',
            value: '${(overallProgress * 100).toInt()}%',
            progress: overallProgress,
            color: AppColors.successColor,
            iconWidget: SizedBox(
              width: 50,
              height: 50,
              child: Image.asset(
                'Approved_Tick/approved_red_badge_white.png', // Corrected path and filename
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildOverviewCard(
            title: 'Active Goals',
            value: activeGoals.toString(),
            progress: totalGoals > 0 ? (activeGoals / totalGoals) : 0.0,
            color: AppColors.activeColor,
            iconWidget: SizedBox(
              width: 50,
              height: 50,
              child: Image.asset(
                'Goal_Target/Goal_Target_White_Badge_Red_Badge_White.png', // Corrected path and filename
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required double progress,
    required Color color,
    IconData? icon, // Make icon optional
    Widget? iconWidget, // Add new iconWidget parameter
  }) {
    assert(
      icon != null || iconWidget != null,
      'Either icon or iconWidget must be provided.',
    );

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (iconWidget != null) ...[
                // Use iconWidget if provided
                SizedBox(
                  width: 20, // Default size for icons in these cards
                  height: 20,
                  child: iconWidget,
                ),
              ] else if (icon != null) ...[
                // Fallback to IconData if iconWidget is null
                Icon(icon, color: color, size: 20),
              ],
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppColors.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyGoalsState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: Image.asset(
              'Business_Growth_Development/Growth_Development_Red.png', // Corrected path and filename
              fit: BoxFit.contain,
            ),
          ), // Replaced Icon with Image.asset
          const SizedBox(height: 16),
          Text(
            'No Active Goals',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first goal to start tracking your progress!',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgressCard(BuildContext context, {required Goal goal}) {
    final now = DateTime.now();
    final daysUntilDeadline = goal.targetDate.difference(now).inDays;
    final progress = goal.progress / 100.0;

    String deadlineText;
    Color deadlineColor;

    if (daysUntilDeadline < 0) {
      deadlineText =
          'Overdue by ${(-daysUntilDeadline)} day${(-daysUntilDeadline) == 1 ? '' : 's'}';
      deadlineColor = AppColors.dangerColor;
    } else if (daysUntilDeadline == 0) {
      deadlineText = 'Due today';
      deadlineColor = AppColors.warningColor;
    } else if (daysUntilDeadline <= 7) {
      deadlineText =
          'Due in $daysUntilDeadline day${daysUntilDeadline == 1 ? '' : 's'}';
      deadlineColor = AppColors.warningColor;
    } else {
      deadlineText = 'Due in $daysUntilDeadline days';
      deadlineColor = AppColors.textSecondary;
    }

    Color progressColor = _getPriorityColor(goal.priority);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 30.0,
            lineWidth: 6.0,
            percent: progress.clamp(0.0, 1.0),
            center: Text(
              "${goal.progress}%",
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            progressColor: progressColor,
            backgroundColor: AppColors.borderColor,
            circularStrokeCap: CircularStrokeCap.round,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        goal.title,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: progressColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: progressColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        goal.priority.name.toUpperCase(),
                        style: AppTypography.bodySmall.copyWith(
                          color: progressColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  deadlineText,
                  style: AppTypography.bodySmall.copyWith(color: deadlineColor),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: AppColors.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 3,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => GoalTrendDialog(
                          goalId: goal.id,
                          goalTitle: goal.title,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.show_chart,
                      size: 16,
                      color: AppColors.activeColor,
                    ),
                    label: Text(
                      'View Trend',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.activeColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.high:
        return AppColors.dangerColor;
      case GoalPriority.medium:
        return AppColors.warningColor;
      case GoalPriority.low:
        return AppColors.successColor;
    }
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.dangerColor),
          const SizedBox(height: 16),
          Text(
            'Error loading progress data',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class GoalTrendDialog extends StatelessWidget {
  final String goalId;
  final String goalTitle;
  const GoalTrendDialog({
    super.key,
    required this.goalId,
    required this.goalTitle,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final since = now.subtract(const Duration(days: 30));
    final sinceKey =
        '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
    return AlertDialog(
      backgroundColor: AppColors.elevatedBackground,
      contentPadding: const EdgeInsets.all(16),
      title: Text(
        'Trends • $goalTitle',
        style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: 600,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('goal_daily_progress')
              .where('goalId', isEqualTo: goalId)
              .where('date', isGreaterThanOrEqualTo: sinceKey)
              .orderBy('date')
              .limit(90)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return SizedBox(
                height: 260,
                child: Center(
                  child: Text(
                    'No daily data yet. Come back tomorrow.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }
            final progress = <double>[];
            final remaining = <double>[];
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>;
              progress.add(
                ((data['progress'] ?? 0) as num).toDouble().clamp(0.0, 100.0),
              );
              remaining.add(
                ((data['remaining'] ?? 0) as num).toDouble().clamp(0.0, 100.0),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ChartCard(
                  title: 'Burnup (Progress %)',
                  color: AppColors.successColor,
                  values: progress,
                ),
                const SizedBox(height: 12),
                _ChartCard(
                  title: 'Burndown (Remaining %)',
                  color: AppColors.warningColor,
                  values: remaining,
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Color color;
  final List<double> values;
  const _ChartCard({
    required this.title,
    required this.color,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: _LineChartPainter(values: values, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values; // 0..100
  final Color color;
  _LineChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = AppColors.elevatedBackground
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = AppColors.borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final gridPaint = Paint()
      ..color = AppColors.borderColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Padding for axes
    const leftPad = 28.0;
    const bottomPad = 18.0;
    final chartRect = Rect.fromLTWH(
      leftPad,
      8,
      size.width - leftPad - 8,
      size.height - bottomPad - 8,
    );

    // Background & border
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    canvas.drawRect(chartRect, border);

    // Grid lines (5 horizontal)
    final gridCount = 5;
    for (int i = 0; i <= gridCount; i++) {
      final y = chartRect.top + (chartRect.height / gridCount) * i;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    if (values.isEmpty) return;

    // Map values to points
    final n = values.length;
    final dx = n > 1 ? chartRect.width / (n - 1) : 0;
    final path = Path();
    for (int i = 0; i < n; i++) {
      final v = values[i].clamp(0.0, 100.0);
      final x = chartRect.left + dx * i;
      final y = chartRect.bottom - (v / 100.0) * chartRect.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Axes tick labels (0, 25, 50, 75, 100)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final tick in [0, 25, 50, 75, 100]) {
      final y = chartRect.bottom - (tick / 100.0) * chartRect.height;
      textPainter.text = TextSpan(
        text: '$tick',
        style: const TextStyle(color: Color(0xFF9AA0AA), fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(2, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
