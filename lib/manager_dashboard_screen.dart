import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/services/season_service.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/services/role_service.dart';

class ManagerDashboardScreen extends StatefulWidget {
  final bool embedded;

  const ManagerDashboardScreen({super.key, this.embedded = false});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final ManagerRealtimeService _realtime = ManagerRealtimeService();

  @override
  void initState() {
    super.initState();
    _redirectIfManagerStandalone();
  }

  

  Future<void> _redirectIfManagerStandalone() async {
    try {
      final role = await RoleService.instance.getRole();
      if (!mounted) return;
      if (role == 'manager') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final current = ModalRoute.of(context)?.settings.name;
          if (current != '/manager_portal') {
            Navigator.pushReplacementNamed(
              context,
              '/manager_portal',
              arguments: {'initialRoute': '/dashboard'},
            );
          }
        });
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: StreamBuilder<List<EmployeeData>>(
        stream: _realtime.employeesStream(),
        builder: (context, employeesSnap) {
          if (employeesSnap.hasError) {
            return Center(
              child: Text('Error loading employees: ${employeesSnap.error}'),
            );
          }
          if (!employeesSnap.hasData) {
            return SizedBox(
              height: 360,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
                ),
              ),
            );
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

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: AppSpacing.xl),
                      _buildDailyMotivationCard(),
                      const SizedBox(height: AppSpacing.xl),
                      metricsSnap.connectionState == ConnectionState.waiting
                          ? _card(
                              child: SizedBox(
                                height: 120,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
                                  ),
                                ),
                              ),
                            )
                          : _buildKpis(metrics, employees),
                      const SizedBox(height: AppSpacing.xl),
                      metricsSnap.connectionState == ConnectionState.waiting
                          ? _card(
                              child: SizedBox(
                                height: 140,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
                                  ),
                                ),
                              ),
                            )
                          : _buildTeamHealth(metrics, employees),
                      const SizedBox(height: AppSpacing.xl),
                      _buildActivitySummary(employees),
                      const SizedBox(height: AppSpacing.xl),
                      _buildSeasonProgressAlerts(),
                      const SizedBox(height: AppSpacing.xl),
                      _buildTopTwoPerformers(employees),
                      const SizedBox(height: AppSpacing.xl),
                      insightsSnap.connectionState == ConnectionState.waiting
                          ? _card(
                              child: SizedBox(
                                height: 120,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
                                  ),
                                ),
                              ),
                            )
                          : _buildInsights(insights),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );

    if (widget.embedded) {
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

    return AppScaffold(
      title: 'Manager Dashboard',
      showAppBar: false,
      items: SidebarConfig.managerItems,
      currentRouteName: '/dashboard',
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
      content: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/khono_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: content,
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Transparent black background to show background image
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.activeColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.manage_accounts, color: Colors.white),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greeting, Manager!', style: AppTypography.heading4),
                const SizedBox(height: 5),
                Text(
                  'Lead by example and help your team grow today.',
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

  Widget _buildDailyMotivationCard() {
    return AppComponents.card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              AppColors.activeColor.withValues(alpha: 0.1),
              AppColors.warningColor.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Image.asset(
                'Innovation_Brainstorm/innovation_brainstorm_red_badge_white.png',
                width: 78,
                height: 78,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Motivation',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.activeColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getDailyMotivation(),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  String _getDailyMotivation() {
    final motivations = [
      "Great leaders inspire others to dream more, learn more, do more.",
      "Your guidance today shapes your team's success tomorrow.",
      "Consistency beats intensity—coach your team daily.",
      "Empower your team; results will follow.",
      "Small nudges create big momentum.",
      "Celebrate progress, not just outcomes.",
      "Lead with clarity, empathy, and action.",
    ];
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return motivations[dayOfYear % motivations.length];
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

    return AppComponents.card(
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

    return AppComponents.card(
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
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final activeToday = employees
        .where((e) => e.lastActivity.isAfter(today))
        .length;
    final activeThisWeek = employees
        .where((e) => e.lastActivity.isAfter(sevenDaysAgo))
        .length;
    final inactive = employees
        .where((e) => e.status == EmployeeStatus.inactive)
        .length;
    final overdue = employees
        .where((e) => e.status == EmployeeStatus.overdue)
        .length;
    final atRisk = employees
        .where((e) => e.status == EmployeeStatus.atRisk)
        .length;

    return AppComponents.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Summary', style: AppTypography.heading2),
          const SizedBox(height: 12),
          Row(
            children: [
              _kpi('Active Today', activeToday.toString()),
              const SizedBox(width: 8),
              _kpi('Active (7d)', activeThisWeek.toString()),
              const SizedBox(width: 8),
              _kpi('Inactive', inactive.toString()),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _kpi('Overdue', overdue.toString()),
              const SizedBox(width: 8),
              _kpi('At Risk', atRisk.toString()),
              const SizedBox(width: 8),
              _kpi(
                'On Track',
                employees
                    .where((e) => e.status == EmployeeStatus.onTrack)
                    .length
                    .toString(),
              ),
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

  // ignore: unused_element
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
                    // Active status indicator
                    _buildActiveStatusIndicator(e),
                    const SizedBox(width: 8),
                    Text('${e.totalPoints}', style: AppTypography.heading4),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveStatusIndicator(EmployeeData employee) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    bool isActiveToday = employee.lastActivity.isAfter(today);
    bool isActiveThisWeek = employee.lastActivity.isAfter(sevenDaysAgo);

    Color statusColor;
    IconData statusIcon;
    String tooltip;

    if (isActiveToday) {
      statusColor = Colors.green;
      statusIcon = Icons.circle;
      tooltip = 'Active today';
    } else if (isActiveThisWeek) {
      statusColor = Colors.orange;
      statusIcon = Icons.circle;
      tooltip = 'Active this week';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.circle_outlined;
      tooltip = 'Inactive';
    }

    return Tooltip(
      message: tooltip,
      child: Icon(statusIcon, color: statusColor, size: 12),
    );
  }

  Widget _buildSeasonProgressAlerts() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: AppColors.activeColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Season Progress Alerts',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Season>>(
            stream: SeasonService.getManagerSeasonsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return Text(
                  'No season data available',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                );
              }

              final seasons = snapshot.data!;
              final activeSeasons = seasons
                  .where((s) => s.status == SeasonStatus.active)
                  .toList();

              if (activeSeasons.isEmpty) {
                return Text(
                  'No active seasons',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                );
              }

              return Column(
                children: activeSeasons.map((season) {
                  return _buildSeasonProgressCard(season);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonProgressCard(Season season) {
    final completedParticipants = season.participantIds.where((participantId) {
      final participation = season.participations[participantId];
      if (participation == null) return false;

      // Check if all milestones are completed
      int totalMilestones = 0;
      int completedMilestones = 0;

      for (final challenge in season.challenges) {
        totalMilestones += challenge.milestones.length;
        for (final milestone in challenge.milestones) {
          final milestoneStatus = participation
              .milestoneProgress['${challenge.id}.${milestone.id}'];
          if (milestoneStatus == MilestoneStatus.completed) {
            completedMilestones++;
          }
        }
      }

      return totalMilestones > 0 && completedMilestones == totalMilestones;
    }).length;

    final totalParticipants = season.participantIds.length;
    final allCompleted =
        completedParticipants == totalParticipants && totalParticipants > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: allCompleted
            ? AppColors.successColor.withValues(alpha: 0.1)
            : AppColors.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: allCompleted
              ? AppColors.successColor.withValues(alpha: 0.3)
              : AppColors.warningColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allCompleted ? Icons.check_circle : Icons.schedule,
                color: allCompleted
                    ? AppColors.successColor
                    : AppColors.warningColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  season.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (allCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'READY',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Progress: ',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$completedParticipants/$totalParticipants employees completed',
                style: AppTypography.bodySmall.copyWith(
                  color: allCompleted
                      ? AppColors.successColor
                      : AppColors.warningColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: totalParticipants > 0
                ? completedParticipants / totalParticipants
                : 0.0,
            backgroundColor: AppColors.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              allCompleted ? AppColors.successColor : AppColors.warningColor,
            ),
            minHeight: 4,
          ),
          if (allCompleted) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _completeSeason(season),
                icon: const Icon(Icons.flag, size: 16),
                label: const Text('Complete Season'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _completeSeason(Season season) {
    Navigator.pushNamed(
      context,
      '/season_management',
      arguments: {'seasonId': season.id},
    );
  }
}
