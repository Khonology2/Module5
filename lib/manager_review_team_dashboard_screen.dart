// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:pdh/manager_employee_detail_screen.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/models/goal.dart';

class ManagerReviewTeamDashboardScreen extends StatefulWidget {
  const ManagerReviewTeamDashboardScreen({super.key});

  @override
  State<ManagerReviewTeamDashboardScreen> createState() =>
      _ManagerReviewTeamDashboardScreenState();
}

class _ManagerReviewTeamDashboardScreenState
    extends State<ManagerReviewTeamDashboardScreen> {
  TimeFilter _selectedTimeFilter = TimeFilter.month;
  String? _selectedDepartment;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Set Scaffold background to transparent
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove AppBar shadow
        automaticallyImplyLeading: false, // Remove back arrow button
        title: Text(
          'Team Dashboard',
          style: AppTypography.heading2.copyWith(color: Colors.white),
        ),
        centerTitle: false,
        actions: [], // Hide profile button on dashboard
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/khono_bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Color(
                      0x880A0F1F,
                    ), // More opaque semi-transparent overlay (alpha 0x88)
                    Color(
                      0x88040610,
                    ), // More opaque semi-transparent overlay (alpha 0x88)
                  ],
                  stops: [0.0, 1.0],
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth < 400
                      ? 12.0
                      : constraints.maxWidth < 700
                      ? 16.0
                      : 24.0;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      MediaQuery.of(context).padding.top +
                          kToolbarHeight +
                          16.0,
                      horizontalPadding,
                      16.0,
                    ),
                    child: StreamBuilder<TeamMetrics>(
                      stream: ManagerRealtimeService.getTeamMetricsStream(
                        department: _selectedDepartment,
                        timeFilter: _selectedTimeFilter,
                      ),
                      builder: (context, metricsSnapshot) {
                        return StreamBuilder<List<EmployeeData>>(
                          stream: ManagerRealtimeService.getTeamDataStream(
                            department: _selectedDepartment,
                            timeFilter: _selectedTimeFilter,
                          ),
                          builder: (context, employeesSnapshot) {
                            if (employeesSnapshot.hasError) {}
                            if (employeesSnapshot.hasData) {}

                            return StreamBuilder<List<TeamInsight>>(
                              stream:
                                  ManagerRealtimeService.getTeamInsightsStream(
                                    department: _selectedDepartment,
                                    timeFilter: _selectedTimeFilter,
                                  ),
                              builder: (context, insightsSnapshot) {
                                if (insightsSnapshot.hasError) {}
                                if (insightsSnapshot.hasData) {}

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildHeader(),
                                    const SizedBox(height: 20),

                                    if (employeesSnapshot.hasData &&
                                        employeesSnapshot.data!.isNotEmpty)
                                      _buildRealTimeEmployeeList(
                                        employeesSnapshot.data!,
                                      )
                                    else if (employeesSnapshot.hasData &&
                                        employeesSnapshot.data!.isEmpty)
                                      _buildEmptyState()
                                    else if (employeesSnapshot.hasError)
                                      _buildErrorState(employeesSnapshot.error!)
                                    else
                                      _buildLoadingState(),

                                    const SizedBox(height: 20),
                                    if (insightsSnapshot.hasData)
                                      _buildAIManagerInsights(
                                        insightsSnapshot.data!,
                                      )
                                    else if (insightsSnapshot.hasError)
                                      _buildErrorInsights(
                                        insightsSnapshot.error!,
                                      )
                                    else
                                      _buildLoadingInsights(),

                                    const SizedBox(height: 24),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(child: SizedBox.shrink()),
        const SizedBox(width: 12),
        _buildTimeFilterDropdown(),
      ],
    );
  }

  Widget _buildTimeFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TimeFilter>(
          value: _selectedTimeFilter,
          dropdownColor: Colors.black.withValues(alpha: 0.8),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          onChanged: (TimeFilter? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedTimeFilter = newValue;
              });
            }
          },
          items: TimeFilter.values.map<DropdownMenuItem<TimeFilter>>((
            TimeFilter value,
          ) {
            return DropdownMenuItem<TimeFilter>(
              value: value,
              child: Text(_getTimeFilterLabel(value)),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getTimeFilterLabel(TimeFilter filter) {
    switch (filter) {
      case TimeFilter.today:
        return 'Today';
      case TimeFilter.week:
        return 'This Week';
      case TimeFilter.month:
        return 'This Month';
      case TimeFilter.quarter:
        return 'This Quarter';
      case TimeFilter.year:
        return 'This Year';
    }
  }

  Widget _buildAIManagerInsights(List<TeamInsight> insights) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_outline, color: Color(0xFFC10D00), size: 20),
              SizedBox(width: 8),
              Text(
                'AI Manager Insights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (insights.isEmpty)
            _buildInsightBullet(
              'All team members are performing well. No immediate action needed.',
            )
          else
            ...insights
                .take(3)
                .map(
                  (insight) => Column(
                    children: [
                      _buildInsightItem(insight),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: () {
              _showFullInsights(insights);
            },
            child: const Text(
              'View Full Analysis',
              style: TextStyle(
                color: Color(0xFFC10D00),
                decoration: TextDecoration.underline,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(TeamInsight insight) {
    Color priorityColor;
    IconData priorityIcon;

    switch (insight.priority) {
      case InsightPriority.urgent:
        priorityColor = Colors.redAccent;
        priorityIcon = Icons.priority_high;
        break;
      case InsightPriority.high:
        priorityColor = Colors.orange;
        priorityIcon = Icons.warning;
        break;
      case InsightPriority.medium:
        priorityColor = Colors.yellow;
        priorityIcon = Icons.info;
        break;
      case InsightPriority.low:
        priorityColor = Colors.green;
        priorityIcon = Icons.check_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: priorityColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(priorityIcon, color: priorityColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                if (insight.actionRequired.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Action: ${insight.actionRequired}',
                    style: TextStyle(color: priorityColor, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeEmployeeList(List<EmployeeData> employees) {
    if (employees.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: const Center(
          child: Text(
            'No employees found in this department',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Team Overview',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...employees.map(
          (employee) => Column(
            children: [
              _buildEmployeeCard(employee),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeCard(EmployeeData employee) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (employee.status) {
      case EmployeeStatus.onTrack:
        statusColor = Colors.green;
        statusText = 'On Track';
        statusIcon = Icons.check_circle;
        break;
      case EmployeeStatus.atRisk:
        statusColor = Colors.orange;
        statusText = 'At Risk';
        statusIcon = Icons.warning;
        break;
      case EmployeeStatus.overdue:
        statusColor = Colors.red;
        statusText = 'Overdue';
        statusIcon = Icons.error;
        break;
      case EmployeeStatus.inactive:
        statusColor = Colors.grey;
        statusText = 'Inactive';
        statusIcon = Icons.pause_circle;
        break;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ManagerEmployeeDetailScreen(employee: employee),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: employee.status == EmployeeStatus.overdue
                ? Colors.red.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.2),
            width: employee.status == EmployeeStatus.overdue ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFC10D00),
                  child: Text(
                    employee.profile.displayName.isNotEmpty
                        ? employee.profile.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        employee.profile.jobTitle.isNotEmpty
                            ? employee.profile.jobTitle
                            : 'Team Member',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile('Goals', '${employee.goals.length}'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Completed',
                    '${employee.completedGoalsCount}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Progress',
                    '${employee.avgProgress.toStringAsFixed(0)}%',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile('Points', '${employee.totalPoints}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Activities',
                    '${employee.weeklyActivityCount}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Engagement',
                    '${employee.engagementScore.toStringAsFixed(0)}%',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Motivation',
                    employee.motivationLevel,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile('Streak', '${employee.streakDays}d'),
                ),
              ],
            ),
            // Management Actions
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showSendNudgeDialog(employee: employee),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Send Nudge'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC10D00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _scheduleOneOnOne(employee),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC10D00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('1:1'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _giveRecognition(employee),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC10D00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Kudos'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _viewActivities(employee),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC10D00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Activity'),
                  ),
                ),
              ],
            ),
            // Upcoming Deadlines Section
            if (_getUpcomingDeadlines(employee).isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildUpcomingDeadlinesSection(employee),
            ],
            // Completed Goals Review Section
            if (employee.completedGoalsCount > 0) ...[
              const SizedBox(height: 12),
              _buildCompletedGoalsReviewSection(employee),
            ],
          ],
        ),
      ),
    );
  }

  List<Goal> _getUpcomingDeadlines(EmployeeData employee) {
    final now = DateTime.now();
    final next14Days = now.add(const Duration(days: 14));
    
    return employee.goals.where((goal) {
      if (goal.status == GoalStatus.completed) return false;
      return goal.targetDate.isAfter(now) && goal.targetDate.isBefore(next14Days);
    }).toList()
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
  }

  Widget _buildUpcomingDeadlinesSection(EmployeeData employee) {
    final upcomingGoals = _getUpcomingDeadlines(employee);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Text(
                'Upcoming Deadlines',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...upcomingGoals.take(3).map((goal) {
            final daysUntil = goal.targetDate.difference(DateTime.now()).inDays;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    daysUntil == 0 
                        ? 'Due today'
                        : '$daysUntil day${daysUntil == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: daysUntil <= 3 ? Colors.red : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (upcomingGoals.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${upcomingGoals.length - 3} more',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompletedGoalsReviewSection(EmployeeData employee) {
    final completedGoals = employee.goals
        .where((g) => g.status == GoalStatus.completed)
        .toList();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Completed Goals (${completedGoals.length})',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _reviewCompletedGoals(employee),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Review & Acknowledge',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _reviewCompletedGoals(EmployeeData employee) {
    final completedGoals = employee.goals
        .where((g) => g.status == GoalStatus.completed)
        .toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0x80000000),
        title: Text(
          'Review Completed Goals - ${employee.profile.displayName}',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: completedGoals.isEmpty
              ? const Center(
                  child: Text(
                    'No completed goals to review',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  itemCount: completedGoals.length,
                  itemBuilder: (context, index) {
                    final goal = completedGoals[index];
                    return _buildCompletedGoalReviewItem(goal, employee);
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedGoalReviewItem(Goal goal, EmployeeData employee) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(Icons.check_circle, color: Colors.green, size: 20),
            ],
          ),
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              goal.description,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _viewGoalNotes(goal, employee),
                  icon: const Icon(Icons.note_outlined, size: 16),
                  label: const Text('Check Notes'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _acknowledgeGoal(goal, employee),
                icon: const Icon(Icons.thumb_up, size: 16),
                label: const Text('Acknowledge'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _viewGoalNotes(Goal goal, EmployeeData employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0x80000000),
        title: Text(
          'Goal Notes: ${goal.title}',
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (goal.description.isNotEmpty) ...[
                const Text(
                  'Description:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  goal.description,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
              ],
              if (goal.evidence.isNotEmpty) ...[
                const Text(
                  'Evidence:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ...goal.evidence.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $e',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )),
              ] else
                const Text(
                  'No additional notes or evidence available.',
                  style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _acknowledgeGoal(Goal goal, EmployeeData employee) async {
    try {
      // TODO: Implement acknowledgement in database service
      // For now, show a success message
      Navigator.pop(context); // Close review dialog
      await _showCenterNotice(
        context,
        'Goal "${goal.title}" acknowledged for ${employee.profile.displayName}',
      );
    } catch (e) {
      await _showCenterNotice(
        context,
        'Error acknowledging goal: $e',
      );
    }
  }

  Widget _buildMetricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFC10D00)),
            SizedBox(height: 12),
            Text(
              'Loading team data...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingInsights() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Color(0xFFC10D00), size: 20),
              SizedBox(width: 8),
              Text(
                'AI Manager Insights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Center(child: CircularProgressIndicator(color: Color(0xFFC10D00))),
          SizedBox(height: 10),
          Center(
            child: Text(
              'Analyzing team performance...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
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
        Navigator.pop(context); // Close dialog
        await _showCenterNotice(context, 'Nudge sent successfully!');
      }
    } catch (e) {
      if (mounted) {
        await _showCenterNotice(context, 'Error sending nudge: $e');
      }
    }
  }

  void _scheduleOneOnOne(EmployeeData employee) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0x80000000),
        title: Text(
          'Schedule 1:1 with ${employee.profile.displayName}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Meeting purpose...',
                hintStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Store purpose
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                try {
                  // In a real app, you would open a date picker here
                  // For now, we'll schedule for tomorrow
                  final scheduledTime = DateTime.now().add(
                    const Duration(days: 1),
                  );

                  await ManagerRealtimeService.scheduleMeeting(
                    employeeId: employee.profile.uid,
                    scheduledTime: scheduledTime,
                    purpose: 'Performance check-in',
                  );
                  // ignore: duplicate_ignore
                  // ignore: use_build_context_synchronously
                  Navigator.pop(dialogContext); // Use dialogContext
                  // ignore: duplicate_ignore
                  // ignore: use_build_context_synchronously
                  if (!mounted) return;
                  await _showCenterNotice(
                    context,
                    '1:1 scheduled with ${employee.profile.displayName}',
                  );
                } catch (e) {
                  if (!mounted) return; // Add this line back
                  await _showCenterNotice(
                    context,
                    'Error scheduling meeting: $e',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC10D00),
              ),
              child: const Text('Schedule'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // Use dialogContext
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _giveRecognition(EmployeeData employee) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0x80000000),
        title: Text(
          'Give Recognition to ${employee.profile.displayName}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Recognition reason...',
                hintStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Store reason
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await ManagerRealtimeService.giveRecognition(
                          employeeId: employee.profile.uid,
                          reason: 'Outstanding performance this week!',
                          points: 50,
                          badgeName: 'Manager Recognition',
                        );
                        Navigator.pop(dialogContext); // Use dialogContext
                        if (!mounted) return;
                        await _showCenterNotice(
                          context,
                          'Recognition sent to ${employee.profile.displayName}',
                        );
                      } catch (e) {
                        if (!mounted) return; // Add this line back
                        await _showCenterNotice(
                          context,
                          'Error giving recognition: $e',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Send Kudos'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // Use dialogContext
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _viewActivities(EmployeeData employee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _EmployeeActivityScreen(employee: employee),
      ),
    );
  }

  void _showFullInsights(List<TeamInsight> insights) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0x80000000),
        title: const Text(
          'Full Team Insights',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: insights.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildInsightItem(insights[index]),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x80000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Icon(Icons.people_outline, color: Colors.white70, size: 48),
          const SizedBox(height: 12),
          const Text(
            'No Team Members Found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This could mean:\n• No employees in your department\n• You don\'t have manager role\n• Database connection issues',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/sign_in');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC10D00),
            ),
            child: const Text('Check Authentication'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x80000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.withValues(alpha: 0.7),
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Error Loading Team Data',
            style: TextStyle(
              color: Colors.red,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Error: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorInsights(Object error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x80000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Color(0xFFC10D00), size: 20),
              SizedBox(width: 8),
              Text(
                'AI Manager Insights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red.withValues(alpha: 0.7),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Error loading insights',
                  style: TextStyle(
                    color: Colors.red.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '$error',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeActivityScreen extends StatelessWidget {
  final EmployeeData employee;

  const _EmployeeActivityScreen({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0x80000000),
        title: Text(
          '${employee.profile.displayName} - Activity',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<EmployeeActivity>>(
        stream: ManagerRealtimeService.getEmployeeActivitiesStream(
          employeeId: employee.profile.uid,
          limit: 50,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFC10D00)),
            );
          }

          final activities = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildActivitySummary(),
                const SizedBox(height: 20),
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: activities.isEmpty
                      ? const Center(
                          child: Text(
                            'No recent activity',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          itemCount: activities.length,
                          itemBuilder: (context, index) {
                            return _buildActivityItem(activities[index]);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivitySummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x80000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryTile(
              'Weekly Activities',
              '${employee.weeklyActivityCount}',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryTile(
              'Engagement Score',
              '${employee.engagementScore.toStringAsFixed(0)}%',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryTile(
              'Motivation Level',
              employee.motivationLevel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActivityItem(EmployeeActivity activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x80000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFC10D00),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.activityType.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Text(
            _formatTimestamp(activity.timestamp),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

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
      backgroundColor: const Color(0x80000000),
      title: Text(
        widget.employee != null
            ? 'Send Nudge to ${widget.employee!.profile.displayName}'
            : 'Send Nudge',
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.employee != null &&
                widget.employee!.goals.isNotEmpty) ...[
              const Text(
                'Related Goal:',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: DropdownButton<Goal>(
                  value: _selectedGoal,
                  underline: const SizedBox(),
                  isExpanded: true,
                  dropdownColor: Colors.black.withValues(alpha: 0.9),
                  hint: const Text(
                    'Select Goal',
                    style: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  onChanged: (goal) => setState(() => _selectedGoal = goal),
                  items: widget.employee!.goals.map((goal) {
                    return DropdownMenuItem<Goal>(
                      value: goal,
                      child: Text(
                        goal.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Quick Presets:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetButton(
                  'Check Progress',
                  Icons.trending_up,
                  'Hope you\'re doing well! How is your progress on your current goals?',
                ),
                _buildPresetButton(
                  'Need Help?',
                  Icons.support_agent,
                  'Is there anything I can help you with regarding your goals or work?',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Message:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter your nudge message or use a preset above...',
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFC10D00)),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          onPressed: _sendNudge,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC10D00),
            foregroundColor: Colors.white,
          ),
          child: const Text('Send'),
        ),
      ],
    );
  }

  Widget _buildPresetButton(String label, IconData icon, String message) {
    return OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _messageController.text = message;
        });
      },
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFC10D00),
        side: BorderSide(color: const Color(0xFFC10D00).withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  void _sendNudge() {
    if (_messageController.text.trim().isEmpty) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0x80000000),
            content: const Text(
              'Please enter a message',
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Colors.white70),
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
