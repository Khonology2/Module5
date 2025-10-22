import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/models/goal.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<EmployeeData> _employeeData = [];
  bool _isLoading = true;
  String _greeting = '';

  @override
  void initState() {
    super.initState();
    _generateGreeting();
    _loadEmployeeData();
  }

  void _generateGreeting() {
    final hour = DateTime.now().hour;
    String timeGreeting;

    if (hour < 12) {
      timeGreeting = 'Good Morning';
    } else if (hour < 17) {
      timeGreeting = 'Good Afternoon';
    } else {
      timeGreeting = 'Good Evening';
    }

    final user = FirebaseAuth.instance.currentUser;
    String userName = 'Manager';

    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      userName = user.displayName!.split(' ').first;
    } else if (user?.email != null && user!.email!.isNotEmpty) {
      userName = user.email!.split('@').first;
    }

    setState(() {
      _greeting = '$timeGreeting, $userName';
    });
  }

  Future<void> _loadEmployeeData() async {
    try {
      final managerId = FirebaseAuth.instance.currentUser?.uid;
      if (managerId == null) return;

      debugPrint('Dashboard: Loading employee data for manager: $managerId');

      // Get the stream and take the first value
      final stream = ManagerRealtimeService.getTeamDataStream();
      await for (final employees in stream.take(1)) {
        debugPrint('Dashboard: Loaded ${employees.length} employees');

        debugPrint('Dashboard: All employees (${employees.length}):');
        for (final emp in employees) {
          debugPrint(
            'Dashboard: Employee - "${emp.profile.displayName}" (${emp.profile.department.isEmpty ? "No Department" : emp.profile.department}) - Goals: ${emp.goals.length}',
          );
        }

        setState(() {
          _employeeData = employees; // Use all employees, not just valid ones
          _isLoading = false;
        });
        break;
      }
    } catch (e) {
      debugPrint('Dashboard: Error loading employee data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _noDataSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              const Text(
                'No Employee Data Found',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'To see employee data on this dashboard:',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            '• Employees need to register with the "employee" role\n'
            '• Employees should update their profiles with department information\n'
            '• Make sure employees have created some goals to track progress',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loadEmployeeData,
            icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
            label: const Text('Refresh Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC10D00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  'assets/20250919_1033_Futuristic Red Patterns_remix_01k5ghm3a8e39bxbzcpw8sgg6v.png',
                ),
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
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 16.0,
                16,
                16,
              ), // Adjusted padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _greetingSection(),
                  const SizedBox(height: 16),
                  _filtersBar(),
                  const SizedBox(height: 16),
                  _kpiRow(),
                  const SizedBox(height: 20),
                  _aiInsights(),
                  const SizedBox(height: 20),
                  _workloadHeatmap(),
                  const SizedBox(height: 20),
                  _engagementSummary(),
                  const SizedBox(height: 20),
                  _statusSections(),
                  // Show message if no employee data exists
                  if (!_isLoading && _employeeData.isEmpty) ...[
                    const SizedBox(height: 20),
                    _noDataSection(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _greetingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC10D00), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16, // Adjusted radius from 30 to 16 to match icon size
                backgroundColor: Colors.transparent,
                child: Image.asset(
                  'assets/Account_User_Profile/Profile.png',
                  width: 32.0, // Adjust as needed
                  height: 32.0, // Adjust as needed
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep up the great momentum!',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const Text(
                    'Level 1', // Static for now, can be dynamic later
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Removed the original Text widget as it's now part of the Column
          // Text(
          //   'Here\'s your team overview for today',
          //   style: const TextStyle(color: Colors.white70, fontSize: 14),
          // ),
        ],
      ),
    );
  }

  Widget _filtersBar() {
    Widget chip(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3652),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                chip('This month'),
                chip('Marketing'),
                chip('Design'),
                chip('At risk'),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _kpiRow() {
    if (_isLoading) {
      return Row(
        children: [
          _kpiTile('Active Goals', '...', const Color(0xFFC10D00)),
          const SizedBox(width: 12),
          _kpiTile('At Risk', '...', Colors.orangeAccent),
          const SizedBox(width: 12),
          _kpiTile('Overdue', '...', Colors.redAccent),
        ],
      );
    }

    // Debug logging
    debugPrint('Dashboard KPI: Employee data count: ${_employeeData.length}');
    for (final emp in _employeeData) {
      debugPrint(
        'Dashboard KPI: ${emp.profile.displayName} - Goals: ${emp.goals.length}, Status: ${emp.status}, Overdue: ${emp.overdueGoalsCount}',
      );
    }

    final activeGoals = _employeeData.fold<int>(
      0,
      (sum, emp) =>
          sum + emp.goals.where((g) => g.status != GoalStatus.completed).length,
    );
    final atRiskCount = _employeeData
        .where((emp) => emp.status == EmployeeStatus.atRisk)
        .length;
    final overdueCount = _employeeData
        .where((emp) => emp.status == EmployeeStatus.overdue)
        .length;

    debugPrint(
      'Dashboard KPI: Active Goals: $activeGoals, At Risk: $atRiskCount, Overdue: $overdueCount',
    );

    return Row(
      children: [
        _kpiTile(
          'Active Goals',
          activeGoals.toString(),
          const Color(0xFFC10D00),
        ),
        const SizedBox(width: 12),
        _kpiTile('At Risk', atRiskCount.toString(), Colors.orangeAccent),
        const SizedBox(width: 12),
        _kpiTile('Overdue', overdueCount.toString(), Colors.redAccent),
      ],
    );
  }

  Widget _kpiTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2840),
          borderRadius: BorderRadius.circular(10),
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

  Widget _statusSections() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC10D00)),
      );
    }

    Widget section(String title, List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );

    Widget card({
      required Color stripe,
      required String heading,
      required String sub,
      Widget? trailing,
    }) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2840),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: stripe, width: 3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heading,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      );
    }

    // Get at-risk employees
    final atRiskEmployees = _employeeData
        .where((emp) => emp.status == EmployeeStatus.atRisk)
        .toList();

    // Get employees with upcoming goals (7-14 days)
    final upcomingEmployees = <EmployeeData>[];
    final now = DateTime.now();
    for (final emp in _employeeData) {
      final upcomingGoals = emp.goals.where((goal) {
        final daysUntilDue = goal.targetDate.difference(now).inDays;
        return daysUntilDue >= 7 && daysUntilDue <= 14;
      }).toList();
      if (upcomingGoals.isNotEmpty) {
        upcomingEmployees.add(emp);
      }
    }

    // Get employees with recently completed goals
    final completedEmployees = <EmployeeData>[];
    for (final emp in _employeeData) {
      final completedGoals = emp.goals.where((goal) {
        final daysSinceCompleted = now.difference(goal.createdAt).inDays;
        return goal.status.toString().contains('completed') &&
            daysSinceCompleted <= 7;
      }).toList();
      if (completedGoals.isNotEmpty) {
        completedEmployees.add(emp);
      }
    }

    return Column(
      children: [
        if (atRiskEmployees.isNotEmpty) ...[
          section(
            'At Risk',
            atRiskEmployees.take(3).map((emp) {
              return card(
                stripe: Colors.orangeAccent,
                heading: emp.profile.displayName,
                sub:
                    '${emp.overdueGoalsCount} overdue goals • ${emp.profile.department.isEmpty ? "No Department" : emp.profile.department}',
                trailing: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                  ),
                  child: const Text(
                    'Nudge',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (upcomingEmployees.isNotEmpty) ...[
          section(
            'Upcoming (7–14 days)',
            upcomingEmployees.take(2).map((emp) {
              final upcomingGoals = emp.goals.where((goal) {
                final daysUntilDue = goal.targetDate.difference(now).inDays;
                return daysUntilDue >= 7 && daysUntilDue <= 14;
              }).toList();
              final nextGoal = upcomingGoals.isNotEmpty
                  ? upcomingGoals.first
                  : emp.goals.first;
              final daysUntilDue = nextGoal.targetDate.difference(now).inDays;
              return card(
                stripe: const Color(0xFFC10D00),
                heading: nextGoal.title,
                sub: '${emp.profile.displayName} • Due in $daysUntilDue days',
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (completedEmployees.isNotEmpty) ...[
          section(
            'Recently Completed',
            completedEmployees.take(1).map((emp) {
              final completedGoals = emp.goals.where((goal) {
                final daysSinceCompleted = now
                    .difference(goal.createdAt)
                    .inDays;
                return goal.status.toString().contains('completed') &&
                    daysSinceCompleted <= 7;
              }).toList();
              final recentGoal = completedGoals.isNotEmpty
                  ? completedGoals.first
                  : emp.goals.first;
              final daysAgo = now.difference(recentGoal.createdAt).inDays;
              return card(
                stripe: Colors.greenAccent,
                heading: recentGoal.title,
                sub: '${emp.profile.displayName} • ${daysAgo}d ago',
                trailing: Row(
                  children: [
                    _chip('share', const Color(0xFFC10D00)),
                    const SizedBox(width: 6),
                    _chip('kudos', Colors.orangeAccent),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
        if (atRiskEmployees.isEmpty &&
            upcomingEmployees.isEmpty &&
            completedEmployees.isEmpty) ...[
          section('Team Status', [
            card(
              stripe: Colors.blueAccent,
              heading: 'All team members are on track',
              sub: 'Great job managing your team!',
            ),
          ]),
        ],
      ],
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 11)),
  );

  List<String> _generateInsights() {
    if (_isLoading || _employeeData.isEmpty) {
      return [
        'Loading team insights...',
        'Analyzing employee performance data...',
        'Preparing personalized recommendations...',
      ];
    }

    List<String> insights = [];

    final atRiskCount = _employeeData
        .where((emp) => emp.status == EmployeeStatus.atRisk)
        .length;
    final overdueCount = _employeeData
        .where((emp) => emp.status == EmployeeStatus.overdue)
        .length;
    final totalEmployees = _employeeData.length;
    final avgEngagement =
        _employeeData.fold<double>(0, (sum, emp) => sum + emp.engagementScore) /
        totalEmployees;

    if (atRiskCount > 0) {
      insights.add(
        '$atRiskCount team member(s) are at risk. Consider scheduling 1:1s to provide support.',
      );
    }

    if (overdueCount > 0) {
      insights.add(
        '$overdueCount employee(s) have overdue goals. Review workload distribution.',
      );
    }

    if (avgEngagement > 70) {
      insights.add(
        'Team engagement is strong (${avgEngagement.toStringAsFixed(1)}%). Keep up the great work!',
      );
    } else if (avgEngagement < 50) {
      insights.add(
        'Team engagement is below average (${avgEngagement.toStringAsFixed(1)}%). Consider team building activities.',
      );
    }

    final topPerformer = _employeeData.reduce(
      (a, b) => a.engagementScore > b.engagementScore ? a : b,
    );
    if (topPerformer.engagementScore > 80) {
      insights.add(
        '${topPerformer.profile.displayName} is excelling. Consider sharing their best practices with the team.',
      );
    }

    if (insights.isEmpty) {
      insights.add(
        'Your team is performing well overall. Continue monitoring progress and provide support as needed.',
      );
    }

    return insights;
  }

  Widget _aiInsights() {
    Widget bullet(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(10),
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
          const SizedBox(height: 12),
          ..._generateInsights().map((insight) => bullet(insight)),
          bullet(
            'High morale signals this week. Share Emily’s win-back workflow as best practice.',
          ),
        ],
      ),
    );
  }

  Widget _workloadHeatmap() {
    List<List<double>> mock = const [
      [0.2, 0.8, 0.4, 0.1, 0.0, 0.3, 0.6],
      [0.1, 0.3, 0.2, 0.5, 0.7, 0.9, 0.4],
      [0.0, 0.2, 0.1, 0.6, 0.8, 0.5, 0.2],
    ];
    Color cell(double v) =>
        Color.lerp(const Color(0xFF22304A), Color(0xFFC10D00), v) ??
        const Color(0xFF22304A);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Workload & Capacity',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2840),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Mon',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    'Tue',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    'Wed',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    'Thu',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    'Fri',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    'Sat',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    'Sun',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                children: mock
                    .map(
                      (row) => Row(
                        children: row
                            .map(
                              (v) => Expanded(
                                child: Container(
                                  height: 16,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cell(v),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _engagementSummary() {
    Widget tile(IconData icon, String label, String value, Color color) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2840),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Engagement & Check-ins',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            tile(
              Icons.rate_review,
              'Check-ins this week',
              '9',
              Color(0xFFC10D00),
            ),
            const SizedBox(width: 12),
            tile(Icons.forum, 'Open comments', '5', Colors.orangeAccent),
            const SizedBox(width: 12),
            tile(Icons.alarm, 'Nudges pending', '3', Colors.pinkAccent),
          ],
        ),
      ],
    );
  }
}
