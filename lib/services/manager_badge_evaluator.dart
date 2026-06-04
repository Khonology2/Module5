import 'package:pdh/models/alert.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/services/badge_service.dart';

class ManagerBadgeEvaluator {
  static final BackendAuthService _backend = BackendAuthService.instance;
  static const int _capApprovalPointsPerWeek = 100; // 10 approvals * 10 pts
  static const int _capNudgePointsPerWeek = 40; // 20 detailed nudges * 2 pts
  static const Duration _window = Duration(days: 7);
  static const Duration _nudgeCooldown = Duration(minutes: 60);
  static const int _timelyApprovalTier1 = 10;
  static const int _timelyApprovalTier2 = 25;
  static const int _meetingTier1 = 5;
  static const int _meetingTier2 = 10;
  static const int _replanTier2 = 15;

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static Future<List<Map<String, dynamic>>> _goalsApprovedBy(
    String managerId,
  ) async {
    final goals = await _backend.getGoals(limit: 2000);
    return goals
        .where(
          (g) => (g['approvedByUserId'] ?? '').toString() == managerId,
        )
        .toList();
  }

  static Future<List<Map<String, dynamic>>> _managerNudgeAlerts(
    String managerId,
  ) async {
    final users = await _backend.listUsers(limit: 2000);
    final chunks = <List<Map<String, dynamic>>>[];
    for (final user in users) {
      final uid = (user['id'] ?? user['uid'] ?? '').toString();
      if (uid.isEmpty) continue;
      try {
        final alerts = await _backend.getAlerts(uid, limit: 200);
        chunks.add(
          alerts.where((alert) {
            final type = (alert['type'] ?? '').toString();
            final fromUserId = (alert['fromUserId'] ?? '').toString();
            return type == AlertType.managerNudge.name &&
                fromUserId == managerId;
          }).toList(),
        );
      } catch (_) {}
    }
    return chunks.expand((e) => e).toList();
  }

  static Future<void> evaluate(String managerId) async {
    await ensureBaselineManagerBadges(managerId);
    final approvalsCount = await _countApprovals(managerId);
    final monthlyAcknowledgements = await _countMonthlyAcknowledgements(
      managerId,
    );
    final detailedNudges = await _countDetailedNudges(managerId);
    final seasonsCompleted = await _countSeasonsCompleted(managerId);
    final reactivations = await _countReactivatedEmployees(managerId);
    final replansHelped = await _countReplansHelped(managerId);
    final managerPoints = await _computeManagerPoints(
      managerId,
      approvalsCount,
      detailedNudges,
    );
    final timelyApprovals30d = await _countTimelyApprovals30d(managerId);
    final meetingsUnique30d = await _countMeetingsUniqueEmployees30d(
      managerId,
    );

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
      category: 'collaboration',
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
      category: 'achievement',
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
      description:
          'Approved 10 goals within 24h of request in the last 30 days',
      iconName: 'check_circle',
      category: 'goals',
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
      description:
          'Approved 25 goals within 24h of request in the last 30 days',
      iconName: 'verified',
      category: 'goals',
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
      category: 'achievement',
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
      category: 'achievement',
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
      category: 'achievement',
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
      category: 'community',
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
      category: 'innovation',
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
      category: 'innovation',
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
      category: 'collaboration',
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
      category: 'collaboration',
      rarity: 'rare',
      isEarned: meetingsUnique30d >= _meetingTier2,
      progress: meetingsUnique30d.clamp(0, _meetingTier2),
      maxProgress: _meetingTier2,
      managerLevel: 4,
    );

    final distinctNudged = await _countDistinctEmployeesNudgedAllTime(
      managerId,
    );

    Future<void> upsertNudgeNetwork({
      required int level,
      required int requiredCount,
    }) async {
      await _upsertBadge(
        userId: managerId,
        badgeId: 'mgr_nudge_network_l$level',
        name: 'Nudge Network L$level',
        description: 'Nudge $requiredCount distinct employees',
        iconName: 'diversity_3',
        category: 'community',
        rarity: level <= 2
            ? 'common'
            : level == 3
            ? 'rare'
            : level == 4
            ? 'epic'
            : 'legendary',
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

  static Future<void> ensureBaselineManagerBadges(String managerId) async {
    Future<void> seed(
      String id,
      String name,
      String description,
      String iconName,
      String rarity,
      String category,
      int maxProgress,
      int managerLevel,
    ) async {
      final existing = await _backend.getBadges(managerId, limit: 500);
      final hasBadge = existing.any(
        (b) => (b['id'] ?? b['badgeId'] ?? '').toString() == id,
      );
      if (hasBadge) return;
      await _backend.upsertBadge(managerId, id, {
        'name': name,
        'description': description,
        'iconName': iconName,
        'category': category,
        'rarity': rarity,
        'pointsRequired': 0,
        'criteria': {'badgeId': id, 'managerLevel': managerLevel},
        'isEarned': false,
        'progress': 0,
        'maxProgress': maxProgress,
      });
    }

    await Future.wait([
      seed(
        'mgr_active_coach',
        'Active Coach',
        'Acknowledge 10+ milestones in a month',
        'verified',
        'common',
        'leadership',
        10,
        1,
      ),
      seed(
        'mgr_feedback_champion',
        'Feedback Champion',
        'Provide 10+ detailed feedback entries',
        'chat',
        'common',
        'collaboration',
        10,
        2,
      ),
      seed(
        'mgr_growth_enabler',
        'Growth Enabler',
        'Reach 500+ manager points',
        'emoji_events',
        'rare',
        'achievement',
        500,
        2,
      ),
      seed(
        'mgr_timely_approver_1',
        'Timely Approver I',
        'Approve 10 goals within 24h in the last 30 days',
        'check_circle',
        'common',
        'goals',
        _timelyApprovalTier1,
        2,
      ),
      seed(
        'mgr_replan_hero',
        'Replan Hero',
        'Helped replan 5+ delayed goals',
        'build',
        'common',
        'innovation',
        5,
        3,
      ),
      seed(
        'mgr_engagement_booster',
        'Engagement Booster',
        'Reactivated 3+ inactive employees',
        'bolt',
        'common',
        'community',
        3,
        3,
      ),
      seed(
        'mgr_all_star_manager',
        'All-Star Manager',
        'Reach 1000+ manager points',
        'workspace_premium',
        'epic',
        'achievement',
        1000,
        3,
      ),
      seed(
        'mgr_meeting_steward_1',
        'Meeting Steward I',
        'Held 1:1s with 5 unique employees in the last 30 days',
        'calendar_today',
        'common',
        'collaboration',
        _meetingTier1,
        3,
      ),
      seed(
        'mgr_timely_approver_2',
        'Timely Approver II',
        'Approve 25 goals within 24h in the last 30 days',
        'verified',
        'rare',
        'goals',
        _timelyApprovalTier2,
        3,
      ),
      seed(
        'mgr_replan_closer_2',
        'Replan Closer II',
        'Helped replan 15 distinct goals',
        'build',
        'rare',
        'innovation',
        _replanTier2,
        4,
      ),
      seed(
        'mgr_meeting_steward_2',
        'Meeting Steward II',
        'Held 1:1s with 10 unique employees in the last 30 days',
        'groups',
        'rare',
        'collaboration',
        _meetingTier2,
        4,
      ),
      seed(
        'mgr_season_leader',
        'Season Leader',
        'Lead a team challenge/season to completion',
        'flag',
        'rare',
        'achievement',
        1,
        4,
      ),
      seed(
        'mgr_master_coach',
        'Master Coach',
        'Reach 3500+ manager points',
        'trophy',
        'legendary',
        'achievement',
        3500,
        5,
      ),
      seed(
        'mgr_nudge_network_l1',
        'Nudge Network L1',
        'Nudge 5 distinct employees',
        'diversity_3',
        'common',
        'community',
        5,
        1,
      ),
      seed(
        'mgr_nudge_network_l2',
        'Nudge Network L2',
        'Nudge 6 distinct employees',
        'diversity_3',
        'common',
        'community',
        6,
        2,
      ),
      seed(
        'mgr_nudge_network_l3',
        'Nudge Network L3',
        'Nudge 7 distinct employees',
        'diversity_3',
        'rare',
        'community',
        7,
        3,
      ),
      seed(
        'mgr_nudge_network_l4',
        'Nudge Network L4',
        'Nudge 8 distinct employees',
        'diversity_3',
        'epic',
        'community',
        8,
        4,
      ),
      seed(
        'mgr_nudge_network_l5',
        'Nudge Network L5',
        'Nudge 9 distinct employees',
        'diversity_3',
        'legendary',
        'community',
        9,
        5,
      ),
    ]);
  }

  static Future<int> _countApprovals(String managerId) async {
    final goals = await _goalsApprovedBy(managerId);
    return goals.length;
  }

  static Future<int> _countMonthlyAcknowledgements(String managerId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final goals = await _goalsApprovedBy(managerId);
    var count = 0;
    for (final data in goals) {
      final dt = _parseDate(data['lastUpdated']);
      if (dt != null && !dt.isBefore(startOfMonth)) count++;
    }
    return count;
  }

  static Future<int> _countDetailedNudges(String managerId) async {
    final nudges = await _managerNudgeAlerts(managerId);
    var detailed = 0;
    for (final data in nudges) {
      final msg = (data['message'] ?? '').toString();
      if (msg.trim().length >= 50) detailed++;
    }
    return detailed;
  }

  static Future<int> _countSeasonsCompleted(String managerId) async {
    final seasons = await _backend.getSeasons(limit: 500);
    return seasons
        .where(
          (s) =>
              (s['createdBy'] ?? '').toString() == managerId &&
              (s['status'] ?? '').toString() == 'completed',
        )
        .length;
  }

  static Future<int> _countReactivatedEmployees(String managerId) async {
    final actions = await _backend.getManagerActions(managerId, limit: 500);
    final ids = <String>{};
    for (final data in actions) {
      if ((data['type'] ?? '').toString() != 'reactivated_employee') continue;
      final employeeId = (data['employeeId'] ?? '').toString();
      if (employeeId.isNotEmpty) ids.add(employeeId);
    }
    return ids.length;
  }

  static Future<int> _countReplansHelped(String managerId) async {
    final actions = await _backend.getManagerActions(managerId, limit: 500);
    final goalIds = <String>{};
    for (final data in actions) {
      if ((data['type'] ?? '').toString() != 'replan_helped') continue;
      final goalId = (data['goalId'] ?? '').toString();
      if (goalId.isNotEmpty) goalIds.add(goalId);
    }
    return goalIds.length;
  }

  static Future<int> _computeManagerPoints(
    String managerId,
    int approvals,
    int detailedNudges,
  ) async {
    double teamEngagement = 0;
    int goalsCompleted = 0;
    int totalEmployees = 0;
    try {
      final data = await _backend.getCollectionItem(
        'manager_metrics',
        managerId,
      );
      teamEngagement = (data['teamEngagement'] is num)
          ? (data['teamEngagement'] as num).toDouble()
          : 0.0;
      goalsCompleted = (data['goalsCompleted'] is int)
          ? data['goalsCompleted'] as int
          : (data['goalsCompleted'] is num)
          ? (data['goalsCompleted'] as num).toInt()
          : 0;
      totalEmployees = (data['totalEmployees'] is int)
          ? data['totalEmployees'] as int
          : (data['totalEmployees'] is num)
          ? (data['totalEmployees'] as num).toInt()
          : 0;
    } catch (_) {}

    final teamCompletionRate = totalEmployees > 0
        ? (goalsCompleted / (totalEmployees * 5)).clamp(0.0, 1.0)
        : 0.0;

    const weightApproval = 10;
    const weightNudge = 2;
    const weightHighCompletionBonus = 100;
    const weightEngagementBonus = 50;

    final now = DateTime.now();
    final windowStart = now.subtract(_window);
    final approvals7d = await _countApprovalsInWindow(managerId, windowStart);
    final nudges7d = await _countDetailedNudgesInWindow(managerId, windowStart);

    final approvalsPoints = (approvals7d * weightApproval).clamp(
      0,
      _capApprovalPointsPerWeek,
    );
    final nudgePoints = (nudges7d * weightNudge).clamp(
      0,
      _capNudgePointsPerWeek,
    );

    var points = 0;
    points += approvalsPoints;
    points += nudgePoints;
    var bonus = 0;
    if (teamCompletionRate >= 0.6) bonus += weightHighCompletionBonus;
    if (teamEngagement >= 70) bonus += weightEngagementBonus;
    points += bonus;

    await _logPointSnapshot(
      userId: managerId,
      approvals7d: approvals7d,
      nudges7d: nudges7d,
      approvalsPoints: approvalsPoints,
      nudgePoints: nudgePoints,
      bonusPoints: bonus,
      totalPoints: points,
    );
    return points;
  }

  static Future<int> _countApprovalsInWindow(
    String managerId,
    DateTime windowStart,
  ) async {
    final goals = await _goalsApprovedBy(managerId);
    var count = 0;
    for (final data in goals) {
      final dt = _parseDate(
        data['lastUpdated'] ?? data['approvedAt'] ?? data['createdAt'],
      );
      if (dt != null && !dt.isBefore(windowStart)) count++;
    }
    return count;
  }

  static Future<int> _countTimelyApprovals30d(String managerId) async {
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(days: 30));
    var count = 0;
    final goals = await _goalsApprovedBy(managerId);
    for (final data in goals) {
      final createdAt = _parseDate(data['createdAt']);
      final approvedAt = _parseDate(data['approvedAt'] ?? data['lastUpdated']);
      if (createdAt == null || approvedAt == null) continue;
      if (approvedAt.isBefore(windowStart)) continue;
      if (approvedAt.difference(createdAt).inHours <= 24) count++;
    }
    return count;
  }

  static Future<int> _countMeetingsUniqueEmployees30d(String managerId) async {
    final windowStart = DateTime.now().subtract(const Duration(days: 30));
    final actions = await _backend.getManagerActions(managerId, limit: 500);
    final ids = <String>{};
    for (final data in actions) {
      if ((data['actionType'] ?? '').toString() != 'scheduleMeeting') continue;
      final dt = _parseDate(data['createdAt']);
      if (dt == null || dt.isBefore(windowStart)) continue;
      final employeeId = (data['employeeId'] ?? '').toString();
      if (employeeId.isNotEmpty) ids.add(employeeId);
    }
    return ids.length;
  }

  static Future<int> _countDetailedNudgesInWindow(
    String managerId,
    DateTime windowStart,
  ) async {
    final nudges = await _managerNudgeAlerts(managerId);
    final lastByRecipient = <String, DateTime>{};
    var counted = 0;
    for (final data in nudges) {
      final msg = (data['message'] ?? '').toString();
      if (msg.trim().length < 50) continue;
      final dt = _parseDate(
        data['createdAt'] ?? data['lastUpdated'] ?? data['timestamp'],
      );
      if (dt == null || dt.isBefore(windowStart)) continue;
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

  static Future<void> _logPointSnapshot({
    required String userId,
    required int approvals7d,
    required int nudges7d,
    required int approvalsPoints,
    required int nudgePoints,
    required int bonusPoints,
    required int totalPoints,
  }) async {
    await _backend.createPointEvent({
      'userId': userId,
      'role': 'manager',
      'type': 'snapshot',
      'approvals7d': approvals7d,
      'nudges7d': nudges7d,
      'approvalsPoints': approvalsPoints,
      'nudgePoints': nudgePoints,
      'bonusPoints': bonusPoints,
      'totalPoints': totalPoints,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<int> _countDistinctEmployeesNudgedAllTime(
    String managerId,
  ) async {
    final nudges = await _managerNudgeAlerts(managerId);
    final distinct = <String>{};
    for (final data in nudges) {
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
    final existing = await _backend.getBadges(userId, limit: 500);
    Map<String, dynamic>? prior;
    for (final item in existing) {
      final id = (item['id'] ?? item['badgeId'] ?? '').toString();
      if (id == badgeId) {
        prior = item;
        break;
      }
    }

    final wasEarned = prior?['isEarned'] == true;
    final preservedEarnedAt = _parseDate(prior?['earnedAt']);
    final earnedAt = isEarned
        ? (wasEarned && preservedEarnedAt != null
              ? preservedEarnedAt.toIso8601String()
              : DateTime.now().toIso8601String())
        : null;

    await _backend.upsertBadge(userId, badgeId, {
      'name': name,
      'description': description,
      'iconName': iconName,
      'category': category,
      'rarity': rarity,
      'pointsRequired': 0,
      'criteria': {
        'badgeId': badgeId,
        'managerLevel': ?managerLevel,
      },
      'earnedAt': earnedAt,
      'isEarned': isEarned,
      'progress': progress,
      'maxProgress': maxProgress,
    });
  }

  static Future<void> logEmployeeReactivated({
    required String managerId,
    required String employeeId,
    String? reason,
  }) async {
    await _backend.createManagerAction(managerId, {
      'managerId': managerId,
      'employeeId': employeeId,
      'type': 'reactivated_employee',
      'reason': reason,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> logReplanHelped({
    required String managerId,
    required String goalId,
    String? note,
  }) async {
    await _backend.createManagerAction(managerId, {
      'managerId': managerId,
      'goalId': goalId,
      'type': 'replan_helped',
      'note': note,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}
