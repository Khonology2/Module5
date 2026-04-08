import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/services/role_service.dart';

enum LeaderboardMetric { points, streaks, progress }

class ManagerLeaderboardScreen extends StatefulWidget {
  final bool embedded;
  const ManagerLeaderboardScreen({super.key, this.embedded = false});

  @override
  State<ManagerLeaderboardScreen> createState() =>
      _ManagerLeaderboardScreenState();
}

class _ManagerLeaderboardScreenState extends State<ManagerLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  LeaderboardMetric _metric = LeaderboardMetric.points;
  List<EmployeeData> _lastEmployees = const [];
  late final Stream<List<EmployeeData>> _employeeStream;
  Future<List<EmployeeData>>? _employeeFuture;
  late final AnimationController _topHoverController;
  bool _isTopHovered = false;

  @override
  void initState() {
    super.initState();
    _redirectIfManagerStandalone();
    _topHoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _topHoverController.repeat(reverse: true);
    // IMPORTANT: Cache the stream instance so StreamBuilder doesn't resubscribe
    // on every rebuild (which can destabilize Firestore listeners on web).
    _employeeStream = ManagerRealtimeService.getTeamDataStream(
      timeFilter: TimeFilter.month,
    );
    // On web, prefer one-time fetches to avoid Firestore Web listener instability.
    if (kIsWeb) {
      _employeeFuture = ManagerRealtimeService.getTeamDataStream(
        timeFilter: TimeFilter.month,
      ).first;
    }
  }

  int _badgeCount(EmployeeData e) {
    final v2 = e.profile.badgesV2.length;
    if (v2 > 0) return v2;
    return e.profile.badges.length;
  }

  Widget _buildInlineStatChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _topHoverController.dispose();
    super.dispose();
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.trending_up_outlined, color: AppColors.textSecondary),
        SizedBox(height: 8),
        Text(
          'No employees found',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        SizedBox(height: 4),
        Text(
          'If some employees are missing, verify their user profiles exist in Firestore `users` and their role is set to employee.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
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
              arguments: {'initialRoute': '/manager_leaderboard'},
            );
          }
        });
      }
    } catch (_) {
      // ignore
    }
  }

  // Removed unused legacy query function to avoid linter warning

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (kIsWeb) {
      content = FutureBuilder<List<EmployeeData>>(
        future: _employeeFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.dangerColor),
                  const SizedBox(height: 8),
                  const Text(
                    'Failed to load leaderboard',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${snapshot.error}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _employeeFuture = ManagerRealtimeService
                            .getTeamDataStream(
                              timeFilter: TimeFilter.month,
                            )
                            .first;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.activeColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final team = snapshot.data ?? _lastEmployees;

          // Sort by metric
          team.sort((a, b) {
            switch (_metric) {
              case LeaderboardMetric.points:
                final byPoints = b.totalPoints.compareTo(a.totalPoints);
                if (byPoints != 0) return byPoints;
                return a.profile.displayName.compareTo(b.profile.displayName);
              case LeaderboardMetric.streaks:
                final byStreak = b.streakDays.compareTo(a.streakDays);
                if (byStreak != 0) return byStreak;
                return a.profile.displayName.compareTo(b.profile.displayName);
              case LeaderboardMetric.progress:
                final byProgress = b.avgProgress.compareTo(a.avgProgress);
                if (byProgress != 0) return byProgress;
                return a.profile.displayName.compareTo(b.profile.displayName);
            }
          });

          if (team.isNotEmpty) _lastEmployees = team;

          if (team.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
              children: [
                Row(
                  children: [
                    Expanded(child: _buildHeaderWithFilters()),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () {
                        setState(() {
                          _employeeFuture = ManagerRealtimeService
                              .getTeamDataStream(
                                timeFilter: TimeFilter.month,
                              )
                              .first;
                        });
                      },
                      icon: const Icon(
                        Icons.refresh,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildEmptyState(),
              ],
            );
          }

          // Build podium for top 3
          final top = team.take(3).toList();
          final rest = team.skip(3).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
            children: [
              Row(
                children: [
                  Expanded(child: _buildHeaderWithFilters()),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () {
                      setState(() {
                        _employeeFuture = ManagerRealtimeService
                            .getTeamDataStream(
                              timeFilter: TimeFilter.month,
                            )
                            .first;
                      });
                    },
                    icon: const Icon(
                      Icons.refresh,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (top.isNotEmpty) _buildPodium(top),
              const SizedBox(height: 16),
              ...rest.asMap().entries.map((entry) {
                final idx = entry.key;
                final e = entry.value;
                final rank = idx + 4; // top 3 are ranks 1..3
                return _buildListItem(e, rank: rank);
              }),
            ],
          );
        },
      );
    } else {
      content = StreamBuilder<List<EmployeeData>>(
        stream: _employeeStream,
        builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.dangerColor),
                const SizedBox(height: 8),
                const Text(
                  'Failed to load leaderboard',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${snapshot.error}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        // Prefer live data, otherwise show last cached team to avoid spinners
        final team = snapshot.data ?? _lastEmployees;

        // Sort by metric
        team.sort((a, b) {
          switch (_metric) {
            case LeaderboardMetric.points:
              final byPoints = b.totalPoints.compareTo(a.totalPoints);
              if (byPoints != 0) return byPoints;
              return a.profile.displayName.compareTo(b.profile.displayName);
            case LeaderboardMetric.streaks:
              final byStreak = b.streakDays.compareTo(a.streakDays);
              if (byStreak != 0) return byStreak;
              return a.profile.displayName.compareTo(b.profile.displayName);
            case LeaderboardMetric.progress:
              final byProgress = b.avgProgress.compareTo(a.avgProgress);
              if (byProgress != 0) return byProgress;
              return a.profile.displayName.compareTo(b.profile.displayName);
          }
        });

        // Update cache when we have any data
        if (team.isNotEmpty) {
          _lastEmployees = team;
        }

        if (team.isEmpty &&
            (snapshot.connectionState == ConnectionState.waiting)) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderWithFilters(),
              const SizedBox(height: 16),
              _buildEmptyState(),
            ],
          );
        }

        if (team.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
            children: [
              _buildHeaderWithFilters(),
              const SizedBox(height: 16),
              _buildEmptyState(),
            ],
          );
        }

        // Build podium for top 3
        final top = team.take(3).toList();
        final rest = team.skip(3).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
          children: [
            _buildHeaderWithFilters(),
            const SizedBox(height: 16),
            if (top.isNotEmpty) _buildPodium(top),
            const SizedBox(height: 16),
            ...rest.asMap().entries.map((entry) {
              final idx = entry.key;
              final e = entry.value;
              final rank = idx + 4; // top 3 are ranks 1..3
              return _buildListItem(e, rank: rank);
            }),
          ],
        );
      },
      );
    }

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text(
          'Manager Leaderboard',
          style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: false,
      ),
      body: content,
    );
  }

  Widget _buildHeaderWithFilters() {
    Widget metricChip(String label, LeaderboardMetric metric) {
      final selected = _metric == metric;
      return GestureDetector(
        onTap: () => setState(() => _metric = metric),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.activeColor
                : AppColors.elevatedBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.activeColor : AppColors.borderColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 11,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Employees',
            style: AppTypography.heading2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Switch metrics to compare different dimensions of impact.',
            style: AppTypography.bodySmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              metricChip('Points', LeaderboardMetric.points),
              metricChip('Streaks', LeaderboardMetric.streaks),
              metricChip('Progress', LeaderboardMetric.progress),
            ],
          ),
        ],
      ),
    );
  }

  String _podiumMetricText(EmployeeData e) {
    switch (_metric) {
      case LeaderboardMetric.points:
        return '${e.totalPoints} pts';
      case LeaderboardMetric.streaks:
        return '${e.streakDays} day streak';
      case LeaderboardMetric.progress:
        return '${e.avgProgress.toStringAsFixed(1)}%';
    }
  }

  Widget _buildPodium(List<EmployeeData> top) {
    final topThree = top.take(3).toList();
    if (topThree.isEmpty) return const SizedBox.shrink();

    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
    ];

    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
          ),
          if (topThree.length > 1)
            Positioned(
              bottom: 20,
              left: MediaQuery.of(context).size.width * 0.2,
              child: _buildPodiumCardWithNumber(
                employee: topThree[1],
                color: colors[1],
                width: 120,
                numberText: '2',
              ),
            ),
          if (topThree.length > 2)
            Positioned(
              bottom: 20,
              right: MediaQuery.of(context).size.width * 0.2,
              child: _buildPodiumCardWithNumber(
                employee: topThree[2],
                color: colors[2],
                width: 120,
                numberText: '3',
              ),
            ),
          if (topThree.isNotEmpty)
            Positioned(
              top: 0,
              child: MouseRegion(
                onEnter: (_) => setState(() => _isTopHovered = true),
                onExit: (_) => setState(() => _isTopHovered = false),
                child: AnimatedBuilder(
                  animation: _topHoverController,
                  builder: (context, child) {
                    final amplitude = _isTopHovered ? 10.0 : 4.0;
                    final dy =
                        math.sin(_topHoverController.value * math.pi) * amplitude;
                    return Transform.translate(
                      offset: Offset(0, dy),
                      child: child,
                    );
                  },
                  child: _buildPodiumCardWithNumber(
                    employee: topThree[0],
                    color: colors[0],
                    width: 120,
                    numberText: '1',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPodiumCardWithNumber({
    required EmployeeData employee,
    required Color color,
    required double width,
    required String numberText,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPodiumCard(
          employee: employee,
          color: color,
          width: width,
        ),
        const SizedBox(height: 8),
        _buildPositionBadge(color: color, text: numberText),
      ],
    );
  }

  Widget _buildPodiumCard({
    required EmployeeData employee,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color,
            child: Text(
              employee.profile.displayName.isNotEmpty
                  ? employee.profile.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            employee.profile.displayName,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _podiumMetricText(employee),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionBadge({required Color color, required String text}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildListItem(EmployeeData e, {required int rank}) {
    final metricText = switch (_metric) {
      LeaderboardMetric.points => '${e.totalPoints} pts',
      LeaderboardMetric.streaks => '${e.streakDays} day streak',
      LeaderboardMetric.progress => '${e.avgProgress.toStringAsFixed(1)}%',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.elevatedBackground,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.activeColor,
            child: Text(
              e.profile.displayName.isNotEmpty
                  ? e.profile.displayName[0].toUpperCase()
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
                  e.profile.displayName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  e.profile.department,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  children: [
                    _buildInlineStatChip(
                      icon: Icons.stars,
                      text: '${e.totalPoints} pts',
                      color: AppColors.warningColor,
                    ),
                    _buildInlineStatChip(
                      icon: Icons.workspace_premium,
                      text: '${_badgeCount(e)}',
                      color: AppColors.activeColor,
                    ),
                    if (_metric != LeaderboardMetric.points)
                      _buildInlineStatChip(
                        icon: _metric == LeaderboardMetric.streaks
                            ? Icons.local_fire_department
                            : Icons.trending_up,
                        text: metricText,
                        color: Colors.white70,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
