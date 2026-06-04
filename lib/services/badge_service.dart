import 'dart:developer' as developer;
import 'dart:async';
import 'package:pdh/badges_v2/badge_v2_definition.dart';
import 'package:pdh/badges_v2/badge_v2_engine.dart';
import 'package:pdh/models/badge.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/services/streak_service.dart';
import 'package:pdh/utils/backend_polling_stream.dart';

class BadgeService {
  static final BackendAuthService _backend = BackendAuthService.instance;
  static const BadgeEngineV2 _engineV2 = BadgeEngineV2();

  static String _badgeIdFromMap(Map<String, dynamic> data) =>
      (data['id'] ?? data['badgeId'] ?? '').toString();

  static Future<List<Badge>> _fetchUserBadges(String userId) async {
    final items = await _backend.getBadges(userId, limit: 500);
    return items
        .map((m) => Badge.fromMap(m, fallbackId: _badgeIdFromMap(m)))
        .toList();
  }

  static Future<List<Goal>> _fetchUserGoals(String userId) async {
    final items = await _backend.getGoals(userId: userId, limit: 500);
    return items
        .where((m) => !_isPlaceholderGoalDoc(m, _badgeIdFromMap(m)))
        .map((m) => Goal.fromMap(m, id: _badgeIdFromMap(m)))
        .toList();
  }

  static Future<UserProfile> _fetchUserProfile(String userId) async {
    final data = await _backend.getUser(userId);
    return UserProfile.fromMap(data, id: userId);
  }

  static Future<void> _upsertUserBadge(String userId, Badge badge) async {
    await _backend.upsertBadge(
      userId,
      badge.id,
      badge.toMap(includeId: false),
    );
  }

  static Future<void> _patchUserBadge(
    String userId,
    String badgeId,
    Map<String, dynamic> payload,
  ) async {
    await _backend.patchBadge(userId, badgeId, payload);
  }

  static List<Badge> _sortBadgesLegacy(List<Badge> list) {
    return list
      ..sort((a, b) {
        final rarityOrder = {
          BadgeRarity.common: 0,
          BadgeRarity.rare: 1,
          BadgeRarity.epic: 2,
          BadgeRarity.legendary: 3,
        };
        final aOrder = rarityOrder[a.rarity] ?? 99;
        final bOrder = rarityOrder[b.rarity] ?? 99;
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        if (a.isEarned != b.isEarned) return a.isEarned ? -1 : 1;
        return b.progressPercentage.compareTo(a.progressPercentage);
      });
  }

  static Future<List<Map<String, dynamic>>> _participantSeasons(
    String userId,
  ) async {
    final seasons = await _backend.getSeasons(limit: 500);
    return seasons
        .where(
          (s) => List<String>.from(s['participantIds'] ?? const [])
              .contains(userId),
        )
        .toList();
  }

  static List<Badge> _sortBadgesV2(List<Badge> list) {
    return list
      ..sort((a, b) {
        if (a.category != b.category) {
          return a.category.name.compareTo(b.category.name);
        }
        if (a.isEarned != b.isEarned) return a.isEarned ? -1 : 1;
        final p = b.progressPercentage.compareTo(a.progressPercentage);
        if (p != 0) return p;
        return a.name.compareTo(b.name);
      });
  }

  static bool isV2BadgeId(String badgeId) =>
      badgeId.toLowerCase().startsWith('v2_');

  // Some user subcollections (like goals) are bootstrapped with an "init" document
  // so the collection exists for security rules. These placeholders should NEVER
  // count toward badge progress or goal totals.
  static bool _isPlaceholderGoalDoc(Map<String, dynamic>? data, String docId) {
    if (docId == 'init') return true;
    final placeholderFlag = data?['placeholder'];
    return placeholderFlag is bool && placeholderFlag;
  }

  static bool _isApprovedManualGoal(Goal goal) {
    return !goal.isSeasonGoal &&
        goal.approvalStatus == GoalApprovalStatus.approved;
  }

  /// Detect manager-only badges so employee views can hide them.
  static bool isManagerBadge(Badge badge) {
    final id = badge.id.toLowerCase();
    if (id.startsWith('mgr_')) return true;

    final criteria = badge.criteria;
    final criteriaId = (criteria['badgeId'] ?? '').toString().toLowerCase();
    if (criteriaId.startsWith('mgr_')) return true;

    if (criteria.containsKey('managerLevel')) return true;
    return false;
  }

  static String? _desiredManagerCategoryForBadgeDoc({
    required String docId,
    required Map<String, dynamic>? data,
  }) {
    final id = docId.toLowerCase();
    final criteria = (data?['criteria'] is Map)
        ? (data?['criteria'] as Map)
        : const {};
    final criteriaBadgeId = (criteria['badgeId'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final source = (criteria['source'] ?? '').toString().trim().toLowerCase();

    final effectiveId = criteriaBadgeId.isNotEmpty ? criteriaBadgeId : id;

    // Season manager badges
    if (source == 'season' ||
        effectiveId.startsWith('season_') ||
        effectiveId.contains('season_guardian') ||
        effectiveId.contains('season_architect') ||
        effectiveId.contains('season_closer') ||
        effectiveId.contains('team_builder') ||
        effectiveId.contains('momentum_maker') ||
        effectiveId.contains('challenge_crusher')) {
      return 'achievement';
    }

    if (!effectiveId.startsWith('mgr_')) return null;

    if (effectiveId.startsWith('mgr_timely_approver')) return 'goals';
    if (effectiveId.startsWith('mgr_meeting_steward')) return 'collaboration';
    if (effectiveId.startsWith('mgr_replan_')) return 'innovation';
    if (effectiveId.startsWith('mgr_nudge_network')) return 'community';

    switch (effectiveId) {
      case 'mgr_active_coach':
        return 'leadership';
      case 'mgr_feedback_champion':
        return 'collaboration';
      case 'mgr_engagement_booster':
        return 'community';
      case 'mgr_growth_enabler':
      case 'mgr_all_star_manager':
      case 'mgr_master_coach':
      case 'mgr_season_leader':
        return 'achievement';
    }

    return 'leadership';
  }

  /// Re-categorize already-existing manager badges in PostgreSQL so they show up
  /// in the new manager category UI.
  ///
  /// Safe to call multiple times (idempotent).
  static Future<void> migrateManagerBadgeCategories(String userId) async {
    if (userId.trim().isEmpty) return;
    try {
      final items = await _backend.getBadges(userId, limit: 500);
      if (items.isEmpty) return;

      var updated = 0;
      for (final data in items) {
        final docId = _badgeIdFromMap(data);
        final desired = _desiredManagerCategoryForBadgeDoc(
          docId: docId,
          data: data,
        );
        if (desired == null) continue;
        final current = (data['category'] ?? '').toString().trim();
        if (current == desired) continue;
        await _patchUserBadge(userId, docId, {'category': desired});
        updated++;
      }

      if (updated > 0) {
        developer.log('Migrated manager badge categories: $updated updates');
      }
    } catch (e) {
      developer.log('Manager badge category migration failed: $e');
    }
  }

  // ===== Real-time tracking (backend polling) =====
  static final Map<String, Timer?> _trackingTimersByUser = {};
  static final Map<String, DateTime> _lastCheckAtByUser = {};
  static const Duration _throttleDuration = Duration(seconds: 2);

  /// Start polling-based tracking for a user's activity to automatically
  /// evaluate and award badges as they meet criteria.
  static void startRealtimeTracking(String userId) {
    if (userId.isEmpty) return;
    if (_trackingTimersByUser.containsKey(userId)) return;

    Future<void> maybeCheck() async {
      final now = DateTime.now();
      final last = _lastCheckAtByUser[userId];
      if (last != null && now.difference(last) < _throttleDuration) return;
      _lastCheckAtByUser[userId] = now;
      try {
        await checkAndAwardBadgesV2(userId);
      } catch (e) {
        developer.log('Realtime badge check failed: $e');
      }
    }

    _trackingTimersByUser[userId]?.cancel();
    _trackingTimersByUser[userId] = Timer.periodic(
      const Duration(seconds: 5),
      (_) => maybeCheck(),
    );
    maybeCheck();
  }

  /// Stop real-time tracking for a user.
  static void stopRealtimeTracking(String userId) {
    _trackingTimersByUser.remove(userId)?.cancel();
    _lastCheckAtByUser.remove(userId);
  }

  // Get all badges for a user with their progress
  static Stream<List<Badge>> getUserBadgesStream(String userId) {
    return backendPollingStream<List<Badge>>(
      fetch: () async => _sortBadgesLegacy(await _fetchUserBadges(userId)),
      onError: (error, stackTrace) {
        developer.log('Error loading badges stream: $error', stackTrace: stackTrace);
      },
    );
  }

  /// V2-only stream: emits only badges that belong to the new category-based design.
  static Stream<List<Badge>> getUserBadgesV2Stream(String userId) {
    return backendPollingStream<List<Badge>>(
      fetch: () async {
        final badges = await _fetchUserBadges(userId);
        return _sortBadgesV2(
          badges.where((b) => isV2BadgeId(b.id)).toList(),
        );
      },
      onError: (error, stackTrace) {
        developer.log('Error loading v2 badges stream: $error', stackTrace: stackTrace);
      },
    );
  }

  static List<BadgeDefinitionV2> _getDefaultBadgeDefinitionsV2() {
    return const [
      // ===== Goal Mastery =====
      BadgeDefinitionV2(
        id: 'v2_goal_starter_1',
        name: 'Goal Starter',
        description: 'Create your first goal',
        iconName: 'emoji_events',
        category: BadgeCategory.goalMastery,
        rarity: BadgeRarity.common,
        rule: BadgeRuleV2(type: BadgeRuleTypeV2.goalsCreated, target: 1),
        sortOrder: 10,
      ),
      BadgeDefinitionV2(
        id: 'v2_goal_builder_5',
        name: 'Goal Builder',
        description: 'Create 5 goals',
        iconName: 'track_changes',
        category: BadgeCategory.goalMastery,
        rarity: BadgeRarity.common,
        rule: BadgeRuleV2(type: BadgeRuleTypeV2.goalsCreated, target: 5),
        sortOrder: 20,
      ),
      BadgeDefinitionV2(
        id: 'v2_goal_finisher_1',
        name: 'First Finish',
        description: 'Complete your first goal',
        iconName: 'check_circle',
        category: BadgeCategory.goalMastery,
        rarity: BadgeRarity.common,
        rule: BadgeRuleV2(type: BadgeRuleTypeV2.goalsCompleted, target: 1),
        sortOrder: 30,
      ),
      BadgeDefinitionV2(
        id: 'v2_goal_master_10',
        name: 'Goal Master',
        description: 'Complete 10 goals',
        iconName: 'workspace_premium',
        category: BadgeCategory.goalMastery,
        rarity: BadgeRarity.rare,
        rule: BadgeRuleV2(type: BadgeRuleTypeV2.goalsCompleted, target: 10),
        sortOrder: 40,
      ),

      // ===== Consistency =====
      BadgeDefinitionV2(
        id: 'v2_streak_starter_3',
        name: 'Streak Starter',
        description: 'Maintain a 3-day streak',
        iconName: 'local_fire_department',
        category: BadgeCategory.consistency,
        rarity: BadgeRarity.common,
        rule: BadgeRuleV2(type: BadgeRuleTypeV2.currentStreakDays, target: 3),
        sortOrder: 110,
      ),
      BadgeDefinitionV2(
        id: 'v2_week_warrior_7',
        name: 'Week Warrior',
        description: 'Maintain a 7-day streak',
        iconName: 'local_fire_department',
        category: BadgeCategory.consistency,
        rarity: BadgeRarity.rare,
        rule: BadgeRuleV2(type: BadgeRuleTypeV2.currentStreakDays, target: 7),
        sortOrder: 120,
      ),
      BadgeDefinitionV2(
        id: 'v2_month_master_30',
        name: 'Month Master',
        description: 'Maintain a 30-day streak',
        iconName: 'local_fire_department',
        category: BadgeCategory.consistency,
        rarity: BadgeRarity.epic,
        rule: BadgeRuleV2(type: BadgeRuleTypeV2.currentStreakDays, target: 30),
        sortOrder: 130,
      ),

      // ===== Growth =====
      BadgeDefinitionV2(
        id: 'v2_growth_points_500',
        name: 'Growth Momentum',
        description: 'Reach 500 total points',
        iconName: 'stars',
        category: BadgeCategory.growth,
        rarity: BadgeRarity.rare,
        rule: BadgeRuleV2(type: BadgeRuleTypeV2.totalPoints, target: 500),
        sortOrder: 210,
      ),

      // ===== Milestones =====
      BadgeDefinitionV2(
        id: 'v2_season_joined_1',
        name: 'Season Starter',
        description: 'Join your first team season',
        iconName: 'group_add',
        category: BadgeCategory.milestones,
        rarity: BadgeRarity.common,
        rule: BadgeRuleV2(type: BadgeRuleTypeV2.seasonsJoined, target: 1),
        sortOrder: 310,
      ),

      // ===== Collaboration =====
      BadgeDefinitionV2(
        id: 'v2_collaborator_3',
        name: 'Collaborator',
        description: 'Engage in 3 collaboration actions',
        iconName: 'handshake',
        category: BadgeCategory.collaboration,
        rarity: BadgeRarity.common,
        rule: BadgeRuleV2(
          type: BadgeRuleTypeV2.collaborationEngagements,
          target: 3,
        ),
        sortOrder: 410,
      ),
    ];
  }

  static Future<void> initializeUserBadgesV2(String userId) async {
    try {
      final defs = _getDefaultBadgeDefinitionsV2();
      final existing = await _fetchUserBadges(userId);
      final existingIds = existing.map((b) => b.id).toSet();

      for (final def in defs) {
        if (existingIds.contains(def.id)) continue;
        await _upsertUserBadge(userId, def.seedBadge());
      }
      await updateUserBadgeSummaryV2(userId);
    } catch (e) {
      developer.log('Error initializing v2 badges: $e');
    }
  }

  static Future<void> checkAndAwardBadgesV2(String userId) async {
    try {
      await initializeUserBadgesV2(userId);

      final userProfile = await _fetchUserProfile(userId);
      final goals = await _fetchUserGoals(userId);
      final manualGoals = goals.where(_isApprovedManualGoal).toList();
      final goalsCreated = manualGoals.length;
      final goalsCompleted = manualGoals
          .where((g) => g.status == GoalStatus.completed)
          .length;

      final currentStreak = await StreakService.getCurrentStreak(userId);

      int seasonsJoined = 0;
      try {
        final seasons = await _backend.getSeasons(limit: 500);
        seasonsJoined = seasons
            .where(
              (s) => List<String>.from(s['participantIds'] ?? const [])
                  .contains(userId),
            )
            .length;
      } catch (_) {}

      // Collaboration engagements are now wired to real events through the badge system
      const collaborationEngagements = 0;

      final stats = BadgeUserStatsV2(
        goalsCreated: goalsCreated,
        goalsCompleted: goalsCompleted,
        currentStreakDays: currentStreak,
        totalPoints: userProfile.totalPoints,
        seasonsJoined: seasonsJoined,
        collaborationEngagements: collaborationEngagements,
      );

      final defs = _getDefaultBadgeDefinitionsV2();
      final existingBadges = await _fetchUserBadges(userId);
      final badgeById = {for (final b in existingBadges) b.id: b};
      for (final def in defs) {
        final current = badgeById[def.id];
        if (current == null) continue;

        final newProgress = _engineV2.progressFor(def.rule, stats);
        final maxProgress = current.maxProgress;
        final nowEarned = newProgress >= maxProgress;

        final wasEarned = current.isEarned;
        final earnedAt = nowEarned
            ? (wasEarned ? current.earnedAt : DateTime.now())
            : null;

        final updated = current.copyWith(
          progress: newProgress,
          isEarned: nowEarned,
          earnedAt: earnedAt,
        );

        if (updated.progress != current.progress ||
            updated.isEarned != current.isEarned) {
          await _upsertUserBadge(userId, updated);

          if (updated.isEarned && !current.isEarned) {
            await _createBadgeEarnedAlert(userId, updated);
          }
        }
      }

      await updateUserBadgeSummaryV2(userId);
    } catch (e) {
      developer.log('Error checking v2 badges: $e');
    }
  }

  static Future<void> updateUserBadgeSummaryV2(String userId) async {
    try {
      final items = await _backend.getBadges(userId, limit: 500);
      final v2Items = items.where((d) => isV2BadgeId(_badgeIdFromMap(d))).toList();
      final earnedBadgeIds = v2Items
          .where((doc) => _isBadgeEarned(doc))
          .map(_badgeIdFromMap)
          .toList();

      await _backend.updateUserProfile(userId, {
        'badgesV2': earnedBadgeIds,
        'badgeV2Summary': {
          'earned': earnedBadgeIds.length,
          'total': v2Items.length,
          'lastSyncedAt': DateTime.now().toIso8601String(),
        },
      });
    } catch (e) {
      developer.log('Error syncing v2 badge summary for $userId: $e');
    }
  }

  // Initialize default badges for a user
  static Future<void> initializeUserBadges(String userId) async {
    try {
      final goals = await _fetchUserGoals(userId);
      final userGoalCount = goals.where((g) => !g.isSeasonGoal).length;
      final defaultBadges = _getDefaultBadges();

      for (final badge in defaultBadges) {
        if (badge.id == 'first_goal' && userGoalCount == 0) {
          await _upsertUserBadge(
            userId,
            badge.copyWith(isEarned: false, progress: 0, earnedAt: null),
          );
          developer.log(
            'Initialized first_goal badge as unearned (user has no goals)',
          );
        } else {
          await _upsertUserBadge(userId, badge);
        }
      }

      try {
        final existing = await _fetchUserBadges(userId);
        final firstGoal = existing.where((b) => b.id == 'first_goal').toList();
        if (firstGoal.isNotEmpty &&
            firstGoal.first.isEarned &&
            userGoalCount == 0) {
          await _patchUserBadge(userId, 'first_goal', {
            'isEarned': false,
            'progress': 0,
            'earnedAt': null,
          });
          developer.log(
            'Post-initialization correction: first_goal badge un-earned (user has no goals)',
          );
        }
      } catch (e) {
        developer.log('Error in post-initialization badge correction: $e');
      }

      await updateUserBadgeSummary(userId);
    } catch (e) {
      developer.log('Error initializing badges: $e');
    }
  }

  // Retroactively award badges and update level based on existing accomplishments
  static Future<void> retroactivelyAwardBadgesAndUpdateLevel(
    String userId,
  ) async {
    try {
      developer.log(
        'Starting retroactive badge and level update for user: $userId',
      );

      final userData = await _backend.getUser(userId);
      final currentPoints = (userData['totalPoints'] ?? 0) as int;
      final currentLevel = (userData['level'] ?? 1) as int;
      final correctLevel = (currentPoints ~/ 500) + 1;
      final goals = await _fetchUserGoals(userId);

      // Count completed goals
      final completedGoals = goals
          .where((g) => g.status == GoalStatus.completed)
          .length;
      final totalGoals = goals.length;

      developer.log(
        'User stats: $currentPoints points, $completedGoals completed goals, $totalGoals total goals',
      );

      // Update level if needed
      if (correctLevel > currentLevel) {
        await _backend.updateUserProfile(userId, {'level': correctLevel});
        developer.log('Updated user level from $currentLevel to $correctLevel');
      }

      // Ensure default badges exist for this user before awarding
      await _ensureDefaultBadgesExist(userId);

      // Award badges based on accomplishments
      await _awardRetroactiveBadges(
        userId,
        currentPoints,
        completedGoals,
        totalGoals,
        correctLevel,
      );

      await updateUserBadgeSummary(userId);

      developer.log('Completed retroactive badge and level update');
    } catch (e) {
      developer.log('Error in retroactive badge and level update: $e');
    }
  }

  // Award badges based on existing accomplishments
  static Future<void> _awardRetroactiveBadges(
    String userId,
    int points,
    int completedGoals,
    int totalGoals,
    int level,
  ) async {
    try {
      // First Goal: Create your first goal
      if (totalGoals > 0) {
        await _awardRetroactiveBadge(
          userId,
          'first_goal',
          'First Goal',
          'Create your first goal',
          'emoji_events',
          BadgeCategory.goals,
          BadgeRarity.common,
        );
      }

      // Goal Enthusiast: Create 5 goals
      if (totalGoals >= 5) {
        await _awardRetroactiveBadge(
          userId,
          'goal_starter',
          'Goal Enthusiast',
          'Create 5 goals',
          'track_changes',
          BadgeCategory.goals,
          BadgeRarity.common,
        );
      }

      // First completion badge: first completed goal
      if (completedGoals > 0) {
        await _awardRetroactiveBadge(
          userId,
          'goal_finisher_1',
          'Goal Finisher',
          'Complete your first goal',
          'check_circle',
          BadgeCategory.goals,
          BadgeRarity.common,
        );
      }

      // 10 completed goals: match defaults for 'goal_finisher'
      if (completedGoals >= 10) {
        await _awardRetroactiveBadge(
          userId,
          'goal_finisher',
          'Goal Master',
          'Complete 10 goals',
          'check_circle',
          BadgeCategory.achievement,
          BadgeRarity.rare,
        );
      }

      // Badge 3: Goal Completer 5 (completed 5+ goals)
      if (completedGoals >= 5) {
        await _awardRetroactiveBadge(
          userId,
          'goal_completer_5',
          'Goal Completer',
          'Complete 5 goals',
          'emoji_events',
          BadgeCategory.goals,
          BadgeRarity.rare,
        );
      }

      // 15 completed goals
      if (completedGoals >= 15) {
        await _awardRetroactiveBadge(
          userId,
          'goal_completer_15',
          'Goal Finisher (15)',
          'Complete 15 goals',
          'emoji_events',
          BadgeCategory.goals,
          BadgeRarity.rare,
        );
      }

      // 50 completed goals
      if (completedGoals >= 50) {
        await _awardRetroactiveBadge(
          userId,
          'goal_completer_50',
          'Epic Goal Completer',
          'Complete 50 goals',
          'emoji_events',
          BadgeCategory.goals,
          BadgeRarity.epic,
        );
      }

      // Badge 5: Point Collector badges based on points
      if (points >= 100) {
        await _awardRetroactiveBadge(
          userId,
          'point_collector_100',
          'First 100 Points',
          'Earn 100 points',
          'stars',
          BadgeCategory.achievement,
          BadgeRarity.common,
        );
      }
      if (points >= 250) {
        await _awardRetroactiveBadge(
          userId,
          'point_collector_250',
          'First 250 Points',
          'Earn 250 points',
          'stars',
          BadgeCategory.achievement,
          BadgeRarity.common,
        );
      }
      if (points >= 500) {
        await _awardRetroactiveBadge(
          userId,
          'point_collector_500',
          'Point Collector',
          'Earn 500 points',
          'star',
          BadgeCategory.achievement,
          BadgeRarity.rare,
        );
      }
      if (points >= 750) {
        await _awardRetroactiveBadge(
          userId,
          'point_collector_750',
          'First 750 Points',
          'Earn 750 points',
          'star',
          BadgeCategory.achievement,
          BadgeRarity.rare,
        );
      }
      if (points >= 1000) {
        await _awardRetroactiveBadge(
          userId,
          'point_collector_1000',
          'Point Collector',
          'Earn 1000 points',
          'star',
          BadgeCategory.achievement,
          BadgeRarity.rare,
        );
      }
      if (points >= 1500) {
        await _awardRetroactiveBadge(
          userId,
          'point_collector_1500',
          'First 1500 Points',
          'Earn 1500 points',
          'star',
          BadgeCategory.achievement,
          BadgeRarity.rare,
        );
      }
      if (points >= 2000) {
        await _awardRetroactiveBadge(
          userId,
          'point_collector_2000',
          'Point Master',
          'Earn 2000 points',
          'workspace_premium',
          BadgeCategory.achievement,
          BadgeRarity.epic,
        );
      }
      if (points >= 3000) {
        await _awardRetroactiveBadge(
          userId,
          'point_collector_3000',
          'First 3000 Points',
          'Earn 3000 points',
          'workspace_premium',
          BadgeCategory.achievement,
          BadgeRarity.epic,
        );
      }
      if (points >= 5000) {
        await _awardRetroactiveBadge(
          userId,
          'point_collector_5000',
          'Point Legend',
          'Earn 5000 points',
          'workspace_premium',
          BadgeCategory.achievement,
          BadgeRarity.legendary,
        );
      }
      if (points >= 10000) {
        await _awardRetroactiveBadge(
          userId,
          'point_collector_10000',
          'Point Legend',
          'Earn 10000 points',
          'workspace_premium',
          BadgeCategory.achievement,
          BadgeRarity.legendary,
        );
      }

      // Goal Legend badge (25+ completed goals)
      if (completedGoals >= 25) {
        await _awardRetroactiveBadge(
          userId,
          'goal_legend_25',
          'Goal Legend',
          'Complete 25 goals',
          'emoji_events',
          BadgeCategory.goals,
          BadgeRarity.legendary,
        );
      }

      // 100 completed goals
      if (completedGoals >= 100) {
        await _awardRetroactiveBadge(
          userId,
          'goal_legend_100',
          'Goal Grandmaster',
          'Complete 100 goals',
          'emoji_events',
          BadgeCategory.goals,
          BadgeRarity.legendary,
        );
      }
    } catch (e) {
      developer.log('Error awarding retroactive badges: $e');
    }
  }

  /// Ensure the user's badges subcollection contains all defaults.
  static Future<void> _ensureDefaultBadgesExist(String userId) async {
    try {
      final defaults = _getDefaultBadges();
      final existing = await _fetchUserBadges(userId);
      final existingIds = existing.map((b) => b.id).toSet();
      final missing = defaults.where((b) => !existingIds.contains(b.id)).toList();
      if (missing.isEmpty) return;

      var userGoalCount = 0;
      if (missing.any((b) => b.id == 'first_goal')) {
        final goals = await _fetchUserGoals(userId);
        userGoalCount = goals.where((g) => !g.isSeasonGoal).length;
      }

      for (final badge in missing) {
        if (badge.id == 'first_goal' && userGoalCount == 0) {
          await _upsertUserBadge(
            userId,
            badge.copyWith(isEarned: false, progress: 0, earnedAt: null),
          );
        } else {
          await _upsertUserBadge(userId, badge);
        }
      }
    } catch (e) {
      developer.log('Error ensuring default badges: $e');
    }
  }

  // Helper method to award a retroactive badge
  static Future<void> _awardRetroactiveBadge(
    String userId,
    String badgeId,
    String name,
    String description,
    String iconName,
    BadgeCategory category,
    BadgeRarity rarity,
  ) async {
    try {
      // Special validation for first_goal badge: verify user actually has goals
      if (badgeId == 'first_goal') {
        final goals = await _fetchUserGoals(userId);
        final totalGoals = goals.where((g) => !g.isSeasonGoal).length;
        if (totalGoals == 0) {
          developer.log('Skipping first_goal badge award: user has no goals');
          final existing = await _fetchUserBadges(userId);
          final firstGoal = existing.where((b) => b.id == badgeId).toList();
          if (firstGoal.isNotEmpty && firstGoal.first.isEarned) {
            await _patchUserBadge(userId, badgeId, {
              'isEarned': false,
              'progress': 0,
              'earnedAt': null,
            });
            developer.log(
              'Corrected first_goal badge: un-earned because user has no goals',
            );
          }
          return;
        }
      }

      final existing = await _fetchUserBadges(userId);
      final prior = existing.where((b) => b.id == badgeId).toList();

      if (prior.isEmpty) {
        final badge = Badge(
          id: badgeId,
          name: name,
          description: description,
          iconName: iconName,
          category: category,
          rarity: rarity,
          pointsRequired: 0,
          criteria: {},
          maxProgress: 1,
          isEarned: true,
          earnedAt: DateTime.now(),
          progress: 1,
        );
        await _upsertUserBadge(userId, badge);
        developer.log('Awarded retroactive badge: $name');
      } else {
        final current = prior.first;
        if (!current.isEarned || current.progress < current.maxProgress) {
          await _patchUserBadge(userId, badgeId, {
            'isEarned': true,
            'progress': current.maxProgress,
            'earnedAt': DateTime.now().toIso8601String(),
            'name': name,
            'description': description,
            'iconName': iconName,
            'category': category.name,
            'rarity': rarity.name,
          });
          developer.log('Updated existing badge to earned: $name');
        }
      }
    } catch (e) {
      developer.log('Error awarding retroactive badge $badgeId: $e');
    }
  }

  // Check and award badges based on user activity
  static Future<void> checkAndAwardBadges(String userId) async {
    try {
      final userProfile = await _fetchUserProfile(userId);
      final goals = await _fetchUserGoals(userId);
      final approvedManualGoals = goals.where(_isApprovedManualGoal).toList();
      final hasUserCreatedGoals = approvedManualGoals.isNotEmpty;

      await _ensureDefaultBadgesExist(userId);

      try {
        final existing = await _fetchUserBadges(userId);
        final firstGoal = existing.where((b) => b.id == 'first_goal').toList();
        if (firstGoal.isNotEmpty &&
            firstGoal.first.isEarned &&
            !hasUserCreatedGoals) {
          await _patchUserBadge(userId, 'first_goal', {
            'isEarned': false,
            'progress': 0,
            'earnedAt': null,
          });
          developer.log(
            'Corrected first_goal badge: user has no goals but badge was marked as earned',
          );
        }
      } catch (e) {
        developer.log('Error validating first_goal badge: $e');
      }

      var userBadges = await _fetchUserBadges(userId);
      try {
        final finisher = userBadges.where((b) => b.id == 'goal_finisher').toList();
        if (finisher.isNotEmpty) {
          final badge = finisher.first;
          final needsUpdate = badge.maxProgress != 10 ||
              badge.name != 'Goal Master' ||
              badge.description != 'Complete 10 goals' ||
              badge.category != BadgeCategory.achievement ||
              badge.rarity != BadgeRarity.rare;
          if (needsUpdate) {
            await _patchUserBadge(userId, 'goal_finisher', {
              'name': 'Goal Master',
              'description': 'Complete 10 goals',
              'iconName': 'check_circle',
              'category': BadgeCategory.achievement.name,
              'rarity': BadgeRarity.rare.name,
              'maxProgress': 10,
            });
            userBadges = await _fetchUserBadges(userId);
          }
        }
      } catch (_) {}

      // Check each badge criteria
      for (final badge in userBadges) {
        // Always check first_goal badge to ensure it's only earned when user has goals
        // For other badges, only check if not already earned
        if (!badge.isEarned || badge.id == 'first_goal') {
          final updatedBadge = await _checkBadgeCriteria(
            badge,
            userProfile,
            approvedManualGoals,
            userId,
          );
          if (updatedBadge.progress != badge.progress ||
              updatedBadge.isEarned != badge.isEarned) {
            await _updateUserBadge(userId, updatedBadge);

            // Create alert if badge was earned (but not if it was un-earned)
            if (updatedBadge.isEarned && !badge.isEarned) {
              await _createBadgeEarnedAlert(userId, updatedBadge);
              developer.log('Badge earned: ${updatedBadge.name}');
            }
          }
        }
      }

      // Check for streak-based badges
      await _checkStreakBasedBadges(userId);

      // Check for points milestone badges
      await _checkPointsMilestoneBadges(userId, userProfile);

      await updateUserBadgeSummary(userId);
    } catch (e) {
      developer.log('Error checking badges: $e');
    }
  }

  // Update a user's badge progress
  static Future<void> _updateUserBadge(String userId, Badge badge) async {
    await _patchUserBadge(userId, badge.id, badge.toMap(includeId: false));
  }

  // Check badge criteria and update progress
  static Future<Badge> _checkBadgeCriteria(
    Badge badge,
    UserProfile userProfile,
    List<Goal> goals,
    String userId,
  ) async {
    int newProgress = badge.progress;
    bool isEarned = false;

    switch (badge.id) {
      case 'first_goal':
        // Only mark progress if user actually has at least one goal
        // This badge should only be earned when the user has created at least one goal
        // CRITICAL: Explicitly check goals count - badge should NEVER be earned if goals list is empty
        final hasUserCreatedGoals = goals.any((g) => !g.isSeasonGoal);
        newProgress = hasUserCreatedGoals ? 1 : 0;
        break;

      // Complete 5 goals (progressive)
      case 'goal_completer_5':
        final completed = goals
            .where((g) => g.status == GoalStatus.completed)
            .length;
        newProgress = completed.clamp(0, badge.maxProgress);
        break;

      case 'goal_completer_15':
        final completed15 = goals
            .where((g) => g.status == GoalStatus.completed)
            .length;
        newProgress = completed15.clamp(0, badge.maxProgress);
        break;

      case 'goal_starter':
        newProgress = goals.length;
        break;

      case 'goal_finisher':
        newProgress = goals
            .where((g) => g.status == GoalStatus.completed)
            .length;
        break;

      case 'goal_completer_50':
        final completed50 = goals
            .where((g) => g.status == GoalStatus.completed)
            .length;
        newProgress = completed50.clamp(0, badge.maxProgress);
        break;

      case 'goal_finisher_1':
        newProgress =
            goals.where((g) => g.status == GoalStatus.completed).isNotEmpty
            ? 1
            : 0;
        break;

      // Complete 25 goals (progressive)
      case 'goal_legend_25':
        final completed25 = goals
            .where((g) => g.status == GoalStatus.completed)
            .length;
        newProgress = completed25.clamp(0, badge.maxProgress);
        break;

      case 'goal_legend_100':
        final completed100 = goals
            .where((g) => g.status == GoalStatus.completed)
            .length;
        newProgress = completed100.clamp(0, badge.maxProgress);
        break;

      // Category-specific completions by count
      case 'cat_work_bronze':
      case 'cat_work_silver':
      case 'cat_work_gold':
        final workCompleted = goals
            .where(
              (g) =>
                  g.status == GoalStatus.completed &&
                  g.category == GoalCategory.work,
            )
            .length;
        final max = (badge.criteria['count'] as int?) ?? badge.maxProgress;
        newProgress = workCompleted.clamp(0, max);
        break;
      case 'cat_financial_bronze':
      case 'cat_financial_silver':
      case 'cat_financial_gold':
        final finCompleted = goals
            .where(
              (g) => g.status == GoalStatus.completed && (g.kpa == 'financial'),
            )
            .length;
        final max = (badge.criteria['count'] as int?) ?? badge.maxProgress;
        newProgress = finCompleted.clamp(0, max);
        break;

      case 'balanced_performer':
        final cats = goals
            .where((g) => g.status == GoalStatus.completed)
            .map((g) => g.category)
            .toSet()
            .length;
        final target = (badge.criteria['uniqueCategories'] as int?) ?? 3;
        newProgress = cats.clamp(0, target);
        break;

      // ===== Growth Levels (Employee) =====
      case 'first_milestone':
        // Approximation: consider having completed at least one milestone as completing any goal
        final completedAny = goals.any((g) => g.status == GoalStatus.completed);
        newProgress = completedAny ? 1 : 0;
        break;

      case 'goal_getter':
        // Complete a full goal
        final completed1 = goals.any((g) => g.status == GoalStatus.completed);
        newProgress = completed1 ? 1 : 0;
        break;

      case 'consistency_streak_4w':
        // 4-week streak (28 days) via StreakService
        final currentStreak = await StreakService.getCurrentStreak(userId);
        newProgress = currentStreak >= 28 ? 1 : 0;
        break;

      case 'evidence_collector_5':
        // Pending: evidence items not yet modeled; leave 0 to show locked until integrated
        newProgress = 0;
        break;

      case 'collaborator_3':
        // Pending: manager review replies/comments not yet modeled; leave 0
        newProgress = 0;
        break;

      case 'goal_master_3q':
        // Approximation: 3+ completed goals (until time-window metadata available)
        final completed = goals
            .where((g) => g.status == GoalStatus.completed)
            .length;
        newProgress = completed.clamp(0, badge.maxProgress);
        break;

      case 'streak_master_7':
        // Get current streak from StreakService
        final currentStreak = await StreakService.getCurrentStreak(userId);
        newProgress = currentStreak >= 7 ? 1 : 0;
        break;

      case 'streak_starter_3':
        final cs3 = await StreakService.getCurrentStreak(userId);
        newProgress = cs3 >= 3 ? 1 : 0;
        break;

      case 'streak_master_30':
        // Get current streak from StreakService
        final currentStreak = await StreakService.getCurrentStreak(userId);
        newProgress = currentStreak >= 30 ? 1 : 0;
        break;

      case 'streak_runner_14':
        final cs14 = await StreakService.getCurrentStreak(userId);
        newProgress = cs14 >= 14 ? 1 : 0;
        break;

      case 'point_collector_100':
        newProgress = userProfile.totalPoints >= 100 ? 1 : 0;
        break;

      case 'point_collector_500':
        newProgress = userProfile.totalPoints >= 500 ? 1 : 0;
        break;

      case 'point_collector_1000':
        newProgress = userProfile.totalPoints >= 1000 ? 1 : 0;
        break;

      case 'point_collector_2000':
        newProgress = userProfile.totalPoints >= 2000 ? 1 : 0;
        break;

      case 'category_explorer':
        final uniqueCategories = goals.map((g) => g.category).toSet();
        newProgress = uniqueCategories.length;
        break;

      case 'priority_master':
        final highPriorityCompleted = goals
            .where(
              (g) =>
                  g.priority == GoalPriority.high &&
                  g.status == GoalStatus.completed,
            )
            .length;
        newProgress = highPriorityCompleted;
        break;

      case 'priority_champion_10':
        final highPriorityCompleted10 = goals
            .where(
              (g) =>
                  g.priority == GoalPriority.high &&
                  g.status == GoalStatus.completed,
            )
            .length;
        newProgress = highPriorityCompleted10.clamp(0, badge.maxProgress);
        break;

      case 'consistency_king':
        // Get longest streak from StreakService
        final longestStreak = await StreakService.getLongestStreak(userId);
        newProgress = longestStreak >= 100 ? 1 : 0;
        break;

      // ===== Season-based badges =====
      // Joined at least 1 season
      case 'season_joined_1':
      case 'season_joined_3':
        try {
          final joined = await _participantSeasons(userId);
          newProgress = joined.length.clamp(0, badge.maxProgress);
        } catch (_) {
          newProgress = 0;
        }
        break;

      case 'season_contributor_500':
      case 'season_contributor_1000':
        try {
          final joined = await _participantSeasons(userId);
          var total = 0;
          for (final data in joined) {
            final participation =
                (data['participations'] ?? {}) as Map<String, dynamic>;
            final me = participation[userId] as Map<String, dynamic>?;
            if (me != null) {
              final points = me['totalPoints'];
              if (points is int) {
                total += points;
              } else if (points is num) {
                total += points.round();
              }
            }
          }
          newProgress = total.clamp(0, badge.maxProgress);
        } catch (_) {
          newProgress = 0;
        }
        break;

      case 'season_finisher_1':
        try {
          final joined = await _participantSeasons(userId);
          final completed = joined
              .where((s) => (s['status'] ?? '').toString() == 'completed');
          newProgress = completed.isNotEmpty ? 1 : 0;
        } catch (_) {
          newProgress = 0;
        }
        break;

      case 'season_finisher_3':
        try {
          final joined = await _participantSeasons(userId);
          final completedCount = joined
              .where((s) => (s['status'] ?? '').toString() == 'completed')
              .length;
          newProgress = completedCount.clamp(0, badge.maxProgress);
        } catch (_) {
          newProgress = 0;
        }
        break;
    }

    isEarned = newProgress >= badge.maxProgress;

    // CRITICAL FINAL CHECK: For first_goal badge, NEVER mark as earned if user has no goals
    // This is a final safeguard to prevent any edge cases
    if (badge.id == 'first_goal' && !goals.any((g) => !g.isSeasonGoal)) {
      isEarned = false;
      newProgress = 0;
    }

    return badge.copyWith(
      progress: newProgress,
      isEarned: isEarned,
      earnedAt: isEarned && !badge.isEarned ? DateTime.now() : badge.earnedAt,
    );
  }

  // Get default badges to initialize for new users
  static List<Badge> _getDefaultBadges() {
    return [
      Badge(
        id: 'first_goal',
        name: 'Goal Starter', // Changed name to 'Goal Starter'
        description: 'Create your first goal',
        iconName: 'emoji_events',
        category: BadgeCategory.goals,
        rarity: BadgeRarity.common,
        pointsRequired: 0,
        criteria: {'goals_created': 1},
        maxProgress: 1,
      ),
      Badge(
        id: 'goal_finisher_1',
        name: 'Goal Finisher',
        description: 'Complete your first goal',
        iconName: 'check_circle',
        category: BadgeCategory.goals,
        rarity: BadgeRarity.common,
        pointsRequired: 0,
        criteria: {'goals_completed': 1},
        maxProgress: 1,
      ),
      Badge(
        id: 'goal_completer_5',
        name: 'Goal Completer',
        description: 'Complete 5 goals',
        iconName: 'check_circle',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.common,
        pointsRequired: 0,
        criteria: {'goals_completed': 5},
        maxProgress: 5,
      ),
      Badge(
        id: 'goal_starter',
        name:
            'Goal Enthusiast', // Kept this as 'Goal Enthusiast' or updated based on clarity
        description: 'Create 5 goals',
        iconName: 'emoji_events', // Already set to emoji_events
        category: BadgeCategory.goals,
        rarity: BadgeRarity.common,
        pointsRequired: 0,
        criteria: {'goals_created': 5},
        maxProgress: 5,
      ),
      Badge(
        id: 'goal_finisher',
        name: 'Goal Master',
        description: 'Complete 10 goals',
        iconName: 'check_circle',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.rare,
        pointsRequired: 0,
        criteria: {'goals_completed': 10},
        maxProgress: 10,
      ),
      Badge(
        id: 'goal_legend_25',
        name: 'Goal Legend',
        description: 'Complete 25 goals',
        iconName: 'check_circle',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.epic,
        pointsRequired: 0,
        criteria: {'goals_completed': 25},
        maxProgress: 25,
      ),
      Badge(
        id: 'streak_master_7',
        name: 'Week Warrior',
        description: 'Maintain a 7-day streak',
        iconName: 'local_fire_department',
        category: BadgeCategory.streak,
        rarity: BadgeRarity.common,
        pointsRequired: 0,
        criteria: {'streak_days': 7},
        maxProgress: 1,
      ),
      Badge(
        id: 'streak_master_30',
        name: 'Month Master',
        description: 'Maintain a 30-day streak',
        iconName: 'local_fire_department',
        category: BadgeCategory.streak,
        rarity: BadgeRarity.epic,
        pointsRequired: 0,
        criteria: {'streak_days': 30},
        maxProgress: 1,
      ),
      // ===== Growth Levels (Employee) =====
      Badge(
        id: 'first_milestone',
        name: 'First Milestone',
        description: 'Complete your first milestone',
        iconName: 'emoji_events',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.common,
        pointsRequired: 0,
        criteria: {'milestones_completed': 1},
        maxProgress: 1,
      ),
      Badge(
        id: 'goal_getter',
        name: 'Goal Getter',
        description: 'Complete a full goal',
        iconName: 'check_circle',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.common,
        pointsRequired: 0,
        criteria: {'goals_completed': 1},
        maxProgress: 1,
      ),
      Badge(
        id: 'consistency_streak_4w',
        name: 'Consistency Streak',
        description: 'Maintain a 4-week streak of progress updates',
        iconName: 'local_fire_department',
        category: BadgeCategory.streak,
        rarity: BadgeRarity.rare,
        pointsRequired: 0,
        criteria: {'streak_days': 28},
        maxProgress: 1,
      ),
      Badge(
        id: 'evidence_collector_5',
        name: 'Evidence Collector',
        description: 'Upload or link 5+ pieces of evidence',
        iconName: 'inventory_2',
        category: BadgeCategory.learning,
        rarity: BadgeRarity.common,
        pointsRequired: 0,
        criteria: {'evidence_items': 5},
        maxProgress: 5,
      ),
      Badge(
        id: 'collaborator_3',
        name: 'Collaborator',
        description: 'Respond to or act on 3+ manager reviews or comments',
        iconName: 'handshake',
        category: BadgeCategory.collaboration,
        rarity: BadgeRarity.common,
        pointsRequired: 0,
        criteria: {'manager_feedback_engagements': 3},
        maxProgress: 3,
      ),
      Badge(
        id: 'goal_master_3q',
        name: 'Goal Master',
        description: 'Complete 3 or more goals within a period',
        iconName: 'workspace_premium',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.epic,
        pointsRequired: 0,
        criteria: {'goals_completed_period': 3},
        maxProgress: 3,
      ),
      Badge(
        id: 'point_collector_100',
        name: 'First 100 Points',
        description: 'Earn your first 100 points',
        iconName: 'stars',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.common,
        pointsRequired: 100,
        criteria: {'total_points': 100},
        maxProgress: 1,
      ),
      Badge(
        id: 'point_collector_500',
        name: 'Point Master',
        description: 'Earn 500 points',
        iconName: 'star',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.rare,
        pointsRequired: 500,
        criteria: {'total_points': 500},
        maxProgress: 1,
      ),
      Badge(
        id: 'point_collector_1000',
        name: 'Point Legend',
        description: 'Earn 1000 points',
        iconName: 'workspace_premium',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.legendary,
        pointsRequired: 1000,
        criteria: {'total_points': 1000},
        maxProgress: 1,
      ),
      // ===== Season-based badges =====
      Badge(
        id: 'season_joined_1',
        name: 'Season Starter',
        description: 'Join your first team season',
        iconName: 'group_add',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.common,
        pointsRequired: 0,
        criteria: {'seasons_joined': 1},
        maxProgress: 1,
      ),
      Badge(
        id: 'season_joined_3',
        name: 'Season Explorer',
        description: 'Join 3 team seasons',
        iconName: 'groups',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.rare,
        pointsRequired: 0,
        criteria: {'seasons_joined': 3},
        maxProgress: 3,
      ),
      Badge(
        id: 'season_contributor_500',
        name: 'Season Contributor',
        description: 'Earn 500 season points across seasons',
        iconName: 'military_tech',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.rare,
        pointsRequired: 0,
        criteria: {'season_points': 500},
        maxProgress: 500,
      ),
      Badge(
        id: 'season_contributor_1000',
        name: 'Season Champion',
        description: 'Earn 1000 season points across seasons',
        iconName: 'workspace_premium',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.epic,
        pointsRequired: 0,
        criteria: {'season_points': 1000},
        maxProgress: 1000,
      ),
      Badge(
        id: 'season_finisher_1',
        name: 'Season Finisher',
        description: 'Complete a team season',
        iconName: 'emoji_events',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.common,
        pointsRequired: 0,
        criteria: {'seasons_completed': 1},
        maxProgress: 1,
      ),
      Badge(
        id: 'season_finisher_3',
        name: 'Season Veteran',
        description: 'Complete 3 team seasons',
        iconName: 'emoji_events',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.epic,
        pointsRequired: 0,
        criteria: {'seasons_completed': 3},
        maxProgress: 3,
      ),
      Badge(
        id: 'point_collector_2000',
        name: 'Point Legend',
        description: 'Earn 2000 points',
        iconName: 'workspace_premium',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.legendary,
        pointsRequired: 2000,
        criteria: {'total_points': 2000},
        maxProgress: 1,
      ),
      Badge(
        id: 'category_explorer',
        name: 'Category Explorer',
        description: 'Create goals in 4 different categories',
        iconName: 'explore',
        category: BadgeCategory.learning,
        rarity: BadgeRarity.rare,
        pointsRequired: 0,
        criteria: {'unique_categories': 4},
        maxProgress: 4,
      ),
      Badge(
        id: 'priority_master',
        name: 'Priority Master',
        description: 'Complete 5 high-priority goals',
        iconName: 'priority_high',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.rare,
        pointsRequired: 0,
        criteria: {'high_priority_completed': 5},
        maxProgress: 5,
      ),
      Badge(
        id: 'consistency_king',
        name: 'Consistency King',
        description: 'Achieve a 100-day longest streak',
        iconName: 'trending_up',
        category: BadgeCategory.streak,
        rarity: BadgeRarity.legendary,
        pointsRequired: 0,
        criteria: {'longest_streak': 100},
        maxProgress: 1,
      ),
    ];
  }

  static Future<void> updateUserBadgeSummary(
    String userId, {
    List<Map<String, dynamic>>? badgeItems,
  }) async {
    try {
      final items = badgeItems ??
          await _backend.getBadges(userId, limit: 500);

      final visibleItems = items
          .where((d) => !_badgeIdFromMap(d).startsWith('level_up_'))
          .toList();

      final earnedBadgeIds = visibleItems
          .where(_isBadgeEarned)
          .map(_badgeIdFromMap)
          .toList();

      await _backend.updateUserProfile(userId, {
        'badges': earnedBadgeIds,
        'earnedBadgesCount': earnedBadgeIds.length,
        'badgeSummary': {
          'earned': earnedBadgeIds.length,
          'total': visibleItems.length,
          'lastSyncedAt': DateTime.now().toIso8601String(),
        },
      });
    } catch (e) {
      developer.log('Error syncing badge summary for $userId: $e');
    }
  }

  static bool _isBadgeEarned(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['isEarned'] == true) return true;
    final progress = data['progress'];
    final maxProgress = data['maxProgress'];
    if (progress is num && maxProgress is num && maxProgress > 0) {
      return progress >= maxProgress;
    }
    return false;
  }

  // Get leaderboard data
  static Future<List<Map<String, dynamic>>> getLeaderboard({
    int limit = 10,
    String orderBy = 'totalPoints',
    bool descending = true,
    String? department,
    bool onlyOptedIn = true,
  }) async {
    try {
      final users = await _backend.listUsers(
        role: 'employee',
        department: department,
        limit: limit * 4,
      );

      Iterable<Map<String, dynamic>> filtered = users.where((data) {
        final role = data['role']?.toString() ?? 'employee';
        if (role != 'employee') return false;
        if (onlyOptedIn) {
          final optIn = data['leaderboardOptin'];
          final legacyOptIn = data['leaderboardParticipation'];
          return optIn == true || legacyOptIn == true;
        }
        return true;
      });

      filtered = filtered.toList()
        ..sort((a, b) {
          final aVal = a[orderBy];
          final bVal = b[orderBy];
          if (aVal is num && bVal is num) {
            return descending ? bVal.compareTo(aVal) : aVal.compareTo(bVal);
          }
          return 0;
        });

      return filtered.take(limit).toList().asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        final userId = (data['id'] ?? data['uid'] ?? '').toString();

        // Safely extract badge count
        int badgeCount = 0;
        try {
          // Prefer v2 badge summary/counts (category-based badge system)
          final badgeV2Summary = data['badgeV2Summary'];
          if (badgeV2Summary is Map<String, dynamic>) {
            final earned = badgeV2Summary['earned'];
            if (earned is num) {
              badgeCount = earned.toInt();
            } else if (earned is String) {
              badgeCount = int.tryParse(earned) ?? 0;
            }
          }
          if (badgeCount == 0) {
            final badgesV2Field = data['badgesV2'];
            if (badgesV2Field is List) {
              badgeCount = badgesV2Field.length;
            } else if (badgesV2Field is num) {
              badgeCount = badgesV2Field.toInt();
            } else if (badgesV2Field is String) {
              badgeCount = int.tryParse(badgesV2Field) ?? 0;
            }
          }

          // Legacy fallback (kept for managers/older data)
          final badgesField = data['badges'];
          if (badgeCount == 0) {
            if (badgesField is List) {
              badgeCount = badgesField.length;
            } else if (badgesField is num) {
              badgeCount = badgesField.toInt();
            }
          }

          if (badgeCount == 0) {
            final earnedBadgesCount = data['earnedBadgesCount'];
            if (earnedBadgesCount is num) {
              badgeCount = earnedBadgesCount.toInt();
            } else {
              final badgeSummary = data['badgeSummary'];
              if (badgeSummary is Map<String, dynamic>) {
                final earned = badgeSummary['earned'];
                if (earned is num) {
                  badgeCount = earned.toInt();
                }
              }
            }
          }
        } catch (_) {
          // Ignore badge count errors
        }

        return {
          'rank': index + 1,
          'userId': userId,
          'name': data['displayName']?.toString() ?? 'Anonymous',
          'points': (data['totalPoints'] is num) ? data['totalPoints'] : 0,
          'level': (data['level'] is num) ? data['level'] : 1,
          'badges': badgeCount,
          'department': data['department']?.toString() ?? 'Unknown',
          'jobTitle': data['jobTitle']?.toString() ?? 'Unknown',
        };
      }).toList();
    } catch (e) {
      developer.log('Error getting leaderboard: $e');

      // Fallback: Return mock data for development
      return _getMockLeaderboardData();
    }
  }

  // Mock data for development and testing
  static List<Map<String, dynamic>> _getMockLeaderboardData() {
    return [
      {
        'rank': 1,
        'userId': 'user1',
        'name': 'Angel Sibanda',
        'points': 1250,
        'level': 3,
        'badges': 8,
        'department': 'Engineering',
        'jobTitle': 'Software Developer',
      },
      {
        'rank': 2,
        'userId': 'user2',
        'name': 'Nathi Radebe',
        'points': 1180,
        'level': 3,
        'badges': 7,
        'department': 'Engineering',
        'jobTitle': 'Senior Developer',
      },
      {
        'rank': 3,
        'userId': 'user3',
        'name': 'Sarah Johnson',
        'points': 950,
        'level': 2,
        'badges': 5,
        'department': 'Design',
        'jobTitle': 'UX Designer',
      },
      {
        'rank': 4,
        'userId': 'user4',
        'name': 'Mike Chen',
        'points': 875,
        'level': 2,
        'badges': 4,
        'department': 'Product',
        'jobTitle': 'Product Manager',
      },
      {
        'rank': 5,
        'userId': 'user5',
        'name': 'Lisa Kumar',
        'points': 720,
        'level': 2,
        'badges': 3,
        'department': 'Marketing',
        'jobTitle': 'Marketing Specialist',
      },
    ];
  }

  // Get user's rank
  static Future<int> getUserRank(String userId) async {
    try {
      final userData = await _backend.getUser(userId);
      final userPoints = (userData['totalPoints'] ?? 0) as int;
      final employees = await _backend.listUsers(role: 'employee', limit: 2000);
      final higher = employees.where((u) {
        final pts = u['totalPoints'];
        if (pts is num) return pts > userPoints;
        return false;
      }).length;
      return higher + 1;
    } catch (e) {
      developer.log('Error getting user rank: $e');
      return 0;
    }
  }

  // Create badge earned alert
  static Future<void> _createBadgeEarnedAlert(
    String userId,
    Badge badge,
  ) async {
    try {
      await _backend.createAlert(userId, {
        'userId': userId,
        'type': 'badge_earned',
        'priority': 'high',
        'title': 'Badge Earned! 🏆',
        'message': 'Congratulations! You earned the "${badge.name}" badge.',
        'actionText': 'View Badge',
        'actionRoute': '/badges_points',
        'actionData': {
          'badgeId': badge.id,
          'badgeCategory': badge.category.name,
        },
        'createdAt': DateTime.now().toIso8601String(),
        'badgeId': badge.id,
        'badgeCategory': badge.category.name,
        'badgeRarity': badge.rarity.name,
        'isRead': false,
        'isDismissed': false,
        'expiresAt': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
      });
    } catch (e) {
      developer.log('Error creating badge alert: $e');
    }
  }

  // Check for streak-based badges
  static Future<void> _checkStreakBasedBadges(String userId) async {
    try {
      final currentStreak = await StreakService.getCurrentStreak(userId);
      final longestStreak = await StreakService.getLongestStreak(userId);

      // Check streak milestones
      final streakMilestones = [7, 14, 30, 60, 100, 365];

      for (final milestone in streakMilestones) {
        if (currentStreak >= milestone || longestStreak >= milestone) {
          await _awardStreakBadge(userId, milestone);
        }
      }
    } catch (e) {
      developer.log('Error checking streak badges: $e');
    }
  }

  // Award streak badge
  static Future<void> _awardStreakBadge(String userId, int streakDays) async {
    try {
      final badgeId = 'streak_master_$streakDays';
      final existing = await _fetchUserBadges(userId);
      final hasBadge = existing.any((b) => b.id == badgeId);

      if (!hasBadge) {
        final badge = Badge(
          id: badgeId,
          name: streakDays >= 100
              ? 'Consistency King'
              : streakDays >= 30
              ? 'Month Master'
              : streakDays >= 7
              ? 'Week Warrior'
              : 'Streak Starter',
          description: 'Maintain a $streakDays-day streak',
          iconName: 'local_fire_department',
          category: BadgeCategory.streak,
          rarity: streakDays >= 100
              ? BadgeRarity.legendary
              : streakDays >= 30
              ? BadgeRarity.epic
              : streakDays >= 7
              ? BadgeRarity.rare
              : BadgeRarity.common,
          pointsRequired: 0,
          criteria: {'streak_days': streakDays},
          maxProgress: 1,
          isEarned: true,
          earnedAt: DateTime.now(),
          progress: 1,
        );

        await _upsertUserBadge(userId, badge);
        await _createBadgeEarnedAlert(userId, badge);
      }
    } catch (e) {
      developer.log('Error awarding streak badge: $e');
    }
  }

  // Check for points milestone badges
  static Future<void> _checkPointsMilestoneBadges(
    String userId,
    UserProfile userProfile,
  ) async {
    final points = userProfile.totalPoints;

    // Check points milestones
    final pointsMilestones = [
      100,
      250,
      500,
      750,
      1000,
      1500,
      2000,
      3000,
      5000,
      10000,
    ];

    for (final milestone in pointsMilestones) {
      if (points >= milestone) {
        await _awardPointsBadge(userId, milestone);
      }
    }
  }

  // Award points badge
  static Future<void> _awardPointsBadge(String userId, int points) async {
    try {
      final badgeId = 'point_collector_$points';
      final existing = await _fetchUserBadges(userId);
      final hasBadge = existing.any((b) => b.id == badgeId);

      if (!hasBadge) {
        final badge = Badge(
          id: badgeId,
          name: points >= 5000
              ? 'Point Legend'
              : points >= 2000
              ? 'Point Master'
              : points >= 1000
              ? 'Point Collector'
              : 'First $points Points',
          description: 'Earn $points points',
          iconName: points >= 2000
              ? 'workspace_premium'
              : points >= 1000
              ? 'star'
              : 'stars',
          category: BadgeCategory.achievement,
          rarity: points >= 5000
              ? BadgeRarity.legendary
              : points >= 2000
              ? BadgeRarity.epic
              : points >= 1000
              ? BadgeRarity.rare
              : BadgeRarity.common,
          pointsRequired: points,
          criteria: {'total_points': points},
          maxProgress: 1,
          isEarned: true,
          earnedAt: DateTime.now(),
          progress: 1,
        );

        await _upsertUserBadge(userId, badge);
        await _createBadgeEarnedAlert(userId, badge);
      }
    } catch (e) {
      developer.log('Error awarding points badge: $e');
    }
  }

  // Get achievement summary for user
  static Future<Map<String, dynamic>> getAchievementSummary(
    String userId,
  ) async {
    try {
      final badges = await _fetchUserBadges(userId);

      final earnedBadges = badges.where((b) => b.isEarned).toList();
      final totalBadges = badges.length;
      final earnedByRarity = <String, int>{};

      for (final badge in earnedBadges) {
        final rarity = badge.rarity.name;
        earnedByRarity[rarity] = (earnedByRarity[rarity] ?? 0) + 1;
      }

      return {
        'totalBadges': totalBadges,
        'earnedBadges': earnedBadges.length,
        'completionPercentage': totalBadges > 0
            ? (earnedBadges.length / totalBadges) * 100
            : 0,
        'earnedByRarity': earnedByRarity,
        'recentBadges': earnedBadges
            .where(
              (b) =>
                  b.earnedAt != null &&
                  DateTime.now().difference(b.earnedAt!).inDays <= 7,
            )
            .toList(),
      };
    } catch (e) {
      developer.log('Error getting achievement summary: $e');
      return {
        'totalBadges': 0,
        'earnedBadges': 0,
        'completionPercentage': 0,
        'earnedByRarity': <String, int>{},
        'recentBadges': <Badge>[],
      };
    }
  }
}
