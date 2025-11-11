// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/manager_profile_screen.dart';
import 'package:pdh/manager_employee_detail_screen.dart';
import 'package:pdh/services/manager_realtime_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Set Scaffold background to transparent
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove AppBar shadow
        title: const Text(
          'Manager Review',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          _buildProfileButton(context), // Use the new profile button widget
        ],
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
                                    _buildKpiRow(metricsSnapshot.data),
                                    const SizedBox(height: 20),
                                    _buildHeader(),
                                    const SizedBox(height: 20),

                                    // Debug info display
                                    _buildDebugInfo(
                                      employeesSnapshot,
                                      insightsSnapshot,
                                    ),
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

  Widget _buildProfileButton(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String userName = 'User';
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      userName = user.displayName!.split(' ').first;
    } else if (user?.email != null && user!.email!.isNotEmpty) {
      userName = user.email!.split('@').first;
    }
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManagerProfileScreen(),
            ),
          );
        },
        child: Row(
          children: [
            const Icon(Icons.person, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              userName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(TeamMetrics? metrics) {
    Widget tile(String label, String value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (metrics == null) {
      return Row(
        children: [
          tile('On Track', '--', Colors.greenAccent),
          const SizedBox(width: 12),
          tile('At Risk', '--', Colors.orangeAccent),
          const SizedBox(width: 12),
          tile('Overdue', '--', Colors.redAccent),
        ],
      );
    }

    return Row(
      children: [
        tile('On Track', '${metrics.onTrackGoals}', Colors.greenAccent),
        const SizedBox(width: 12),
        tile('At Risk', '${metrics.atRiskGoals}', Colors.orangeAccent),
        const SizedBox(width: 12),
        tile('Overdue', '${metrics.overdueGoals}', Colors.redAccent),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Text(
            'Team Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
            // Always show management actions for all employees
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sendNudge(employee),
                    icon: const Icon(Icons.notifications, size: 16),
                    label: const Text('Nudge'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC10D00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _scheduleOneOnOne(employee),
                    icon: const Icon(Icons.event, size: 16),
                    label: const Text('1:1'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white70),
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _giveRecognition(employee),
                    icon: const Icon(Icons.emoji_events, size: 16),
                    label: const Text('Kudos'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewActivities(employee),
                    icon: const Icon(Icons.timeline, size: 16),
                    label: const Text('Activity'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue),
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  void _sendNudge(EmployeeData employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0x80000000),
        title: Text(
          'Send Nudge to ${employee.profile.displayName}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter your message...',
                hintStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Store message
              },
            ),
          ],
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
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Nudge sent to ${employee.profile.displayName}',
                  ),
                  backgroundColor: const Color(0xFFC10D00),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC10D00),
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
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
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        '1:1 scheduled with ${employee.profile.displayName}',
                      ),
                      backgroundColor: const Color(0xFFC10D00),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return; // Add this line back
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Error scheduling meeting: $e'),
                      backgroundColor: Colors.red,
                    ),
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
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Recognition sent to ${employee.profile.displayName}',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return; // Add this line back
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Error giving recognition: $e'),
                            backgroundColor: Colors.red,
                          ),
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

  Widget _buildDebugInfo(
    AsyncSnapshot<List<EmployeeData>> employeesSnapshot,
    AsyncSnapshot<List<TeamInsight>> insightsSnapshot,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x80000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debug Information',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildDebugRow(
            'Employees Stream:',
            'hasData: ${employeesSnapshot.hasData}, hasError: ${employeesSnapshot.hasError}',
          ),
          if (employeesSnapshot.hasData)
            _buildDebugRow(
              'Employee Count:',
              '${employeesSnapshot.data!.length}',
            ),
          if (employeesSnapshot.hasError)
            _buildDebugRow('Employee Error:', '${employeesSnapshot.error}'),
          _buildDebugRow(
            'Insights Stream:',
            'hasData: ${insightsSnapshot.hasData}, hasError: ${insightsSnapshot.hasError}',
          ),
          if (insightsSnapshot.hasError)
            _buildDebugRow('Insights Error:', '${insightsSnapshot.error}'),
        ],
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
