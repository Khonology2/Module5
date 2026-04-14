import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';

enum LeaderboardMetric { points, streaks, progress }

class ManagerLeaderboardScreen extends StatefulWidget {
  final bool embedded;
  const ManagerLeaderboardScreen({super.key, this.embedded = false});

  @override
  State<ManagerLeaderboardScreen> createState() =>
      _ManagerLeaderboardScreenState();
}

class _ManagerLeaderboardScreenState extends State<ManagerLeaderboardScreen> {
  LeaderboardMetric _metric = LeaderboardMetric.points;
  List<EmployeeData> _lastTeam = const [];
  late final Stream<List<EmployeeData>> _teamStream;
  Future<List<EmployeeData>>? _teamFuture;

  @override
  void initState() {
    super.initState();
    _redirectIfManagerStandalone();
    // IMPORTANT: Cache the stream instance so StreamBuilder doesn't resubscribe
    // on every rebuild (which can destabilize Firestore listeners on web).
    _teamStream = ManagerRealtimeService.getTeamDataStream(
      department: null,
      timeFilter: TimeFilter.month,
    );
    // On web, prefer one-time fetches to avoid Firestore Web listener instability.
    if (kIsWeb) {
      _teamFuture = ManagerRealtimeService.getTeamDataOnce(
        department: null,
        timeFilter: TimeFilter.month,
      );
    }
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.trending_up_outlined, color: DashboardChrome.fg),
        const SizedBox(height: 8),
        Text(
          'No employees found',
          style: TextStyle(color: DashboardChrome.fg),
        ),
        const SizedBox(height: 4),
        Text(
          'If some employees are missing, verify their user profiles exist in Firestore `users` and their role is set to employee.',
          style: TextStyle(color: DashboardChrome.fg, fontSize: 12),
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
        future: _teamFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.dangerColor),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load leaderboard',
                    style: TextStyle(color: DashboardChrome.fg),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(
                      color: DashboardChrome.fg,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _teamFuture = ManagerRealtimeService.getTeamDataOnce(
                          department: null,
                          timeFilter: TimeFilter.month,
                        );
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

          final raw = snapshot.data ?? _lastTeam;
          final team = raw.where((e) => e.profile.leaderboardOptin).toList();

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

          if (team.isNotEmpty) _lastTeam = team;

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
                          _teamFuture = ManagerRealtimeService.getTeamDataOnce(
                            department: null,
                            timeFilter: TimeFilter.month,
                          );
                        });
                      },
                      icon: const Icon(
                        Icons.refresh,
                        color: AppColors.activeColor,
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
                        _teamFuture = ManagerRealtimeService.getTeamDataOnce(
                          department: null,
                          timeFilter: TimeFilter.month,
                        );
                      });
                    },
                    icon: const Icon(
                      Icons.refresh,
                      color: AppColors.activeColor,
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
        stream: _teamStream,
        builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.dangerColor),
                const SizedBox(height: 8),
                Text(
                  'Failed to load leaderboard',
                  style: TextStyle(color: DashboardChrome.fg),
                ),
                const SizedBox(height: 4),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(
                    color: DashboardChrome.fg,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        // Prefer live data, otherwise show last cached team to avoid spinners
        final raw = snapshot.data ?? _lastTeam;
        // Only show employees who opted in to leaderboard participation
        final team = raw.where((e) => e.profile.leaderboardOptin).toList();

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
          _lastTeam = team;
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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: DashboardThemedBackground(child: content),
    );
  }

  Widget _buildHeaderWithFilters() {
    Widget metricChip(String label, LeaderboardMetric metric) {
      final selected = _metric == metric;
      return GestureDetector(
        onTap: () => setState(() => _metric = metric),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.activeColor
                : DashboardChrome.cardFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.activeColor : DashboardChrome.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : DashboardChrome.fg,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DashboardChrome.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Team Performers',
                  style:
                      AppTypography.heading2.copyWith(color: DashboardChrome.fg),
                ),
                const SizedBox(height: 4),
                Text(
                  'Switch metrics to compare different dimensions of impact.',
                  style: AppTypography.bodySmall.copyWith(
                    color: DashboardChrome.fg,
                  ),
                ),
              ],
            ),
          ),
          metricChip('Points', LeaderboardMetric.points),
          metricChip('Streaks', LeaderboardMetric.streaks),
          metricChip('Progress', LeaderboardMetric.progress),
        ],
      ),
    );
  }

  Widget _buildPodium(List<EmployeeData> top) {
    // Pad to 3 slots
    final List<EmployeeData?> slots = [
      top.length > 1 ? top[1] : null, // 2nd place left
      top.isNotEmpty ? top[0] : null, // 1st center
      top.length > 2 ? top[2] : null, // 3rd right
    ];

    Widget tile(EmployeeData? e, int rank, double height, Color color) {
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.8),
                    color.withValues(alpha: 0.4),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (e != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DashboardChrome.cardFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: DashboardChrome.border,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: color,
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
                    const SizedBox(height: 6),
                    Text(
                      e.profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: DashboardChrome.fg,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${e.totalPoints} pts',
                          style: TextStyle(
                            color: DashboardChrome.fg,
                            fontSize: 11,
                          ),
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

    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          tile(slots[0], 2, 70, const Color(0xFFC0C0C0)),
          const SizedBox(width: 8),
          tile(slots[1], 1, 90, const Color(0xFFFFD700)),
          const SizedBox(width: 8),
          tile(slots[2], 3, 50, const Color(0xFFCD7F32)),
        ],
      ),
    );
  }

  Widget _buildListItem(EmployeeData e, {required int rank}) {
    String rightText = '';
    switch (_metric) {
      case LeaderboardMetric.points:
        rightText = '${e.totalPoints} pts';
        break;
      case LeaderboardMetric.streaks:
        rightText = '${e.streakDays} day streak';
        break;
      case LeaderboardMetric.progress:
        rightText = '${e.avgProgress.toStringAsFixed(1)}%';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardChrome.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: DashboardChrome.cardFill,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: DashboardChrome.border),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: DashboardChrome.fg,
                  fontWeight: FontWeight.bold,
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
                  style: TextStyle(
                    color: DashboardChrome.fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  e.profile.department,
                  style: TextStyle(color: DashboardChrome.fg, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            rightText,
            style: TextStyle(
              color: DashboardChrome.fg,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
