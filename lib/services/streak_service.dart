import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
<<<<<<< HEAD
=======
import 'dart:async';
>>>>>>> origin/lihle-manager
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/badge_service.dart';

class StreakService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
<<<<<<< HEAD
=======
  static final Map<String, List<StreamSubscription>> _subsByUser = {};
  static final Map<String, Timer> _midnightTimerByUser = {};
>>>>>>> origin/lihle-manager

  // Record daily activity (goal progress, completion, etc.)
  static Future<void> recordDailyActivity(
    String userId,
    String activityType,
  ) async {
    try {
      final today = DateTime.now();
      final todayString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Refresh lastLoginAt FIRST so streak calculation considers today as an active day
      try {
        await _firestore.collection('users').doc(userId).set({
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

<<<<<<< HEAD
=======
      // Record in the activities collection for manager visibility
      await _firestore.collection('activities').add({
        'userId': userId,
        'type': activityType,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'User performed $activityType',
      });

>>>>>>> origin/lihle-manager
      // Check if activity already recorded today
      final existingActivity = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_activities')
          .doc(todayString)
          .get();

      if (!existingActivity.exists) {
        // Record today's activity
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('daily_activities')
            .doc(todayString)
            .set({
              'date': Timestamp.fromDate(today),
              'activities': [activityType],
              'createdAt': Timestamp.fromDate(today),
            });

        // Update streak
        await _updateStreak(userId);
      } else {
        // Add activity to existing day
        final activities = List<String>.from(
          existingActivity.data()?['activities'] ?? [],
        );
        if (!activities.contains(activityType)) {
          activities.add(activityType);
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('daily_activities')
              .doc(todayString)
              .update({'activities': activities});
        }
      }
    } catch (e) {
      developer.log('Error recording daily activity: $e');
    }
  }

  static Future<void> _updateStreak(String userId) async {
    try {
      // Get user's daily activities, sorted by date
      final activitiesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_activities')
          .orderBy('date', descending: true)
          .limit(365) // Check last year
          .get();

      if (activitiesSnapshot.docs.isEmpty) return;

      int currentStreak = 0;
      DateTime? lastDate;

      // Require activity recorded today to maintain a streak (timezone-safe)
      final now = DateTime.now();
      final todayOnly = DateTime(now.year, now.month, now.day);
      final mostRecent =
          (activitiesSnapshot.docs.first.data()['date'] as Timestamp).toDate();
      final mostRecentOnly = DateTime(
        mostRecent.year,
        mostRecent.month,
        mostRecent.day,
      );
      if (!mostRecentOnly.isAtSameMomentAs(todayOnly)) {
        await _firestore.collection('users').doc(userId).update({
          'currentStreak': 0,
        });
        return;
      }

      for (final doc in activitiesSnapshot.docs) {
        final activityDate = (doc.data()['date'] as Timestamp).toDate();
        final activityDateOnly = DateTime(
          activityDate.year,
          activityDate.month,
          activityDate.day,
        );

        if (lastDate == null) {
          // First activity (most recent)
          lastDate = activityDateOnly;
          currentStreak = 1;
        } else {
          // Check if this activity is consecutive (previous day)
          final expectedDate = lastDate.subtract(const Duration(days: 1));
          if (activityDateOnly.isAtSameMomentAs(expectedDate)) {
            currentStreak++;
            lastDate = activityDateOnly;
          } else {
            // Streak broken
            break;
          }
        }
      }

      // Update user's streak in profile
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();
      final previousStreak = (userDoc.data()?['currentStreak'] ?? 0) as int;

      await userRef.update({
        'currentStreak': currentStreak,
        'longestStreak': FieldValue.increment(
          currentStreak > (userDoc.data()?['longestStreak'] ?? 0)
              ? currentStreak - (userDoc.data()?['longestStreak'] ?? 0)
              : 0,
        ),
      });

      // Check for streak milestones
      if (currentStreak > previousStreak) {
        await _checkStreakMilestones(userId, currentStreak);
      }
    } catch (e) {
      developer.log('Error updating streak: $e');
    }
  }

<<<<<<< HEAD
=======
  /// Start real-time streak tracking: reacts to activity changes and day rollover
  static void startRealtimeTracking(String userId) {
    if (userId.isEmpty) return;
    if (_subsByUser.containsKey(userId)) return;

    // Listen to most recent daily activity to recompute streak
    final activitiesSub = _firestore
        .collection('users')
        .doc(userId)
        .collection('daily_activities')
        .orderBy('date', descending: true)
        .limit(1)
        .snapshots()
        .listen((_) => _updateStreak(userId), onError: (_) {});

    // Also listen to user doc changes that might affect streak display
    final userDocSub = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((_) {}, onError: (_) {});

    _subsByUser[userId] = [activitiesSub, userDocSub];

    // Schedule a timer at next midnight to recompute streak across day boundary
    void scheduleMidnightTimer() {
      final now = DateTime.now();
      final nextMidnight = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1));
      final duration = nextMidnight.difference(now);
      _midnightTimerByUser[userId]?.cancel();
      _midnightTimerByUser[userId] = Timer(duration, () async {
        await _updateStreak(userId);
        scheduleMidnightTimer();
      });
    }

    scheduleMidnightTimer();

    // Kick initial computation
    _updateStreak(userId);
  }

  /// Stop real-time streak tracking for a user
  static void stopRealtimeTracking(String userId) {
    final subs = _subsByUser.remove(userId);
    if (subs != null) {
      for (final s in subs) {
        try {
          s.cancel();
        } catch (_) {}
      }
    }
    _midnightTimerByUser[userId]?.cancel();
    _midnightTimerByUser.remove(userId);
  }

>>>>>>> origin/lihle-manager
  static Future<void> _checkStreakMilestones(String userId, int streak) async {
    // Award alerts for streak milestones
    final milestones = [3, 7, 14, 30, 60, 100, 365];

    for (final milestone in milestones) {
      if (streak == milestone) {
        await AlertService.createStreakAlert(
          userId: userId,
          streakDays: streak,
        );

        // Award bonus points for major milestones
        int bonusPoints = 0;
        if (streak == 7) {
          bonusPoints = 50;
        } else if (streak == 30) {
          bonusPoints = 100;
        } else if (streak == 100) {
          bonusPoints = 200;
        } else if (streak == 365) {
          bonusPoints = 500;
        }

        if (bonusPoints > 0) {
          await AlertService.createPointsAlert(
            userId: userId,
            pointsEarned: bonusPoints,
            reason: 'reaching $streak-day streak milestone',
          );
        }

        // After alerts and points, update badges progress/awards
        await BadgeService.checkAndAwardBadges(userId);
        break;
      }
    }
  }

  // Get current streak for a user
  static Future<int> getCurrentStreak(String userId) async {
    try {
      if (userId.isEmpty) return 0;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return 0;

      final data = userDoc.data();
      if (data == null) return 0;

      final streak = data['currentStreak'];
      if (streak == null) return 0;

      return (streak is int) ? streak : int.tryParse(streak.toString()) ?? 0;
    } catch (e) {
      developer.log('Error getting current streak: $e');
      return 0;
    }
  }

  // Get longest streak for a user
  static Future<int> getLongestStreak(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return (userDoc.data()?['longestStreak'] ?? 0) as int;
    } catch (e) {
      return 0;
    }
  }

  // Check if user has activity today
  static Future<bool> hasActivityToday(String userId) async {
    try {
      if (userId.isEmpty) return false;

      final today = DateTime.now();
      final todayString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_activities')
          .doc(todayString)
          .get();

      return doc.exists;
    } catch (e) {
      developer.log('Error checking today\'s activity: $e');
      return false;
    }
  }

  // Get activity history for visualization
  static Future<List<Map<String, dynamic>>> getActivityHistory(
    String userId, {
    int days = 30,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_activities')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'date': (data['date'] as Timestamp).toDate(),
          'activities': List<String>.from(data['activities'] ?? []),
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
