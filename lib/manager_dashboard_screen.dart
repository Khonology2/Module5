import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/services/manager_realtime_service.dart';

class ManagerDashboardScreen extends StatelessWidget {
  const ManagerDashboardScreen({super.key});

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
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [Color(0x880A0F1F), Color(0x88040610)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                kToolbarHeight + 24,
                16,
                16,
              ),
              child: StreamBuilder<TeamMetrics>(
                stream: ManagerRealtimeService.getTeamMetricsStream(
                  timeFilter: TimeFilter.month,
                ),
                builder: (context, metricsSnapshot) {
                  return StreamBuilder<List<EmployeeData>>(
                    stream: ManagerRealtimeService.getTeamDataStream(
                      timeFilter: TimeFilter.month,
                    ),
                    builder: (context, employeesSnapshot) {
                      return StreamBuilder<List<TeamInsight>>(
                        stream: ManagerRealtimeService.getTeamInsightsStream(
                          timeFilter: TimeFilter.month,
                        ),
                        builder: (context, insightsSnapshot) {
                          return ListView(
                            children: [
                              _buildGreetingCard(),
                              const SizedBox(height: 16),
                              _buildKpis(
                                metricsSnapshot.data,
                                employeesSnapshot.data ?? const [],
                              ),
                              const SizedBox(height: 16),
                              _buildTeamHealth(
                                metricsSnapshot.data,
                                employeesSnapshot.data ?? const [],
                              ),
                              const SizedBox(height: 16),
                              _buildActivitySummary(
                                employeesSnapshot.data ?? const [],
                              ),
                              const SizedBox(height: 16),
                              _buildTopTwoPerformers(
                                employeesSnapshot.data ?? const [],
                              ),
                              const SizedBox(height: 16),
                              _buildInsights(insightsSnapshot.data ?? const []),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: child,
    );
  }

  Widget _buildKpis(TeamMetrics? m, List<EmployeeData> employees) {
    // Fallbacks when TeamMetrics hasn't populated yet
    final totalEmployees = m?.totalEmployees ?? employees.length;
    final activeEmployees =
        m?.activeEmployees ??
        employees.where((e) {
          final now = DateTime.now();
          final sevenDaysAgo = now.subtract(const Duration(days: 7));
          return e.lastActivity.isAfter(sevenDaysAgo);
        }).length;
    final avgProgress =
        m?.avgTeamProgress ??
        (employees.isNotEmpty
            ? employees.map((e) => e.avgProgress).fold(0.0, (a, b) => a + b) /
                  employees.length
            : 0.0);
    final engagement =
        m?.teamEngagement ??
        (totalEmployees > 0 ? (activeEmployees / totalEmployees) * 100 : 0.0);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Team KPIs',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _kpi('Employees', totalEmployees.toString()),
              const SizedBox(width: 8),
              _kpi('Active', activeEmployees.toString()),
              const SizedBox(width: 8),
              _kpi('Avg Progress', '${avgProgress.toStringAsFixed(0)}%'),
              const SizedBox(width: 8),
              _kpi('Engagement', '${engagement.toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamHealth(TeamMetrics? m, List<EmployeeData> employees) {
    // Derive stats if metrics null
    int onTrack = m?.onTrackGoals ?? 0;
    int atRisk = m?.atRiskGoals ?? 0;
    int overdue = m?.overdueGoals ?? 0;
    double avgProgress =
        m?.avgTeamProgress ??
        (employees.isNotEmpty
            ? employees.map((e) => e.avgProgress).fold(0.0, (a, b) => a + b) /
                  employees.length
            : 0.0);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Team Health',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _kpi('On Track', '$onTrack'),
              const SizedBox(width: 8),
              _kpi('At Risk', '$atRisk'),
              const SizedBox(width: 8),
              _kpi('Overdue', '$overdue'),
              const SizedBox(width: 8),
              _kpi('Avg Progress', '${avgProgress.toStringAsFixed(0)}%'),
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
          color: AppColors.elevatedBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderColor),
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
          Text(
            'Activity Summary',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _kpi('Active Today', '$activeToday'),
              const SizedBox(width: 8),
              _kpi('Overdue', '$overdue'),
              const SizedBox(width: 8),
              _kpi('At Risk', '$atRisk'),
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
          Text(
            'AI Team Insights',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (insights.isEmpty)
            Text('No insights at the moment', style: AppTypography.muted)
          else
            ...insights
                .take(5)
                .map(
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: AppColors.activeColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            i.description,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildGreetingCard() {
    final greeting = _timeGreeting();
    return _card(
      child: Row(
        children: [
          const Icon(Icons.waving_hand, color: AppColors.activeColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              greeting,
              style: AppTypography.heading3.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
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
          Text(
            'Top 2 Performers',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (top2.isEmpty)
            Text('No performers to show yet', style: AppTypography.muted)
          else
            Column(
              children: top2
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.activeColor,
                            child: Text(
                              e.profile.displayName.isNotEmpty
                                  ? e.profile.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.profile.displayName,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.stars,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${e.totalPoints} pts',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  // Removed: superseded by _buildTopTwoPerformers
}
