import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/streak_service.dart';
import 'package:pdh/services/badge_service.dart';

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
          progress: (data['progress'] ?? 0) as int,
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          targetDate:
              (data['targetDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          points: (data['points'] ?? 0) as int,
          kpa: (data['kpa'] as String?)?.toLowerCase(),
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
              progress: (data['progress'] ?? 0) as int,
              createdAt:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              targetDate:
                  (data['targetDate'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              points: (data['points'] ?? 0) as int,
              kpa: (data['kpa'] as String?)?.toLowerCase(),
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
    });
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

  static Future<void> attachGoalEvidence({
    required String goalId,
    required List<String> evidence,
  }) async {
    final goalRef = FirebaseFirestore.instance.collection('goals').doc(goalId);
    await goalRef.set({
      'evidence': FieldValue.arrayUnion(evidence),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
<<<<<<< HEAD

    // Auto audit log: evidence upload
    await AuditLogger.logAuditAction(
      goalId: goalId,
      actionType: 'evidence_upload',
      description: 'Uploaded ${evidence.length} evidence item(s)',
    );
=======
>>>>>>> origin/lihle-manager
  }

  static Future<void> updateGoalProgress(String goalId, int progress) async {
    // Snap progress to 10% steps and clamp 0..100
    int snapped = ((progress / 10).round() * 10).clamp(0, 100);

    final goals = FirebaseFirestore.instance.collection('goals');
    final goalRef = goals.doc(goalId);
<<<<<<< HEAD
=======
    String? userId;
    
>>>>>>> origin/lihle-manager
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(goalRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final currentStatus = (data['status'] ?? 'notStarted').toString();
<<<<<<< HEAD
      final userId = data['userId'] as String?;
=======
      userId = data['userId'] as String?;
>>>>>>> origin/lihle-manager
      final previousProgress = (data['progress'] ?? 0) as int;
      final milestones = Map<String, dynamic>.from(
        data['milestones'] ?? const {},
      );

      // Always update progress
      tx.update(goalRef, {'progress': snapped});

      // Auto-transition: if progress > 0 and goal was not started, mark inProgress and award start points once
      if (snapped > 0 &&
          currentStatus != GoalStatus.inProgress.name &&
          currentStatus != GoalStatus.completed.name) {
        tx.update(goalRef, {'status': GoalStatus.inProgress.name});
<<<<<<< HEAD
        if (userId != null && userId.isNotEmpty) {
=======
        if (userId != null && userId!.isNotEmpty) {
>>>>>>> origin/lihle-manager
          final userRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userId);
          tx.update(userRef, {'totalPoints': FieldValue.increment(20)});
        }
      }

      // Milestone: First time crossing/reaching 50% → award +20 points and mark milestone
      final crossed50 = previousProgress < 50 && snapped >= 50;
      if (crossed50 &&
          userId != null &&
<<<<<<< HEAD
          userId.isNotEmpty &&
=======
          userId!.isNotEmpty &&
>>>>>>> origin/lihle-manager
          milestones['p50'] != true) {
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId);
        tx.update(userRef, {'totalPoints': FieldValue.increment(20)});
        milestones['p50'] = true;
        tx.update(goalRef, {'milestones': milestones});
      }
    });

    // Record daily activity for streak tracking when making progress
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await StreakService.recordDailyActivity(user.uid, 'goal_progress');
      await BadgeService.checkAndAwardBadges(user.uid);
    }
<<<<<<< HEAD

    // Auto audit log: progress update
    await AuditLogger.logAuditAction(
      goalId: goalId,
      actionType: 'progress_update',
      description: 'Progress updated to $snapped%',
    );
=======
    
    // Also update the user's lastActivity timestamp directly
    if (userId != null && userId!.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
    }
>>>>>>> origin/lihle-manager

    // Create alerts after transaction if 50% milestone reached
    try {
      final snap = await FirebaseFirestore.instance
          .collection('goals')
          .doc(goalId)
          .get();
      final data = snap.data();
      if (data != null) {
        final userId = data['userId'] as String?;
        final progressNow = (data['progress'] ?? 0) as int;
        final milestones = Map<String, dynamic>.from(
          data['milestones'] ?? const {},
        );
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
    } catch (_) {}
  }

  static Future<void> startGoal(String goalId, String userId) async {
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
<<<<<<< HEAD

    // Auto audit log: milestone completion
    await AuditLogger.logAuditAction(
      goalId: goalId,
      actionType: 'milestone_completion',
      description: 'Goal marked completed',
    );
=======
>>>>>>> origin/lihle-manager
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
