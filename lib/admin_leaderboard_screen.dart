import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/services/manager_realtime_service.dart';

enum LeaderboardMetric { points, streaks, progress }

class AdminLeaderboardScreen extends StatefulWidget {
  final bool embedded;

  const AdminLeaderboardScreen({super.key, this.embedded = false});

  @override
  State<AdminLeaderboardScreen> createState() => _AdminLeaderboardScreenState();
}

class _AdminLeaderboardScreenState extends State<AdminLeaderboardScreen> {
  LeaderboardMetric _metric = LeaderboardMetric.points;
  List<EmployeeData> _lastManagers = const [];
  late final Stream<List<EmployeeData>> _managersStream;

  @override
  void initState() {
    super.initState();
    _managersStream = ManagerRealtimeService.getManagersDataStream(
      timeFilter: TimeFilter.month,
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.trending_up_outlined, color: AppColors.textSecondary),
        const SizedBox(height: 8),
        Text(
          'No managers found',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          'Managers will appear here once they exist in the database with role "manager".',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = StreamBuilder<List<EmployeeData>>(
      stream: _managersStream,
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

        final raw = snapshot.data ?? _lastManagers;
        final managers = raw.where((e) => e.profile.leaderboardOptin).toList();

        managers.sort((a, b) {
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

        if (managers.isNotEmpty) _lastManagers = managers;

        if (managers.isEmpty &&
            snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderWithFilters(),
              const SizedBox(height: 16),
              _buildEmptyState(),
            ],
          );
        }

        if (managers.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
            children: [
              _buildHeaderWithFilters(),
              const SizedBox(height: 16),
              _buildEmptyState(),
            ],
          );
        }

        final top = managers.take(3).toList();
        final rest = managers.skip(3).toList();

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
              final rank = idx + 4;
              return _buildListItem(e, rank: rank);
            }),
          ],
        );
      },
    );

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
              fontSize: 12,
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Managers',
                  style: AppTypography.heading2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Switch metrics to compare different dimensions of impact.',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white70,
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
    final List<EmployeeData?> slots = [
      top.length > 1 ? top[1] : null,
      top.isNotEmpty ? top[0] : null,
      top.length > 2 ? top[2] : null,
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
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
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
                      style: const TextStyle(
                        color: Colors.white,
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
                          style: const TextStyle(
                            color: Colors.white70,
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
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.elevatedBackground,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
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
              ],
            ),
          ),
          Text(
            rightText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
