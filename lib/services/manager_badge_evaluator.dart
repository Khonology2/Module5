import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/services/badge_service.dart';

class ManagerBadgeEvaluator {
  static final _db = FirebaseFirestore.instance;
  static const int _capApprovalPointsPerWeek = 100; // 10 approvals * 10 pts
  static const int _capNudgePointsPerWeek = 40; // 20 detailed nudges * 2 pts
  static const Duration _window = Duration(days: 7);
  static const Duration _nudgeCooldown = Duration(minutes: 60);
  // Lifetime-based counting for Nudge Network badges (no window)
  static const int _timelyApprovalTier1 = 10;
  static const int _timelyApprovalTier2 = 25;
  static const int _meetingTier1 = 5;
  static const int _meetingTier2 = 10;
  static const int _replanTier2 = 15;

  static Future<void> evaluate(String managerId) async {
    // Compute metrics
    await ensureBaselineManagerBadges(managerId);
    final approvalsCount = await _countApprovals(managerId);
    final monthlyAcknowledgements = await _countMonthlyAcknowledgements(managerId);
    final detailedNudges = await _countDetailedNudges(managerId);
    final seasonsCompleted = await _countSeasonsCompleted(managerId);
    final reactivations = await _countReactivatedEmployees(managerId);
    final replansHelped = await _countReplansHelped(managerId);
    final managerPoints = await _computeManagerPoints(managerId, approvalsCount, detailedNudges);
    final timelyApprovals30d = await _countTimelyApprovals30d(managerId);
    final meetingsUnique30d = await _countMeetingsUniqueEmployees30d(managerId);

    // Award badges (write to users/{uid}/badges)
    await _upsertBadge(
      userId: managerId,
      badgeId: 'mgr_active_coach',
      name: 'Active Coach',
      description: 'Acknowledge 10+ milestones in a month',
      iconName: 'verified',
      category: 'leadership',
      rarity: 'common',
      isEarned: monthlyAcknowledgements >= 10,
      progress: monthlyAcknowledgements.clamp(0, 10),
      maxProgress: 10,
      managerLevel: 1,
    );

    await _upsertBadge(
      userId: managerId,
      badgeId: 'mgr_feedback_champion',
      name: 'Feedback Champion',
      description: 'Provided 10+ detailed feedback entries',
      iconName: 'chat',
      category: 'leadership',
      rarity: 'common',
      isEarned: detailedNudges >= 10,
      progress: detailedNudges.clamp(0, 10),
      maxProgress: 10,
      managerLevel: 2,
    );

    await _upsertBadge(
      userId: managerId,
      badgeId: 'mgr_growth_enabler',
      name: 'Growth Enabler',
      description: 'Reached 500+ manager points',
      iconName: 'emoji_events',
      category: 'leadership',
      rarity: 'rare',
      isEarned: managerPoints >= 500,
      progress: managerPoints.clamp(0, 500),
      maxProgress: 500,
      managerLevel: 2,
    );

    await _upsertBadge(
      userId: managerId,
      badgeId: 'mgr_timely_approver_1',
      name: 'Timely Approver I',
      description: 'Approved 10 goals within 24h of request in the last 30 days',
      iconName: 'check_circle',
      category: 'leadership',
      rarity: 'common',
      isEarned: timelyApprovals30d >= _timelyApprovalTier1,
      progress: timelyApprovals30d.clamp(0, _timelyApprovalTier1),
      maxProgress: _timelyApprovalTier1,
      managerLevel: 2,
    );

    await _upsertBadge(
      userId: managerId,
      badgeId: 'mgr_timely_approver_2',
      name: 'Timely Approver II',
      description: 'Approved 25 goals within 24h of request in the last 30 days',
      iconName: 'verified',
      category: 'leadership',
      rarity: 'rare',
      isEarned: timelyApprovals30d >= _timelyApprovalTier2,
      progress: timelyApprovals30d.clamp(0, _timelyApprovalTier2),
      maxProgress: _timelyApprovalTier2,
      managerLevel: 3,
    );

    await _upsertBadge(
      userId: managerId,
      badgeId: 'mgr_season_leader',
      name: 'Season Leader',
      description: 'Led a team challenge/season to completion',
      iconName: 'flag',
      category: 'leadership',
      rarity: 'rare',
      isEarned: seasonsCompleted >= 1,
      progress: seasonsCompleted.clamp(0, 1),
      maxProgress: 1,
      managerLevel: 4,
    );

    await _upsertBadge(
      userId: managerId,
      badgeId: 'mgr_all_star_manager',
      name: 'All-Star Manager',
      description: 'Reached 1000+ manager points',
      iconName: 'workspace_premium',
      category: 'leadership',
      rarity: 'epic',
      isEarned: managerPoints >= 1000,
      progress: managerPoints.clamp(0, 1000),
      maxProgress: 1000,
      managerLevel: 3,
    );

    await _upsertBadge(
      userId: managerId,
      badgeId: 'mgr_master_coach',
      name: 'Master Coach',
      description: 'Reached 3500+ manager points',
      iconName: 'trophy',
      category: 'leadership',
      rarity: 'legendary',
      isEarned: managerPoints >= 3500,
      progress: managerPoints.clamp(0, 3500),
      maxProgress: 3500,
      managerLevel: 5,
    );

    await _upsertBadge(
      userId: managerId,
      badgeId: 'mgr_engagement_booster',
      name: 'Engagement Booster',
      description: 'Reactivated 3+ inactive employees',
      iconName: 'bolt',
      category: 'leadership',
      rarity: 'common',
      isEarned: reactivations >= 3,
      progress: reactivations.clamp(0, 3),
      maxProgress: 3,
      managerLevel: 3,
    );

    await _upsertBadge(
      userId: managerId,
      badgeId: 'mgr_replan_hero',
      name: 'Replan Hero',
      description: 'Helped replan 5+ delayed goals',
      iconName: 'build',
      category: 'leadership',
      rarity: 'common',
      isEarned: replansHelped >= 5,
      progress: replansHelped.clamp(0, 5),
      maxProgress: 5,
      managerLevel: 3,
    );

    await _upsertBadge(
      userId: managerId,
      badgeId: 'mgr_replan_closer_2',
      name: 'Replan Closer II',
      description: 'Helped replan 15 distinct goals',
      iconName: 'build',
      category: 'leadership',
      rarity: 'rare',
      isEarned: replansHelped >= _replanTier2,
      progress: replansHelped.clamp(0, _replanTier2),
      maxProgress: _replanTier2,
      managerLevel: 4,
    );

    await _upsertBadge(
      userId: managerId,
      badgeId: 'mgr_meeting_steward_1',
      name: 'Meeting Steward I',
      description: 'Held 1:1s with 5 unique employees in the last 30 days',
      iconName: 'calendar_today',
      category: 'leadership',
      rarity: 'common',
      isEarned: meetingsUnique30d >= _meetingTier1,
      progress: meetingsUnique30d.clamp(0, _meetingTier1),
      maxProgress: _meetingTier1,
      managerLevel: 3,
    );

    await _upsertBadge(
      userId: managerId,
      badgeId: 'mgr_meeting_steward_2',
      name: 'Meeting Steward II',
      description: 'Held 1:1s with 10 unique employees in the last 30 days',
      iconName: 'groups',
      category: 'leadership',
      rarity: 'rare',
      isEarned: meetingsUnique30d >= _meetingTier2,
      progress: meetingsUnique30d.clamp(0, _meetingTier2),
      maxProgress: _meetingTier2,
      managerLevel: 4,
    );

    // === Nudge Network per Level (lifetime distinct employees nudged) ===
    final distinctNudged = await _countDistinctEmployeesNudgedAllTime(managerId);

    Future<void> upsertNudgeNetwork({required int level, required int requiredCount}) async {
      await _upsertBadge(
        userId: managerId,
        badgeId: 'mgr_nudge_network_l$level',
        name: 'Nudge Network L$level',
        description: 'Nudge $requiredCount distinct employees',
        iconName: 'diversity_3',
        category: 'leadership',
        rarity: level <= 2 ? 'common' : level == 3 ? 'rare' : level == 4 ? 'epic' : 'legendary',
        isEarned: distinctNudged >= requiredCount,
        progress: distinctNudged.clamp(0, requiredCount),
        maxProgress: requiredCount,
        managerLevel: level,
      );
    }

    await upsertNudgeNetwork(level: 1, requiredCount: 5);
    await upsertNudgeNetwork(level: 2, requiredCount: 6);
    await upsertNudgeNetwork(level: 3, requiredCount: 7);
    await upsertNudgeNetwork(level: 4, requiredCount: 8);
    await upsertNudgeNetwork(level: 5, requiredCount: 9);

    await BadgeService.updateUserBadgeSummary(managerId);
  }

  // Ensure manager badge docs exist (locked) so UI can display them grouped by level
  static Future<void> ensureBaselineManagerBadges(String managerId) async {
    Future<void> seed(
      String id,
      String name,
      String description,
      String iconName,
      String rarity,
      int maxProgress,
      int managerLevel,
    ) async {
      final ref = _db.collection('users').doc(managerId).collection('badges').doc(id);
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'name': name,
          'description': description,
          'iconName': iconName,
          'category': 'leadership',
          'rarity': rarity,
          'pointsRequired': 0,
          'criteria': {
            'badgeId': id,
            'managerLevel': managerLevel,
          },
          'isEarned': false,
          'progress': 0,
          'maxProgress': maxProgress,
        }, SetOptions(merge: true));
      }
    }

    await Future.wait([
      seed('mgr_active_coach', 'Active Coach', 'Acknowledge 10+ milestones in a month', 'verified', 'common', 10, 1),
      seed('mgr_feedback_champion', 'Feedback Champion', 'Provide 10+ detailed feedback entries', 'chat', 'common', 10, 2),
      seed('mgr_growth_enabler', 'Growth Enabler', 'Reach 500+ manager points', 'emoji_events', 'rare', 500, 2),
      seed('mgr_timely_approver_1', 'Timely Approver I', 'Approve 10 goals within 24h in the last 30 days', 'check_circle', 'common', _timelyApprovalTier1, 2),
      seed('mgr_replan_hero', 'Replan Hero', 'Helped replan 5+ delayed goals', 'build', 'common', 5, 3),
      seed('mgr_engagement_booster', 'Engagement Booster', 'Reactivated 3+ inactive employees', 'bolt', 'common', 3, 3),
      seed('mgr_all_star_manager', 'All-Star Manager', 'Reach 1000+ manager points', 'workspace_premium', 'epic', 1000, 3),
      seed('mgr_meeting_steward_1', 'Meeting Steward I', 'Held 1:1s with 5 unique employees in the last 30 days', 'calendar_today', 'common', _meetingTier1, 3),
      seed('mgr_timely_approver_2', 'Timely Approver II', 'Approve 25 goals within 24h in the last 30 days', 'verified', 'rare', _timelyApprovalTier2, 3),
      seed('mgr_replan_closer_2', 'Replan Closer II', 'Helped replan 15 distinct goals', 'build', 'rare', _replanTier2, 4),
      seed('mgr_meeting_steward_2', 'Meeting Steward II', 'Held 1:1s with 10 unique employees in the last 30 days', 'groups', 'rare', _meetingTier2, 4),
      seed('mgr_season_leader', 'Season Leader', 'Lead a team challenge/season to completion', 'flag', 'rare', 1, 4),
      seed('mgr_master_coach', 'Master Coach', 'Reach 3500+ manager points', 'trophy', 'legendary', 3500, 5),
      // Seed Nudge Network badges (lifetime distinct employees nudged)
      seed('mgr_nudge_network_l1', 'Nudge Network L1', 'Nudge 5 distinct employees', 'diversity_3', 'common', 5, 1),
      seed('mgr_nudge_network_l2', 'Nudge Network L2', 'Nudge 6 distinct employees', 'diversity_3', 'common', 6, 2),
      seed('mgr_nudge_network_l3', 'Nudge Network L3', 'Nudge 7 distinct employees', 'diversity_3', 'rare', 7, 3),
      seed('mgr_nudge_network_l4', 'Nudge Network L4', 'Nudge 8 distinct employees', 'diversity_3', 'epic', 8, 4),
      seed('mgr_nudge_network_l5', 'Nudge Network L5', 'Nudge 9 distinct employees', 'diversity_3', 'legendary', 9, 5),
    ]);
  }

  static Future<int> _countApprovals(String managerId) async {
    final goalsSnap = await _db
        .collection('goals')
        .where('approvedByUserId', isEqualTo: managerId)
        .get();
    return goalsSnap.docs.length;
  }

  static Future<int> _countMonthlyAcknowledgements(String managerId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final goalsSnap = await _db
        .collection('goals')
        .where('approvedByUserId', isEqualTo: managerId)
        .get();
    int count = 0;
    for (final d in goalsSnap.docs) {
      final data = d.data();
      final ts = data['lastUpdated'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        if (!dt.isBefore(startOfMonth)) count++;
      } else {
        // If timestamp missing, skip to avoid false positives
      }
    }
    return count;
  }

  static Future<int> _countDetailedNudges(String managerId) async {
    final nudgesSnap = await _db
        .collection('alerts')
        .where('type', isEqualTo: AlertType.managerNudge.name)
        .where('fromUserId', isEqualTo: managerId)
        .get();
    int detailed = 0;
    for (final d in nudgesSnap.docs) {
      final data = d.data();
      final msg = (data['message'] ?? '').toString();
      if (msg.trim().length >= 50) detailed++;
    }
    return detailed;
  }

  static Future<int> _countSeasonsCompleted(String managerId) async {
    final seasonsSnap = await _db
        .collection('seasons')
        .where('createdBy', isEqualTo: managerId)
        .where('status', isEqualTo: 'completed')
        .get();
    return seasonsSnap.docs.length;
  }

  static Future<int> _countReactivatedEmployees(String managerId) async {
    final actionsSnap = await _db
        .collection('manager_actions')
        .where('managerId', isEqualTo: managerId)
        .where('type', isEqualTo: 'reactivated_employee')
        .get();
    // Distinct employees for progress
    final ids = <String>{};
    for (final d in actionsSnap.docs) {
      final data = d.data();
      final employeeId = (data['employeeId'] ?? '').toString();
      if (employeeId.isNotEmpty) ids.add(employeeId);
    }
    return ids.length;
  }

  static Future<int> _countReplansHelped(String managerId) async {
    final actionsSnap = await _db
        .collection('manager_actions')
        .where('managerId', isEqualTo: managerId)
        .where('type', isEqualTo: 'replan_helped')
        .get();
    // Distinct goals replanned
    final goalIds = <String>{};
    for (final d in actionsSnap.docs) {
      final data = d.data();
      final goalId = (data['goalId'] ?? '').toString();
      if (goalId.isNotEmpty) goalIds.add(goalId);
    }
    return goalIds.length;
  }

  static Future<int> _computeManagerPoints(String managerId, int approvals, int detailedNudges) async {
    // Mirror the screen calculation
    // Get team metrics baseline
    double teamEngagement = 0;
    int goalsCompleted = 0;
    int totalEmployees = 0;
    try {
      // Optional: read a cached metrics doc if present to avoid heavy aggregation
      final doc = await _db.collection('manager_metrics').doc(managerId).get();
      final data = doc.data();
      if (data != null) {
        teamEngagement = (data['teamEngagement'] is num) ? (data['teamEngagement'] as num).toDouble() : 0.0;
        goalsCompleted = (data['goalsCompleted'] is int) ? data['goalsCompleted'] as int : 0;
        totalEmployees = (data['totalEmployees'] is int) ? data['totalEmployees'] as int : 0;
      }
    } catch (_) {}

    final teamCompletionRate = totalEmployees > 0 ? (goalsCompleted / (totalEmployees * 5)).clamp(0.0, 1.0) : 0.0;

    const weightApproval = 10;
    const weightNudge = 2;
    const weightHighCompletionBonus = 100;
    const weightEngagementBonus = 50;

    final now = DateTime.now();
    final windowStart = now.subtract(_window);
    final approvals7d = await _countApprovalsInWindow(managerId, windowStart);
    final nudges7d = await _countDetailedNudgesInWindow(managerId, windowStart);

    final approvalsPoints = (approvals7d * weightApproval).clamp(0, _capApprovalPointsPerWeek);
    final nudgePoints = (nudges7d * weightNudge).clamp(0, _capNudgePointsPerWeek);

    int points = 0;
    points += approvalsPoints;
    points += nudgePoints;
    int bonus = 0;
    if (teamCompletionRate >= 0.6) bonus += weightHighCompletionBonus;
    if (teamEngagement >= 70) bonus += weightEngagementBonus;
    points += bonus;

    await _logPointSnapshot(userId: managerId, approvals7d: approvals7d, nudges7d: nudges7d, approvalsPoints: approvalsPoints, nudgePoints: nudgePoints, bonusPoints: bonus, totalPoints: points);
    return points;
  }

  static Future<int> _countApprovalsInWindow(String managerId, DateTime windowStart) async {
    final goalsSnap = await _db
        .collection('goals')
        .where('approvedByUserId', isEqualTo: managerId)
        .get();
    int count = 0;
    for (final d in goalsSnap.docs) {
      final data = d.data();
      final ts = data['lastUpdated'] ?? data['approvedAt'] ?? data['createdAt'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        if (!dt.isBefore(windowStart)) count++;
      }
    }
    return count;
  }

  static Future<int> _countTimelyApprovals30d(String managerId) async {
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(days: 30));
    int count = 0;

    final goalsSnap = await _db
        .collection('goals')
        .where('approvedByUserId', isEqualTo: managerId)
        .get();

    for (final d in goalsSnap.docs) {
      final data = d.data();
      final createdTs = data['createdAt'];
      final approvedTs = data['approvedAt'] ?? data['lastUpdated'];
      if (createdTs is! Timestamp || approvedTs is! Timestamp) continue;
      final createdAt = createdTs.toDate();
      final approvedAt = approvedTs.toDate();
      if (approvedAt.isBefore(windowStart)) continue;
      final diff = approvedAt.difference(createdAt);
      if (diff.inHours <= 24) {
        count++;
      }
    }

    return count;
  }

  static Future<int> _countMeetingsUniqueEmployees30d(String managerId) async {
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(days: 30));
    final actionsSnap = await _db
        .collection('manager_actions')
        .where('managerId', isEqualTo: managerId)
        .where('actionType', isEqualTo: 'scheduleMeeting')
        .get();

    final ids = <String>{};
    for (final d in actionsSnap.docs) {
      final data = d.data();
      final ts = data['createdAt'];
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      if (dt.isBefore(windowStart)) continue;
      final employeeId = (data['employeeId'] ?? '').toString();
      if (employeeId.isNotEmpty) {
        ids.add(employeeId);
      }
    }
    return ids.length;
  }

  static Future<int> _countDetailedNudgesInWindow(String managerId, DateTime windowStart) async {
    final nudgesSnap = await _db
        .collection('alerts')
        .where('type', isEqualTo: AlertType.managerNudge.name)
        .where('fromUserId', isEqualTo: managerId)
        .get();
    final lastByRecipient = <String, DateTime>{};
    int counted = 0;
    for (final d in nudgesSnap.docs) {
      final data = d.data();
      final msg = (data['message'] ?? '').toString();
      if (msg.trim().length < 50) continue;
      final ts = data['createdAt'] ?? data['lastUpdated'] ?? data['timestamp'];
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      if (dt.isBefore(windowStart)) continue;
      final toUserId = (data['toUserId'] ?? data['userId'] ?? '').toString();
      if (toUserId.isEmpty) {
        counted++;
        continue;
      }
      final last = lastByRecipient[toUserId];
      if (last == null || dt.difference(last) >= _nudgeCooldown) {
        lastByRecipient[toUserId] = dt;
        counted++;
      }
    }
    return counted;
  }

  // Removed unused helper: _countDistinctEmployeesNudgedInWindow

  static Future<void> _logPointSnapshot({
    required String userId,
    required int approvals7d,
    required int nudges7d,
    required int approvalsPoints,
    required int nudgePoints,
    required int bonusPoints,
    required int totalPoints,
  }) async {
    await _db.collection('point_events').add({
      'userId': userId,
      'role': 'manager',
      'type': 'snapshot',
      'approvals7d': approvals7d,
      'nudges7d': nudges7d,
      'approvalsPoints': approvalsPoints,
      'nudgePoints': nudgePoints,
      'bonusPoints': bonusPoints,
      'totalPoints': totalPoints,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Lifetime distinct employees nudged (no time window)
  static Future<int> _countDistinctEmployeesNudgedAllTime(String managerId) async {
    final nudgesSnap = await _db
        .collection('alerts')
        .where('type', isEqualTo: AlertType.managerNudge.name)
        .where('fromUserId', isEqualTo: managerId)
        .get();
    final distinct = <String>{};
    for (final d in nudgesSnap.docs) {
      final data = d.data();
      final toUserId = (data['toUserId'] ?? data['userId'] ?? '').toString();
      if (toUserId.isNotEmpty) distinct.add(toUserId);
    }
    return distinct.length;
  }

  static Future<void> _upsertBadge({
    required String userId,
    required String badgeId,
    required String name,
    required String description,
    required String iconName,
    required String category,
    required String rarity,
    required bool isEarned,
    required int progress,
    required int maxProgress,
    int? managerLevel,
  }) async {
    final ref = _db.collection('users').doc(userId).collection('badges').doc(badgeId);
    await ref.set({
      'name': name,
      'description': description,
      'iconName': iconName,
      'category': category,
      'rarity': rarity,
      'pointsRequired': 0,
      'criteria': {
        'badgeId': badgeId,
        if (managerLevel != null) 'managerLevel': managerLevel,
      },
      'earnedAt': isEarned ? FieldValue.serverTimestamp() : null,
      'isEarned': isEarned,
      'progress': progress,
      'maxProgress': maxProgress,
    }, SetOptions(merge: true));
  }

  // Utility to log engagement reactivation events (Option A schema)
  static Future<void> logEmployeeReactivated({
    required String managerId,
    required String employeeId,
    String? reason,
  }) async {
    await _db.collection('manager_actions').add({
      'managerId': managerId,
      'employeeId': employeeId,
      'type': 'reactivated_employee',
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Utility to log replan helped events (per goal)
  static Future<void> logReplanHelped({
    required String managerId,
    required String goalId,
    String? note,
  }) async {
    await _db.collection('manager_actions').add({
      'managerId': managerId,
      'goalId': goalId,
      'type': 'replan_helped',
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
