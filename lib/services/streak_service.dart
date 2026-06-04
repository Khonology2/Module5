import 'dart:async';
import 'dart:developer' as developer;

import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/services/badge_service.dart';
import 'package:pdh/utils/backend_polling_stream.dart';

class StreakService {
  static final BackendAuthService _backend = BackendAuthService.instance;
  static final Map<String, List<StreamSubscription<dynamic>>> _subsByUser = {};
  static final Map<String, Timer> _midnightTimerByUser = {};
  static final Map<String, bool> _cancelledByUser = {};

  static DateTime? _parseActivityDate(Map<String, dynamic> data) {
    final dateValue = data['date'];
    if (dateValue is DateTime) return dateValue;
    if (dateValue != null) {
      final parsed = DateTime.tryParse(dateValue.toString());
      if (parsed != null) return parsed;
    }
    final id = data['id']?.toString() ?? data['dateKey']?.toString() ?? '';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(id)) {
      return DateTime.tryParse(id);
    }
    return null;
  }

  static bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static List<Map<String, dynamic>> _sortedDailyActivities(
    List<Map<String, dynamic>> items,
  ) {
    final sorted = List<Map<String, dynamic>>.from(items);
    sorted.sort((a, b) {
      final aDate = _parseActivityDate(a);
      final bDate = _parseActivityDate(b);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  static Future<void> recordDailyActivity(
    String userId,
    String activityType,
  ) async {
    try {
      final today = DateTime.now();
      final todayString = _dateKey(today);

      try {
        await _backend.patchUserStreak(userId, {
          'lastLoginAt': today.toIso8601String(),
        });
      } catch (_) {}

      await _backend.createActivity(userId, {
        'userId': userId,
        'type': activityType,
        'timestamp': today.toIso8601String(),
        'description': 'User performed $activityType',
      });

      final existingActivities = await _backend.getDailyActivities(userId);
      Map<String, dynamic>? todayActivity;
      for (final item in existingActivities) {
        if (_isSameDay(_parseActivityDate(item), today)) {
          todayActivity = item;
          break;
        }
      }

      if (todayActivity == null) {
        await _backend.createDailyActivity(userId, {
          'id': todayString,
          'dateKey': todayString,
          'date': today.toIso8601String(),
          'activities': [activityType],
          'createdAt': today.toIso8601String(),
        });
        await _updateStreak(userId);
      } else {
        final activities = List<String>.from(todayActivity['activities'] ?? []);
        if (!activities.contains(activityType)) {
          activities.add(activityType);
          await _backend.patchDailyActivity(
            userId,
            (todayActivity['id'] ?? todayString).toString(),
            {'activities': activities},
          );
        }
      }
    } catch (e) {
      developer.log('Error recording daily activity: $e');
    }
  }

  static Future<void> _updateStreak(String userId) async {
    if (userId.isEmpty) return;
    if (_cancelledByUser[userId] == true) return;

    try {
      final activitiesSnapshot = _sortedDailyActivities(
        await _backend.getDailyActivities(userId, limit: 365),
      );

      if (activitiesSnapshot.isEmpty) return;
      if (_cancelledByUser[userId] == true) return;

      int currentStreak = 0;
      DateTime? lastDate;

      final now = DateTime.now();
      final todayOnly = DateTime(now.year, now.month, now.day);
      final mostRecent = _parseActivityDate(activitiesSnapshot.first);
      final mostRecentOnly = mostRecent == null
          ? null
          : DateTime(mostRecent.year, mostRecent.month, mostRecent.day);
      if (mostRecentOnly == null ||
          !mostRecentOnly.isAtSameMomentAs(todayOnly)) {
        await _backend.patchUserStreak(userId, {'currentStreak': 0});
        return;
      }

      for (final doc in activitiesSnapshot) {
        final activityDate = _parseActivityDate(doc);
        if (activityDate == null) continue;
        final activityDateOnly = DateTime(
          activityDate.year,
          activityDate.month,
          activityDate.day,
        );

        if (lastDate == null) {
          lastDate = activityDateOnly;
          currentStreak = 1;
        } else {
          final expectedDate = lastDate.subtract(const Duration(days: 1));
          if (activityDateOnly.isAtSameMomentAs(expectedDate)) {
            currentStreak++;
            lastDate = activityDateOnly;
          } else {
            break;
          }
        }
      }

      if (_cancelledByUser[userId] == true) return;

      Map<String, dynamic> userData;
      try {
        userData = await _backend.getUser(userId);
      } catch (_) {
        return;
      }

      if (_cancelledByUser[userId] == true) return;

      final previousStreak = (userData['currentStreak'] ?? 0) is int
          ? userData['currentStreak'] as int
          : int.tryParse(userData['currentStreak']?.toString() ?? '0') ?? 0;
      final longestStreak = (userData['longestStreak'] ?? 0) is int
          ? userData['longestStreak'] as int
          : int.tryParse(userData['longestStreak']?.toString() ?? '0') ?? 0;

      try {
        await _backend.patchUserStreak(userId, {
          'currentStreak': currentStreak,
          'longestStreak': currentStreak > longestStreak
              ? currentStreak
              : longestStreak,
        });
      } catch (e) {
        if (!(_cancelledByUser[userId] == true)) {
          developer.log('Error updating streak via backend: $e');
        }
        return;
      }

      if (currentStreak > previousStreak) {
        await _checkStreakMilestones(userId, currentStreak);
      }
    } catch (e) {
      developer.log('Error updating streak: $e');
    }
  }

  static void startRealtimeTracking(String userId) {
    if (userId.isEmpty) return;
    if (_subsByUser.containsKey(userId)) return;

    _cancelledByUser[userId] = false;

    final activitiesSub = createManagedPollingStream<List<Map<String, dynamic>>>(
      fetch: () => _backend.getDailyActivities(userId, limit: 1),
      initialValue: const [],
    ).listen(
      (_) {
        if (!(_cancelledByUser[userId] ?? false)) {
          _updateStreak(userId).catchError((e) {
            developer.log('Error updating streak from stream: $e');
          });
        }
      },
      cancelOnError: false,
    );

    _subsByUser[userId] = [activitiesSub];

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
    _updateStreak(userId);
  }

  static void stopRealtimeTracking(String userId) {
    _cancelledByUser[userId] = true;

    final subs = _subsByUser.remove(userId);
    if (subs != null) {
      for (final s in subs) {
        try {
          s.cancel();
        } catch (e) {
          developer.log('Error cancelling streak subscription: $e');
        }
      }
    }
    _midnightTimerByUser[userId]?.cancel();
    _midnightTimerByUser.remove(userId);
    _cancelledByUser.remove(userId);
  }

  static Future<void> _checkStreakMilestones(String userId, int streak) async {
    final milestones = [3, 7, 14, 30, 60, 100, 365];

    for (final milestone in milestones) {
      if (streak == milestone) {
        await AlertService.createStreakAlert(
          userId: userId,
          streakDays: streak,
        );

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

        await BadgeService.checkAndAwardBadgesV2(userId);
        break;
      }
    }
  }

  static Future<int> getCurrentStreak(String userId) async {
    try {
      if (userId.isEmpty) return 0;

      final data = await _backend.getUser(userId);
      final streak = data['currentStreak'];
      if (streak == null) return 0;

      return (streak is int) ? streak : int.tryParse(streak.toString()) ?? 0;
    } catch (e) {
      developer.log('Error getting current streak: $e');
      return 0;
    }
  }

  static Future<int> getLongestStreak(String userId) async {
    try {
      final data = await _backend.getUser(userId);
      final streak = data['longestStreak'];
      if (streak == null) return 0;
      return (streak is int) ? streak : int.tryParse(streak.toString()) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<bool> hasActivityToday(String userId) async {
    try {
      if (userId.isEmpty) return false;

      final today = DateTime.now();
      final activities = await _backend.getDailyActivities(userId, limit: 30);
      return activities.any((item) => _isSameDay(_parseActivityDate(item), today));
    } catch (e) {
      developer.log('Error checking today\'s activity: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getActivityHistory(
    String userId, {
    int days = 30,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      final snapshot = await _backend.getDailyActivities(userId, limit: days + 30);
      return snapshot
          .map((doc) {
            final date = _parseActivityDate(doc);
            if (date == null) return null;
            if (date.isBefore(startDate) || date.isAfter(endDate)) return null;
            return {
              'date': date,
              'activities': List<String>.from(doc['activities'] ?? []),
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    } catch (e) {
      return [];
    }
  }
}
