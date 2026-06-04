import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/utils/backend_polling_stream.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/goal_milestone.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/services/milestone_evidence_service.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/streak_service.dart';
import 'package:pdh/services/badge_service.dart';
import 'package:pdh/services/season_service.dart';
import 'package:pdh/services/onboarding_service.dart';
import 'package:pdh/services/performance_cache_service.dart';
import 'package:pdh/services/approved_goal_audit_service.dart';
import 'package:pdh/services/points_service.dart';
import 'package:pdh/services/timeline_service.dart';
import 'package:pdh/services/unified_milestone_audit.dart';

class DatabaseService {

  static final BackendAuthService _backend = BackendAuthService.instance;

  static String _iso(DateTime dt) => dt.toIso8601String();

  static DateTime? _parseBackendDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static Goal _goalFromMap(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    return Goal.fromMap(item, id: id);
  }

  static GoalMilestone _milestoneFromMap(
    Map<String, dynamic> item, {
    String? goalId,
  }) {
    return GoalMilestone.fromMap(
      item,
      id: item['id']?.toString(),
      goalId: goalId ?? item['goalId']?.toString(),
    );
  }

  static Future<Map<String, dynamic>> _fetchGoalData(String goalId) async {
    final items = await _backend.getGoals(goalId: goalId, limit: 1);
    if (items.isEmpty) {
      throw StateError('Goal not found');
    }
    return items.first;
  }

  static Future<List<Map<String, dynamic>>> _fetchGoalMilestones(
    String goalId,
  ) async {
    return _backend.getMilestones(goalId: goalId);
  }

  static Future<Map<String, dynamic>> _fetchUserData(String uid) async {
    try {
      return await _backend.getUser(uid);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Map<String, dynamic> _goalCreatePayload(
    Goal goal, {
    Map<String, dynamic>? extra,
  }) {
    return {
      'userId': goal.userId,
      'title': goal.title,
      'description': goal.description,
      'category': goal.category.name,
      'priority': goal.priority.name,
      'status': goal.status.name,
      'progress': goal.progress,
      'createdAt': _iso(goal.createdAt),
      'targetDate': _iso(goal.targetDate),
      'points': goal.points,
      'kpa': goal.kpa,
      'approvalStatus': GoalApprovalStatus.pending.name,
      'approvedByUserId': null,
      'approvedByName': null,
      'approvedAt': null,
      'rejectionReason': null,
      ...?extra,
    };
  }

  static List<dynamic> _normalizedEvidenceList(dynamic existing) {
    if (existing is List) {
      return List<dynamic>.from(existing);
    }
    if (existing is String && existing.trim().isNotEmpty) {
      return <dynamic>[existing.trim()];
    }
    return <dynamic>[];
  }

  static List<dynamic> _mergeEvidenceValues(
    dynamic existing,
    List<dynamic> additions,
  ) {
    final merged = _normalizedEvidenceList(existing);
    for (final item in additions) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        if (!merged.any((e) => e is Map && e['id'] == map['id'])) {
          merged.add(map);
        }
      } else if (item is String && item.trim().isNotEmpty) {
        final trimmed = item.trim();
        if (!merged.contains(trimmed)) {
          merged.add(trimmed);
        }
      }
    }
    return merged;
  }

  static Future<void> _createAuditEvent(Map<String, dynamic> event) async {
    final now = _iso(DateTime.now());
    final payload = Map<String, dynamic>.from(event);
    for (final key in ['submittedDate', 'timestamp', 'approvedDate', 'completedDate']) {
      payload.putIfAbsent(key, () => now);
    }
    await _backend.createAuditEntry(payload);
  }

  // Caps configuration
  static const int _dailyPointsCap = 400;
  static const int _weeklyPointsCap = 1500;
  static const int _milestoneCompletionPoints = 10;

  static String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  // Privacy enforcement helpers
  static Future<String> _getUserRole(String uid) async {
    try {
      final data = await _fetchUserData(uid);
      return (data['role'] ?? 'employee') as String;
    } catch (_) {
      return 'employee';
    }
  }

  // Role normalization used by approval routing so alias roles
  // (e.g. line_manager, super_admin) still follow the correct chain.
  static bool _isAdminLikeRole(String role) {
    final normalized = role.trim().toLowerCase();
    return normalized == 'admin' ||
        normalized == 'administrator' ||
        normalized == 'super_admin' ||
        normalized == 'superadmin' ||
        normalized.contains('admin');
  }

  static bool _isManagerLikeRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (_isAdminLikeRole(normalized)) return false;
    return normalized == 'manager' ||
        normalized == 'line_manager' ||
        normalized == 'linemanager' ||
        normalized.contains('manager');
  }

  static Future<Map<String, dynamic>> _getUserPrivacySettings(
    String uid,
  ) async {
    try {
      final data = await _fetchUserData(uid);
      final nested = data['data'];
      final extra = nested is Map<String, dynamic> ? nested : <String, dynamic>{};
      return {
        'privateGoals': data['privateGoals'] == true || extra['privateGoals'] == true,
        'privateMilestones':
            data['privateMilestones'] == true || extra['privateMilestones'] == true,
        'privateProgress':
            data['privateProgress'] == true || extra['privateProgress'] == true,
        'managerOnly': data['managerOnly'] == true,
        'teamShare': data['teamShare'] != false,
        'profileVisible': data['profileVisible'] == true,
      };
    } catch (_) {
      return {
        'privateGoals': false,
        'privateMilestones': false,
        'privateProgress': false,
        'managerOnly': false,
        'teamShare': true,
        'profileVisible': false,
      };
    }
  }

  static Future<bool> canViewerSeeUserProfile({
    required String viewerId,
    required String targetUserId,
  }) async {
    if (viewerId == targetUserId) return true;
    final role = await _getUserRole(viewerId);
    if (role == 'manager') return true;
    final settings = await _getUserPrivacySettings(targetUserId);
    return settings['profileVisible'] == true;
  }

  static Future<List<Goal>> getUserGoalsForViewer({
    required String viewerId,
    required String targetUserId,
  }) async {
    final isOwner = viewerId == targetUserId;
    final viewerRole = await _getUserRole(viewerId);
    final settings = await _getUserPrivacySettings(targetUserId);

    // Enforce managerOnly/privateGoals for non-owners and non-managers
    if (!isOwner && viewerRole != 'manager') {
      if (settings['managerOnly'] == true) {
        return <Goal>[];
      }
      if (settings['privateGoals'] == true) {
        return <Goal>[];
      }
    }

    // Fetch goals with optimized query
    final items = await _backend.getGoals(userId: targetUserId);
    var goals = items.map(_goalFromMap).toList();
    goals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    goals = goals.where((g) => g.isDisplayableGoal).toList();

    // If teamShare is disabled, hide completed goals from non-owners/non-managers
    if (!isOwner && viewerRole != 'manager' && settings['teamShare'] == false) {
      goals = goals.where((g) => g.status != GoalStatus.completed).toList();
    }
    return goals;
  }


  static Stream<List<Goal>> getUserGoalsStreamForViewer({
    required String viewerId,
    required String targetUserId,
  }) {
    return backendPollingStream<List<Goal>>(
      initialValue: const [],
      fetch: () async {
        final isOwner = viewerId == targetUserId;
        final viewerRole = await _getUserRole(viewerId);
        final settings = await _getUserPrivacySettings(targetUserId);

        if (!isOwner && viewerRole != 'manager') {
          if (settings['managerOnly'] == true ||
              settings['privateGoals'] == true) {
            return <Goal>[];
          }
        }

        var goals = (await _backend.getGoals(userId: targetUserId))
            .map(_goalFromMap)
            .toList();
        goals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (!isOwner &&
            viewerRole != 'manager' &&
            settings['teamShare'] == false) {
          goals = goals
              .where((g) => g.status != GoalStatus.completed)
              .toList();
        }
        return goals.where((g) => g.isDisplayableGoal).toList();
      },
    );
  }

  static String _weekKey(DateTime dt) {
    // Simple week-of-year approximation
    final firstDay = DateTime(dt.year, 1, 1);
    final days = dt.difference(firstDay).inDays;
    final week = (days / 7).floor() + 1;
    final w = week.toString().padLeft(2, '0');
    return '${dt.year}W$w';
  }

  static int _coerceInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value == null) return fallback;
    return int.tryParse(value.toString()) ?? fallback;
  }

  // Safely increment user points enforcing daily/weekly caps; returns awarded amount
  static Future<int> _incrementUserPointsCapped({
    required String userId,
    required int amount,
  }) async {
    if (amount <= 0) return 0;
    final now = DateTime.now();
    final dKey = _dateKey(now);
    final wKey = _weekKey(now);
    final data = await _fetchUserData(userId);
    if (data.isEmpty) return 0;

    final metrics = (data['metrics'] as Map<String, dynamic>?) ?? {};
    final points = (metrics['points'] as Map<String, dynamic>?) ?? {};
    final daily = Map<String, dynamic>.from(
      (points['daily'] as Map<String, dynamic>?) ?? {},
    );
    final weekly = Map<String, dynamic>.from(
      (points['weekly'] as Map<String, dynamic>?) ?? {},
    );
    final daySoFar = _coerceInt(daily[dKey]);
    final weekSoFar = _coerceInt(weekly[wKey]);
    final remainingDay = (_dailyPointsCap - daySoFar).clamp(0, _dailyPointsCap);
    final remainingWeek = (_weeklyPointsCap - weekSoFar).clamp(0, _weeklyPointsCap);
    final allow = amount.clamp(0, remainingDay).clamp(0, remainingWeek);
    if (allow <= 0) return 0;

    daily[dKey] = daySoFar + allow;
    weekly[wKey] = weekSoFar + allow;
    final totalPoints = _coerceInt(data['totalPoints']) + allow;
    final level = _calculateLevel(totalPoints);

    await _backend.updateUserProfile(userId, {
      'totalPoints': totalPoints,
      'level': level,
      'metrics': {
        ...metrics,
        'points': {
          ...points,
          'daily': daily,
          'weekly': weekly,
          'lastUpdated': _iso(now),
        },
      },
    });
    try {
      await _backend.createPointEvent({
        'userId': userId,
        'amount': allow,
        'timestamp': _iso(now),
      });
    } catch (_) {}
    return allow;
  }

  static Stream<UserProfile?> getUserProfileStream(String uid) {
    return backendPollingStream<UserProfile?>(
      fetch: () async {
        try {
          return await getUserProfile(uid);
        } catch (_) {
          return null;
        }
      },
    );
  }

  static Future<UserProfile> getUserProfile(
    String uid, {
    int retryCount = 0,
  }) async {
    // Check cache first
    final cache = PerformanceCacheService();
    final cached = cache.getCachedUserProfile();
    if (cached != null && cached.uid == uid) {
      return cached;
    }

    Map<String, dynamic> data = {};

    try {
      // Add small delay on retry to avoid race conditions
      if (retryCount > 0) {
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }

      data = await _fetchUserData(uid);

      // If displayName is missing/empty, try to sync from onboarding
      final displayName =
          data['displayName']?.toString() ?? data['fullName']?.toString() ?? '';
      if (displayName.isEmpty) {
        await syncOnboardingData(uid);
        data = await _fetchUserData(uid);
      }
    } catch (e) {
      if (cached != null && cached.uid == uid) {
        developer.log('Using cached profile due to error: $e');
        return cached;
      }
      rethrow;
    }

    final profile = UserProfile.fromMap(data, id: uid);

    // Cache the profile
    cache.cacheUserProfile(profile);
    return profile;
  }

  static Future<Map<String, dynamic>> _validateGoalApprovalAction({
    required String goalId,
    required String actorId,
    required bool approving,
  }) async {
    final data = await _fetchGoalData(goalId);
    final currentStatus =
        (data['approvalStatus'] ?? GoalApprovalStatus.pending.name).toString();
    if (currentStatus == GoalApprovalStatus.approved.name ||
        currentStatus == GoalApprovalStatus.rejected.name) {
      throw StateError('Goal has already been finalized');
    }
    final goalOwnerId = (data['userId'] ?? '').toString();
    if (goalOwnerId.isEmpty) {
      throw StateError('Goal has no owner');
    }
    final approverRoleRaw = (await _getUserRole(actorId)).trim().toLowerCase();
    final goalOwnerRoleRaw =
        (await _getUserRole(goalOwnerId)).trim().toLowerCase();
    final goalOwnerIsManagerLike = _isManagerLikeRole(goalOwnerRoleRaw);
    final approverIsAdminLike = _isAdminLikeRole(approverRoleRaw);
    final approverIsManagerLike = _isManagerLikeRole(approverRoleRaw);
    if (goalOwnerIsManagerLike && !approverIsAdminLike) {
      throw StateError(
        approving
            ? 'Manager-created goals must be approved by an admin'
            : 'Manager-created goals must be rejected by an admin',
      );
    }
    if (!goalOwnerIsManagerLike &&
        !approverIsManagerLike &&
        !approverIsAdminLike) {
      throw StateError(
        approving
            ? 'You do not have permission to approve this goal'
            : 'You do not have permission to reject this goal',
      );
    }
    return data;
  }

  static Future<void> approveGoal({
    required String goalId,
    required String managerId,
    required String managerName,
  }) async {
    Map<String, dynamic>? goalData;
    bool isSeasonFinalReview = false;
    goalData = await _validateGoalApprovalAction(
      goalId: goalId,
      actorId: managerId,
      approving: true,
    );
    isSeasonFinalReview =
        goalData['isSeasonGoal'] == true && goalData['approvalRequestedAt'] != null;
    await _backend.patchGoal(goalId, {
      'approvalStatus': GoalApprovalStatus.approved.name,
      'approvedByUserId': managerId,
      'approvedByName': managerName,
      'approvedAt': _iso(DateTime.now()),
      'rejectionReason': null,
      if (isSeasonFinalReview) 'status': GoalStatus.acknowledged.name,
    });
    if (goalData.isEmpty) return;

    if (isSeasonFinalReview) {
      try {
        await SeasonService.finalizeApprovedSeasonGoal(goalId: goalId);
      } catch (e) {
        developer.log('Error finalizing approved season goal: $e');
      }
      try {
        await _syncSeasonGoalFromGoalState(goalId);
      } catch (e) {
        developer.log('Error syncing approved season goal: $e');
      }
    }

    // Move pending approval request alert(s) out of inbox for this reviewer.
    try {
      await AlertService.markGoalApprovalAlertsAsFinalized(
        userId: managerId,
        goalId: goalId,
        approved: true,
      );
    } catch (e) {
      developer.log('Error finalizing manager approval-request alert: $e');
    }

    // Get employee details for audit
    String employeeName = '';
    String department = '';
    try {
      final employeeData = await _fetchUserData(
        (goalData['userId'] ?? '').toString(),
      );
      employeeName =
          employeeData['displayName'] ??
          employeeData['fullName'] ??
          employeeData['name'] ??
          employeeData['email'] ??
          '';
      department = employeeData['department'] ?? '';
    } catch (_) {}

    // Log approved goal audit
    try {
      await ApprovedGoalAuditService.logApprovedGoal(
        goalId: goalId,
        goalTitle: (goalData['title'] ?? '') as String,
        employeeId: (goalData['userId'] ?? '') as String? ?? '',
        employeeName: employeeName,
        department: department,
        approvedBy: managerId,
        approvedByName: managerName,
      );
    } catch (_) {}

    // Mirror approval into audit_entries so Repository & Audit + orderBy(submittedDate) feeds work.
    try {
      await _logGoalApprovedToAuditEntries(
        goalId: goalId,
        goalTitle: (goalData['title'] ?? '') as String,
        employeeUserId: (goalData['userId'] ?? '') as String,
        employeeName: employeeName,
        department: department,
        approvedByUid: managerId,
        approvedByName: managerName,
      );
    } catch (_) {}

    // Create approval alert for EMPLOYEE (existing functionality)
    try {
      await AlertService.createGoalApprovalDecisionAlert(
        employeeId: (goalData['userId'] ?? '') as String,
        goalId: goalId,
        goalTitle: (goalData['title'] ?? '') as String,
        approved: true,
      );
    } catch (e) {
      developer.log('Error creating employee approval alert: $e');
    }

    // Create approval alert for MANAGER (NEW - so manager sees approved goal in archived)
    try {
      final manager = FirebaseAuth.instance.currentUser;
      if (manager != null) {
        await AlertService.createGoalApprovalDecisionAlert(
          employeeId: manager.uid,
          goalId: goalId,
          goalTitle: (goalData['title'] ?? '') as String,
          approved: true,
        );
      }
    } catch (e) {
      developer.log('Error creating manager approval alert: $e');
    }
  }

  static Future<void> rejectGoal({
    required String goalId,
    required String managerId,
    required String managerName,
    String? reason,
  }) async {
    Map<String, dynamic>? goalData;
    bool isSeasonFinalReview = false;
    goalData = await _validateGoalApprovalAction(
      goalId: goalId,
      actorId: managerId,
      approving: false,
    );
    isSeasonFinalReview =
        goalData['isSeasonGoal'] == true && goalData['approvalRequestedAt'] != null;
    await _backend.patchGoal(goalId, {
      'approvalStatus': GoalApprovalStatus.rejected.name,
      'approvedByUserId': managerId,
      'approvedByName': managerName,
      'approvedAt': _iso(DateTime.now()),
      'rejectionReason': reason,
      if (isSeasonFinalReview) 'status': GoalStatus.inProgress.name,
    });
    if (goalData.isEmpty) return;

    if (isSeasonFinalReview) {
      try {
        await _syncSeasonGoalFromGoalState(goalId);
      } catch (e) {
        developer.log('Error syncing rejected season goal: $e');
      }
    }

    // Move pending approval request alert(s) out of inbox for this reviewer.
    try {
      await AlertService.markGoalApprovalAlertsAsFinalized(
        userId: managerId,
        goalId: goalId,
        approved: false,
      );
    } catch (e) {
      developer.log('Error finalizing manager rejection-request alert: $e');
    }

    try {
      await AlertService.createGoalApprovalDecisionAlert(
        employeeId: (goalData['userId'] ?? '') as String,
        goalId: goalId,
        goalTitle: (goalData['title'] ?? '') as String,
        approved: false,
        reason: reason,
      );
    } catch (_) {}

    // Log goal rejection to audit trail (include owner labels like approvals)
    String ownerName = '';
    String ownerDept = '';
    try {
      final ownerId = (goalData['userId'] ?? '').toString();
      if (ownerId.isNotEmpty) {
        final odMap = await _fetchUserData(ownerId);
        ownerName =
            odMap['displayName'] ??
            odMap['fullName'] ??
            odMap['name'] ??
            odMap['email'] ??
            '';
        ownerDept = odMap['department']?.toString() ?? '';
      }
    } catch (_) {}

    try {
      await _logGoalRejected(
        goalId: goalId,
        goalTitle: (goalData['title'] ?? '') as String? ?? '',
        userId: (goalData['userId'] ?? '') as String? ?? '',
        rejectionReason: reason ?? '',
        ownerDisplayName: ownerName,
        ownerDepartment: ownerDept,
      );
    } catch (e) {
      developer.log('Error logging goal rejection: $e');
    }

    // Create rejection alert for MANAGER (NEW - so manager sees rejected goal in archived)
    try {
      final manager = FirebaseAuth.instance.currentUser;
      if (manager != null) {
        await AlertService.createGoalApprovalDecisionAlert(
          employeeId: manager.uid,
          goalId: goalId,
          goalTitle: (goalData['title'] ?? '') as String,
          approved: false,
          reason: reason,
        );
      }
    } catch (e) {
      developer.log('Error creating manager rejection alert: $e');
    }
  }

  static Future<Goal?> getGoalById(String goalId) async {
    try {
      final items = await _backend.getGoals(goalId: goalId, limit: 1);
      if (items.isEmpty) return null;
      return _goalFromMap(items.first);
    } catch (_) {
      return null;
    }
  }

  static Stream<Goal?> getGoalStream(String goalId) {
    return backendPollingStream<Goal?>(
      fetch: () => getGoalById(goalId),
    );
  }

  static Stream<Map<String, dynamic>?> getGoalDataStream(String goalId) {
    return backendPollingStream<Map<String, dynamic>?>(
      fetch: () async {
        final items = await _backend.getGoals(goalId: goalId, limit: 1);
        return items.isEmpty ? null : items.first;
      },
    );
  }

  static Future<List<Goal>> getUserGoals(String uid) async {
    try {
      final viewer = FirebaseAuth.instance.currentUser?.uid ?? uid;
      return await getUserGoalsForViewer(viewerId: viewer, targetUserId: uid);
    } catch (e) {
      return [];
    }
  }

  static Stream<List<Goal>> getUserGoalsStream(String uid) {
    final viewer = FirebaseAuth.instance.currentUser?.uid ?? uid;
    return getUserGoalsStreamForViewer(viewerId: viewer, targetUserId: uid);
  }

  static Future<String> createGoal(
    Goal goal, {
    String? sourceWorkspace,
    String? sourceRoute,
  }) async {
    const int maxAttempts = 3;
    const List<int> retryDelaysMs = [250, 500];
    Object? lastError;
    String? createdGoalId;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final created = await _backend.createGoal(
          _goalCreatePayload(
            goal,
            extra: {
              if (sourceWorkspace != null && sourceWorkspace.trim().isNotEmpty)
                'sourceWorkspace': sourceWorkspace.trim(),
              if (sourceRoute != null && sourceRoute.trim().isNotEmpty)
                'sourceRoute': sourceRoute.trim(),
            },
          ),
        );
        createdGoalId =
            created['id']?.toString() ?? created['goalId']?.toString();
        if (createdGoalId == null || createdGoalId.isEmpty) {
          throw StateError('Backend did not return a goal id');
        }
        developer.log('Goal created successfully: $createdGoalId');
        lastError = null;
        Future(() async {
          try {
            await _logGoalCreated(
              goalId: createdGoalId!,
              goalTitle: goal.title,
              userId: goal.userId,
            );
          } catch (e) {
            developer.log('Error logging goal creation: $e');
          }
        });
        break;
      } catch (e) {
        lastError = e;
        developer.log(
          'Goal create attempt ${attempt + 1}/$maxAttempts failed: $e',
        );
        if (attempt < maxAttempts - 1) {
          final delayMs =
              retryDelaysMs[attempt.clamp(0, retryDelaysMs.length - 1)];
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          rethrow;
        }
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    if (createdGoalId == null) {
      throw StateError('Goal create failed after $maxAttempts attempts');
    }

    const int approvalDispatchAttempts = 3;
    var approvalErrorText = '';
    var approvalSent = false;
    for (int i = 0; i < approvalDispatchAttempts; i++) {
      try {
        await requestGoalApproval(
          goalId: createdGoalId,
          userId: goal.userId,
          goalTitle: goal.title,
          sourceWorkspace: sourceWorkspace,
        );
        approvalSent = true;
        break;
      } catch (e) {
        approvalErrorText = e.toString();
        developer.log(
          'Goal approval dispatch attempt ${i + 1}/$approvalDispatchAttempts failed for $createdGoalId: $e',
        );
        if (i < approvalDispatchAttempts - 1) {
          await Future.delayed(
            Duration(
              milliseconds:
                  retryDelaysMs[i.clamp(0, retryDelaysMs.length - 1)],
            ),
          );
        }
      }
    }

    await _backend.patchGoal(createdGoalId, {
      'approvalDispatchStatus': approvalSent ? 'sent' : 'failed',
      'approvalDispatchUpdatedAt': _iso(DateTime.now()),
      if (!approvalSent) 'approvalDispatchError': approvalErrorText,
    });

    return createdGoalId;
  }

  static Future<void> requestGoalApproval({
    required String goalId,
    required String userId,
    required String goalTitle,
    String? sourceWorkspace,
  }) async {
    final ownerRole = (await _getUserRole(userId)).trim().toLowerCase();
    final requiredApproverRole = _isManagerLikeRole(ownerRole)
        ? 'admin'
        : 'manager';

    Future<void> attempt(int attemptCount) async {
      try {
        Map<String, dynamic>? dispatchResult;
        await _backend.patchGoal(goalId, {
          'approvalStatus': GoalApprovalStatus.pending.name,
          'approvalRequestedAt': _iso(DateTime.now()),
          'requiredApproverRole': requiredApproverRole,
          'approvalRoleResolvedFrom': ownerRole,
          if (sourceWorkspace != null && sourceWorkspace.trim().isNotEmpty)
            'approvalSourceWorkspace': sourceWorkspace.trim(),
        });

        dispatchResult = await AlertService.createGoalApprovalRequestedAlert(
          employeeId: userId,
          goalId: goalId,
          goalTitle: goalTitle,
          approverRole: requiredApproverRole,
        );
        await _backend.patchGoal(goalId, {
          'approvalDispatchRecipients':
              List<String>.from(dispatchResult['recipientIds'] ?? const []),
          'approvalDispatchRecipientEmails':
              List<String>.from(dispatchResult['recipientEmails'] ?? const []),
          'approvalDispatchWriteCount': dispatchResult['successfulWrites'] ?? 0,
          'approvalDispatchApproverRole':
              dispatchResult['approverRole'] ?? requiredApproverRole,
          'approvalDispatchUpdatedAt': _iso(DateTime.now()),
        });

        try {
          final ownerMap = await _fetchUserData(userId);
          final ownerName =
              (ownerMap['displayName'] ??
                      ownerMap['fullName'] ??
                      ownerMap['name'] ??
                      ownerMap['email'] ??
                      '')
                  .toString();
          final ownerDept = (ownerMap['department'] ?? '').toString();
          await _logGoalSubmittedToAuditEntries(
            goalId: goalId,
            goalTitle: goalTitle,
            userId: userId,
            userDisplayName: ownerName,
            userDepartment: ownerDept,
            requiredApproverRole: requiredApproverRole,
          );
        } catch (e) {
          developer.log('Error logging goal submission: $e');
        }
      } catch (e) {
        if (attemptCount < 1) {
          await Future.delayed(const Duration(milliseconds: 200));
          return attempt(attemptCount + 1);
        }
        rethrow;
      }
    }

    await attempt(0);
  }

  static Future<void> submitSeasonGoalForFinalReview({
    required String goalId,
    required String userId,
    required String goalTitle,
    required String finalEvidence,
  }) async {
    final trimmedEvidence = finalEvidence.trim();
    if (trimmedEvidence.isEmpty) {
      throw Exception('Please provide final evidence before submitting.');
    }

    final data = await _fetchGoalData(goalId);
    if (data['userId'] != userId || data['isSeasonGoal'] != true) {
      throw Exception('You are not allowed to submit this season goal.');
    }

    final progress = _coerceInt(data['progress']);
    if (progress < 100) {
      throw Exception('Set progress to 100% before submitting final review.');
    }

    await _backend.patchGoal(goalId, {
      'status': GoalStatus.completed.name,
      'progress': 100,
      'completedAt': _iso(DateTime.now()),
      'evidence': _mergeEvidenceValues(data['evidence'], [trimmedEvidence]),
      'seasonFinalReviewSubmittedAt': _iso(DateTime.now()),
      'seasonFinalReviewEvidence': trimmedEvidence,
      'approvalStatus': GoalApprovalStatus.pending.name,
      'approvedByUserId': null,
      'approvedByName': null,
      'approvedAt': null,
      'rejectionReason': null,
      'updatedAt': _iso(DateTime.now()),
    });

    await requestGoalApproval(
      goalId: goalId,
      userId: userId,
      goalTitle: goalTitle,
      sourceWorkspace: 'season_final_review',
    );

    await _syncSeasonGoalFromGoalState(goalId);
  }

  static Future<void> patchGoalFields(
    String goalId,
    Map<String, dynamic> fields,
  ) {
    final payload = Map<String, dynamic>.from(fields);
    for (final key in ['targetDate', 'lastUpdated', 'approvedAt', 'createdAt']) {
      final value = payload[key];
      if (value is DateTime) {
        payload[key] = _iso(value);
      }
    }
    return _backend.patchGoal(goalId, payload);
  }

  static Future<void> updateGoal(Goal goal) async {
    await _backend.patchGoal(goal.id, {
      'title': goal.title,
      'description': goal.description,
      'category': goal.category.name,
      'priority': goal.priority.name,
      'status': goal.status.name,
      'progress': goal.progress,
      'targetDate': _iso(goal.targetDate),
      'points': goal.points,
      'kpa': goal.kpa,
    });
  }

  // NEW: Submit milestone with evidence - atomic operation for workflow
  static Future<void> submitMilestoneWithEvidence({
    required String goalId,
    required String milestoneId,
    required MilestoneEvidence evidence,
  }) async {
    final now = DateTime.now();
    final goalMeta = await _fetchGoalData(goalId);
    final isSeasonGoal = goalMeta['isSeasonGoal'] == true;

    final milestones = await _fetchGoalMilestones(goalId);
    final milestoneSnapshot = milestones.firstWhere(
      (item) => item['id']?.toString() == milestoneId,
      orElse: () => throw Exception('Milestone not found'),
    );
    final currentStatus = _goalMilestoneStatusFromString(
      milestoneSnapshot['status']?.toString(),
    );

    await _backend.patchMilestone(milestoneId, {
      'goalId': goalId,
      'evidence': _mergeEvidenceValues(
        milestoneSnapshot['evidence'],
        [evidence.toMap()],
      ),
      'status': _statusAfterEvidenceSubmission(
        isSeasonGoal: isSeasonGoal,
        currentStatus: currentStatus,
      ).name,
      'updatedAt': _iso(now),
    });

    try {
      await _backend.createMilestoneEvidence({
        ...evidence.toMap(),
        'goalId': goalId,
        'milestoneId': milestoneId,
      });
    } catch (e) {
      developer.log('Error storing milestone evidence record: $e');
    }

    final milestone = _milestoneFromMap(
      {
        ...milestoneSnapshot,
        'evidence': _mergeEvidenceValues(
          milestoneSnapshot['evidence'],
          [evidence.toMap()],
        ),
      },
      goalId: goalId,
    );
    await _handleMilestoneEvidenceSubmission(
      goalId: goalId,
      milestone: milestone,
      evidenceList: [evidence],
    );
    await _syncSeasonGoalFromGoalState(goalId);
  }

  // Submit multiple milestone evidence files — sequential updates to avoid backend race conditions
  static Future<void> submitMultipleMilestoneEvidence({
    required String goalId,
    required String milestoneId,
    required List<MilestoneEvidence> evidenceList,
  }) async {
    final goalMeta = await _fetchGoalData(goalId);
    final isSeasonGoal = goalMeta['isSeasonGoal'] == true;

    Future<void> attempt(int attemptCount) async {
      final evidenceMaps = evidenceList.map((e) => e.toMap()).toList();

      try {
        final milestones = await _fetchGoalMilestones(goalId);
        final milestoneSnapshot = milestones.firstWhere(
          (item) => item['id']?.toString() == milestoneId,
          orElse: () => throw Exception('Milestone not found'),
        );
        final currentStatus = _goalMilestoneStatusFromString(
          milestoneSnapshot['status']?.toString(),
        );

        await _backend.patchMilestone(milestoneId, {
          'goalId': goalId,
          'evidence': _mergeEvidenceValues(
            milestoneSnapshot['evidence'],
            evidenceMaps,
          ),
          'status': _statusAfterEvidenceSubmission(
            isSeasonGoal: isSeasonGoal,
            currentStatus: currentStatus,
          ).name,
          'updatedAt': _iso(DateTime.now()),
        });

        developer.log(
          'Successfully submitted evidence for milestone: $milestoneId',
        );

        try {
          final milestone = _milestoneFromMap(
            {
              ...milestoneSnapshot,
              'evidence': _mergeEvidenceValues(
                milestoneSnapshot['evidence'],
                evidenceMaps,
              ),
            },
            goalId: goalId,
          );
          await _handleMilestoneEvidenceSubmission(
            goalId: goalId,
            milestone: milestone,
            evidenceList: evidenceList,
          );
        } catch (notificationError) {
          developer.log(
            'Error sending evidence submission notification: $notificationError',
          );
        }
      } catch (e) {
        developer.log('Error submitting milestone evidence: $e');

        if (_isPermissionDeniedError(e)) {
          throw Exception(
            'You do not have permission to submit evidence for this milestone. Please contact your manager.',
          );
        } else if (attemptCount < 2) {
          await Future.delayed(Duration(milliseconds: 200 * (attemptCount + 1)));
          return attempt(attemptCount + 1);
        } else if (_isDocumentNotFoundError(e)) {
          throw Exception(
            'The milestone could not be found. It may have been deleted.',
          );
        } else {
          throw Exception('Failed to submit evidence. Please try again later.');
        }
      }
    }

    await attempt(0);
    await _syncSeasonGoalFromGoalState(goalId);
  }

  // Helper methods for error detection
  static bool _isPermissionDeniedError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('permission-denied') ||
        errorString.contains('permission denied') ||
        errorString.contains('missing or insufficient permissions') ||
        errorString.contains('firestore: permission-denied');
  }

  static bool _isDocumentNotFoundError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('not-found') ||
        errorString.contains('not found') ||
        errorString.contains('firestore: not-found');
  }

  static GoalMilestoneStatus? _goalMilestoneStatusFromString(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    for (final status in GoalMilestoneStatus.values) {
      if (status.name == value) {
        return status;
      }
    }
    return null;
  }

  static GoalMilestoneStatus _statusAfterEvidenceSubmission({
    required bool isSeasonGoal,
    GoalMilestoneStatus? currentStatus,
  }) {
    if (!isSeasonGoal) {
      return GoalMilestoneStatus.pendingManagerReview;
    }

    switch (currentStatus) {
      case GoalMilestoneStatus.completedAcknowledged:
        return GoalMilestoneStatus.completedAcknowledged;
      case GoalMilestoneStatus.completed:
        return GoalMilestoneStatus.completed;
      case GoalMilestoneStatus.blocked:
        return GoalMilestoneStatus.blocked;
      case GoalMilestoneStatus.pendingManagerReview:
      case GoalMilestoneStatus.inProgress:
      case GoalMilestoneStatus.notStarted:
      case null:
        return GoalMilestoneStatus.inProgress;
    }
  }

  // NEW: Handle milestone evidence submission notifications
  static Future<void> _handleMilestoneEvidenceSubmission({
    required String goalId,
    required GoalMilestone milestone,
    required List<MilestoneEvidence> evidenceList,
  }) async {
    try {
      // Get goal details for notification
      final goal = _goalFromMap(await _fetchGoalData(goalId));

      // Send notification to manager with correct evidence count
      await AlertService.createMilestoneEvidenceSubmittedAlert(
        employeeId: goal.userId,
        goalId: goalId,
        milestoneId: milestone.id,
        milestoneTitle: milestone.title,
        evidenceCount: evidenceList.length, // Use actual list length
      );
    } catch (e) {
      developer.log('Error sending evidence submission notification: $e');
    }
  }

  // NEW: Manager acknowledges milestone completion
  static Future<void> acknowledgeMilestone({
    required String goalId,
    required String milestoneId,
    required String managerId,
    required String managerName,
    String? checkInNotes,
  }) async {
    final now = DateTime.now();

    try {
      final milestones = await _fetchGoalMilestones(goalId);
      final milestoneSnapshot = milestones.firstWhere(
        (item) => item['id']?.toString() == milestoneId,
        orElse: () => <String, dynamic>{},
      );
      if (milestoneSnapshot.isEmpty) {
        throw Exception('Milestone not found. It may have been deleted.');
      }

      final milestone = _milestoneFromMap(milestoneSnapshot, goalId: goalId);

      await _backend.patchMilestone(milestoneId, {
        'goalId': goalId,
        'status': GoalMilestoneStatus.completedAcknowledged.name,
        'updatedAt': _iso(now),
        'acknowledgedAt': _iso(now),
        'acknowledgedBy': managerId,
        'acknowledgedByName': managerName,
        'checkInNotes': checkInNotes ?? '',
      });

      // Log manager acknowledgment in audit timeline
      try {
        final auditEvent = TimelineService.buildEvent(
          eventType: 'milestone_acknowledged',
          description:
              'Manager acknowledged milestone: "${milestone.title}"${checkInNotes != null && checkInNotes.isNotEmpty ? ' with notes: "$checkInNotes"' : ''}',
          actorIdOverride: managerId,
          actorNameOverride: managerName,
        );

        await TimelineService.logEvent(goalId, auditEvent);
      } catch (auditError) {
        developer.log(
          'Error logging milestone acknowledgment in audit timeline: $auditError',
        );
        // Don't fail the whole operation if audit logging fails
      }

      // Send notification to employee (non-critical)
      try {
        await _sendMilestoneAcknowledgedNotification(
          goalId: goalId,
          milestone: milestone,
          managerId: managerId,
          managerName: managerName,
          checkInNotes: checkInNotes,
        );
      } catch (notificationError) {
        developer.log(
          'Error sending acknowledgement notification: $notificationError',
        );
        // Don't fail the whole operation if notification fails
      }

      await _syncSeasonGoalFromGoalState(goalId);

      developer.log('Milestone acknowledged: $milestoneId by $managerName');
    } catch (e) {
      developer.log('Error acknowledging milestone: $e');

      // Handle different types of errors with specific messages
      if (_isPermissionDeniedError(e)) {
        throw Exception(
          'You do not have permission to acknowledge this milestone. Please check your access rights.',
        );
      } else if (_isDocumentNotFoundError(e)) {
        throw Exception(
          'The milestone could not be found. It may have been deleted. Please refresh the page.',
        );
      } else {
        throw Exception('Failed to acknowledge milestone: ${e.toString()}');
      }
    }
  }

  // NEW: Send notification to employee about milestone acknowledgement
  static Future<void> _sendMilestoneAcknowledgedNotification({
    required String goalId,
    required GoalMilestone milestone,
    required String managerId,
    required String managerName,
    String? checkInNotes,
  }) async {
    try {
      // Get goal details
      final goal = _goalFromMap(await _fetchGoalData(goalId));

      // Create notification for employee
      await AlertService.createMilestoneAcknowledgedAlert(
        employeeId: goal.userId,
        goalId: goalId,
        milestoneId: milestone.id,
        milestoneTitle: milestone.title,
        managerName: managerName,
        checkInNotes: checkInNotes,
      );
    } catch (e) {
      developer.log('Error sending acknowledgement notification: $e');
    }
  }

  static Future<String> getUserName(String userId) async {
    try {
      final data = await _fetchUserData(userId);
      return data['displayName']?.toString() ??
          data['name']?.toString() ??
          'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  static Stream<List<GoalMilestone>> getGoalMilestonesStream(String goalId) {
    return backendPollingListStream<GoalMilestone>(
      fetch: () => _backend.getMilestones(goalId: goalId),
      mapper: (item) => _milestoneFromMap(item, goalId: goalId),
    );
  }

  static Future<String> addGoalMilestone({
    required String goalId,
    required String title,
    required String description,
    required DateTime dueDate,
    required String createdBy,
    String? createdByName,
    GoalMilestoneStatus status = GoalMilestoneStatus.notStarted,
    // REMOVED: requiresEvidence parameter - no longer needed
  }) async {
    final now = DateTime.now();
    final created = await _backend.createMilestone({
      'goalId': goalId,
      'title': title,
      'description': description,
      'status': status.name,
      'dueDate': _iso(dueDate),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': _iso(now),
      'updatedAt': _iso(now),
      'completedAt': status == GoalMilestoneStatus.completed ? _iso(now) : null,
      'evidence': <dynamic>[],
    });
    final milestoneId =
        created['id']?.toString() ?? created['milestoneId']?.toString() ?? '';
    final milestone = _milestoneFromMap(created, goalId: goalId);

    try {
      final goalData = await _fetchGoalData(goalId);
      final goalTitle = goalData['title'] ?? 'Unknown Goal';

      await UnifiedMilestoneAudit.logMilestoneCreated(
        goalId: goalId,
        milestoneId: milestone.id,
        milestoneTitle: milestone.title,
        goalTitle: goalTitle,
      );
    } catch (e) {
      developer.log('Failed to log milestone creation: $e');
    }

    await _afterMilestoneMutation(
      goalId: goalId,
      milestone: milestone,
      previousStatus: null,
    );
    return milestoneId;
  }

  static Future<void> updateGoalMilestone({
    required String goalId,
    required String milestoneId,
    String? title,
    String? description,
    DateTime? dueDate,
    GoalMilestoneStatus? status,
  }) async {
    Map<String, dynamic>? goalData;
    bool goalCompleted = false;
    try {
      goalData = await _fetchGoalData(goalId);
      final String rawStatus =
          (goalData['status'] ?? GoalStatus.notStarted.name).toString();
      goalCompleted = rawStatus == GoalStatus.completed.name;
    } catch (e) {
      throw Exception('Failed to load goal for milestone update: $e');
    }

    GoalMilestoneStatus? previousStatus;
    Map<String, dynamic> beforeSnapshot = {};
    try {
      final milestones = await _fetchGoalMilestones(goalId);
      beforeSnapshot = milestones.firstWhere(
        (item) => item['id']?.toString() == milestoneId,
        orElse: () => <String, dynamic>{},
      );
      if (beforeSnapshot.isNotEmpty) {
        previousStatus = _milestoneFromMap(beforeSnapshot, goalId: goalId).status;
      }
    } catch (_) {}

    if (goalCompleted &&
        status != null &&
        previousStatus == GoalMilestoneStatus.completed &&
        status != GoalMilestoneStatus.completed) {
      throw Exception('Completed goals cannot reopen completed milestones.');
    }

    final Map<String, dynamic> updates = {
      'goalId': goalId,
      'updatedAt': _iso(DateTime.now()),
    };
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (dueDate != null) updates['dueDate'] = _iso(dueDate);
    if (status != null) {
      if (status == GoalMilestoneStatus.completed) {
        final canComplete = await MilestoneEvidenceService.canCompleteMilestone(
          goalId: goalId,
          milestoneId: milestoneId,
        );
        if (!canComplete) {
          throw Exception(
            'Milestone requires approved evidence before completion.',
          );
        }
      }

      updates['status'] = status.name;
      if (status == GoalMilestoneStatus.completed) {
        updates['completedAt'] = _iso(DateTime.now());
      } else {
        updates['completedAt'] = null;
      }
    }
    await _backend.patchMilestone(milestoneId, updates);
    final afterSnapshot = {...beforeSnapshot, ...updates};
    final milestone = _milestoneFromMap(afterSnapshot, goalId: goalId);

    try {
      final goalTitle = goalData['title'] ?? 'Unknown Goal';

      // Log milestone update if any field changed
      if (title != null || description != null || dueDate != null) {
        final changes = <String, dynamic>{};
        if (title != null) changes['title'] = title;
        if (description != null) changes['description'] = description;
        if (dueDate != null) changes['dueDate'] = dueDate.toString();

        await UnifiedMilestoneAudit.logMilestoneStatusChanged(
          goalId: goalId,
          milestoneId: milestone.id,
          milestoneTitle: milestone.title,
          goalTitle: goalTitle,
          oldStatus: previousStatus?.name ?? 'NotStarted',
          newStatus: status?.name ?? 'NotStarted',
        );
      }

      // Log milestone status change
      if (status != null &&
          previousStatus != null &&
          status != previousStatus) {
        await UnifiedMilestoneAudit.logMilestoneStatusChanged(
          goalId: goalId,
          milestoneId: milestone.id,
          milestoneTitle: milestone.title,
          goalTitle: goalTitle,
          oldStatus: previousStatus.name,
          newStatus: status.name,
        );
      }
    } catch (e) {
      developer.log('Failed to log milestone update: $e');
    }

    await _afterMilestoneMutation(
      goalId: goalId,
      milestone: milestone,
      previousStatus: previousStatus,
    );
  }

  static Future<void> _afterMilestoneMutation({
    required String goalId,
    required GoalMilestone milestone,
    GoalMilestoneStatus? previousStatus,
  }) async {
    await _syncGoalProgressWithMilestones(goalId);
    await _syncSeasonGoalFromGoalState(goalId);
    if (milestone.status == GoalMilestoneStatus.completed &&
        previousStatus != GoalMilestoneStatus.completed) {
      await _handleMilestoneCompletion(goalId, milestone);
    }
  }

  static Future<void> _handleMilestoneCompletion(
    String goalId,
    GoalMilestone milestone,
  ) async {
    try {
      final goal = _goalFromMap(await _fetchGoalData(goalId));
      if (goal.userId.isEmpty) return;

      try {
        final awarded = await _incrementUserPointsCapped(
          userId: goal.userId,
          amount: _milestoneCompletionPoints,
        );
        if (awarded > 0) {
          await AlertService.createPointsAlert(
            userId: goal.userId,
            pointsEarned: awarded,
            reason: 'completing milestone "${milestone.title}"',
          );
        }
      } catch (e) {
        developer.log('Milestone points award failed: $e');
      }

      try {
        await AlertService.createMotivationalAlert(
          userId: goal.userId,
          message:
              'Milestone "${milestone.title}" completed for "${goal.title}".',
          goalId: goal.id,
        );
      } catch (e) {
        developer.log('Motivational alert failed: $e');
      }

      // NEW: Extended manager notification with evidence info (additive extension)
      try {
        await AlertService.createManagerMilestoneAlert(
          goal: goal,
          milestoneTitle: milestone.title,
          milestoneId: milestone.id, // Pass milestone ID for evidence checking
        );
      } catch (e) {
        developer.log('Manager milestone alert failed: $e');
      }
    } catch (e) {
      developer.log('Milestone completion handling failed: $e');
      developer.log('handleMilestoneCompletion error: $e');
    }
  }

  static Future<void> _syncGoalProgressWithMilestones(String goalId) async {
    try {
      final milestoneItems = await _fetchGoalMilestones(goalId);
      final total = milestoneItems.length;
      final completed = milestoneItems.where((data) {
        final status = (data['status'] ?? '').toString();
        return status == GoalMilestoneStatus.completed.name ||
            status == GoalMilestoneStatus.completedAcknowledged.name;
      }).length;

      final int rawPercent = total == 0
          ? 0
          : ((completed / total) * 100).round();
      final int percent = rawPercent.clamp(0, 100);

      final summary = <String, dynamic>{
        'total': total,
        'completed': completed,
        'percentage': percent,
      };

      final data = await _fetchGoalData(goalId);
      final current = data['milestoneSummary'];
      bool alreadySynced = false;
      if (current is Map<String, dynamic>) {
        final totalMatch = _coerceInt(current['total']) == total;
        final completedMatch = _coerceInt(current['completed']) == completed;
        final percentMatch =
            _coerceInt(current['percentage'] ?? current['percent']) == percent;
        alreadySynced = totalMatch && completedMatch && percentMatch;
      }
      if (alreadySynced) return;

      await _backend.patchGoal(goalId, {
        'milestoneSummary': summary,
        'updatedAt': _iso(DateTime.now()),
      });
    } catch (e) {
      developer.log('syncGoalProgressWithMilestones error: $e');
    }
  }

  static Future<void> _syncSeasonGoalFromGoalState(String goalId) async {
    try {
      final goalData = await _fetchGoalData(goalId);
      if (goalData.isEmpty) return;
      if (goalData['isSeasonGoal'] != true) return;

      final seasonId = (goalData['seasonId'] ?? '').toString().trim();
      final challengeId = (goalData['challengeId'] ?? '').toString().trim();
      final userId = (goalData['userId'] ?? '').toString().trim();
      if (seasonId.isEmpty || challengeId.isEmpty || userId.isEmpty) return;

      final season = await SeasonService.getSeason(seasonId);
      if (season == null) return;
      SeasonChallenge? challenge;
      for (final candidate in season.challenges) {
        if (candidate.id == challengeId) {
          challenge = candidate;
          break;
        }
      }
      if (challenge == null) return;

      final participation = season.participations[userId];
      final goalProgress = _coerceInt(goalData['progress']);
      final goalStatus = (goalData['status'] ?? '').toString();
      final goalApprovalStatus = (goalData['approvalStatus'] ?? '')
          .toString()
          .trim();
      final goalApprovalRequested = goalData['approvalRequestedAt'] != null;
      final rawGoalEvidence = goalData['evidence'];
      final goalHasEvidence =
          (rawGoalEvidence is List && rawGoalEvidence.isNotEmpty) ||
          (rawGoalEvidence is String && rawGoalEvidence.trim().isNotEmpty);

      final goalMilestoneData = await _fetchGoalMilestones(goalId);

      final hasPendingReview = goalMilestoneData.any(
        (data) => (data['status'] ?? '').toString() ==
            GoalMilestoneStatus.pendingManagerReview.name,
      );
      final hasStartedCustomMilestone = goalMilestoneData.any((data) {
        final rawStatus = (data['status'] ?? '').toString();
        return rawStatus == GoalMilestoneStatus.inProgress.name ||
            rawStatus == GoalMilestoneStatus.pendingManagerReview.name ||
            rawStatus == GoalMilestoneStatus.completed.name ||
            rawStatus == GoalMilestoneStatus.completedAcknowledged.name;
      });

      for (final milestone in challenge.milestones) {
        final desiredStatus = _deriveSeasonMilestoneStatusFromGoal(
          milestone: milestone,
          goalProgress: goalProgress,
          goalStatus: goalStatus,
          goalApprovalStatus: goalApprovalStatus,
          goalApprovalRequested: goalApprovalRequested,
          goalHasEvidence: goalHasEvidence,
          hasPendingReview: hasPendingReview,
          hasStartedCustomMilestone: hasStartedCustomMilestone,
        );
        final currentStatus =
            participation?.milestoneProgress['${challenge.id}.${milestone.id}'] ??
            participation?.milestoneProgress[milestone.id];
        if (desiredStatus == null || currentStatus == desiredStatus) {
          continue;
        }
        if (currentStatus == MilestoneStatus.completed &&
            desiredStatus != MilestoneStatus.completed) {
          continue;
        }

        await SeasonService.updateMilestoneProgress(
          seasonId: seasonId,
          userId: userId,
          milestoneId: milestone.id,
          status: desiredStatus,
          notifyManager: desiredStatus == MilestoneStatus.completed,
          syncGoalProgress: false,
        );
      }
    } catch (e) {
      developer.log('syncSeasonGoalFromGoalState error: $e');
    }
  }

  static MilestoneStatus? _deriveSeasonMilestoneStatusFromGoal({
    required SeasonMilestone milestone,
    required int goalProgress,
    required String goalStatus,
    required String goalApprovalStatus,
    required bool goalApprovalRequested,
    required bool goalHasEvidence,
    required bool hasPendingReview,
    required bool hasStartedCustomMilestone,
  }) {
    final criteria = milestone.criteria;
    if (criteria['managerReview'] == true || criteria['proofApproval'] == true) {
      final hasFinalApproval =
          (goalApprovalRequested &&
              goalApprovalStatus == GoalApprovalStatus.approved.name) ||
          goalStatus == GoalStatus.acknowledged.name;
      final hasFinalSubmission =
          goalApprovalRequested ||
          goalStatus == GoalStatus.completed.name ||
          goalHasEvidence;
      if (hasFinalApproval) {
        return MilestoneStatus.completed;
      }
      if (hasFinalSubmission || hasPendingReview) {
        return MilestoneStatus.inProgress;
      }
      return MilestoneStatus.notStarted;
    }

    final progressThreshold = criteria['progress'];
    if (progressThreshold is num) {
      if (goalProgress >= progressThreshold.round()) {
        return MilestoneStatus.completed;
      }
      if (goalProgress > 0) {
        return MilestoneStatus.inProgress;
      }
      return MilestoneStatus.notStarted;
    }

    final action = (criteria['action'] ?? '').toString();
    final hasStartedGoal = goalProgress > 0 ||
        goalStatus == GoalStatus.inProgress.name ||
        goalStatus == GoalStatus.completed.name ||
        goalStatus == GoalStatus.acknowledged.name;
    if (action == 'start_learning' ||
        action == 'project_start' ||
        action == 'goal_set' ||
        action == 'skill_assessment') {
      return hasStartedGoal ? MilestoneStatus.completed : MilestoneStatus.notStarted;
    }
    if (action == 'project_complete') {
      if (goalProgress >= 100) return MilestoneStatus.completed;
      if (hasStartedGoal) return MilestoneStatus.inProgress;
      return MilestoneStatus.notStarted;
    }

    if (hasStartedCustomMilestone) {
      return MilestoneStatus.inProgress;
    }
    if (hasStartedGoal) {
      return MilestoneStatus.inProgress;
    }
    return MilestoneStatus.notStarted;
  }

  static Future<void> attachGoalEvidence({
    required String goalId,
    required List<String> evidence,
  }) async {
    final data = await _fetchGoalData(goalId);
    await _backend.patchGoal(goalId, {
      'evidence': _mergeEvidenceValues(data['evidence'], evidence),
      'updatedAt': _iso(DateTime.now()),
    });
  }

  static Future<void> clearGoalEvidence({required String goalId}) async {
    await _backend.patchGoal(goalId, {
      'evidence': <dynamic>[],
      'updatedAt': _iso(DateTime.now()),
    });
  }

  static Future<void> updateGoalProgress(String goalId, int progress) async {
    bool isSeason = false;
    String? userId;
    try {
      final data = await _fetchGoalData(goalId);
      isSeason = data['isSeasonGoal'] == true;
      final ap = (data['approvalStatus'] ?? 'pending').toString();
      if (!isSeason && ap != GoalApprovalStatus.approved.name) {
        throw Exception('Goal is not approved yet');
      }

      int snapped = ((progress / 10).round() * 10).clamp(0, 100);
      final currentStatus = (data['status'] ?? 'notStarted').toString();
      userId = data['userId'] as String?;
      if (currentStatus == GoalStatus.paused.name ||
          currentStatus == GoalStatus.completed.name ||
          currentStatus == GoalStatus.burnout.name) {
        throw Exception('progress_update.blocked: status=$currentStatus');
      }

      final previousProgress = _coerceInt(data['progress']);
      final milestones = data['milestones'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['milestones'] as Map)
          : <String, dynamic>{};
      final evList = _normalizedEvidenceList(data['evidence']);
      final evidenceExists = evList.isNotEmpty;
      var toApply = snapped;
      if (!isSeason && !evidenceExists && snapped > 90) {
        toApply = 90;
      }

      final patch = <String, dynamic>{'progress': toApply};
      if (toApply > 0 &&
          currentStatus != GoalStatus.inProgress.name &&
          currentStatus != GoalStatus.completed.name) {
        patch['status'] = GoalStatus.inProgress.name;
        if (!isSeason && userId != null && userId.isNotEmpty) {
          await _incrementUserPointsCapped(userId: userId, amount: 20);
        }
      }

      final crossed50 = previousProgress < 50 && toApply >= 50;
      if (crossed50 &&
          userId != null &&
          userId.isNotEmpty &&
          milestones['p50'] != true) {
        if (!isSeason) {
          await _incrementUserPointsCapped(userId: userId, amount: 20);
        }
        milestones['p50'] = true;
        patch['milestones'] = milestones;
      }

      await _backend.patchGoal(goalId, patch);
    } catch (e) {
      developer.log('updateGoalProgress failed: $e');
      rethrow;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await StreakService.recordDailyActivity(user.uid, 'goal_progress');
        await BadgeService.checkAndAwardBadgesV2(user.uid);
      }
    } catch (e) {
      developer.log('updateGoalProgress post-activity failed: $e');
    }

    try {
      if (userId != null && userId.isNotEmpty) {
        await _backend.updateUserProfile(userId, {
          'lastActivityAt': _iso(DateTime.now()),
        });
      }
    } catch (e) {
      developer.log('updateGoalProgress lastActivity update failed: $e');
    }

    await _syncSeasonGoalFromGoalState(goalId);

    try {
      final data = await _fetchGoalData(goalId);
      final progressUserId = data['userId'] as String?;
      final progressNow = _coerceInt(data['progress']);
      final milestones = data['milestones'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['milestones'] as Map)
          : <String, dynamic>{};
      if (!isSeason &&
          progressUserId != null &&
          progressUserId.isNotEmpty &&
          progressNow >= 50 &&
          milestones['p50'] == true) {
        await AlertService.createPointsAlert(
          userId: progressUserId,
          pointsEarned: 20,
          reason: 'reaching 50% progress milestone',
        );
        await AlertService.createMotivationalAlert(
          userId: progressUserId,
          message:
              'Great momentum! You\'re halfway there. Keep pushing to the finish!',
          goalId: goalId,
        );
      }
    } catch (e) {
      developer.log('updateGoalProgress post-alerts failed: $e');
    }
  }

  static Future<void> startGoal(String goalId, String userId) async {
    final dataStart = await _fetchGoalData(goalId);
    final bool isSeasonStart = dataStart['isSeasonGoal'] == true;
    final ap = (dataStart['approvalStatus'] ?? 'pending').toString();
    if (!isSeasonStart && ap != GoalApprovalStatus.approved.name) {
      throw Exception('Goal is not approved yet');
    }

    final rawCategory = (dataStart['category'] ?? 'personal')
        .toString()
        .toLowerCase();
    final rawPriority = (dataStart['priority'] ?? 'medium')
        .toString()
        .toLowerCase();
    final category = GoalCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == rawCategory,
      orElse: () => GoalCategory.personal,
    );
    final priority = GoalPriority.values.firstWhere(
      (e) => e.name.toLowerCase() == rawPriority,
      orElse: () => GoalPriority.medium,
    );
    final allocated = PointsService.allocatedPointsForGoal(category, priority);
    final int bonus = PointsService.kickoffBonus(allocated);

    final milestones = dataStart['milestones'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(dataStart['milestones'] as Map)
        : <String, dynamic>{};
    if ((milestones['kickoff'] ?? false) != true) {
      milestones['kickoff'] = true;
    }

    await _backend.patchGoal(goalId, {
      'status': GoalStatus.inProgress.name,
      'milestones': milestones,
    });

    try {
      if (!isSeasonStart) {
        await _incrementUserPointsCapped(userId: userId, amount: bonus);
      }
    } catch (e) {
      developer.log('startGoal capped increment failed: $e');
    }

    await StreakService.recordDailyActivity(userId, 'goal_started');
    await BadgeService.checkAndAwardBadgesV2(userId);
  }

  static Future<void> completeGoal(String goalId, String userId) async {
    int completionAward = 0;
    bool isSeasonGoalFlag = false;
    String goalTitleForAudit = '';
    String ownerNameForAudit = '';
    String ownerDeptForAudit = '';

    final data = await _fetchGoalData(goalId);
    goalTitleForAudit = (data['title'] ?? '').toString();
    ownerNameForAudit =
        (data['userDisplayName'] ??
                data['userName'] ??
                data['ownerName'] ??
                '')
            .toString();
    ownerDeptForAudit = (data['userDepartment'] ?? '').toString();
    final bool isSeasonComplete = data['isSeasonGoal'] == true;
    isSeasonGoalFlag = isSeasonComplete;
    final approval = (data['approvalStatus'] ?? 'pending').toString();
    if (!isSeasonComplete && approval != GoalApprovalStatus.approved.name) {
      throw Exception('Goal is not approved yet');
    }
    if (!isSeasonComplete) {
      final ev = data['evidence'];
      final bool hasEvidence =
          _normalizedEvidenceList(ev).isNotEmpty;
      if (!hasEvidence) {
        throw Exception(
          'Please submit evidence before completing this goal.',
        );
      }
    }
    final status = (data['status'] ?? 'notStarted').toString();
    final progress = _coerceInt(data['progress']);
    if (status != GoalStatus.inProgress.name) {
      throw Exception('Start the goal before completing it.');
    }
    if (progress < 100) {
      throw Exception('Set progress to 100% before completing.');
    }

    final rawCategory = (data['category'] ?? 'personal').toString().toLowerCase();
    final rawPriority = (data['priority'] ?? 'medium').toString().toLowerCase();
    final category = GoalCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == rawCategory,
      orElse: () => GoalCategory.personal,
    );
    final priority = GoalPriority.values.firstWhere(
      (e) => e.name.toLowerCase() == rawPriority,
      orElse: () => GoalPriority.medium,
    );
    final allocated = PointsService.allocatedPointsForGoal(category, priority);
    final milestones = data['milestones'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(data['milestones'] as Map)
        : <String, dynamic>{};
    if ((milestones['completion'] ?? false) != true) {
      int totalAward = PointsService.completionBonus(allocated);
      final target = _parseBackendDate(data['targetDate']);
      if (target != null) {
        final now = DateTime.now();
        if (!now.isAfter(target)) {
          totalAward += PointsService.onTimeModifier(allocated).toInt();
        } else {
          totalAward += PointsService.lateModifier(allocated).toInt();
        }
      }
      completionAward = totalAward;
      milestones['completion'] = true;
    }

    await _backend.patchGoal(goalId, {
      'status': GoalStatus.completed.name,
      if (milestones.isNotEmpty) 'milestones': milestones,
    });

    try {
      if (completionAward > 0 && !isSeasonGoalFlag) {
        await _incrementUserPointsCapped(
          userId: userId,
          amount: completionAward,
        );
      }
    } catch (e) {
      developer.log('completeGoal capped increment failed: $e');
    }

    await StreakService.recordDailyActivity(userId, 'goal_completed');
    await BadgeService.checkAndAwardBadgesV2(userId);

    try {
      if (goalTitleForAudit.isEmpty) {
        final refreshed = await _fetchGoalData(goalId);
        goalTitleForAudit = (refreshed['title'] ?? '').toString();
        ownerNameForAudit =
            (refreshed['userDisplayName'] ??
                    refreshed['userName'] ??
                    refreshed['ownerName'] ??
                    ownerNameForAudit)
                .toString();
        ownerDeptForAudit =
            (refreshed['userDepartment'] ?? ownerDeptForAudit).toString();
      }
      if (ownerNameForAudit.trim().isEmpty || ownerDeptForAudit.trim().isEmpty) {
        final owner = await _fetchUserData(userId);
        if (ownerNameForAudit.trim().isEmpty) {
          ownerNameForAudit =
              (owner['displayName'] ??
                      owner['fullName'] ??
                      owner['name'] ??
                      owner['email'] ??
                      '')
                  .toString();
        }
        if (ownerDeptForAudit.trim().isEmpty) {
          ownerDeptForAudit = (owner['department'] ?? '').toString();
        }
      }
      await _logGoalCompletedToAuditEntries(
        goalId: goalId,
        goalTitle: goalTitleForAudit,
        userId: userId,
        userDisplayName: ownerNameForAudit,
        userDepartment: ownerDeptForAudit,
      );
    } catch (e) {
      developer.log('Error logging goal completion lifecycle event: $e');
    }
  }

  static Future<void> updateUserPoints(
    String userId,
    int points,
    String reason,
  ) async {
    final userData = await _fetchUserData(userId);
    final currentPoints = _coerceInt(userData['totalPoints']);
    final newPoints = currentPoints + points;
    final newLevel = _calculateLevel(newPoints);

    await _backend.updateUserProfile(userId, {
      'totalPoints': newPoints,
      'level': newLevel,
    });
  }

  static int _calculateLevel(int points) {
    // Level up every 500 points
    return (points ~/ 500) + 1;
  }

  static int _rolePriority(String? role) {
    final normalized = role?.trim().toLowerCase();
    switch (normalized) {
      case 'admin':
        return 3;
      case 'manager':
        return 2;
      case 'employee':
        return 1;
      default:
        return 0;
    }
  }

  static String _pdhModuleAccessRole(String role) {
    switch (role.trim().toLowerCase()) {
      case 'manager':
        return 'PDH - Manager';
      case 'admin':
        return 'PDH - Admin';
      case 'employee':
      default:
        return 'PDH - Employee';
    }
  }

  static String _mergePdhModuleAccessRole({
    required String? currentModuleAccessRole,
    required String pdhRoleLabel,
  }) {
    final entries = <String>[];
    if (pdhRoleLabel.trim().isNotEmpty) {
      entries.add(pdhRoleLabel.trim());
    }

    final current = currentModuleAccessRole?.trim();
    if (current != null && current.isNotEmpty) {
      for (final entry in current.split(',')) {
        final trimmed = entry.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed.toUpperCase().contains('PDH')) continue;
        if (!entries.contains(trimmed)) {
          entries.add(trimmed);
        }
      }
    }

    return entries.join(', ');
  }

  static Future<void> initializeSubcollections(
    Object userDocRef,
  ) async {
    // PostgreSQL backend uses dedicated tables instead of Firestore subcollections.
  }

  static Future<void> initializeUserData(
    String uid,
    String? displayName,
    String? email, {
    String role = 'employee',
  }) async {
    String? resolvedDisplayName = displayName;
    String? resolvedEmail = email;
    Map<String, dynamic>? onboardingData;

    if ((resolvedDisplayName == null || resolvedDisplayName.isEmpty) ||
        (resolvedEmail == null || resolvedEmail.isEmpty)) {
      try {
        onboardingData = await _backend.getOnboarding(uid);
        if (onboardingData.isNotEmpty) {
          resolvedDisplayName = resolvedDisplayName?.isNotEmpty == true
              ? resolvedDisplayName
              : onboardingData['displayName'] ??
                    onboardingData['fullName'] ??
                    onboardingData['name'] ??
                    onboardingData['firstName'] ??
                    (onboardingData['firstName'] != null &&
                            onboardingData['lastName'] != null
                        ? '${onboardingData['firstName']} ${onboardingData['lastName']}'
                              .trim()
                        : null);
          resolvedEmail = resolvedEmail?.isNotEmpty == true
              ? resolvedEmail
              : onboardingData['email']?.toString() ?? email;
        }
      } catch (e) {
        developer.log('Error checking onboarding collection: $e');
      }
    }

    Map<String, dynamic> existing = {};
    try {
      existing = await _fetchUserData(uid);
    } catch (_) {}

    if (existing.isEmpty) {
      final userData = {
        'displayName': resolvedDisplayName?.isNotEmpty == true
            ? resolvedDisplayName
            : '',
        'email': resolvedEmail ?? '',
        'createdAt': _iso(DateTime.now()),
        'role': role,
        'totalPoints': 0,
        'level': 1,
        'badges': [],
        'jobTitle': '',
        'department': '',
        'phoneNumber': '',
        'profilePhotoUrl': null,
        'skills': [],
        'developmentAreas': [],
        'careerAspirations': '',
        'currentProjects': '',
        'learningStyle': '',
        'preferredDevActivities': [],
        'shortGoals': '',
        'longGoals': '',
        'notificationFrequency': 'daily',
        'goalVisibility': 'private',
        'leaderboardOptin': false,
        'leaderboardParticipation': false,
        'badgeName': '',
        'celebrationConsent': 'private',
      };

      if (role == 'employee' || role == 'manager') {
        userData['tutorialEnabled'] = true;
      } else if (role == 'admin') {
        userData['tutorialEnabled'] = false;
      }

      await _backend.updateUserProfile(uid, userData);
    } else {
      final currentDisplayName = existing['displayName']?.toString() ?? '';
      final finalDisplayName = resolvedDisplayName?.isNotEmpty == true
          ? resolvedDisplayName
          : (currentDisplayName.isNotEmpty ? currentDisplayName : '');
      final currentRole = existing['role'] as String?;

      final updateData = <String, dynamic>{
        'displayName': (finalDisplayName?.isNotEmpty == true
            ? finalDisplayName
            : (existing['displayName'] ?? '')) as String,
        'email': resolvedEmail ?? existing['email'] ?? '',
      };

      if (_rolePriority(role) > _rolePriority(currentRole)) {
        updateData['role'] = role;
      }

      await _backend.updateUserProfile(uid, updateData);
    }

    try {
      onboardingData ??= {};
      if (onboardingData.isEmpty) {
        try {
          onboardingData = await _backend.getOnboarding(uid);
        } catch (_) {
          onboardingData = <String, dynamic>{};
        }
      }
      final onboarding = onboardingData;
      final pdhRoleLabel = _pdhModuleAccessRole(role);
      final mergedRole = _mergePdhModuleAccessRole(
        currentModuleAccessRole:
            onboarding['moduleAccessRole']?.toString() ??
            onboarding['module_access_role']?.toString() ??
            onboarding['moduleRole']?.toString() ??
            onboarding['module_role']?.toString() ??
            onboarding['role']?.toString(),
        pdhRoleLabel: pdhRoleLabel,
      );
      await _backend.updateOnboarding(uid, {
        'displayName': resolvedDisplayName ?? '',
        'fullName': resolvedDisplayName ?? '',
        'email': resolvedEmail ?? '',
        'moduleAccessRole': mergedRole,
        'moduleRole': mergedRole,
        'role': mergedRole,
        'status': 'Active',
      });
    } catch (e) {
      developer.log('Error syncing onboarding role for $uid: $e');
    }

    await initializeSubcollections(uid);
  }

  /// Syncs user data from onboarding collection if displayName or email is missing
  /// This helps resolve "Anonymous" user issues
  static Future<void> syncOnboardingData(String uid) async {
    try {
      final userData = await _fetchUserData(uid);
      if (userData.isEmpty) {
        return;
      }

      final currentDisplayName = userData['displayName']?.toString() ?? '';
      final currentEmail = userData['email']?.toString() ?? '';

      if (currentDisplayName.isEmpty) {
        try {
          final onboardingData = await _backend.getOnboarding(uid);
          if (onboardingData.isNotEmpty) {
            final onboardingName =
                onboardingData['displayName'] ??
                onboardingData['fullName'] ??
                onboardingData['name'] ??
                onboardingData['firstName'] ??
                (onboardingData['firstName'] != null &&
                        onboardingData['lastName'] != null
                    ? '${onboardingData['firstName']} ${onboardingData['lastName']}'
                          .trim()
                    : null);
            final onboardingEmail = onboardingData['email']?.toString();
            final updates = <String, dynamic>{};
            if (onboardingName != null &&
                onboardingName.toString().isNotEmpty) {
              updates['displayName'] = onboardingName.toString();
            }
            if (onboardingEmail != null &&
                onboardingEmail.isNotEmpty &&
                currentEmail.isEmpty) {
              updates['email'] = onboardingEmail;
            }
            if (updates.isNotEmpty) {
              await _backend.updateUserProfile(uid, updates);
              developer.log(
                'Synced onboarding data for user $uid: ${updates.keys.join(", ")}',
              );
            }
          }
        } catch (e) {
          developer.log('Error syncing onboarding data for $uid: $e');
        }
      }
    } catch (e) {
      developer.log('Error in syncOnboardingData for $uid: $e');
    }
  }

  /// Gets user name from PostgreSQL onboarding records.
  static Future<String?> getUserNameFromOnboarding({
    required String userId,
    String? email,
  }) async {
    try {
      final onboardingData = await _backend.tryGetOnboarding(userId);
      if (onboardingData.isNotEmpty) {
        final name = OnboardingService.displayNameFromOnboarding(onboardingData);
        if (name != null && name.isNotEmpty) return name;
      }

      if (email != null && email.isNotEmpty) {
        final items = await _backend.listOnboarding(email: email, limit: 1);
        if (items.isNotEmpty) {
          final name = OnboardingService.displayNameFromOnboarding(items.first);
          if (name != null && name.isNotEmpty) return name;
        }
      }
    } catch (e) {
      developer.log('Error getting user name from onboarding: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>> _prepareUserDataForWrite(
    String uid,
    Map<String, dynamic> data,
  ) async {
    final preparedData = Map<String, dynamic>.from(data);
    try {
      final existing = await _fetchUserData(uid);
      if (existing.isNotEmpty) {
        preparedData.remove('role');
      }
    } catch (_) {}
    return preparedData;
  }

  static Future<void> updateUserProfile(UserProfile userProfile) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid == null) {
      throw Exception('User not authenticated');
    }
    if (authUid != userProfile.uid) {
      throw Exception(
        'Cannot update profile: authenticated user ($authUid) does not match profile UID (${userProfile.uid})',
      );
    }

    final data = await _prepareUserDataForWrite(
      userProfile.uid,
      userProfile.toMap(includeId: false),
    );

    developer.log(
      'updateUserProfile: authUid=$authUid, targetUid=${userProfile.uid}, keys=${data.keys.join(',')}',
    );

    await _backend.updateUserProfile(userProfile.uid, data);

    final cache = PerformanceCacheService();
    cache.cacheUserProfile(userProfile);
  }

  static Future<Map<String, dynamic>> getDashboardData(String uid) async {
    final profile = await _fetchUserData(uid);
    final goals = await _backend.getGoals(userId: uid);
    final badges = await _backend.getBadges(uid);
    final alerts = await _backend.getAlerts(uid);
    final streakItems = await _backend.getCollectionItems(
      'streaks',
      userId: uid,
    );

    return {
      'profile': profile,
      'goals': goals,
      'streaks': streakItems,
      'badges': badges,
      'alerts': alerts,
    };
  }

  /// Log goal approval to audit_entries (parallel to approved_goals_audit collection).
  static Future<void> _logGoalApprovedToAuditEntries({
    required String goalId,
    required String goalTitle,
    required String employeeUserId,
    required String employeeName,
    required String department,
    required String approvedByUid,
    required String approvedByName,
  }) async {
    try {
      final ts = _iso(DateTime.now());
      final event = <String, dynamic>{
        'action': 'goal_approved',
        'goalId': goalId,
        'goalTitle': goalTitle,
        'userId': employeeUserId,
        'userDisplayName': employeeName.isNotEmpty ? employeeName : 'Unknown',
        'userDepartment': department.isNotEmpty ? department : 'Unknown',
        'submittedDate': ts,
        'timestamp': ts,
        'approvedDate': ts,
        'description': 'Goal approved: $goalTitle',
        'metadata': <String, dynamic>{
          'goalTitle': goalTitle,
          'goalId': goalId,
          'approvedBy': approvedByUid,
          'approvedByName': approvedByName,
        },
        'status': 'approved',
        'acknowledgedBy': approvedByName,
      };

      await _createAuditEvent(event);
      developer.log('Goal approval logged to audit_entries: $goalTitle');
    } catch (e, stackTrace) {
      developer.log(
        'Error logging goal approval to audit_entries: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log goal rejection to audit_entries collection
  static Future<void> _logGoalRejected({
    required String goalId,
    required String goalTitle,
    required String userId,
    required String rejectionReason,
    String ownerDisplayName = '',
    String ownerDepartment = '',
  }) async {
    try {
      final ts = _iso(DateTime.now());
      final event = {
        'action': 'goal_rejected',
        'goalId': goalId,
        'goalTitle': goalTitle,
        'userId': userId,
        'userDisplayName': ownerDisplayName.isNotEmpty
            ? ownerDisplayName
            : 'Unknown',
        'userDepartment':
            ownerDepartment.isNotEmpty ? ownerDepartment : 'Unknown',
        'submittedDate': ts,
        'timestamp': ts,
        'description': 'Goal rejected: $goalTitle',
        'metadata': {
          'goalTitle': goalTitle,
          'goalId': goalId,
          'rejectionReason': rejectionReason,
        },
        'rejectionReason': rejectionReason,
        'status': 'rejected',
      };

      await _createAuditEvent(event);
      developer.log('Goal rejection logged: $goalTitle for user $userId');
    } catch (e, stackTrace) {
      developer.log(
        'Error logging goal rejection: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log goal creation to audit_entries collection
  static Future<void> _logGoalCreated({
    required String goalId,
    required String goalTitle,
    required String userId,
  }) async {
    try {
      final ts = _iso(DateTime.now());
      final event = {
        'action': 'goal_created',
        'goalId': goalId,
        'goalTitle': goalTitle,
        'userId': userId,
        'submittedDate': ts,
        'timestamp': ts,
        'description': 'Goal created: $goalTitle',
        'metadata': {'goalTitle': goalTitle, 'goalId': goalId},
        'status': 'pending', // Goals start as pending approval
      };

      await _createAuditEvent(event);
      developer.log('Goal creation logged: $goalTitle for user $userId');
    } catch (e, stackTrace) {
      developer.log(
        'Error logging goal creation: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log goal submission to approval chain (employee->manager or manager->admin).
  static Future<void> _logGoalSubmittedToAuditEntries({
    required String goalId,
    required String goalTitle,
    required String userId,
    required String userDisplayName,
    required String userDepartment,
    required String requiredApproverRole,
  }) async {
    try {
      final ts = _iso(DateTime.now());
      final approverRole = requiredApproverRole.trim().toLowerCase();
      final chain = approverRole.contains('admin')
          ? 'manager_to_admin'
          : 'employee_to_manager';
      final event = <String, dynamic>{
        'action': 'goal_submitted',
        'goalId': goalId,
        'goalTitle': goalTitle,
        'userId': userId,
        'userDisplayName': userDisplayName.isNotEmpty
            ? userDisplayName
            : 'Unknown User',
        'userDepartment': userDepartment.isNotEmpty ? userDepartment : 'Unknown',
        'requiredApproverRole': approverRole.isNotEmpty
            ? approverRole
            : 'manager',
        'approvalChain': chain,
        'submittedDate': ts,
        'timestamp': ts,
        'description': 'Goal submitted for approval: $goalTitle',
        'status': 'pending',
      };
      await _createAuditEvent(event);
      developer.log(
        'Goal submission logged to audit_entries: $goalTitle ($chain)',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error logging goal submission to audit_entries: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _logGoalCompletedToAuditEntries({
    required String goalId,
    required String goalTitle,
    required String userId,
    required String userDisplayName,
    required String userDepartment,
  }) async {
    try {
      final ts = _iso(DateTime.now());
      final event = <String, dynamic>{
        'action': 'goal_completed',
        'goalId': goalId,
        'goalTitle': goalTitle,
        'userId': userId,
        'userDisplayName': userDisplayName.trim().isNotEmpty
            ? userDisplayName.trim()
            : 'Unknown User',
        'userDepartment': userDepartment.trim().isNotEmpty
            ? userDepartment.trim()
            : 'Unknown',
        'submittedDate': ts,
        'timestamp': ts,
        'completedDate': ts,
        'description': 'Goal completed: $goalTitle',
        'status': 'completed',
      };
      await _createAuditEvent(event);
    } catch (e, stackTrace) {
      developer.log(
        'Error logging goal completion to audit_entries: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
