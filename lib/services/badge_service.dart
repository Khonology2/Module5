import 'dart:developer' as developer;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/models/badge.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/services/streak_service.dart';

class BadgeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===== Real-time tracking =====
  static final Map<String, List<StreamSubscription>> _trackingSubsByUser = {};
  static final Map<String, DateTime> _lastCheckAtByUser = {};
  static const Duration _throttleDuration = Duration(seconds: 2);

  /// Start real-time tracking for a user's activity to automatically
  /// evaluate and award badges as they meet criteria.
  static void startRealtimeTracking(String userId) {
    if (userId.isEmpty) return;
    if (_trackingSubsByUser.containsKey(userId)) return; // already tracking

    void maybeCheck() async {
      final now = DateTime.now();
      final last = _lastCheckAtByUser[userId];
      if (last != null && now.difference(last) < _throttleDuration) return;
      _lastCheckAtByUser[userId] = now;
      try {
        await checkAndAwardBadges(userId);
      } catch (e) {
        developer.log('Realtime badge check failed: $e');
      }
    }

    final goalsSub = _firestore
        .collection('goals')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((_) => maybeCheck(), onError: (_) {});

    final userDocSub = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((_) => maybeCheck(), onError: (_) {});

    _trackingSubsByUser[userId] = [goalsSub, userDocSub];

    // Kick off an initial check on start
    maybeCheck();
  }

  /// Stop real-time tracking for a user.
  static void stopRealtimeTracking(String userId) {
    final subs = _trackingSubsByUser.remove(userId);
    if (subs != null) {
      for (final s in subs) {
        try {
          s.cancel();
        } catch (_) {}
      }
    }
    _lastCheckAtByUser.remove(userId);
  }

  // Get all badges for a user with their progress
  static Stream<List<Badge>> getUserBadgesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('badges')
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs.map((doc) => Badge.fromFirestore(doc)).toList()
              ..sort((a, b) {
                // Primary: rarity order Common -> Rare -> Epic -> Legendary
                final rarityOrder = {
                  BadgeRarity.common: 0,
                  BadgeRarity.rare: 1,
                  BadgeRarity.epic: 2,
                  BadgeRarity.legendary: 3,
                };
                final aOrder = rarityOrder[a.rarity] ?? 99;
                final bOrder = rarityOrder[b.rarity] ?? 99;
                if (aOrder != bOrder) return aOrder.compareTo(bOrder);

                // Secondary: earned first within the same rarity
                if (a.isEarned != b.isEarned) return a.isEarned ? -1 : 1;

                // Tertiary: higher progress first
                return b.progressPercentage.compareTo(a.progressPercentage);
              });
          } catch (e) {
            developer.log('Error processing badges: $e');
            return <Badge>[];
          }
        })
        .handleError((error) {
          developer.log('Error loading badges: $error');
          return <Badge>[];
        });
  }

  // Initialize default badges for a user
  static Future<void> initializeUserBadges(String userId) async {
    try {
      final defaultBadges = _getDefaultBadges();
      final batch = _firestore.batch();

      for (final badge in defaultBadges) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('badges')
            .doc(badge.id);
        batch.set(docRef, badge.toFirestore());
      }

      await batch.commit();
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

      // Get user profile and goals
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};
      final currentPoints = (userData['totalPoints'] ?? 0) as int;
      final currentLevel = (userData['level'] ?? 1) as int;

      // Calculate correct level based on points (500 points per level)
      final correctLevel = (currentPoints ~/ 500) + 1;

      // Get user goals
      final goalsSnapshot = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: userId)
          .get();

      List<Goal> goals = goalsSnapshot.docs
          .map((doc) => Goal.fromFirestore(doc))
          .toList();

      // Also check user subcollection
      try {
        final subSnap = await _firestore
            .collection('users')
            .doc(userId)
            .collection('goals')
            .get();
        final subGoals = subSnap.docs
            .map((doc) => Goal.fromFirestore(doc))
            .toList();
        final seen = goals.map((g) => g.id).toSet();
        goals.addAll(subGoals.where((g) => !seen.contains(g.id)));
      } catch (_) {}

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
        await _firestore.collection('users').doc(userId).update({
          'level': correctLevel,
        });
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

      // Badge 2: Goal Finisher (completed any goals)
      if (completedGoals > 0) {
        await _awardRetroactiveBadge(
          userId,
          'goal_finisher',
          'Goal Finisher',
          'Complete your first goal',
          'check_circle',
          BadgeCategory.goals,
          BadgeRarity.common,
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

      // Level-based badges
      if (level >= 5) {
        await _awardRetroactiveBadge(
          userId,
          'level_up_5',
          'Level 5 Achiever',
          'Reach level 5',
          'military_tech',
          BadgeCategory.achievement,
          BadgeRarity.common,
        );
      }
      if (level >= 10) {
        await _awardRetroactiveBadge(
          userId,
          'level_up_10',
          'Level 10 Achiever',
          'Reach level 10',
          'military_tech',
          BadgeCategory.achievement,
          BadgeRarity.epic,
        );
      }
      if (level >= 20) {
        await _awardRetroactiveBadge(
          userId,
          'level_up_20',
          'Level 20 Achiever',
          'Reach level 20',
          'military_tech',
          BadgeCategory.achievement,
          BadgeRarity.legendary,
        );
      }
      if (level >= 30) {
        await _awardRetroactiveBadge(
          userId,
          'level_up_30',
          'Level 30 Achiever',
          'Reach level 30',
          'military_tech',
          BadgeCategory.achievement,
          BadgeRarity.legendary,
        );
      }
      if (level >= 50) {
        await _awardRetroactiveBadge(
          userId,
          'level_up_50',
          'Level 50 Achiever',
          'Reach level 50',
          'military_tech',
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
    } catch (e) {
      developer.log('Error awarding retroactive badges: $e');
    }
  }

  /// Ensure the user's badges subcollection contains all defaults.
  static Future<void> _ensureDefaultBadgesExist(String userId) async {
    try {
      final defaults = _getDefaultBadges();
      final existing = await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .get();

      final existingIds = existing.docs.map((d) => d.id).toSet();
      final missing = defaults.where((b) => !existingIds.contains(b.id)).toList();
      if (missing.isEmpty) return;

      final batch = _firestore.batch();
      for (final badge in missing) {
        final ref = _firestore
            .collection('users')
            .doc(userId)
            .collection('badges')
            .doc(badge.id);
        batch.set(ref, badge.toFirestore());
      }
      await batch.commit();
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
      final badgeDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .doc(badgeId)
          .get();

      if (!badgeDoc.exists) {
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

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('badges')
            .doc(badgeId)
            .set(badge.toFirestore());

        developer.log('Awarded retroactive badge: $name');
      } else {
        // If badge exists but is not earned, mark it as earned
        final data = badgeDoc.data() ?? {};
        final isEarned = (data['isEarned'] ?? false) as bool;
        final progress = (data['progress'] ?? 0) as int;
        final maxProgress = (data['maxProgress'] ?? 1) as int;
        if (!isEarned || progress < maxProgress) {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('badges')
              .doc(badgeId)
              .update({
                'isEarned': true,
                'progress': maxProgress,
                'earnedAt': FieldValue.serverTimestamp(),
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
      // Get user profile and goals
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userProfile = UserProfile.fromFirestore(userDoc);

      final goalsSnapshot = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: userId)
          .get();

      List<Goal> goals = goalsSnapshot.docs
          .map((doc) => Goal.fromFirestore(doc))
          .toList();

      // Also check user subcollection (if app stores goals there)
      try {
        final subSnap = await _firestore
            .collection('users')
            .doc(userId)
            .collection('goals')
            .get();
        final subGoals = subSnap.docs
            .map((doc) => Goal.fromFirestore(doc))
            .toList();
        final seen = goals.map((g) => g.id).toSet();
        goals.addAll(subGoals.where((g) => !seen.contains(g.id)));
      } catch (_) {}

      // Get user badges
      var badgesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .get();
      // If no badges exist (e.g., user predates badges feature), initialize them
      if (badgesSnapshot.docs.isEmpty) {
        await _ensureDefaultBadgesExist(userId);
        badgesSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('badges')
            .get();
      }

      final userBadges = badgesSnapshot.docs
          .map((doc) => Badge.fromFirestore(doc))
          .toList();

      // Check each badge criteria
      for (final badge in userBadges) {
        if (!badge.isEarned) {
          final updatedBadge = await _checkBadgeCriteria(
            badge,
            userProfile,
            goals,
            userId,
          );
          if (updatedBadge.progress != badge.progress ||
              updatedBadge.isEarned != badge.isEarned) {
            await _updateUserBadge(userId, updatedBadge);

            // Create alert if badge was earned
            if (updatedBadge.isEarned && !badge.isEarned) {
              await _createBadgeEarnedAlert(userId, updatedBadge);
              developer.log('Badge earned: ${updatedBadge.name}');
            }
          }
        }
      }

      // Check for level-based badges
      await _checkLevelBasedBadges(userId, userProfile);

      // Check for streak-based badges
      await _checkStreakBasedBadges(userId);

      // Check for points milestone badges
      await _checkPointsMilestoneBadges(userId, userProfile);
    } catch (e) {
      developer.log('Error checking badges: $e');
    }
  }

  // Update a user's badge progress
  static Future<void> _updateUserBadge(String userId, Badge badge) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('badges')
        .doc(badge.id)
        .update(badge.toFirestore());
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
        newProgress = goals.isNotEmpty ? 1 : 0;
        break;

      // Complete 5 goals (progressive)
      case 'goal_completer_5':
        final completed = goals
            .where((g) => g.status == GoalStatus.completed)
            .length;
        newProgress = completed.clamp(0, badge.maxProgress);
        break;

      case 'goal_starter':
        newProgress = goals.length;
        break;

      case 'goal_finisher':
        newProgress = goals
            .where((g) => g.status == GoalStatus.completed)
            .length;
        break;

      // Complete 25 goals (progressive)
      case 'goal_legend_25':
        final completed25 = goals
            .where((g) => g.status == GoalStatus.completed)
            .length;
        newProgress = completed25.clamp(0, badge.maxProgress);
        break;

      case 'streak_master_7':
        // Get current streak from StreakService
        final currentStreak = await StreakService.getCurrentStreak(userId);
        newProgress = currentStreak >= 7 ? 1 : 0;
        break;

      case 'streak_master_30':
        // Get current streak from StreakService
        final currentStreak = await StreakService.getCurrentStreak(userId);
        newProgress = currentStreak >= 30 ? 1 : 0;
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

      case 'level_up_5':
        newProgress = userProfile.level >= 5 ? 1 : 0;
        break;

      case 'level_up_10':
        newProgress = userProfile.level >= 10 ? 1 : 0;
        break;

      case 'level_up_20':
        newProgress = userProfile.level >= 20 ? 1 : 0;
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

      case 'consistency_king':
        // Get longest streak from StreakService
        final longestStreak = await StreakService.getLongestStreak(userId);
        newProgress = longestStreak >= 100 ? 1 : 0;
        break;
    }

    isEarned = newProgress >= badge.maxProgress;

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
        name: 'First Goal',
        description: 'Create your first goal',
        iconName: 'emoji_events',
        category: BadgeCategory.goals,
        rarity: BadgeRarity.common,
        pointsRequired: 0,
        criteria: {'goals_created': 1},
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
        name: 'Goal Enthusiast',
        description: 'Create 5 goals',
        iconName: 'track_changes',
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
        id: 'level_up_5',
        name: 'Level 5 Achiever',
        description: 'Reach level 5',
        iconName: 'military_tech',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.common,
        pointsRequired: 0,
        criteria: {'level': 5},
        maxProgress: 1,
      ),
      Badge(
        id: 'level_up_10',
        name: 'Level 10 Expert',
        description: 'Reach level 10',
        iconName: 'shield',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.epic,
        pointsRequired: 0,
        criteria: {'level': 10},
        maxProgress: 1,
      ),
      Badge(
        id: 'level_up_20',
        name: 'Level 20 Master',
        description: 'Reach level 20',
        iconName: 'trending_up',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.legendary,
        pointsRequired: 0,
        criteria: {'level': 20},
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

  // Get leaderboard data
  static Future<List<Map<String, dynamic>>> getLeaderboard({
    int limit = 10,
    String orderBy = 'totalPoints',
    bool descending = true,
    String? department,
    bool onlyOptedIn = true,
  }) async {
    try {
      Query query = _firestore.collection('users');

      // Add department filter if specified
      if (department != null && department.isNotEmpty) {
        query = query.where('department', isEqualTo: department);
      }

      // Add ordering
      query = query
          .orderBy(orderBy, descending: descending)
          .limit(limit * 2); // Get more to filter

      final snapshot = await query.get();

      // Filter for opted-in users after fetching
      final filteredDocs = onlyOptedIn
          ? snapshot.docs.where((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>?;
                return data != null && data['leaderboardOptin'] == true;
              } catch (e) {
                return false;
              }
            }).toList()
          : snapshot.docs;

      return filteredDocs.take(limit).toList().asMap().entries.map((entry) {
        final index = entry.key;
        final doc = entry.value;
        final data = doc.data() as Map<String, dynamic>;

        // Safely extract badge count
        int badgeCount = 0;
        try {
          final badges = data['badges'];
          if (badges is List) {
            badgeCount = badges.length;
          }
        } catch (e) {
          // Ignore badge count errors
        }

        return {
          'rank': index + 1,
          'userId': doc.id,
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
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userPoints = (userDoc.data()?['totalPoints'] ?? 0) as int;

      final higherRanked = await _firestore
          .collection('users')
          .where('totalPoints', isGreaterThan: userPoints)
          .get();

      return higherRanked.docs.length + 1;
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
      await _firestore.collection('alerts').add({
        'userId': userId,
        'type': 'badge_earned',
        'priority': 'high',
        'title': 'Badge Earned! 🏆',
        'message': 'Congratulations! You earned the "${badge.name}" badge.',
        'actionText': 'View Badge',
        'actionRoute': '/badges_points',
        'createdAt': FieldValue.serverTimestamp(),
        'badgeId': badge.id,
        'badgeRarity': badge.rarity.name,
        'isRead': false,
        'isDismissed': false,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
      });
    } catch (e) {
      developer.log('Error creating badge alert: $e');
    }
  }

  // Check for level-based badges
  static Future<void> _checkLevelBasedBadges(
    String userId,
    UserProfile userProfile,
  ) async {
    final level = userProfile.level;

    // Check if user has level-based badges that should be earned
    final levelBadges = [
      {'level': 5, 'badgeId': 'level_up_5'},
      {'level': 10, 'badgeId': 'level_up_10'},
      {'level': 20, 'badgeId': 'level_up_20'},
      {'level': 30, 'badgeId': 'level_up_30'},
      {'level': 50, 'badgeId': 'level_up_50'},
    ];

    for (final levelBadge in levelBadges) {
      final requiredLevel = levelBadge['level'] as int;
      final badgeId = levelBadge['badgeId'] as String;
      if (level >= requiredLevel) {
        await _awardLevelBadge(userId, badgeId, requiredLevel);
      }
    }
  }

  // Award level badge
  static Future<void> _awardLevelBadge(
    String userId,
    String badgeId,
    int requiredLevel,
  ) async {
    try {
      final badgeDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .doc(badgeId)
          .get();

      if (!badgeDoc.exists) {
        // Create the badge if it doesn't exist
        final badge = Badge(
          id: badgeId,
          name: 'Level $requiredLevel Achiever',
          description: 'Reach level $requiredLevel',
          iconName: 'military_tech',
          category: BadgeCategory.achievement,
          rarity: requiredLevel >= 20
              ? BadgeRarity.legendary
              : requiredLevel >= 10
              ? BadgeRarity.epic
              : BadgeRarity.common,
          pointsRequired: 0,
          criteria: {'level': requiredLevel},
          maxProgress: 1,
          isEarned: true,
          earnedAt: DateTime.now(),
          progress: 1,
        );

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('badges')
            .doc(badgeId)
            .set(badge.toFirestore());

        await _createBadgeEarnedAlert(userId, badge);
      }
    } catch (e) {
      developer.log('Error awarding level badge: $e');
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
      final badgeDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .doc(badgeId)
          .get();

      if (!badgeDoc.exists) {
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

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('badges')
            .doc(badgeId)
            .set(badge.toFirestore());

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
      final badgeDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .doc(badgeId)
          .get();

      if (!badgeDoc.exists) {
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

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('badges')
            .doc(badgeId)
            .set(badge.toFirestore());

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
      final badgesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .get();

      final badges = badgesSnapshot.docs
          .map((doc) => Badge.fromFirestore(doc))
          .toList();

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
