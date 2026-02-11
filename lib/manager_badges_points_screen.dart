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
import 'package:pdh/services/manager_level_service.dart';
import 'package:pdh/services/manager_badge_evaluator.dart';
import 'package:pdh/services/badge_service.dart';
import 'package:pdh/services/badge_celebration_service.dart';
import 'package:pdh/models/badge.dart' as badge_model;
import 'package:pdh/services/season_service.dart';
import 'package:pdh/services/sound_service.dart';
import 'package:pdh/utils/firestore_safe.dart';
import 'package:pdh/widgets/badge_celebration_dialog.dart';

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

    // Baseline on first run (prevents celebrating historical badges).
    await BadgeCelebrationService.ensureBaselineInitialized(
      user.uid,
      scope: 'manager',
    );

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
          final navigator = Navigator.of(dialogContext);
          Future.delayed(const Duration(seconds: 4), () {
            try {
              if (navigator.canPop()) {
                navigator.pop();
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
      content: _buildContent(),
    );
  }

  // Helper method to infer manager level from a badge
  static int? _inferManagerLevel(badge_model.Badge b) {
    final ml = b.criteria['managerLevel'];
    if (ml is int) return ml;
    if (ml is num) return ml.round();

    // Check if it's a season badge
    final source = b.criteria['source'];
    if (source == 'season' || b.id.startsWith('season_')) {
      // Extract the base season badge ID (e.g., 'season_guardian_abc123' -> 'season_guardian')
      final baseId = b.id.split('_').take(2).join('_');
      switch (baseId) {
        case 'season_guardian':
          return 2; // Level 2: Supporting team by extending seasons
        case 'season_architect':
          return 3; // Level 3: Creating growth opportunities
        case 'season_closer':
          return 4; // Level 4: Strategic leadership in completing seasons
        default:
          return 4; // Default season badges to Level 4
      }
    }

    // Fallback based on known manager badge IDs
    switch (b.id) {
      case 'mgr_timely_approver_1':
        return 2;
      case 'mgr_timely_approver_2':
        return 3;
      case 'mgr_meeting_steward_1':
        return 3;
      case 'mgr_meeting_steward_2':
        return 4;
      case 'mgr_replan_closer_2':
        return 4;
      case 'mgr_active_coach':
        return 1;
      case 'mgr_feedback_champion':
      case 'mgr_growth_enabler':
        return 2;
      case 'mgr_all_star_manager':
      case 'mgr_engagement_booster':
      case 'mgr_replan_hero':
        return 3;
      case 'mgr_season_leader':
        return 4;
      case 'mgr_master_coach':
        return 5;
    }
    return null;
  }

  // ===== Manager grouped badges (levels 1-5) =====
  Widget _buildManagerGroupedBadges(_ManagerMetrics m, int totalPoints) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Please sign in to view badges',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    final currentLevel = ManagerLevelService.getInfoForPoints(
      totalPoints,
    ).level;

    return StreamBuilder<List<badge_model.Badge>>(
      stream: BadgeService.getUserBadgesStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            ),
          );
        }

        final allBadges = (snapshot.data ?? <badge_model.Badge>[])
          ..removeWhere((b) => b.id == 'init');

        List<badge_model.Badge> forLevel(int lvl) =>
            allBadges.where((b) {
              final inferred = _inferManagerLevel(b);
              return inferred == lvl;
            }).toList()..sort((a, b) {
              // Sort season badges first, then by name
              final aIsSeason =
                  a.criteria['source'] == 'season' ||
                  a.id.startsWith('season_');
              final bIsSeason =
                  b.criteria['source'] == 'season' ||
                  b.id.startsWith('season_');
              if (aIsSeason != bIsSeason) return aIsSeason ? -1 : 1;
              return a.name.compareTo(b.name);
            });

        return Column(
          children: [
            _buildLevelOvalSection(
              level: 1,
              title: 'Level 1 · Starter Coach',
              subtitle: 'Initial coaching and acknowledgements',
              badges: forLevel(1),
              isActive: currentLevel == 1,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildLevelOvalSection(
              level: 2,
              title: 'Level 2 · Active Coach',
              subtitle: 'Consistent feedback & check-ins',
              badges: forLevel(2),
              isActive: currentLevel == 2,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildLevelOvalSection(
              level: 3,
              title: 'Level 3 · Growth Enabler',
              subtitle: 'Team motivation, replans & engagement',
              badges: forLevel(3),
              isActive: currentLevel == 3,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildLevelOvalSection(
              level: 4,
              title: 'Level 4 · Strategic Mentor',
              subtitle: 'Growth Seasons leadership',
              badges: forLevel(4),
              isActive: currentLevel == 4,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildLevelOvalSection(
              level: 5,
              title: 'Level 5 · Master Coach',
              subtitle: 'Elite mentoring & results',
              badges: forLevel(5),
              isActive: currentLevel >= 5,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLevelOvalSection({
    required int level,
    required String title,
    required String subtitle,
    required List<badge_model.Badge> badges,
    bool isActive = false,
  }) {
    final baseColor = isActive
        ? AppColors.activeColor
        : AppColors.textSecondary;
    final earnedCount = badges.where((b) => b.isEarned).length;
    final total = badges.length;

    final double lift = isActive ? 4 : 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: isActive ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isActive ? 0.25 : 0.15),
            blurRadius: isActive ? 16 : 12,
            offset: Offset(0, 4 - lift),
          ),
        ],
      ),
      transform: Matrix4.translationValues(0, -lift, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: () => _openLevelBadges(level: level, title: title),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: baseColor.withValues(alpha: 0.6)),
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.heading4.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  total == 0 ? '0/0' : '$earnedCount/$total',
                  style: AppTypography.bodySmall.copyWith(
                    color: baseColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: baseColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              total == 0
                  ? 'No badges available in this level'
                  : 'Tap to view all badges in this level',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLevelBadges({required int level, required String title}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        final user = FirebaseAuth.instance.currentUser;
        return FutureBuilder<void>(
          future: () async {
            if (user != null) {
              await ManagerBadgeEvaluator.evaluate(user.uid);
            }
          }(),
          builder: (context, snap) {
            return Dialog(
              backgroundColor: Colors.black.withValues(alpha: 0.85),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxHeight = (MediaQuery.of(ctx).size.height * 0.8)
                      .clamp(360.0, 800.0);
                  return SizedBox(
                    width: 520,
                    height: maxHeight,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Icon(
                                  Icons.workspace_premium,
                                  color: AppColors.activeColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: AppTypography.heading4.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (user == null)
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                  ),
                                  child: Text(
                                    'Please sign in to view badges',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: StreamBuilder<List<badge_model.Badge>>(
                                stream: BadgeService.getUserBadgesStream(
                                  user.uid,
                                ),
                                builder: (context, snapshot) {
                                  final all =
                                      (snapshot.data ??
                                            const <badge_model.Badge>[])
                                        ..removeWhere((b) => b.id == 'init');

                                  final badges =
                                      all.where((b) {
                                        final inferred = _inferManagerLevel(b);
                                        return inferred == level;
                                      }).toList()..sort((a, b) {
                                        // Sort season badges first, then by name
                                        final aIsSeason =
                                            a.criteria['source'] == 'season' ||
                                            a.id.startsWith('season_');
                                        final bIsSeason =
                                            b.criteria['source'] == 'season' ||
                                            b.id.startsWith('season_');
                                        if (aIsSeason != bIsSeason) {
                                          return aIsSeason ? -1 : 1;
                                        }
                                        return a.name.compareTo(b.name);
                                      });

                                  if (snapshot.connectionState ==
                                          ConnectionState.waiting &&
                                      badges.isEmpty) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.activeColor,
                                            ),
                                      ),
                                    );
                                  }

                                  final earnedCount = badges
                                      .where((b) => b.isEarned)
                                      .length;
                                  final total = badges.length;
                                  final progress = total == 0
                                      ? 0.0
                                      : (earnedCount / total).clamp(0.0, 1.0);

                                  return SizedBox.expand(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Progress',
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            minHeight: 6,
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.15),
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                  Color
                                                >(AppColors.activeColor),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '$earnedCount / $total badges',
                                              style: AppTypography.bodySmall
                                                  .copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                            ),
                                            Text(
                                              '${(progress * 100).toStringAsFixed(0)}%',
                                              style: AppTypography.bodySmall
                                                  .copyWith(
                                                    color:
                                                        AppColors.activeColor,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Badges in this level',
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: badges.isEmpty
                                              ? Center(
                                                  child: Text(
                                                    'No badges in this level yet',
                                                    style: AppTypography
                                                        .bodyMedium
                                                        .copyWith(
                                                          color: AppColors
                                                              .textSecondary,
                                                        ),
                                                  ),
                                                )
                                              : ListView.separated(
                                                  itemCount: badges.length,
                                                  separatorBuilder: (_, _) =>
                                                      const SizedBox(height: 8),
                                                  itemBuilder: (context, i) {
                                                    final b = badges[i];
                                                    final earned = b.isEarned;
                                                    return Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: earned
                                                                    ? 0.3
                                                                    : 0.2,
                                                              ),
                                                          width: earned ? 2 : 1,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            width: 40,
                                                            height: 40,
                                                            decoration: BoxDecoration(
                                                              color: Colors
                                                                  .black
                                                                  .withValues(
                                                                    alpha: 0.4,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    20,
                                                                  ),
                                                              border: Border.all(
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.3,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Icon(
                                                              Icons
                                                                  .workspace_premium,
                                                              color: AppColors
                                                                  .activeColor,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  b.name,
                                                                  style: AppTypography
                                                                      .bodyLarge
                                                                      .copyWith(
                                                                        color: AppColors
                                                                            .textPrimary,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                      ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 2,
                                                                ),
                                                                Text(
                                                                  b.description,
                                                                  style: AppTypography
                                                                      .bodySmall
                                                                      .copyWith(
                                                                        color: AppColors
                                                                            .textSecondary,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          if (earned)
                                                            const Icon(
                                                              Icons
                                                                  .check_circle,
                                                              color: AppColors
                                                                  .successColor,
                                                            )
                                                          else
                                                            const Icon(
                                                              Icons
                                                                  .lock_outline,
                                                              color: AppColors
                                                                  .textSecondary,
                                                            ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                        ),
                                        const SizedBox(height: 12),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text(
                                              'Close',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
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

                final m = snapshot.data!;

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
                      _buildPointsCard(m, totalPoints: totalPoints),
                      const SizedBox(height: AppSpacing.xl),
                      _buildSectionHeader('Your Badges'),
                      _buildManagerGroupedBadges(m, totalPoints),
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

  Widget _buildPointsCard(_ManagerMetrics m, {required int totalPoints}) {
    final points = totalPoints;
    final info = ManagerLevelService.getInfoForPoints(points);
    // Determine next level threshold and remaining points
    int? nextThreshold;
    int nextLevel = info.level;
    if (points < 500) {
      nextThreshold = 500; // to Level 2
      nextLevel = 2;
    } else if (points < 1000) {
      nextThreshold = 1000; // to Level 3
      nextLevel = 3;
    } else if (points < 2000) {
      nextThreshold = 2000; // to Level 4
      nextLevel = 4;
    } else if (points < 3500) {
      nextThreshold = 3500; // to Level 5
      nextLevel = 5;
    } else {
      nextThreshold = null; // max level reached
    }
    final remaining = nextThreshold != null
        ? (nextThreshold - points).clamp(0, nextThreshold)
        : 0;
    final progressToNext = nextThreshold != null
        ? (points -
                  (nextLevel == 2
                      ? 0
                      : (nextLevel == 3
                            ? 500
                            : (nextLevel == 4 ? 1000 : 2000)))) /
              (nextThreshold -
                  (nextLevel == 2
                      ? 0
                      : (nextLevel == 3
                            ? 500
                            : (nextLevel == 4 ? 1000 : 2000))))
        : 1.0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.activeColor,
            const Color(0xFF8B0000),
            const Color(0xFF2D1B1B),
            const Color(0xFF1A1A1A),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.activeColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
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
                  const SizedBox(height: 6),
                  if (nextThreshold != null)
                    Text(
                      '$remaining to Level $nextLevel',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Text(
                      'Max level reached',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(info.theme, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        'Level ${info.level}',
                        style: AppTypography.heading4.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    info.title,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress to next level
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressToNext.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            info.description,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.85),
            ),
          ),
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
