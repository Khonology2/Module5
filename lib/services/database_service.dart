import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/goal_milestone.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/services/milestone_evidence_service.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/services/streak_service.dart';
import 'package:pdh/services/badge_service.dart';
import 'package:pdh/services/season_service.dart';
import 'package:pdh/services/performance_cache_service.dart';
import 'package:pdh/services/approved_goal_audit_service.dart';
import 'package:pdh/services/points_service.dart';
import 'package:pdh/services/timeline_service.dart';
import 'package:pdh/services/unified_milestone_audit.dart';
import 'package:pdh/utils/firestore_web_circuit_breaker.dart';
import 'package:firebase_core/firebase_core.dart';

class DatabaseService {
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
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      return (doc.data()?['role'] ?? 'employee') as String;
    } catch (_) {
      return 'employee';
    }
  }

  static Future<Map<String, dynamic>> _getUserPrivacySettings(
    String uid,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? <String, dynamic>{};
      return {
        'privateGoals': data['privateGoals'] == true,
        'privateMilestones': data['privateMilestones'] == true,
        'privateProgress': data['privateProgress'] == true,
      };
    } catch (_) {
      return {
        'privateGoals': false,
        'privateMilestones': false,
        'privateProgress': false,
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
    final snapshot = await FirebaseFirestore.instance
        .collection('goals')
        .where('userId', isEqualTo: targetUserId)
        .orderBy('createdAt', descending: true)
        .get();
    var goals = snapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList();
    // Removed in-memory sort - using Firestore orderBy instead

    // If teamShare is disabled, hide completed goals from non-owners/non-managers
    if (!isOwner && viewerRole != 'manager' && settings['teamShare'] == false) {
      goals = goals.where((g) => g.status != GoalStatus.completed).toList();
    }
    return goals;
  }

  // Detect Firestore transient internal assertion errors that we can safely retry.
  static bool _isFirestoreInternalAssertion(dynamic e) {
    final msg = e.toString();
    return msg.contains('INTERNAL ASSERTION FAILED') ||
        msg.contains('Unexpected state (ID:');
  }

  static Stream<List<Goal>> getUserGoalsStreamForViewer({
    required String viewerId,
    required String targetUserId,
  }) async* {
    final isOwner = viewerId == targetUserId;
    String viewerRole;
    Map<String, dynamic> settings;
    try {
      viewerRole = await _getUserRole(viewerId);
      settings = await _getUserPrivacySettings(targetUserId);
    } catch (_) {
      viewerRole = 'employee';
      settings = {
        'privateGoals': false,
        'privateMilestones': false,
        'privateProgress': false,
      };
    }

    if (!isOwner && viewerRole != 'manager') {
      if (settings['managerOnly'] == true || settings['privateGoals'] == true) {
        yield <Goal>[];
        return;
      }
    }

    // Emit initial empty list so StreamBuilder leaves ConnectionState.waiting
    // immediately; avoids infinite loading if Firestore is slow or errors.
    yield <Goal>[];

    yield* FirebaseFirestore.instance
        .collection('goals')
        .where('userId', isEqualTo: targetUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
          developer.log('Error in getUserGoalsStream: $error');
          if (error is Object) {
            FirestoreWebCircuitBreaker.maybeReload(error);
          }
        })
        .map((snapshot) {
          var goals = snapshot.docs
              .map((doc) => Goal.fromFirestore(doc))
              .toList();
          // Removed in-memory sort - using Firestore orderBy instead
          if (!isOwner &&
              viewerRole != 'manager' &&
              settings['teamShare'] == false) {
            goals = goals
                .where((g) => g.status != GoalStatus.completed)
                .toList();
          }
          if (!isOwner && viewerRole != 'manager') {
            if (settings['managerOnly'] == true ||
                settings['privateGoals'] == true) {
              return <Goal>[];
            }
          }
          return goals;
        });
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
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    int awarded = 0;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final metrics = (data['metrics'] as Map<String, dynamic>?) ?? {};
      final points = (metrics['points'] as Map<String, dynamic>?) ?? {};
      final daily = (points['daily'] as Map<String, dynamic>?) ?? {};
      final weekly = (points['weekly'] as Map<String, dynamic>?) ?? {};
      int daySoFar = 0;
      final rawDay = daily[dKey];
      if (rawDay is int) {
        daySoFar = rawDay;
      } else if (rawDay is num) {
        daySoFar = rawDay.round();
      } else {
        daySoFar = 0;
      }
      int weekSoFar = 0;
      final rawWeek = weekly[wKey];
      if (rawWeek is int) {
        weekSoFar = rawWeek;
      } else if (rawWeek is num) {
        weekSoFar = rawWeek.round();
      } else {
        weekSoFar = 0;
      }

      final remainingDay = (_dailyPointsCap - daySoFar).clamp(
        0,
        _dailyPointsCap,
      );
      final remainingWeek = (_weeklyPointsCap - weekSoFar).clamp(
        0,
        _weeklyPointsCap,
      );
      final allow = amount.clamp(0, remainingDay).clamp(0, remainingWeek);
      if (allow <= 0) {
        awarded = 0;
        return;
      }
      awarded = allow;
      tx.update(userRef, {
        'totalPoints': FieldValue.increment(allow),
        'metrics.points.daily.$dKey': (daySoFar + allow),
        'metrics.points.weekly.$wKey': (weekSoFar + allow),
        'metrics.points.lastUpdated': FieldValue.serverTimestamp(),
      });
    });
    return awarded;
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

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      data = doc.data() ?? {};

      // If displayName is missing/empty, try to sync from onboarding
      final displayName =
          data['displayName']?.toString() ?? data['fullName']?.toString() ?? '';
      if (displayName.isEmpty) {
        await syncOnboardingData(uid);
        // Re-fetch user data after sync
        final updatedDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        data = updatedDoc.data() ?? data;
      }
    } catch (e) {
      // Retry up to 2 times for Firestore internal errors
      final errorString = e.toString();
      if (errorString.contains('INTERNAL ASSERTION FAILED') && retryCount < 2) {
        developer.log('Firestore error, retrying getUserProfile: $e');
        return getUserProfile(uid, retryCount: retryCount + 1);
      }
      // If we have cached data, return it even if fresh fetch failed
      if (cached != null && cached.uid == uid) {
        developer.log('Using cached profile due to error: $e');
        return cached;
      }
      rethrow;
    }

    final profile = UserProfile(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? data['fullName'] ?? '',
      totalPoints: (data['totalPoints'] ?? 0) as int,
      level: (data['level'] ?? 1) as int,
      badges: List<String>.from(data['badges'] ?? const []),
      role: data['role'] ?? 'employee', // Deserialize role
      jobTitle: data['jobTitle'] ?? '',
      department: data['department'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      profilePhotoUrl: data['profilePhotoUrl'],
      skills: List<String>.from(data['skills'] ?? const []),
      developmentAreas: List<String>.from(data['developmentAreas'] ?? const []),
      careerAspirations: data['careerAspirations'] ?? '',
      currentProjects: data['currentProjects'] ?? '',
      learningStyle: data['learningStyle'] ?? '',
      preferredDevActivities: List<String>.from(
        data['preferredDevActivities'] ?? const [],
      ),
      shortGoals: data['shortGoals'] ?? '',
      longGoals: data['longGoals'] ?? '',
      notificationFrequency: data['notificationFrequency'] ?? 'daily',
      goalVisibility: data['goalVisibility'] ?? 'private',
      leaderboardOptin:
          data['leaderboardOptin'] ?? data['leaderboardParticipation'] ?? false,
      badgeName: data['badgeName'] ?? '',
      celebrationConsent: data['celebrationConsent'] ?? 'private',
    );

    // Cache the profile
    cache.cacheUserProfile(profile);
    return profile;
  }

  static Future<void> approveGoal({
    required String goalId,
    required String managerId,
    required String managerName,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final goalRef = firestore.collection('goals').doc(goalId);
    final approverRole = (await _getUserRole(managerId)).trim().toLowerCase();
    Map<String, dynamic>? goalData;
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(goalRef);
      if (!snapshot.exists) {
        throw StateError('Goal not found');
      }
      final data = snapshot.data();
      final currentStatus =
          (data?['approvalStatus'] ?? GoalApprovalStatus.pending.name)
              .toString();
      if (currentStatus == GoalApprovalStatus.approved.name ||
          currentStatus == GoalApprovalStatus.rejected.name) {
        throw StateError('Goal has already been finalized');
      }
      final goalOwnerId = (data?['userId'] ?? '').toString();
      if (goalOwnerId.isEmpty) {
        throw StateError('Goal has no owner');
      }
      final goalOwnerDoc = await transaction.get(
        firestore.collection('users').doc(goalOwnerId),
      );
      final goalOwnerRole = (goalOwnerDoc.data()?['role'] ?? 'employee')
          .toString()
          .trim()
          .toLowerCase();

      // Manager-created goals must be approved by admins only.
      if (goalOwnerRole == 'manager' && approverRole != 'admin') {
        throw StateError('Manager-created goals must be approved by an admin');
      }
      // Employee goals can be approved by manager or admin.
      if (goalOwnerRole != 'manager' &&
          approverRole != 'manager' &&
          approverRole != 'admin') {
        throw StateError('You do not have permission to approve this goal');
      }

      goalData = data;
      transaction.update(goalRef, {
        'approvalStatus': GoalApprovalStatus.approved.name,
        'approvedByUserId': managerId,
        'approvedByName': managerName,
        'approvedAt': FieldValue.serverTimestamp(),
        'rejectionReason': null,
      });
    });
    if (goalData == null) return;

    // Get employee details for audit
    String employeeName = '';
    String department = '';
    try {
      final employeeDoc = await firestore
          .collection('users')
          .doc(goalData!['userId'])
          .get();
      final employeeData = employeeDoc.data() ?? {};
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
        goalTitle: (goalData!['title'] ?? '') as String,
        employeeId: (goalData!['userId'] ?? '') as String,
        employeeName: employeeName,
        department: department,
        approvedBy: managerId,
        approvedByName: managerName,
      );
    } catch (e) {
      developer.log('Error logging approved goal audit: $e');
    }

    try {
      await AlertService.createGoalApprovalDecisionAlert(
        employeeId: (goalData!['userId'] ?? '') as String,
        goalId: goalId,
        goalTitle: (goalData!['title'] ?? '') as String,
        approved: true,
      );
      // Also send the employee a 'New Goal Created' alert upon approval
      // This reminds the employee to start working on their newly approved goal
      try {
        final goal = Goal.fromMap(goalData!, id: goalId);
        await AlertService.createGoalAlert(
          userId: goal.userId,
          goal: goal,
          type: AlertType.goalCreated,
        );
      } catch (e) {
        developer.log('Error creating goalCreated alert after approval: $e');
        // Continue even if alert creation fails - approval was successful
      }
    } catch (_) {}
  }

  static Future<void> rejectGoal({
    required String goalId,
    required String managerId,
    required String managerName,
    String? reason,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final goalRef = firestore.collection('goals').doc(goalId);
    final approverRole = (await _getUserRole(managerId)).trim().toLowerCase();
    Map<String, dynamic>? goalData;
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(goalRef);
      if (!snapshot.exists) {
        throw StateError('Goal not found');
      }
      final data = snapshot.data();
      final currentStatus =
          (data?['approvalStatus'] ?? GoalApprovalStatus.pending.name)
              .toString();
      if (currentStatus == GoalApprovalStatus.approved.name ||
          currentStatus == GoalApprovalStatus.rejected.name) {
        throw StateError('Goal has already been finalized');
      }
      final goalOwnerId = (data?['userId'] ?? '').toString();
      if (goalOwnerId.isEmpty) {
        throw StateError('Goal has no owner');
      }
      final goalOwnerDoc = await transaction.get(
        firestore.collection('users').doc(goalOwnerId),
      );
      final goalOwnerRole = (goalOwnerDoc.data()?['role'] ?? 'employee')
          .toString()
          .trim()
          .toLowerCase();

      // Manager-created goals must be reviewed by admins only.
      if (goalOwnerRole == 'manager' && approverRole != 'admin') {
        throw StateError('Manager-created goals must be rejected by an admin');
      }
      // Employee goals can be rejected by manager or admin.
      if (goalOwnerRole != 'manager' &&
          approverRole != 'manager' &&
          approverRole != 'admin') {
        throw StateError('You do not have permission to reject this goal');
      }

      goalData = data;
      transaction.update(goalRef, {
        'approvalStatus': GoalApprovalStatus.rejected.name,
        'approvedByUserId': managerId,
        'approvedByName': managerName,
        'approvedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
      });
    });
    if (goalData == null) return;
    try {
      await AlertService.createGoalApprovalDecisionAlert(
        employeeId: (goalData!['userId'] ?? '') as String,
        goalId: goalId,
        goalTitle: (goalData!['title'] ?? '') as String,
        approved: false,
        reason: reason,
      );
    } catch (_) {}

    // Log goal rejection to audit trail
    try {
      await _logGoalRejected(
        goalId: goalId,
        goalTitle: (goalData!['title'] ?? '') as String? ?? '',
        userId: (goalData!['userId'] ?? '') as String? ?? '',
        rejectionReason: reason ?? '',
      );
    } catch (e) {
      developer.log('Error logging goal rejection: $e');
    }
  }

  static Future<Goal?> getGoalById(String goalId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('goals')
          .doc(goalId)
          .get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return Goal(
        id: doc.id,
        userId: data['userId'] ?? '',
        title: data['title'] ?? '',
        description: data['description'] ?? '',
        category: GoalCategory.values.firstWhere(
          (e) => e.name == (data['category'] ?? 'personal'),
          orElse: () => GoalCategory.personal,
        ),
        priority: GoalPriority.values.firstWhere(
          (e) => e.name == (data['priority'] ?? 'medium'),
          orElse: () => GoalPriority.medium,
        ),
        status: GoalStatus.values.firstWhere(
          (e) => e.name == (data['status'] ?? 'notStarted'),
          orElse: () => GoalStatus.notStarted,
        ),
        progress: (() {
          final raw = data['progress'];
          if (raw is int) return raw;
          if (raw is num) return raw.round();
          return 0;
        })(),
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        targetDate:
            (data['targetDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        points: (data['points'] ?? 0) as int,
        kpa: (() {
          final raw = data['kpa'];
          return raw is String ? raw.toLowerCase() : null;
        })(),
      );
    } catch (_) {
      return null;
    }
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

  static Future<String> createGoal(Goal goal) async {
    const int maxAttempts = 3;
    const List<int> retryDelaysMs = [250, 500];

    final Map<String, dynamic> goalData = {
      'userId': goal.userId,
      'title': goal.title,
      'description': goal.description,
      'category': goal.category.name,
      'priority': goal.priority.name,
      'status': goal.status.name,
      'progress': goal.progress,
      'createdAt': Timestamp.fromDate(goal.createdAt),
      'targetDate': Timestamp.fromDate(goal.targetDate),
      'points': goal.points,
      'kpa': goal.kpa,
      'approvalStatus': GoalApprovalStatus.pending.name,
      'approvedByUserId': null,
      'approvedByName': null,
      'approvedAt': null,
      'rejectionReason': null,
    };

    final col = FirebaseFirestore.instance.collection('goals');
    Object? lastError;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final docRef = await col
            .add(goalData)
            .timeout(const Duration(seconds: 8));
        developer.log('Goal created successfully: ${docRef.id}');
        lastError = null;

        // Auto-request approval asynchronously
        // ignore: unawaited_futures
        Future(() async {
          try {
            await requestGoalApproval(
              goalId: docRef.id,
              userId: goal.userId,
              goalTitle: goal.title,
            );
          } catch (e) {
            developer.log('Error requesting goal approval: $e');
          }
        });
        // ignore: unawaited_futures
        Future(() async {
          try {
            await BadgeService.checkAndAwardBadgesV2(goal.userId);
          } catch (_) {}
        });

        // Log goal creation to audit trail
        // ignore: unawaited_futures
        Future(() async {
          try {
            await _logGoalCreated(
              goalId: docRef.id,
              goalTitle: goal.title,
              userId: goal.userId,
            );
          } catch (e) {
            developer.log('Error logging goal creation: $e');
          }
        });

        return docRef.id;
      } catch (e) {
        lastError = e;
        developer.log(
          'Goal create attempt ${attempt + 1}/$maxAttempts failed: $e',
        );
        final isRetryable =
            _isFirestoreInternalAssertion(e) ||
            (e is FirebaseException &&
                [
                  'unavailable',
                  'deadline-exceeded',
                  'resource-exhausted',
                ].contains(e.code.toLowerCase()));
        if (attempt < maxAttempts - 1 && isRetryable) {
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
    throw StateError('Goal create failed after $maxAttempts attempts');
  }

  static Future<void> requestGoalApproval({
    required String goalId,
    required String userId,
    required String goalTitle,
  }) async {
    final ownerRole = (await _getUserRole(userId)).trim().toLowerCase();
    final requiredApproverRole = ownerRole == 'manager' ? 'admin' : 'manager';

    Future<void> attempt(int attemptCount) async {
      final ref = FirebaseFirestore.instance.collection('goals').doc(goalId);
      try {
        await ref.set({
          'approvalStatus': GoalApprovalStatus.pending.name,
          'approvalRequestedAt': FieldValue.serverTimestamp(),
          'requiredApproverRole': requiredApproverRole,
        }, SetOptions(merge: true));

        await AlertService.createGoalApprovalRequestedAlert(
          employeeId: userId,
          goalId: goalId,
          goalTitle: goalTitle,
          approverRole: requiredApproverRole,
        );
      } catch (e) {
        if (_isFirestoreInternalAssertion(e) && attemptCount < 1) {
          await Future.delayed(const Duration(milliseconds: 200));
          return attempt(attemptCount + 1);
        }
        rethrow;
      }
    }

    await attempt(0);
  }

  static Future<void> updateGoal(Goal goal) async {
    await FirebaseFirestore.instance.collection('goals').doc(goal.id).update({
      'title': goal.title,
      'description': goal.description,
      'category': goal.category.name,
      'priority': goal.priority.name,
      'status': goal.status.name,
      'progress': goal.progress,
      'targetDate': Timestamp.fromDate(goal.targetDate),
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

    // Atomic operation: add evidence and update milestone status
    final batch = FirebaseFirestore.instance.batch();

    // Add evidence to milestone
    final milestoneRef = _goalMilestonesRef(goalId).doc(milestoneId);
    batch.update(milestoneRef, {
      'evidence': FieldValue.arrayUnion([evidence.toMap()]),
      'status': GoalMilestoneStatus
          .pendingManagerReview
          .name, // NEW: Change to pending review
      'updatedAt': Timestamp.fromDate(now),
    });

    // Store evidence in separate collection for audit trail
    final evidenceRef = FirebaseFirestore.instance
        .collection('milestone_evidence')
        .doc(evidence.id);
    batch.set(evidenceRef, evidence.toMap());

    await batch.commit();

    // Send notification to manager
    final milestoneDoc = await milestoneRef.get();
    final milestone = GoalMilestone.fromFirestore(milestoneDoc);
    await _handleMilestoneEvidenceSubmission(
      goalId: goalId,
      milestone: milestone,
      evidenceList: [evidence], // Create list with single evidence
    );
  }

  // NEW: Submit multiple milestone evidence files - simplified to avoid Firestore race conditions
  static Future<void> submitMultipleMilestoneEvidence({
    required String goalId,
    required String milestoneId,
    required List<MilestoneEvidence> evidenceList,
  }) async {
    Future<void> attempt(int attemptCount) async {
      final milestoneRef = _goalMilestonesRef(goalId).doc(milestoneId);

      // Convert evidence to simple maps like goal evidence
      final evidenceMaps = evidenceList.map((e) => e.toMap()).toList();

      try {
        // Single operation only - no secondary operations that cause race conditions
        await milestoneRef.set({
          'evidence': FieldValue.arrayUnion(evidenceMaps),
          'status': GoalMilestoneStatus.pendingManagerReview.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        developer.log(
          'Successfully submitted evidence for milestone: $milestoneId',
        );

        // Send notification to manager (non-critical)
        try {
          final milestoneDoc = await milestoneRef.get();
          if (milestoneDoc.exists) {
            final milestone = GoalMilestone.fromFirestore(milestoneDoc);
            await _handleMilestoneEvidenceSubmission(
              goalId: goalId,
              milestone: milestone,
              evidenceList: evidenceList,
            );
          }
        } catch (notificationError) {
          developer.log(
            'Error sending evidence submission notification: $notificationError',
          );
          // Don't fail the whole operation if notification fails
        }
      } catch (e) {
        developer.log('Error submitting milestone evidence: $e');

        // Handle different types of Firestore errors
        if (_isPermissionDeniedError(e)) {
          developer.log(
            'Permission denied for milestone evidence submission - user may not have rights',
          );
          throw Exception(
            'You do not have permission to submit evidence for this milestone. Please contact your manager.',
          );
        } else if (_isFirestoreInternalAssertion(e) && attemptCount < 2) {
          final delayMs = 200 * (attemptCount + 1);
          developer.log(
            'Retrying milestone evidence submission after transient Firestore error (attempt ${attemptCount + 1})',
          );
          await Future.delayed(Duration(milliseconds: delayMs));
          return attempt(attemptCount + 1);
        } else if (_isDocumentNotFoundError(e)) {
          developer.log('Milestone document not found: $milestoneId');
          throw Exception(
            'The milestone could not be found. It may have been deleted.',
          );
        } else {
          developer.log(
            'Unexpected error in milestone evidence submission: $e',
          );
          throw Exception('Failed to submit evidence. Please try again later.');
        }
      }
    }

    await attempt(0);

    // Note: Audit trail and notifications removed to prevent Firestore race conditions
    // The core functionality (evidence submission) works consistently this way
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

  // NEW: Handle milestone evidence submission notifications
  static Future<void> _handleMilestoneEvidenceSubmission({
    required String goalId,
    required GoalMilestone milestone,
    required List<MilestoneEvidence> evidenceList,
  }) async {
    try {
      // Get goal details for notification
      final goalDoc = await FirebaseFirestore.instance
          .collection('goals')
          .doc(goalId)
          .get();
      final goal = Goal.fromFirestore(goalDoc);

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
      // Get milestone details
      final milestoneDoc = await _goalMilestonesRef(
        goalId,
      ).doc(milestoneId).get();

      if (!milestoneDoc.exists) {
        throw Exception('Milestone not found. It may have been deleted.');
      }

      final milestone = GoalMilestone.fromFirestore(milestoneDoc);

      // Update milestone status to completedAcknowledged
      await _goalMilestonesRef(goalId).doc(milestoneId).update({
        'status': GoalMilestoneStatus.completedAcknowledged.name,
        'updatedAt': Timestamp.fromDate(now),
        'acknowledgedAt': Timestamp.fromDate(now),
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
      } else if (e.toString().contains('INTERNAL ASSERTION FAILED')) {
        throw Exception(
          'A temporary error occurred. Please try again in a moment.',
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
      final goalDoc = await FirebaseFirestore.instance
          .collection('goals')
          .doc(goalId)
          .get();
      final goal = Goal.fromFirestore(goalDoc);

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
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userDoc.data()?['displayName'] ??
          userDoc.data()?['name'] ??
          'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  static CollectionReference<Map<String, dynamic>> _goalMilestonesRef(
    String goalId,
  ) {
    return FirebaseFirestore.instance
        .collection('goals')
        .doc(goalId)
        .collection('milestones');
  }

  static Stream<List<GoalMilestone>> getGoalMilestonesStream(String goalId) {
    return _goalMilestonesRef(goalId)
        .orderBy('dueDate')
        .snapshots()
        .handleError((error) {
          developer.log('Error in milestones stream: $error');
          // Return empty list on error to prevent UI crashes
          return <GoalMilestone>[];
        })
        .map((snapshot) {
          try {
            return snapshot.docs
                .map((doc) => GoalMilestone.fromFirestore(doc))
                .toList();
          } catch (e) {
            developer.log('Error parsing milestone documents: $e');
            return <GoalMilestone>[];
          }
        });
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
    final docRef = await _goalMilestonesRef(goalId).add({
      'title': title,
      'description': description,
      'status': status.name,
      'dueDate': Timestamp.fromDate(dueDate),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'completedAt': status == GoalMilestoneStatus.completed
          ? Timestamp.fromDate(now)
          : null,
      // REMOVED: requiresEvidence field - no longer needed
      'evidence': [], // Initialize empty evidence array for new workflow
    });
    final snapshot = await docRef.get();
    final milestone = GoalMilestone.fromFirestore(snapshot);

    // Log milestone creation to audit trail
    try {
      final goalSnap = await FirebaseFirestore.instance
          .collection('goals')
          .doc(goalId)
          .get();
      final goalTitle = goalSnap.data()?['title'] ?? 'Unknown Goal';

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
    return docRef.id;
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
      final goalSnap = await FirebaseFirestore.instance
          .collection('goals')
          .doc(goalId)
          .get();
      if (!goalSnap.exists) {
        throw Exception('Goal not found');
      }
      goalData = goalSnap.data();
      final String rawStatus =
          (goalData?['status'] ?? GoalStatus.notStarted.name).toString();
      goalCompleted = rawStatus == GoalStatus.completed.name;
    } catch (e) {
      throw Exception('Failed to load goal for milestone update: $e');
    }

    final docRef = _goalMilestonesRef(goalId).doc(milestoneId);
    GoalMilestoneStatus? previousStatus;
    try {
      final beforeSnap = await docRef.get();
      if (beforeSnap.exists) {
        previousStatus = GoalMilestone.fromFirestore(beforeSnap).status;
      }
    } catch (_) {}

    if (goalCompleted &&
        status != null &&
        previousStatus == GoalMilestoneStatus.completed &&
        status != GoalMilestoneStatus.completed) {
      throw Exception('Completed goals cannot reopen completed milestones.');
    }

    final Map<String, dynamic> updates = {
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (dueDate != null) updates['dueDate'] = Timestamp.fromDate(dueDate);
    if (status != null) {
      // NEW: Evidence validation before milestone completion (additive extension)
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
        updates['completedAt'] = FieldValue.serverTimestamp();
      } else {
        updates['completedAt'] = null;
      }
    }
    await docRef.update(updates);
    final afterSnap = await docRef.get();
    final milestone = GoalMilestone.fromFirestore(afterSnap);

    // Log milestone updates to audit trail
    try {
      final goalSnap = await FirebaseFirestore.instance
          .collection('goals')
          .doc(goalId)
          .get();
      final goalTitle = goalSnap.data()?['title'] ?? 'Unknown Goal';

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
      final goalSnap = await FirebaseFirestore.instance
          .collection('goals')
          .doc(goalId)
          .get();
      if (!goalSnap.exists) return;
      final goal = Goal.fromFirestore(goalSnap);
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
      final snapshot = await _goalMilestonesRef(goalId).get();
      final total = snapshot.docs.length;
      final completed = snapshot.docs.where((doc) {
        final status = (doc.data()['status'] ?? '').toString();
        return status == GoalMilestoneStatus.completed.name;
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

      final goalRef = FirebaseFirestore.instance
          .collection('goals')
          .doc(goalId);
      final goalSnap = await goalRef.get();
      if (!goalSnap.exists) return;
      final data = goalSnap.data() as Map<String, dynamic>;
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

      await goalRef.set({
        'milestoneSummary': summary,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      developer.log('syncGoalProgressWithMilestones error: $e');
    }
  }

  static Future<void> attachGoalEvidence({
    required String goalId,
    required List<String> evidence,
  }) async {
    final goalRef = FirebaseFirestore.instance.collection('goals').doc(goalId);
    await goalRef.set({
      'evidence': FieldValue.arrayUnion(evidence),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> clearGoalEvidence({required String goalId}) async {
    final goalRef = FirebaseFirestore.instance.collection('goals').doc(goalId);
    await goalRef.update({
      'evidence': [],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateGoalProgress(String goalId, int progress) async {
    // Gate: only allow progress on approved goals
    bool isSeason = false;
    try {
      final meta = await FirebaseFirestore.instance
          .collection('goals')
          .doc(goalId)
          .get();
      final data = meta.data();
      isSeason = (data?['isSeasonGoal'] == true);
      final ap = (data?['approvalStatus'] ?? 'pending').toString();
      if (!isSeason && ap != GoalApprovalStatus.approved.name) {
        throw Exception('Goal is not approved yet');
      }
    } catch (e) {
      throw Exception('progress_update.gate: $e');
    }
    // Snap progress to 10% steps and clamp 0..100
    int snapped = ((progress / 10).round() * 10).clamp(0, 100);

    final goals = FirebaseFirestore.instance.collection('goals');
    final goalRef = goals.doc(goalId);
    String? userId;
    bool evidenceExists = false;

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(goalRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final currentStatus = (data['status'] ?? 'notStarted').toString();
        userId = data['userId'] as String?;
        if (currentStatus == GoalStatus.paused.name ||
            currentStatus == GoalStatus.completed.name ||
            currentStatus == GoalStatus.burnout.name) {
          throw Exception('progress_update.blocked: status=$currentStatus');
        }
        final dynamic progressRaw = data['progress'];
        final int previousProgress = progressRaw is int
            ? progressRaw
            : (progressRaw is num ? progressRaw.round() : 0);
        final rawMilestones = data['milestones'];
        final Map<String, dynamic> milestones =
            rawMilestones is Map<String, dynamic>
            ? Map<String, dynamic>.from(rawMilestones)
            : {};
        // Enforce: without evidence, cap progress at 90% for non-season goals
        final List<dynamic> evList = (data['evidence'] is List)
            ? List<dynamic>.from(data['evidence'] as List)
            : <dynamic>[];
        evidenceExists = evList.isNotEmpty;
        int toApply = snapped;
        if (!isSeason && !evidenceExists && snapped > 90) {
          toApply = 90;
        }
        tx.update(goalRef, {'progress': toApply});

        // Auto-transition: if progress > 0 and goal was not started, mark inProgress
        // For season goals, do NOT award regular user points on start
        if (toApply > 0 &&
            currentStatus != GoalStatus.inProgress.name &&
            currentStatus != GoalStatus.completed.name) {
          tx.update(goalRef, {'status': GoalStatus.inProgress.name});
          if (!isSeason && userId != null && userId!.isNotEmpty) {
            final userRef = FirebaseFirestore.instance
                .collection('users')
                .doc(userId);
            tx.update(userRef, {'totalPoints': FieldValue.increment(20)});
          }
        }

        // Milestone: First time crossing/reaching 50% → award +20 points and mark milestone
        final crossed50 = previousProgress < 50 && toApply >= 50;
        if (crossed50 &&
            userId != null &&
            userId!.isNotEmpty &&
            milestones['p50'] != true) {
          if (!isSeason) {
            final userRef = FirebaseFirestore.instance
                .collection('users')
                .doc(userId);
            tx.update(userRef, {'totalPoints': FieldValue.increment(20)});
          }
          milestones['p50'] = true;
          tx.update(goalRef, {'milestones': milestones});
        }
      });
    } catch (e) {
      developer.log('updateGoalProgress transaction failed: $e');
      rethrow;
    }

    // Record daily activity for streak tracking when making progress
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await StreakService.recordDailyActivity(user.uid, 'goal_progress');
        await BadgeService.checkAndAwardBadgesV2(user.uid);
      }
    } catch (e) {
      developer.log('updateGoalProgress post-activity failed: $e');
      // Do not fail the whole call for auxiliary updates
    }

    // Also update the user's lastActivity timestamp directly
    try {
      if (userId != null && userId!.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {'lastActivityAt': FieldValue.serverTimestamp()},
        );
      }
    } catch (e) {
      developer.log('updateGoalProgress lastActivity update failed: $e');
    }

    // If this goal is linked to a Season challenge, sync milestone progress there
    try {
      final goalSnap = await FirebaseFirestore.instance
          .collection('goals')
          .doc(goalId)
          .get();
      final goal = goalSnap.data();
      if (goal != null && (goal['isSeasonGoal'] == true)) {
        final String? seasonId = goal['seasonId'] as String?;
        final String? challengeId = goal['challengeId'] as String?;
        final String? uId = (userId ?? goal['userId']) as String?;
        final dynamic p = goal['progress'];
        final int pNow = p is int ? p : (p is num ? p.round() : 0);
        if (seasonId != null &&
            challengeId != null &&
            uId != null &&
            uId.isNotEmpty) {
          // Load season to discover milestone criteria thresholds
          final season = await SeasonService.getSeason(seasonId);
          if (season != null) {
            final challenge = season.challenges.firstWhere(
              (c) => c.id == challengeId,
              orElse: () => season.challenges.first,
            );
            for (final m in challenge.milestones) {
              final crit = m.criteria;
              final num? threshold = (crit['progress'] is num)
                  ? crit['progress'] as num
                  : null;
              if (threshold != null && pNow >= threshold.round()) {
                await SeasonService.updateMilestoneProgress(
                  seasonId: seasonId,
                  userId: uId,
                  milestoneId: m.id,
                  status: MilestoneStatus.completed,
                );
              } else if (pNow > 0 && threshold == null) {
                final String? action = crit['action'] is String
                    ? crit['action'] as String
                    : null;
                await SeasonService.updateMilestoneProgress(
                  seasonId: seasonId,
                  userId: uId,
                  milestoneId: m.id,
                  status: action == 'project_start'
                      ? MilestoneStatus.completed
                      : MilestoneStatus.inProgress,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      developer.log('updateGoalProgress season sync failed: $e');
    }

    // Create alerts after transaction if 50% milestone reached
    try {
      final snap = await FirebaseFirestore.instance
          .collection('goals')
          .doc(goalId)
          .get();
      final data = snap.data();
      if (data != null) {
        final userId = data['userId'] as String?;
        final dynamic progressNowRaw = data['progress'];
        final int progressNow = progressNowRaw is int
            ? progressNowRaw
            : (progressNowRaw is num ? progressNowRaw.round() : 0);
        final rawMilestones = data['milestones'];
        final Map<String, dynamic> milestones =
            rawMilestones is Map<String, dynamic>
            ? Map<String, dynamic>.from(rawMilestones)
            : {};
        if (!isSeason &&
            userId != null &&
            userId.isNotEmpty &&
            progressNow >= 50 &&
            milestones['p50'] == true) {
          await AlertService.createPointsAlert(
            userId: userId,
            pointsEarned: 20,
            reason: 'reaching 50% progress milestone',
          );
          await AlertService.createMotivationalAlert(
            userId: userId,
            message:
                'Great momentum! You\'re halfway there. Keep pushing to the finish!',
            goalId: goalId,
          );
        }
      }
    } catch (e) {
      developer.log('updateGoalProgress post-alerts failed: $e');
    }
  }

  static Future<void> startGoal(String goalId, String userId) async {
    // Gate: only allow start on approved goals
    final snap = await FirebaseFirestore.instance
        .collection('goals')
        .doc(goalId)
        .get();
    final dataStart = snap.data();
    final bool isSeasonStart = (dataStart?['isSeasonGoal'] == true);
    final ap = (dataStart?['approvalStatus'] ?? 'pending').toString();
    if (!isSeasonStart && ap != GoalApprovalStatus.approved.name) {
      throw Exception('Goal is not approved yet');
    }
    final batch = FirebaseFirestore.instance.batch();

    // Update goal status and award kickoff based on allocated points (idempotent via milestones)
    final goalRef = FirebaseFirestore.instance.collection('goals').doc(goalId);
    final goalSnap = await goalRef.get();
    final data = goalSnap.data();
    final rawCategory = (data?['category'] ?? 'personal')
        .toString()
        .toLowerCase();
    final rawPriority = (data?['priority'] ?? 'medium')
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

    batch.update(goalRef, {'status': GoalStatus.inProgress.name});
    // mark kickoff in milestones
    final Map<String, dynamic> milestones =
        (data?['milestones'] is Map<String, dynamic>)
        ? Map<String, dynamic>.from(data!['milestones'] as Map)
        : {};
    if ((milestones['kickoff'] ?? false) != true) {
      milestones['kickoff'] = true;
      batch.update(goalRef, {'milestones': milestones});
    }

    await batch.commit();

    // Apply capped kickoff award (not for season goals)
    try {
      if (!isSeasonStart) {
        await _incrementUserPointsCapped(userId: userId, amount: bonus);
      }
    } catch (e) {
      developer.log('startGoal capped increment failed: $e');
    }

    // Record daily activity for streak tracking
    await StreakService.recordDailyActivity(userId, 'goal_started');
    await BadgeService.checkAndAwardBadgesV2(userId);
  }

  static Future<void> completeGoal(String goalId, String userId) async {
    final goalRef = FirebaseFirestore.instance.collection('goals').doc(goalId);
    int completionAward = 0;
    bool isSeasonGoalFlag = false;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(goalRef);
      if (!snap.exists) {
        throw Exception('Goal not found');
      }
      final data = snap.data() as Map<String, dynamic>;
      final bool isSeasonComplete = (data['isSeasonGoal'] == true);
      isSeasonGoalFlag = isSeasonComplete;
      final approval = (data['approvalStatus'] ?? 'pending').toString();
      if (!isSeasonComplete && approval != GoalApprovalStatus.approved.name) {
        throw Exception('Goal is not approved yet');
      }
      // Enforce: non-season goals must have evidence before completion
      if (!isSeasonComplete) {
        final ev = data['evidence'];
        final bool hasEvidence = (ev is List && ev.isNotEmpty);
        if (!hasEvidence) {
          throw Exception(
            'Please submit evidence before completing this goal.',
          );
        }
      }
      final status = (data['status'] ?? 'notStarted').toString();
      final progress = (data['progress'] ?? 0) as int;

      // Enforce: must be inProgress and progress 100 to complete
      if (status != GoalStatus.inProgress.name) {
        throw Exception('Start the goal before completing it.');
      }
      if (progress < 100) {
        throw Exception('Set progress to 100% before completing.');
      }

      // Update goal status to completed
      tx.update(goalRef, {'status': GoalStatus.completed.name});

      // Award weighted completion bonus and timing modifier (idempotent via milestones)
      final rawCategory = (data['category'] ?? 'personal')
          .toString()
          .toLowerCase();
      final rawPriority = (data['priority'] ?? 'medium')
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
      final allocated = PointsService.allocatedPointsForGoal(
        category,
        priority,
      );

      final Map<String, dynamic> milestones =
          (data['milestones'] is Map<String, dynamic>)
          ? Map<String, dynamic>.from(data['milestones'] as Map)
          : {};
      if ((milestones['completion'] ?? false) != true) {
        int totalAward = PointsService.completionBonus(allocated);
        // On-time or late modifier
        final targetTs = data['targetDate'];
        if (targetTs is Timestamp) {
          final target = targetTs.toDate();
          final now = DateTime.now();
          if (!now.isAfter(target)) {
            totalAward += PointsService.onTimeModifier(allocated).toInt();
          } else {
            totalAward += PointsService.lateModifier(allocated).toInt();
          }
        }
        completionAward = totalAward;
        milestones['completion'] = true;
        tx.update(goalRef, {'milestones': milestones});
      }
    });

    // Apply capped completion award (not for season goals)
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

    // Record daily activity for streak tracking
    await StreakService.recordDailyActivity(userId, 'goal_completed');
    await BadgeService.checkAndAwardBadgesV2(userId);
  }

  static Future<void> updateUserPoints(
    String userId,
    int points,
    String reason,
  ) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    // Get current user data to check for level up
    final userDoc = await userRef.get();
    final currentPoints = (userDoc.data()?['totalPoints'] ?? 0) as int;

    final newPoints = currentPoints + points;
    final newLevel = _calculateLevel(newPoints);

    final batch = FirebaseFirestore.instance.batch();

    // Update points
    batch.update(userRef, {'totalPoints': newPoints, 'level': newLevel});

    await batch.commit();
  }

  static int _calculateLevel(int points) {
    // Level up every 500 points
    return (points ~/ 500) + 1;
  }

  static Future<void> initializeSubcollections(
    DocumentReference userDocRef,
  ) async {
    final subcollections = [
      'goals',
      'streaks',
      'badges',
      'alerts',
      'development_activities',
    ];

    for (String sub in subcollections) {
      final subRef = userDocRef.collection(sub).doc('init');
      final subSnap = await subRef.get();
      if (!subSnap.exists) {
        await subRef.set({
          'placeholder': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  static Future<void> initializeUserData(
    String uid,
    String? displayName,
    String? email, {
    String role = 'employee',
  }) async {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);

    // Check onboarding collection for user data if displayName is missing
    String? resolvedDisplayName = displayName;
    String? resolvedEmail = email;

    if ((resolvedDisplayName == null || resolvedDisplayName.isEmpty) ||
        (resolvedEmail == null || resolvedEmail.isEmpty)) {
      try {
        final onboardingDoc = await FirebaseFirestore.instance
            .collection('onboarding')
            .doc(uid)
            .get();

        if (onboardingDoc.exists) {
          final onboardingData = onboardingDoc.data();
          // Try multiple possible field names for name in onboarding
          resolvedDisplayName = resolvedDisplayName?.isNotEmpty == true
              ? resolvedDisplayName
              : onboardingData?['displayName'] ??
                    onboardingData?['fullName'] ??
                    onboardingData?['name'] ??
                    onboardingData?['firstName'] ??
                    (onboardingData?['firstName'] != null &&
                            onboardingData?['lastName'] != null
                        ? '${onboardingData?['firstName']} ${onboardingData?['lastName']}'
                              .trim()
                        : null);

          resolvedEmail = resolvedEmail?.isNotEmpty == true
              ? resolvedEmail
              : onboardingData?['email'] ?? email;
        }
      } catch (e) {
        developer.log('Error checking onboarding collection: $e');
        // Continue with original values if onboarding check fails
      }
    }

    final docSnapshot = await userDocRef.get();
    if (!docSnapshot.exists) {
      final userData = {
        'displayName': resolvedDisplayName?.isNotEmpty == true
            ? resolvedDisplayName
            : '', // Use displayName from onboarding or provided, or an empty string
        'email': resolvedEmail ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'role': role, // default role, only set on creation
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

      // For new users, enable tutorial but don't set completion status
      // This allows tutorial to show on first login
      if (role == 'employee') {
        userData['tutorialEnabled'] = true;
        // Don't set employeeSidebarTutorialCompleted - leave it as null
        // so tutorial will show on first login
      } else if (role == 'manager') {
        userData['tutorialEnabled'] = true;
        // Don't set managerSidebarTutorialCompleted - leave it as null
        // so tutorial will show on first login
      } else if (role == 'admin') {
        userData['tutorialEnabled'] = false;
        // Admin portal has no sidebar tutorial
      }

      await userDocRef.set(userData);
    } else {
      // Only update fields that might change
      // Also check if displayName is currently empty and update from onboarding if needed
      final currentDisplayName = docSnapshot.data()?['displayName'] ?? '';
      final finalDisplayName = resolvedDisplayName?.isNotEmpty == true
          ? resolvedDisplayName
          : (currentDisplayName.isNotEmpty ? currentDisplayName : '');

      // Get current role, if any
      final currentRole = docSnapshot.data()?['role'] as String?;

      // Prepare update map
      final updateData = <String, dynamic>{
        'displayName': finalDisplayName.isNotEmpty
            ? finalDisplayName
            : (docSnapshot.data()?['displayName'] ?? ''),
        'email': resolvedEmail ?? docSnapshot.data()?['email'] ?? '',
      };

      // Update role ONLY if:
      // 1. Role is not currently set (null or empty), OR
      // 2. Current role is 'employee' AND new role is 'manager' (upgrade)
      // NEVER overwrite a 'manager' role with 'employee'
      if (currentRole == null || currentRole.isEmpty) {
        // Role is not set - set it to the provided role (or default to employee)
        updateData['role'] = role;
      } else if (currentRole == 'employee' && role == 'manager') {
        // Allow upgrade from employee to manager
        updateData['role'] = role;
      } else if (currentRole == 'manager') {
        // NEVER overwrite manager role - preserve it
        // Don't add role to updateData
      } else if (currentRole == 'employee' && role == 'employee') {
        // Already employee, no need to update
        // Don't add role to updateData
      }
      // If role is already set to 'manager', it's preserved above

      await userDocRef.update(updateData);
    }

    await initializeSubcollections(userDocRef);
  }

  /// Syncs user data from onboarding collection if displayName or email is missing
  /// This helps resolve "Anonymous" user issues
  static Future<void> syncOnboardingData(String uid) async {
    try {
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        return; // User document doesn't exist yet
      }

      final userData = userDoc.data() ?? {};
      final currentDisplayName = userData['displayName']?.toString() ?? '';
      final currentEmail = userData['email']?.toString() ?? '';

      // If displayName is empty or missing, check onboarding
      if (currentDisplayName.isEmpty) {
        try {
          final onboardingDoc = await FirebaseFirestore.instance
              .collection('onboarding')
              .doc(uid)
              .get();

          if (onboardingDoc.exists) {
            final onboardingData = onboardingDoc.data() ?? {};
            // Try multiple possible field names for name in onboarding
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

            // Update user document if we found name or email from onboarding
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
              await userDocRef.update(updates);
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

  /// Gets user name from onboarding collection
  /// Tries multiple field names: displayName, fullName, name, firstName, or firstName + lastName
  static Future<String?> getUserNameFromOnboarding({
    required String userId,
    String? email,
  }) async {
    if (FirestoreWebCircuitBreaker.isBroken) {
      return null;
    }
    try {
      // First try by userId
      var onboardingDoc = await FirebaseFirestore.instance
          .collection('onboarding')
          .doc(userId)
          .get();

      // If not found by userId and email is provided, try to find by email
      if (!onboardingDoc.exists && email != null && email.isNotEmpty) {
        final onboardingQuery = await FirebaseFirestore.instance
            .collection('onboarding')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (onboardingQuery.docs.isNotEmpty) {
          onboardingDoc = onboardingQuery.docs.first;
        }
      }

      if (onboardingDoc.exists) {
        final onboardingData = onboardingDoc.data() ?? {};
        // Try multiple possible field names for name in onboarding
        final name =
            onboardingData['displayName'] ??
            onboardingData['fullName'] ??
            onboardingData['name'] ??
            onboardingData['firstName'] ??
            (onboardingData['firstName'] != null &&
                    onboardingData['lastName'] != null
                ? '${onboardingData['firstName']} ${onboardingData['lastName']}'
                      .trim()
                : null);

        if (name != null && name.toString().isNotEmpty) {
          return name.toString();
        }
      }
    } catch (e) {
      developer.log('Error getting user name from onboarding: $e');
      FirestoreWebCircuitBreaker.maybeReload(e);
    }
    return null;
  }

  /// Helper function to prepare user document data for writing
  /// Removes 'role' field if document exists (to satisfy security rules)
  /// This ensures all write operations (set, update) comply with Firestore rules
  static Future<Map<String, dynamic>> _prepareUserDataForWrite(
    String uid,
    Map<String, dynamic> data,
  ) async {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final existing = await userDocRef.get();

    // Create a copy to avoid modifying the original
    final preparedData = Map<String, dynamic>.from(data);

    // Remove 'role' field if document exists (users can't change their own role)
    // Only admins can modify roles, and they should use a separate admin function
    if (existing.exists) {
      preparedData.remove('role');
    }

    return preparedData;
  }

  static Future<void> updateUserProfile(UserProfile userProfile) async {
    final userDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userProfile.uid);

    // Verify user is authenticated and matches the profile UID
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid == null) {
      throw Exception('User not authenticated');
    }
    if (authUid != userProfile.uid) {
      throw Exception(
        'Cannot update profile: authenticated user ($authUid) does not match profile UID ($userProfile.uid)',
      );
    }

    // Prepare data for write (removes role if document exists)
    final data = await _prepareUserDataForWrite(
      userProfile.uid,
      userProfile.toFirestore(),
    );

    // Debug log to help diagnose permission issues
    try {
      final projectId = Firebase.app().options.projectId;
      developer.log(
        'updateUserProfile: authUid=$authUid, targetUid=${userProfile.uid}, keys=${data.keys.join(',')}, project=$projectId',
      );
    } catch (_) {}

    // Use set with merge: true to ensure all fields are saved
    // This is more robust and handles cases where some fields might not exist yet
    try {
      await userDocRef.set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      developer.log(
        'updateUserProfile: FirebaseException code=${e.code}, message=${e.message ?? ''}, path=${userDocRef.path}',
        error: e,
      );
      rethrow;
    } catch (e) {
      developer.log('updateUserProfile: Unexpected error $e');
      rethrow;
    }

    // Update cache immediately after successful save to reflect changes
    // This ensures the UI shows the latest data immediately
    final cache = PerformanceCacheService();
    cache.cacheUserProfile(userProfile);
  }

  static Future<Map<String, dynamic>> getDashboardData(String uid) async {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final doc = await userDocRef.get();
    final goals = await userDocRef.collection('goals').get();
    final streaks = await userDocRef.collection('streaks').get();
    final badges = await userDocRef.collection('badges').get();
    final alerts = await userDocRef.collection('alerts').get();

    return {
      'profile': doc.data(),
      'goals': goals.docs.map((d) => d.data()).toList(),
      'streaks': streaks.docs.map((d) => d.data()).toList(),
      'badges': badges.docs.map((d) => d.data()).toList(),
      'alerts': alerts.docs.map((d) => d.data()).toList(),
    };
  }

  /// Log goal rejection to audit_entries collection
  static Future<void> _logGoalRejected({
    required String goalId,
    required String goalTitle,
    required String userId,
    required String rejectionReason,
  }) async {
    try {
      final event = {
        'action': 'goal_rejected',
        'goalId': goalId,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Goal rejected: $goalTitle',
        'metadata': {
          'goalTitle': goalTitle,
          'goalId': goalId,
          'rejectionReason': rejectionReason,
        },
        'status': 'rejected',
      };

      await FirebaseFirestore.instance.collection('audit_entries').add(event);
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
      final event = {
        'action': 'goal_created',
        'goalId': goalId,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'Goal created: $goalTitle',
        'metadata': {'goalTitle': goalTitle, 'goalId': goalId},
        'status': 'pending', // Goals start as pending approval
      };

      await FirebaseFirestore.instance.collection('audit_entries').add(event);
      developer.log('Goal creation logged: $goalTitle for user $userId');
    } catch (e, stackTrace) {
      developer.log(
        'Error logging goal creation: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
