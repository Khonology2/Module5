import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/services/manager_realtime_service.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final ManagerRealtimeService _realtime = ManagerRealtimeService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Manager Dashboard'),
      ),
      body: StreamBuilder<List<EmployeeData>>(
        stream: _realtime.employeesStream(),
        builder: (context, employeesSnap) {
          if (employeesSnap.hasError) {
            return Center(
              child: Text('Error loading employees: ${employeesSnap.error}'),
            );
          }
          if (!employeesSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final employees = employeesSnap.data!;

          return StreamBuilder<TeamMetrics?>(
            stream: _realtime.teamMetricsStream(),
            builder: (context, metricsSnap) {
              final metrics = metricsSnap.data;

              return StreamBuilder<List<TeamInsight>>(
                stream: _realtime.teamInsightsStream(),
                builder: (context, insightsSnap) {
                  final insights = insightsSnap.data ?? [];

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGreetingCard(employees),
                        const SizedBox(height: 12),
                        _buildKpis(metrics, employees),
                        const SizedBox(height: 12),
                        _buildTeamHealth(metrics, employees),
                        const SizedBox(height: 12),
                        _buildActivitySummary(employees),
                        const SizedBox(height: 12),
                        _buildTopTwoPerformers(employees),
                        const SizedBox(height: 12),
                        _buildInsights(insights),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Transparent black background to show background image
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: child,
    );
  }

  Widget _buildKpis(TeamMetrics? m, List<EmployeeData> employees) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final totalEmployees = m?.totalEmployees ?? employees.length;
    final activeEmployees =
        m?.activeEmployees ??
        employees.where((e) => e.lastActivity.isAfter(sevenDaysAgo)).length;
    final avgProgress = m?.avgTeamProgress ?? 0.0;
    final engagement =
        m?.teamEngagement ??
        (totalEmployees > 0 ? (activeEmployees / totalEmployees) * 100 : 0.0);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Team KPIs', style: AppTypography.heading2),
          const SizedBox(height: 12),
          Row(
            children: [
              _kpi('Total', totalEmployees.toString()),
              const SizedBox(width: 8),
              _kpi('Active (7d)', activeEmployees.toString()),
              const SizedBox(width: 8),
              _kpi('Avg Progress', '${avgProgress.toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Engagement: ${engagement.toStringAsFixed(0)}%',
            style: AppTypography.muted,
          ),
        ],
      ),
    );
  }

  Widget _buildTeamHealth(TeamMetrics? m, List<EmployeeData> employees) {
    final onTrack = m?.onTrackGoals ?? 0;
    final atRisk = m?.atRiskGoals ?? 0;
    final overdue = m?.overdueGoals ?? 0;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Team Health', style: AppTypography.heading2),
          const SizedBox(height: 12),
          Row(
            children: [
              _kpi('On Track', onTrack.toString()),
              const SizedBox(width: 8),
              _kpi('At Risk', atRisk.toString()),
              const SizedBox(width: 8),
              _kpi('Overdue', overdue.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // Transparent black for KPI tiles to match card styling
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTypography.heading4.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTypography.muted),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySummary(List<EmployeeData> employees) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activeToday = employees
        .where((e) => e.lastActivity.isAfter(today))
        .length;
    final overdue = employees
        .where((e) => e.status == EmployeeStatus.overdue)
        .length;
    final atRisk = employees
        .where((e) => e.status == EmployeeStatus.atRisk)
        .length;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Summary', style: AppTypography.heading2),
          const SizedBox(height: 12),
          Row(
            children: [
              _kpi('Active Today', activeToday.toString()),
              const SizedBox(width: 8),
              _kpi('Overdue', overdue.toString()),
              const SizedBox(width: 8),
              _kpi('At Risk', atRisk.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsights(List<TeamInsight> insights) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Team Insights', style: AppTypography.heading2),
          const SizedBox(height: 12),
          if (insights.isEmpty)
            Text('No insights available', style: AppTypography.muted)
          else
            ...insights.map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• ${i.title}', style: AppTypography.bodyText),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGreetingCard(List<EmployeeData> employees) {
    final greeting = _timeGreeting();
    final teamSize = employees.length;
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: AppTypography.heading1),
                const SizedBox(height: 4),
                Text('Team size: $teamSize', style: AppTypography.muted),
              ],
            ),
          ),
          // simple avatar or placeholder
          const CircleAvatar(child: Icon(Icons.person)),
        ],
      ),
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning, Manager';
    if (hour < 17) return 'Good afternoon, Manager';
    return 'Good evening, Manager';
  }

  Widget _buildTopTwoPerformers(List<EmployeeData> employees) {
    final top = [...employees]
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    final top2 = top.take(2).toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Performers', style: AppTypography.heading2),
          const SizedBox(height: 12),
          if (top2.isEmpty)
            Text('No performers yet', style: AppTypography.muted)
          else
            ...top2.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.profile.displayName,
                        style: AppTypography.bodyText,
                      ),
                    ),
                    Text('${e.totalPoints}', style: AppTypography.heading4),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
