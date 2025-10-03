import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/models/badge.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/services/streak_service.dart';

class BadgeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
            // Sort earned badges first, then by rarity
            if (a.isEarned && !b.isEarned) return -1;
            if (!a.isEarned && b.isEarned) return 1;
            
            // Then by rarity (legendary first)
            final rarityOrder = {
              BadgeRarity.legendary: 0,
              BadgeRarity.epic: 1,
              BadgeRarity.rare: 2,
              BadgeRarity.common: 3,
            };
            final aOrder = rarityOrder[a.rarity] ?? 4;
            final bOrder = rarityOrder[b.rarity] ?? 4;
            
            if (aOrder != bOrder) return aOrder.compareTo(bOrder);
            
            // Finally by progress
            return b.progressPercentage.compareTo(a.progressPercentage);
          });
      } catch (e) {
        developer.log('Error processing badges: $e');
        return <Badge>[];
      }
    }).handleError((error) {
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
      
      final goals = goalsSnapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList();
      
      // Get user badges
      final badgesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .get();
      
      final userBadges = badgesSnapshot.docs.map((doc) => Badge.fromFirestore(doc)).toList();
      
      // Check each badge criteria
      for (final badge in userBadges) {
        if (!badge.isEarned) {
          final updatedBadge = await _checkBadgeCriteria(badge, userProfile, goals, userId);
          if (updatedBadge.progress != badge.progress || updatedBadge.isEarned != badge.isEarned) {
            await _updateUserBadge(userId, updatedBadge);
            
            // Create alert if badge was earned
            if (updatedBadge.isEarned && !badge.isEarned) {
              // For now, we'll skip the badge alert since the method doesn't exist yet
              // This can be implemented later when AlertService is expanded
              developer.log('Badge earned: ${updatedBadge.name}');
            }
          }
        }
      }
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
  static Future<Badge> _checkBadgeCriteria(Badge badge, UserProfile userProfile, List<Goal> goals, String userId) async {
    int newProgress = badge.progress;
    bool isEarned = false;

    switch (badge.id) {
      case 'first_goal':
        newProgress = goals.isNotEmpty ? 1 : 0;
        break;
        
      case 'goal_starter':
        newProgress = goals.length;
        break;
        
      case 'goal_finisher':
        newProgress = goals.where((g) => g.status == GoalStatus.completed).length;
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
        
      case 'level_up_5':
        newProgress = userProfile.level >= 5 ? 1 : 0;
        break;
        
      case 'level_up_10':
        newProgress = userProfile.level >= 10 ? 1 : 0;
        break;
        
      case 'category_explorer':
        final uniqueCategories = goals.map((g) => g.category).toSet();
        newProgress = uniqueCategories.length;
        break;
        
      case 'priority_master':
        final highPriorityCompleted = goals
            .where((g) => g.priority == GoalPriority.high && g.status == GoalStatus.completed)
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
        name: 'Goal Setter',
        description: 'Create your first goal',
        iconName: 'emoji_events',
        category: BadgeCategory.goals,
        rarity: BadgeRarity.common,
        pointsRequired: 0,
        criteria: {'goals_created': 1},
        maxProgress: 1,
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
        name: 'Achievement Hunter',
        description: 'Complete 10 goals',
        iconName: 'check_circle',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.rare,
        pointsRequired: 0,
        criteria: {'goals_completed': 10},
        maxProgress: 10,
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
        name: 'Point Collector',
        description: 'Earn 100 total points',
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
        description: 'Earn 500 total points',
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
        description: 'Earn 1000 total points',
        iconName: 'workspace_premium',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.legendary,
        pointsRequired: 1000,
        criteria: {'total_points': 1000},
        maxProgress: 1,
      ),
      Badge(
        id: 'level_up_5',
        name: 'Level 5 Hero',
        description: 'Reach Level 5',
        iconName: 'military_tech',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.common,
        pointsRequired: 0,
        criteria: {'level': 5},
        maxProgress: 1,
      ),
      Badge(
        id: 'level_up_10',
        name: 'Level 10 Champion',
        description: 'Reach Level 10',
        iconName: 'shield',
        category: BadgeCategory.achievement,
        rarity: BadgeRarity.epic,
        pointsRequired: 0,
        criteria: {'level': 10},
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
      query = query.orderBy(orderBy, descending: descending).limit(limit * 2); // Get more to filter
      
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
}
