import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdh/models/badge.dart';
import 'package:pdh/services/badge_service.dart';

/// Persists "last celebrated badge earnedAt" locally so we can show
/// a one-time celebration popup for newly earned badges.
///
/// Why local?
/// - Avoids re-celebrating on every screen open/rebuild.
/// - Works even if multiple badges are earned while away from the screen.
class BadgeCelebrationService {
  static const String _prefsPrefix = 'badgeCelebration:lastSeenEarnedAt';

  static String _key(String userId, String scope) => '$_prefsPrefix:$scope:$userId';

  static Future<DateTime?> getLastSeenEarnedAt(
    String userId, {
    required String scope,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_key(userId, scope));
      if (ms == null || ms <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    } catch (e) {
      developer.log('getLastSeenEarnedAt failed: $e');
      return null;
    }
  }

  static Future<void> setLastSeenEarnedAt(
    String userId, {
    required String scope,
    required DateTime value,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key(userId, scope), value.toUtc().millisecondsSinceEpoch);
    } catch (e) {
      developer.log('setLastSeenEarnedAt failed: $e');
    }
  }

  /// Initializes the local baseline (no celebration) the first time we run.
  /// This prevents spamming a user with celebrations for historical badges.
  static Future<void> ensureBaselineInitialized(
    String userId, {
    required String scope,
  }) async {
    final existing = await getLastSeenEarnedAt(userId, scope: scope);
    if (existing != null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('badges')
          .where('isEarned', isEqualTo: true)
          .where(
            'earnedAt',
            isGreaterThan: Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
          )
          .orderBy('earnedAt', descending: true)
          .limit(1)
          .get();

      final newestEarnedAt =
          (snap.docs.isNotEmpty ? (snap.docs.first.data()['earnedAt'] as Timestamp?)?.toDate() : null);

      await setLastSeenEarnedAt(
        userId,
        scope: scope,
        value: newestEarnedAt?.toUtc() ?? DateTime.now().toUtc(),
      );
    } catch (e) {
      developer.log('ensureBaselineInitialized failed: $e');
      // Best-effort: still set a baseline to "now".
      await setLastSeenEarnedAt(userId, scope: scope, value: DateTime.now().toUtc());
    }
  }

  static Future<List<Badge>> fetchUncelebratedEarnedBadges(
    String userId, {
    required String scope,
    required bool includeManagerBadges,
    int limit = 3,
  }) async {
    // NOTE:
    // We intentionally do NOT call `ensureBaselineInitialized()` here.
    //
    // Reason: celebrations are meant to trigger when the user opens the
    // Badges/Points screen *after* earning a badge. If the baseline is first
    // initialized on that screen, it may get set to the newest earned badge and
    // accidentally suppress the celebration.
    //
    // If there's no baseline yet, fall back to a reasonable recent window so
    // users still get a celebration for recently earned badges without spamming
    // their entire historical badge set.
    final lastSeen =
        await getLastSeenEarnedAt(userId, scope: scope) ??
        DateTime.now().toUtc().subtract(const Duration(days: 30));

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('badges')
          .where('isEarned', isEqualTo: true)
          .where('earnedAt', isGreaterThan: Timestamp.fromDate(lastSeen.toUtc()))
          .orderBy('earnedAt', descending: false)
          .limit(limit)
          .get();

      final list = snap.docs
          .where((d) => d.id != 'init')
          .map((d) => Badge.fromFirestore(d))
          .where((b) => b.isEarned && b.earnedAt != null)
          .toList();

      final filtered = includeManagerBadges
          ? list
          : list.where((b) => !BadgeService.isManagerBadge(b)).toList();

      return filtered;
    } catch (e) {
      developer.log('fetchUncelebratedEarnedBadges failed: $e');
      return <Badge>[];
    }
  }

  static Future<void> markCelebratedUpTo(
    String userId, {
    required String scope,
    required DateTime upTo,
  }) async {
    final current = await getLastSeenEarnedAt(userId, scope: scope);
    if (current != null && !upTo.isAfter(current)) return;
    await setLastSeenEarnedAt(userId, scope: scope, value: upTo.toUtc());
  }
}

