import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/models/user_profile.dart';
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

class _ManagerLeaderboardScreenState extends State<ManagerLeaderboardScreen> {
  UserProfile? _manager;
  LeaderboardMetric _metric = LeaderboardMetric.points;
  List<EmployeeData> _lastTeam = const [];

  @override
  void initState() {
    super.initState();
    _redirectIfManagerStandalone();
    _loadManagerProfile();
  }

  

  Widget _buildEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(
          Icons.trending_up_outlined,
          color: AppColors.textSecondary,
        ),
        SizedBox(height: 8),
        Text(
          'No opted-in employees found',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        SizedBox(height: 4),
        Text(
          'Ask your team to enable Leaderboard Participation',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
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

  Future<void> _loadManagerProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      setState(() {
        _manager = UserProfile.fromFirestore(doc);
      });
    } catch (e) {
      developer.log('Error loading manager profile: $e');
    }
  }

  // Removed unused legacy query function to avoid linter warning

  @override
  Widget build(BuildContext context) {
    final String? dept = (_manager == null || _manager!.department.isEmpty)
        ? null
        : _manager!.department;

    final content = StreamBuilder<List<EmployeeData>>(
      stream: ManagerRealtimeService.getTeamDataStream(
        department: dept,
        timeFilter: TimeFilter.month,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.dangerColor,
                ),
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
        final raw = snapshot.data ?? _lastTeam;
        var team = raw.where((e) => e.profile.leaderboardOptin == true).toList();

        // Sort by metric
        team.sort((a, b) {
          switch (_metric) {
            case LeaderboardMetric.points:
              return b.totalPoints.compareTo(a.totalPoints);
            case LeaderboardMetric.streaks:
              return b.streakDays.compareTo(a.streakDays);
            case LeaderboardMetric.progress:
              return b.avgProgress.compareTo(a.avgProgress);
          }
        });

        // Update cache when we have any data
        if (team.isNotEmpty) {
          _lastTeam = team;
        }

        if (team.isEmpty && (snapshot.connectionState == ConnectionState.waiting)) {
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
            padding: const EdgeInsets.all(16),
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
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeaderWithFilters(),
            const SizedBox(height: 16),
            if (top.isNotEmpty) _buildPodium(top),
            const SizedBox(height: 16),
            ...rest.map((e) => _buildListItem(e)),
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
        title: const Text('Manager Leaderboard'),
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

    return Row(
      children: [
        const Expanded(
          child: Text(
            'Top Team Performers',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        metricChip('Points', LeaderboardMetric.points),
        metricChip('Streaks', LeaderboardMetric.streaks),
        metricChip('Progress', LeaderboardMetric.progress),
      ],
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
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
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
                    const SizedBox(height: 4),
                    Text(
                      e.profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${e.totalPoints} pts',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
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

  Widget _buildListItem(EmployeeData e) {
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
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
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
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            rightText,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
