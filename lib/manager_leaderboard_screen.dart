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
  bool _isAllTime = true;
  List<EmployeeData> _lastEmployees = const [];
  late Stream<List<EmployeeData>> _employeeStream;
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
    _reloadLeaderboardSource();
  }

  TimeFilter get _selectedTimeFilter =>
      _isAllTime ? TimeFilter.year : TimeFilter.month;

  void _reloadLeaderboardSource() {
    // Cache stream instance so StreamBuilder doesn't resubscribe every rebuild.
    _employeeStream = ManagerRealtimeService.getTeamDataStream(
      timeFilter: _selectedTimeFilter,
    );
    // On web, prefer one-time fetches to avoid listener instability.
    if (kIsWeb) {
      _employeeFuture = ManagerRealtimeService.getTeamDataStream(
        timeFilter: _selectedTimeFilter,
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
      children: [
        Icon(Icons.trending_up_outlined, color: DashboardChrome.fg),
        const SizedBox(height: 8),
        Text(
          'No employees found',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
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
                        _employeeFuture = ManagerRealtimeService
                            .getTeamDataStream(
                              timeFilter: _selectedTimeFilter,
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
                    Expanded(child: _buildHeader()),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () {
                        setState(() {
                          _employeeFuture = ManagerRealtimeService
                              .getTeamDataStream(
                                timeFilter: _selectedTimeFilter,
                              )
                              .first;
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
                _buildFiltersBar(),
                const SizedBox(height: 12),
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
                  Expanded(child: _buildHeader()),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () {
                      setState(() {
                        _employeeFuture = ManagerRealtimeService
                            .getTeamDataStream(
                              timeFilter: _selectedTimeFilter,
                            )
                            .first;
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
              _buildFiltersBar(),
              const SizedBox(height: 12),
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
              _buildHeader(),
              const SizedBox(height: 16),
              _buildFiltersBar(),
              const SizedBox(height: 12),
              _buildEmptyState(),
            ],
          );
        }

        if (team.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildFiltersBar(),
              const SizedBox(height: 12),
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
            _buildHeader(),
            const SizedBox(height: 16),
            _buildFiltersBar(),
            const SizedBox(height: 12),
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
          'Leaderboard',
          style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: false,
      ),
      body: content,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Leaderboard',
            style: AppTypography.heading2.copyWith(color: Colors.white),
          ),
          Row(
            children: [
              const Icon(Icons.circle, color: AppColors.successColor, size: 10),
              const SizedBox(width: 6),
              Text(
                'Live',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.successColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar() {
    Widget filterChip(String label, bool selected, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.activeColor : AppColors.elevatedBackground,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              filterChip('This month', !_isAllTime, () {
                setState(() {
                  _isAllTime = false;
                  _reloadLeaderboardSource();
                });
              }),
              filterChip('All time', _isAllTime, () {
                setState(() {
                  _isAllTime = true;
                  _reloadLeaderboardSource();
                });
              }),
              filterChip('Points', _metric == LeaderboardMetric.points, () {
                setState(() => _metric = LeaderboardMetric.points);
              }),
              filterChip('Streaks', _metric == LeaderboardMetric.streaks, () {
                setState(() => _metric = LeaderboardMetric.streaks);
              }),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Active filters: ${_isAllTime ? 'allTime' : 'thisMonth'}, ${_metric == LeaderboardMetric.points ? 'points' : 'streaks'}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
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
    final metricText = switch (_metric) {
      LeaderboardMetric.points => '${e.totalPoints} pts',
      LeaderboardMetric.streaks => '${e.streakDays} day streak',
      LeaderboardMetric.progress => '${e.avgProgress.toStringAsFixed(1)}%',
    };

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
