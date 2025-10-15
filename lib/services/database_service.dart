import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/streak_service.dart';
import 'package:pdh/services/badge_service.dart';
import 'package:pdh/services/season_service.dart';

class DatabaseService {
  static Future<UserProfile> getUserProfile(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data() ?? {};
    return UserProfile(
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
  }

  static Future<void> approveGoal({
    required String goalId,
    required String managerId,
    required String managerName,
  }) async {
    final goalRef = FirebaseFirestore.instance.collection('goals').doc(goalId);
    await goalRef.update({
      'approvalStatus': GoalApprovalStatus.approved.name,
      'approvedByUserId': managerId,
      'approvedByName': managerName,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectionReason': null,
    });
    try {
      final doc = await goalRef.get();
      final data = doc.data();
      if (data != null) {
        await AlertService.createGoalApprovalDecisionAlert(
          employeeId: (data['userId'] ?? '') as String,
          goalId: goalId,
          goalTitle: (data['title'] ?? '') as String,
          approved: true,
        );
      }
    } catch (_) {}
  }

  static Future<void> rejectGoal({
    required String goalId,
    required String managerId,
    required String managerName,
    String? reason,
  }) async {
    final goalRef = FirebaseFirestore.instance.collection('goals').doc(goalId);
    await goalRef.update({
      'approvalStatus': GoalApprovalStatus.rejected.name,
      'approvedByUserId': managerId,
      'approvedByName': managerName,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
    });
    try {
      final doc = await goalRef.get();
      final data = doc.data();
      if (data != null) {
        await AlertService.createGoalApprovalDecisionAlert(
          employeeId: (data['userId'] ?? '') as String,
          goalId: goalId,
          goalTitle: (data['title'] ?? '') as String,
          approved: false,
          reason: reason,
        );
      }
    } catch (_) {}
  }

  static Future<Goal?> getGoalById(String goalId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('goals').doc(goalId).get();
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
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        targetDate: (data['targetDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      final snapshot = await FirebaseFirestore.instance
          .collection('goals')
          .where('userId', isEqualTo: uid)
          .get();

      final goals = snapshot.docs.map((doc) {
        final data = doc.data();
        return Goal(
          id: doc.id,
          userId: data['userId'] ?? uid,
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
          approvalStatus: GoalApprovalStatus.values.firstWhere(
            (e) => e.name == (data['approvalStatus'] ?? 'pending'),
            orElse: () => GoalApprovalStatus.pending,
          ),
          approvedByUserId: data['approvedByUserId'],
          approvedByName: data['approvedByName'],
          approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
          rejectionReason: data['rejectionReason'],
        );
      }).toList();

      // Sort in memory to avoid Firestore index requirements
      goals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return goals;
    } catch (e) {
      // Return empty list if there's an error (like missing index)
      return [];
    }
  }

  static Stream<List<Goal>> getUserGoalsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('goals')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return Goal(
              id: doc.id,
              userId: data['userId'] ?? uid,
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
                  (data['targetDate'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              points: (data['points'] ?? 0) as int,
              kpa: (() {
                final raw = data['kpa'];
                return raw is String ? raw.toLowerCase() : null;
              })(),
              approvalStatus: GoalApprovalStatus.values.firstWhere(
                (e) => e.name == (data['approvalStatus'] ?? 'pending'),
                orElse: () => GoalApprovalStatus.pending,
              ),
              approvedByUserId: data['approvedByUserId'],
              approvedByName: data['approvedByName'],
              approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
              rejectionReason: data['rejectionReason'],
            );
          }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  static Future<String> createGoal(Goal goal) async {
    final doc = await FirebaseFirestore.instance.collection('goals').add({
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
      // approval fields
      'approvalStatus': GoalApprovalStatus.pending.name,
      'approvedByUserId': null,
      'approvedByName': null,
      'approvedAt': null,
      'rejectionReason': null,
    });
    try {
      // Notify managers for approval
      await AlertService.createGoalApprovalRequestedAlert(
        employeeId: goal.userId,
        goalId: doc.id,
        goalTitle: goal.title,
      );
    } catch (_) {}
    return doc.id;
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

  static Future<void> deleteGoal({
    required String goalId,
    required String requesterId,
  }) async {
    final fs = FirebaseFirestore.instance;
    final goalRef = fs.collection('goals').doc(goalId);
    final goalSnap = await goalRef.get();
    if (!goalSnap.exists) {
      throw Exception('Goal not found');
    }
    final data = goalSnap.data() as Map<String, dynamic>;
    final ownerId = (data['userId'] ?? '') as String;

    String role = 'employee';
    try {
      final userDoc = await fs.collection('users').doc(requesterId).get();
      role = (userDoc.data()?['role'] ?? 'employee') as String;
    } catch (_) {}

    if (requesterId != ownerId && role != 'manager') {
      throw Exception('Not authorized to delete this goal');
    }

    final batch = fs.batch();
    batch.delete(goalRef);

    try {
      final alerts = await fs
          .collection('alerts')
          .where('relatedGoalId', isEqualTo: goalId)
          .get();
      for (final d in alerts.docs) {
        batch.delete(d.reference);
      }
    } catch (_) {}

    try {
      final daily = await fs
          .collection('goal_daily_progress')
          .where('goalId', isEqualTo: goalId)
          .get();
      for (final d in daily.docs) {
        batch.delete(d.reference);
      }
    } catch (_) {}

    await batch.commit();
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

  static Future<void> updateGoalProgress(String goalId, int progress) async {
    // Gate: only allow progress on approved goals
    try {
      final meta = await FirebaseFirestore.instance.collection('goals').doc(goalId).get();
      final ap = (meta.data()?['approvalStatus'] ?? 'pending').toString();
      if (ap != GoalApprovalStatus.approved.name) {
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
    
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(goalRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final currentStatus = (data['status'] ?? 'notStarted').toString();
        userId = data['userId'] as String?;
        final dynamic progressRaw = data['progress'];
        final int previousProgress = progressRaw is int
            ? progressRaw
            : (progressRaw is num ? progressRaw.round() : 0);
        final rawMilestones = data['milestones'];
        final Map<String, dynamic> milestones = rawMilestones is Map<String, dynamic>
            ? Map<String, dynamic>.from(rawMilestones)
            : {};

        tx.update(goalRef, {'progress': snapped});

        if (snapped > 0 &&
            currentStatus != GoalStatus.inProgress.name &&
            currentStatus != GoalStatus.completed.name) {
          tx.update(goalRef, {'status': GoalStatus.inProgress.name});
          if (userId != null && userId!.isNotEmpty) {
            final userRef = FirebaseFirestore.instance
                .collection('users')
                .doc(userId);
            tx.update(userRef, {'totalPoints': FieldValue.increment(20)});
          }
        }

        final crossed50 = previousProgress < 50 && snapped >= 50;
        if (crossed50 &&
            userId != null &&
            userId!.isNotEmpty &&
            milestones['p50'] != true) {
          final userRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userId);
          tx.update(userRef, {'totalPoints': FieldValue.increment(20)});
          milestones['p50'] = true;
          tx.update(goalRef, {'milestones': milestones});
        }
      });
    } catch (e) {
      developer.log('updateGoalProgress transaction failed: $e');
      throw Exception('progress_update.tx: $e');
    }

    // Record daily activity for streak tracking when making progress
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await StreakService.recordDailyActivity(user.uid, 'goal_progress');
        await BadgeService.checkAndAwardBadges(user.uid);
      }
    } catch (e) {
      developer.log('updateGoalProgress post-activity failed: $e');
      // Do not fail the whole call for auxiliary updates
    }
    
    // Also update the user's lastActivity timestamp directly
    try {
      if (userId != null && userId!.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'lastActivityAt': FieldValue.serverTimestamp(),
        });
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
        if (seasonId != null && challengeId != null && uId != null && uId.isNotEmpty) {
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
                // If no numeric criteria, mark as in progress when user starts
                await SeasonService.updateMilestoneProgress(
                  seasonId: seasonId,
                  userId: uId,
                  milestoneId: m.id,
                  status: MilestoneStatus.inProgress,
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
        final Map<String, dynamic> milestones = rawMilestones is Map<String, dynamic>
            ? Map<String, dynamic>.from(rawMilestones)
            : {};
        if (userId != null &&
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
    final snap = await FirebaseFirestore.instance.collection('goals').doc(goalId).get();
    final ap = (snap.data()?['approvalStatus'] ?? 'pending').toString();
    if (ap != GoalApprovalStatus.approved.name) {
      throw Exception('Goal is not approved yet');
    }
    final batch = FirebaseFirestore.instance.batch();

    // Update goal status
    final goalRef = FirebaseFirestore.instance.collection('goals').doc(goalId);
    batch.update(goalRef, {'status': GoalStatus.inProgress.name});

    // Award points for starting goal
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    batch.update(userRef, {'totalPoints': FieldValue.increment(20)});

    await batch.commit();

    // Record daily activity for streak tracking
    await StreakService.recordDailyActivity(userId, 'goal_started');
    await BadgeService.checkAndAwardBadges(userId);
  }

  static Future<void> completeGoal(String goalId, String userId) async {
    final goalRef = FirebaseFirestore.instance.collection('goals').doc(goalId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(goalRef);
      if (!snap.exists) {
        throw Exception('Goal not found');
      }
      final data = snap.data() as Map<String, dynamic>;
      final approval = (data['approvalStatus'] ?? 'pending').toString();
      if (approval != GoalApprovalStatus.approved.name) {
        throw Exception('Goal is not approved yet');
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

      // Award points for completing goal
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      tx.update(userRef, {'totalPoints': FieldValue.increment(100)});
    });

    // Record daily activity for streak tracking
    await StreakService.recordDailyActivity(userId, 'goal_completed');
    await BadgeService.checkAndAwardBadges(userId);
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
    final currentLevel = (userDoc.data()?['level'] ?? 1) as int;

    final newPoints = currentPoints + points;
    final newLevel = _calculateLevel(newPoints);

    final batch = FirebaseFirestore.instance.batch();

    // Update points
    batch.update(userRef, {'totalPoints': newPoints, 'level': newLevel});

    await batch.commit();

    // Check if user leveled up
    if (newLevel > currentLevel) {
      await AlertService.createLevelUpAlert(userId: userId, newLevel: newLevel);
    }
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

    final docSnapshot = await userDocRef.get();
    if (!docSnapshot.exists) {
      await userDocRef.set({
        'displayName':
            displayName ??
            '', // Use displayName as full name, or an empty string
        'email': email ?? '',
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
        'badgeName': '',
        'celebrationConsent': 'private',
      });
    } else {
      // Only update fields that might change, excluding 'role'
      await userDocRef.update({
        'displayName': displayName ?? docSnapshot.data()?['displayName'] ?? '',
        'email': email ?? docSnapshot.data()?['email'] ?? '',
        // Other fields will be updated by a dedicated updateUserProfile method.
      });
    }

    await initializeSubcollections(userDocRef);
  }

  static Future<void> updateUserProfile(UserProfile userProfile) async {
    final userDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userProfile.uid);
    await userDocRef.update(userProfile.toFirestore());
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
}
