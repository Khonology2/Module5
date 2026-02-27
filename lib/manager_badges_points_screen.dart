import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/services/manager_badge_evaluator.dart';
import 'package:pdh/services/badge_service.dart';
import 'package:pdh/services/badge_celebration_service.dart';
import 'package:pdh/models/badge.dart' as badge_model;
import 'package:pdh/services/season_service.dart';
import 'package:pdh/services/sound_service.dart';
import 'package:pdh/utils/firestore_safe.dart';
import 'package:pdh/widgets/badge_celebration_dialog.dart';
import 'package:pdh/manager_badges_v2/manager_badge_category_detail_screen.dart';

class ManagerBadgesPointsScreen extends StatefulWidget {
  final bool embedded;

  const ManagerBadgesPointsScreen({super.key, this.embedded = false});

  @override
  State<ManagerBadgesPointsScreen> createState() =>
      _ManagerBadgesPointsScreenState();
}

class _ManagerBadgesPointsScreenState extends State<ManagerBadgesPointsScreen> {
  final _auth = FirebaseAuth.instance;
  bool? _didEval;
  StreamSubscription? _badgesSub;
  bool _badgeCelebrationInFlight = false;
  bool _badgeDialogOpen = false;

  // Weights for manager points calculation (tunable)
  static const int weightApproval = 10; // approve/reject acknowledgements
  static const int weightNudge = 2; // meaningful nudges / check-ins
  static const int weightHighCompletionBonus =
      100; // bonus when team completion high
  static const int weightEngagementBonus = 50; // bonus for engagement threshold

  @override
  void initState() {
    super.initState();
    // Ensure season-earned points/badges are synced into the manager profile before rendering.
    Future.microtask(() => SeasonService.syncCurrentManagerSeasonPoints());
    Future.microtask(() => SeasonService.syncCurrentManagerSeasonBadges());
    Future.microtask(() async {
      final user = _auth.currentUser;
      if (user == null) return;
      await BadgeService.migrateManagerBadgeCategories(user.uid);
    });
    Future.microtask(_startBadgeCelebrationListener);
  }

  @override
  void dispose() {
    try {
      _badgesSub?.cancel();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _startBadgeCelebrationListener() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Initial catch-up (if a badge was earned while away from this screen).
    unawaited(_maybeCelebrateNewManagerBadges(user.uid));

    // Listen for new badge writes while the manager is on this screen.
    try {
      _badgesSub?.cancel();
    } catch (_) {}
    _badgesSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('badges')
        .snapshots()
        .listen((_) {
          unawaited(_maybeCelebrateNewManagerBadges(user.uid));
        });
  }

  Color _rarityColor(badge_model.BadgeRarity rarity) {
    switch (rarity) {
      case badge_model.BadgeRarity.common:
        return AppColors.textSecondary;
      case badge_model.BadgeRarity.rare:
        return AppColors.activeColor;
      case badge_model.BadgeRarity.epic:
        return AppColors.warningColor;
      case badge_model.BadgeRarity.legendary:
        return const Color(0xFFFFD700);
    }
  }

  static Color _categoryAccent(badge_model.BadgeCategory _) =>
      AppColors.activeColor;

  Widget _iconForBadge(String iconName) {
    switch (iconName) {
      case 'verified':
        return const Icon(Icons.verified);
      case 'chat':
        return const Icon(Icons.chat);
      case 'flag':
        return const Icon(Icons.flag);
      case 'bolt':
        return const Icon(Icons.bolt);
      case 'build':
        return const Icon(Icons.build);
      case 'calendar_today':
        return const Icon(Icons.calendar_today);
      case 'groups':
        return const Icon(Icons.groups);
      case 'workspace_premium':
        return const Icon(Icons.workspace_premium);
      case 'emoji_events':
        return const Icon(Icons.emoji_events);
      case 'trophy':
        return const Icon(Icons.emoji_events);
      case 'diversity_3':
        return const Icon(Icons.diversity_3);
      default:
        return const Icon(Icons.emoji_events);
    }
  }

  Future<void> _maybeCelebrateNewManagerBadges(String userId) async {
    if (!mounted) return;
    if (_badgeCelebrationInFlight) return;
    _badgeCelebrationInFlight = true;
    try {
      final badges =
          await BadgeCelebrationService.fetchUncelebratedEarnedBadges(
            userId,
            scope: 'manager',
            includeManagerBadges: true,
            limit: 5,
          );
      if (!mounted) return;
      if (badges.isEmpty) return;

      if (_badgeDialogOpen) return;
      _badgeDialogOpen = true;

      final first = badges.first;
      final moreCount = (badges.length - 1).clamp(0, 99);
      unawaited(SoundService.playChime());

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          Future.delayed(const Duration(seconds: 4), () {
            try {
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            } catch (_) {}
          });

          return BadgeCelebrationDialog(
            title: 'Congratulations!',
            badgeName: first.name,
            badgeDescription: first.description,
            accentColor: _rarityColor(first.rarity),
            badgeIcon: _iconForBadge(first.iconName),
            moreCount: moreCount,
          );
        },
      );

      final upTo = badges
          .map((b) => b.earnedAt!)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      await BadgeCelebrationService.markCelebratedUpTo(
        userId,
        scope: 'manager',
        upTo: upTo,
      );
    } catch (e) {
      developer.log('Manager badge celebration failed: $e');
    } finally {
      _badgeDialogOpen = false;
      _badgeCelebrationInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '',
      showAppBar: false,
      embedded: widget.embedded,
      items: SidebarConfig.getItemsForRole('manager'),
      currentRouteName: '/manager_badges_points',
      onNavigate: (route) {
        // Managers should navigate via the portal so the sidebar remains persistent
        // and moved items (e.g. Review Team) open the correct content.
        if (widget.embedded) return;
        Navigator.pushReplacementNamed(
          context,
          '/manager_portal',
          arguments: {'initialRoute': route},
        );
      },
      onLogout: () async {
        final navigator = Navigator.of(context);
        await AuthService().signOut();
        if (mounted) {
          navigator.pushNamedAndRemoveUntil('/landing', (route) => false);
        }
      },
      content: _buildContent(),
    );
  }

  Widget _buildManagerBadgeCategories(String userId) {
    final categories = <_ManagerCategoryMeta>[
      _ManagerCategoryMeta(
        category: badge_model.BadgeCategory.leadership,
        title: 'Leadership',
        subtitle: 'Coaching, guidance, and leading by example',
        icon: Icons.verified,
      ),
      _ManagerCategoryMeta(
        category: badge_model.BadgeCategory.goals,
        title: 'Goals',
        subtitle: 'Fast approvals and supporting goal progress',
        icon: Icons.flag,
      ),
      _ManagerCategoryMeta(
        category: badge_model.BadgeCategory.collaboration,
        title: 'Collaboration',
        subtitle: '1:1s, feedback, and building team rhythm',
        icon: Icons.groups,
      ),
      _ManagerCategoryMeta(
        category: badge_model.BadgeCategory.innovation,
        title: 'Innovation',
        subtitle: 'Unlock progress through smart replans and improvements',
        icon: Icons.build,
      ),
      _ManagerCategoryMeta(
        category: badge_model.BadgeCategory.community,
        title: 'Community',
        subtitle: 'Engage and re-activate your team consistently',
        icon: Icons.diversity_3,
      ),
      _ManagerCategoryMeta(
        category: badge_model.BadgeCategory.achievement,
        title: 'Achievements',
        subtitle: 'Big milestones across points and seasons',
        icon: Icons.emoji_events,
      ),
    ];

    return StreamBuilder<List<badge_model.Badge>>(
      stream: BadgeService.getUserBadgesStream(userId),
      initialData: const [],
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            ),
          );
        }

        final allBadges = (snapshot.data ?? const <badge_model.Badge>[])
            .where((b) => b.id != 'init')
            .where(BadgeService.isManagerBadge)
            .toList();

        if (allBadges.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  size: 56,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  'No manager badges yet',
                  style: AppTypography.heading4.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Start acknowledging goals and supporting your team to earn badges.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (final meta in categories) ...[
              _buildCategoryCard(
                meta: meta,
                badges: allBadges
                    .where((b) => b.category == meta.category)
                    .toList(),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCategoryCard({
    required _ManagerCategoryMeta meta,
    required List<badge_model.Badge> badges,
  }) {
    final earned = badges.where((b) => b.isEarned).length;
    final total = badges.length;
    final progress = total == 0 ? 0.0 : (earned / total).clamp(0.0, 1.0);
    final accent = _categoryAccent(meta.category);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ManagerBadgeCategoryDetailScreen(
                category: meta.category,
                title: meta.title,
                embedded: widget.embedded,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: accent.withValues(alpha: 0.6)),
                  ),
                  child: Icon(meta.icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta.title,
                        style: AppTypography.heading4.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta.subtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  total == 0 ? '0/0' : '$earned/$total',
                  style: AppTypography.bodySmall.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: accent),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final manager = _auth.currentUser;
    if (manager == null) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Text(
            'Please sign in to view manager badges & points',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/khono_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirestoreSafe.stream(
            FirebaseFirestore.instance
                .collection('users')
                .doc(manager.uid)
                .snapshots(),
          ),
          builder: (context, userSnap) {
            final userData = userSnap.data?.data() ?? {};
            final totalPointsRaw = userData['totalPoints'];
            final totalPoints = totalPointsRaw is int
                ? totalPointsRaw
                : (totalPointsRaw is num
                      ? totalPointsRaw.toInt()
                      : int.tryParse('$totalPointsRaw') ?? 0);

            return StreamBuilder(
              stream: _buildManagerMetricsStream(manager.uid),
              builder: (context, AsyncSnapshot<_ManagerMetrics> snapshot) {
                // Run badge evaluation in background (non-blocking) after first build
                if (_didEval != true) {
                  _didEval = true;
                  // Don't await - let it run in background while UI displays
                  ManagerBadgeEvaluator.evaluate(manager.uid).catchError((e) {
                    developer.log('Error evaluating badges in background: $e');
                  });
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) {
                  return Center(
                    child: Padding(
                      padding: AppSpacing.screenPadding,
                      child: Text(
                        'No data available yet',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ManagerBadgeEvaluator.evaluate(manager.uid);
                    await SeasonService.syncCurrentManagerSeasonPoints();
                    await SeasonService.syncCurrentManagerSeasonBadges();
                    if (mounted) setState(() {});
                  },
                  child: ListView(
                    padding: AppSpacing.screenPadding,
                    children: [
                      _buildPointsCard(totalPoints: totalPoints),
                      const SizedBox(height: AppSpacing.xl),
                      _buildSectionHeader('Your Badges'),
                      _buildManagerBadgeCategories(manager.uid),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        title,
        style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildPointsCard({required int totalPoints}) {
    final points = totalPoints;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$points',
                  style: AppTypography.heading1.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Total Points',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.stars, color: AppColors.textPrimary, size: 40),
        ],
      ),
    );
  }

  // Stream aggregator for manager metrics and points
  Stream<_ManagerMetrics> _buildManagerMetricsStream(String managerId) async* {
    // Team metrics stream (reuses existing service)
    final teamMetrics$ = ManagerRealtimeService.getTeamMetricsStream();

    // Approvals and nudges snapshots (one-time fetch on changes via snapshots)
    final approvalsQuery = FirebaseFirestore.instance
        .collection('goals')
        .where('approvedByUserId', isEqualTo: managerId);

    final nudgesQuery = FirebaseFirestore.instance
        .collection('alerts')
        .where('type', isEqualTo: AlertType.managerNudge.name)
        .where('fromUserId', isEqualTo: managerId);

    // Seasons created by this manager for manager badges
    final seasonsQuery = FirebaseFirestore.instance
        .collection('seasons')
        .where('createdBy', isEqualTo: managerId);

    await for (final tm in teamMetrics$) {
      try {
        final approvalsSnap = await approvalsQuery.get();
        final nudgesSnap = await nudgesQuery.get();
        final seasonsSnap = await seasonsQuery.get();

        final approvalsCount = approvalsSnap.docs.length;
        final nudgesSent = nudgesSnap.docs.length;

        // Compute team outcome metrics
        final goalsCompleted = tm.goalsCompleted;
        final totalEmployees = tm.totalEmployees;
        final teamEngagement = tm.teamEngagement; // 0-100 percentage
        final teamCompletionRate = totalEmployees > 0
            ? (goalsCompleted / (totalEmployees * 5)).clamp(
                0.0,
                1.0,
              ) // assume ~5 goals/person baseline
            : 0.0;

        // Manager badges from seasons (ids stored in season.metrics.managerBadgesEarned)
        final managerBadgeIds = <String>{};
        int seasonsManaged = 0;
        int activeSeasonsTeamPoints = 0;
        int completedTeamChallenges = 0;
        final recentActions = <_RecentManagerAction>[];
        for (final d in seasonsSnap.docs) {
          final data = d.data();
          final metrics = (data['metrics'] ?? {}) as Map<String, dynamic>;
          final list = (metrics['managerBadgesEarned'] ?? []) as List<dynamic>;
          for (final id in list) {
            if (id is String && id.isNotEmpty) managerBadgeIds.add(id);
          }
          seasonsManaged++;
          activeSeasonsTeamPoints += (metrics['totalTeamPoints'] is int)
              ? metrics['totalTeamPoints'] as int
              : (metrics['totalTeamPoints'] is num)
              ? (metrics['totalTeamPoints'] as num).round()
              : 0;
          completedTeamChallenges += (metrics['completedTeamChallenges'] is int)
              ? metrics['completedTeamChallenges'] as int
              : (metrics['completedTeamChallenges'] is num)
              ? (metrics['completedTeamChallenges'] as num).round()
              : 0;
        }

        // Build recent actions: latest 10 nudges and approvals
        final recentNudges = await FirebaseFirestore.instance
            .collection('alerts')
            .where('type', isEqualTo: AlertType.managerNudge.name)
            .where('fromUserId', isEqualTo: managerId)
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get();
        for (final doc in recentNudges.docs) {
          final data = doc.data();
          final createdAt =
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          recentActions.add(
            _RecentManagerAction(
              type: 'nudge',
              title: data['title'] ?? 'Nudge sent',
              timeLabel: _timeAgo(createdAt),
            ),
          );
        }
        final recentApprovals = await FirebaseFirestore.instance
            .collection('goals')
            .where('approvedByUserId', isEqualTo: managerId)
            .orderBy('lastUpdated', descending: true)
            .limit(10)
            .get();
        for (final doc in recentApprovals.docs) {
          final data = doc.data();
          final updatedAt =
              (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now();
          final title = data['title'] ?? 'Goal approval';
          recentActions.add(
            _RecentManagerAction(
              type: 'approval',
              title: 'Acknowledged: $title',
              timeLabel: _timeAgo(updatedAt),
            ),
          );
        }

        // Points calculation
        int points = 0;
        points += approvalsCount * weightApproval;
        points += nudgesSent * weightNudge;
        if (teamCompletionRate >= 0.6) {
          points += weightHighCompletionBonus; // reward high completion
        }
        if (teamEngagement >= 70) {
          points += weightEngagementBonus; // reward engagement
        }

        yield _ManagerMetrics(
          approvalsCount: approvalsCount,
          nudgesSent: nudgesSent,
          teamCompletionRate: teamCompletionRate,
          teamEngagement: teamEngagement,
          totalEmployees: tm.totalEmployees,
          goalsCompleted: tm.goalsCompleted,
          avgTeamProgress: tm.avgTeamProgress,
          totalPoints: points,
          managerSeasonBadges: managerBadgeIds.toList()..sort(),
          seasonsManaged: seasonsManaged,
          activeSeasonsTeamPoints: activeSeasonsTeamPoints,
          completedTeamChallenges: completedTeamChallenges,
          recentActions: recentActions.take(10).toList(),
        );
      } catch (e) {
        developer.log('Manager metrics calc error: $e');
        yield _ManagerMetrics.empty();
      }
    }
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '${weeks}w ago';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '${months}mo ago';
    final years = (diff.inDays / 365).floor();
    return '${years}y ago';
  }
}

class _ManagerMetrics {
  final int approvalsCount;
  final int nudgesSent;
  final double teamCompletionRate; // 0..1
  final double teamEngagement; // percentage 0..100
  final int totalEmployees;
  final int goalsCompleted;
  final double avgTeamProgress;
  final int totalPoints;
  final List<String> managerSeasonBadges;
  final int seasonsManaged;
  final int activeSeasonsTeamPoints;
  final int completedTeamChallenges;
  final List<_RecentManagerAction> recentActions;

  const _ManagerMetrics({
    required this.approvalsCount,
    required this.nudgesSent,
    required this.teamCompletionRate,
    required this.teamEngagement,
    required this.totalEmployees,
    required this.goalsCompleted,
    required this.avgTeamProgress,
    required this.totalPoints,
    required this.managerSeasonBadges,
    required this.seasonsManaged,
    required this.activeSeasonsTeamPoints,
    required this.completedTeamChallenges,
    required this.recentActions,
  });

  factory _ManagerMetrics.empty() => const _ManagerMetrics(
    approvalsCount: 0,
    nudgesSent: 0,
    teamCompletionRate: 0.0,
    teamEngagement: 0.0,
    totalEmployees: 0,
    goalsCompleted: 0,
    avgTeamProgress: 0.0,
    totalPoints: 0,
    managerSeasonBadges: [],
    seasonsManaged: 0,
    activeSeasonsTeamPoints: 0,
    completedTeamChallenges: 0,
    recentActions: [],
  );
}

// ignore: unused_element
class _ManagerBadgeMeta {
  final String name;
  final String desc;
  final String emoji;
  const _ManagerBadgeMeta({
    required this.name,
    required this.desc,
    required this.emoji,
  });
}

// Mirror of SeasonService manager badge IDs

class _RecentManagerAction {
  final String type; // 'nudge' | 'approval'
  final String title;
  final String timeLabel;
  const _RecentManagerAction({
    required this.type,
    required this.title,
    required this.timeLabel,
  });
}

class _ManagerCategoryMeta {
  final badge_model.BadgeCategory category;
  final String title;
  final String subtitle;
  final IconData icon;
  const _ManagerCategoryMeta({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
