import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/manager_realtime_service.dart';

class AlertService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create different types of alerts
  static Future<void> createGoalAlert({
    required String userId,
    required Goal goal,
    required AlertType type,
  }) async {
    String title;
    String message;
    String? actionText;
    String? actionRoute;
    AlertPriority priority;

    switch (type) {
      case AlertType.goalCreated:
        title = 'New Goal Created!';
        message = 'You created "${goal.title}". Time to make it happen!';
        actionText = 'View Goal';
        actionRoute = '/my_goal_workspace';
        priority = AlertPriority.medium;
        break;
      case AlertType.goalCompleted:
        title = 'Goal Completed! 🎉';
        message = 'Congratulations! You completed "${goal.title}" and earned ${goal.points} points!';
        actionText = 'View Progress';
        actionRoute = '/progress_visuals';
        priority = AlertPriority.high;
        break;
      case AlertType.goalDueSoon:
        final daysLeft = goal.targetDate.difference(DateTime.now()).inDays;
        title = 'Goal Due Soon ⏰';
        message = '"${goal.title}" is due in $daysLeft day${daysLeft == 1 ? '' : 's'}. Keep pushing!';
        actionText = 'Update Progress';
        actionRoute = '/my_goal_workspace';
        priority = AlertPriority.high;
        break;
      case AlertType.goalOverdue:
        final daysOverdue = DateTime.now().difference(goal.targetDate).inDays;
        title = 'Goal Overdue ⚠️';
        message = '"${goal.title}" is overdue by $daysOverdue day${daysOverdue == 1 ? '' : 's'}. Don\'t give up!';
        actionText = 'Reschedule';
        actionRoute = '/my_goal_workspace';
        priority = AlertPriority.urgent;
        break;
      default:
        return;
    }

    final alert = Alert(
      id: '',
      userId: userId,
      type: type,
      priority: priority,
      title: title,
      message: message,
      actionText: actionText,
      actionRoute: actionRoute,
      createdAt: DateTime.now(),
      relatedGoalId: goal.id,
      expiresAt: DateTime.now().add(const Duration(days: 7)), // Expire after 7 days
    );

    await _createAlert(alert);
  }

  static Future<void> createPointsAlert({
    required String userId,
    required int pointsEarned,
    required String reason,
  }) async {
    final alert = Alert(
      id: '',
      userId: userId,
      type: AlertType.pointsEarned,
      priority: AlertPriority.medium,
      title: 'Points Earned! ⭐',
      message: 'You earned $pointsEarned points for $reason!',
      actionText: 'View Points',
      actionRoute: '/badges_points',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 3)),
    );

    await _createAlert(alert);
  }

  // Simple motivational alert used for progress encouragement
  static Future<void> createMotivationalAlert({
    required String userId,
    required String message,
    String? goalId,
  }) async {
    final alert = Alert(
      id: '',
      userId: userId,
      type: AlertType.achievementUnlocked,
      priority: AlertPriority.low,
      title: 'Keep Going! 💪',
      message: message,
      actionText: goalId != null ? 'View Goal' : null,
      actionRoute: goalId != null ? '/my_goal_workspace' : null,
      actionData: goalId != null ? {'goalId': goalId} : null,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 3)),
      relatedGoalId: goalId,
    );

    await _createAlert(alert);
  }

  static Future<void> createLevelUpAlert({
    required String userId,
    required int newLevel,
  }) async {
    final alert = Alert(
      id: '',
      userId: userId,
      type: AlertType.levelUp,
      priority: AlertPriority.high,
      title: 'Level Up! 🚀',
      message: 'Congratulations! You\'ve reached Level $newLevel!',
      actionText: 'View Profile',
      actionRoute: '/employee_profile',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );

    await _createAlert(alert);
  }

  static Future<void> createBadgeAlert({
    required String userId,
    required String badgeName,
  }) async {
    final alert = Alert(
      id: '',
      userId: userId,
      type: AlertType.badgeEarned,
      priority: AlertPriority.high,
      title: 'Badge Earned! 🏆',
      message: 'You\'ve earned the "$badgeName" badge! Keep up the great work!',
      actionText: 'View Badges',
      actionRoute: '/badges_points',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );

    await _createAlert(alert);
  }

  static Future<void> createTeamGoalAlert({
    required String userId,
    required String teamGoalTitle,
    required String managerName,
    required int points,
    required DateTime deadline,
  }) async {
    final alert = Alert(
      id: '',
      userId: userId,
      type: AlertType.teamGoalAvailable,
      priority: AlertPriority.high,
      title: 'New Team Goal Available! 🎯',
      message: '$managerName created a new team goal: "$teamGoalTitle". Join your team and earn $points points by ${deadline.day}/${deadline.month}/${deadline.year}!',
      actionText: 'Join Team',
      actionRoute: '/team_goals',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 14)),
    );

    await _createAlert(alert);
  }

  static Future<void> createEmployeeJoinedTeamGoalAlert({
    required String managerId,
    required String employeeName,
    required String teamGoalTitle,
    required String teamGoalId,
  }) async {
    final alert = Alert(
      id: '',
      userId: managerId,
      type: AlertType.employeeJoinedTeamGoal,
      priority: AlertPriority.medium,
      title: 'Employee Joined Team Goal! 👥',
      message: '$employeeName joined your team goal "$teamGoalTitle". The team is growing stronger!',
      actionText: 'View Team',
      actionRoute: '/manager_team_workspace',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );

    await _createAlert(alert);
  }

  static Future<void> createTeamAssignmentAlert({
    required String userId,
    required String teamName,
    required String managerName,
  }) async {
    final alert = Alert(
      id: '',
      userId: userId,
      type: AlertType.teamAssigned,
      priority: AlertPriority.high,
      title: 'Added to Team! 👥',
      message: '$managerName added you to the "$teamName" team.',
      actionText: 'View Team',
      actionRoute: '/employee_dashboard',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 14)),
    );

    await _createAlert(alert);
  }

  static Future<void> createManagerNudgeAlert({
    required String userId,
    required String managerName,
    required String goalTitle,
    required String nudgeMessage,
  }) async {
    final alert = Alert(
      id: '',
      userId: userId,
      type: AlertType.managerNudge,
      priority: AlertPriority.high,
      title: 'Manager Nudge 📢',
      message: '$managerName sent you a nudge about "$goalTitle": $nudgeMessage',
      actionText: 'View Goal',
      actionRoute: '/my_goal_workspace',
      createdAt: DateTime.now(),
      fromUserName: managerName,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );

    await _createAlert(alert);
  }

  /// Create manager nudge alert with enhanced data
  static Future<void> createManagerNudgeAlertEnhanced({
    required String userId,
    required String goalId,
    required String managerId,
    required String managerName,
    required String goalTitle,
    required String nudgeMessage,
  }) async {
    try {
      await _firestore.collection('alerts').add({
        'userId': userId,
        'type': AlertType.managerNudge.name,
        'priority': AlertPriority.high.name,
        'title': 'Manager Nudge 📢',
        'message': '$managerName sent you a nudge about "$goalTitle": $nudgeMessage',
        'actionText': 'View Goal',
        'actionRoute': '/my_goal_workspace',
        'actionData': {'goalId': goalId},
        'createdAt': FieldValue.serverTimestamp(),
        'fromUserId': managerId,
        'fromUserName': managerName,
        'relatedGoalId': goalId,
        'isRead': false,
        'isDismissed': false,
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
      });

      // Record activity for the employee
      await ManagerRealtimeService.recordEmployeeActivity(
        employeeId: userId,
        activityType: 'nudge_received',
        description: 'Received a nudge from $managerName about "$goalTitle"',
        metadata: {
          'goalId': goalId,
          'goalTitle': goalTitle,
          'managerName': managerName,
          'managerId': managerId,
        },
      );

      developer.log('Created enhanced manager nudge alert for user $userId');
    } catch (e) {
      developer.log('Error creating enhanced manager nudge alert: $e');
      rethrow;
    }
  }

  static Future<void> createStreakAlert({
    required String userId,
    required int streakDays,
  }) async {
    final alert = Alert(
      id: '',
      userId: userId,
      type: AlertType.streakMilestone,
      priority: AlertPriority.medium,
      title: 'Streak Milestone! 🔥',
      message: 'Amazing! You\'ve maintained a $streakDays-day streak!',
      actionText: 'View Progress',
      actionRoute: '/progress_visuals',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 3)),
    );

    await _createAlert(alert);
  }

  // Core alert management
  static Future<void> _createAlert(Alert alert) async {
    try {
      await _firestore.collection('alerts').add(alert.toFirestore());
    } catch (e) {
      developer.log('Error creating alert: $e');
      // Silently fail for now - alerts are not critical for app functionality
    }
  }

  static Stream<List<Alert>> getUserAlertsStream(String userId) {
    return _firestore
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .where('isDismissed', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      try {
        final alerts = snapshot.docs
            .map((doc) => Alert.fromFirestore(doc))
            .where((alert) {
              // Filter out expired alerts
              if (alert.expiresAt != null && alert.expiresAt!.isBefore(DateTime.now())) {
                return false;
              }
              return true;
            })
            .toList();
        
        // Sort in memory to avoid index requirements
        alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return alerts.take(50).toList();
      } catch (e) {
        developer.log('Error processing alerts: $e');
        return <Alert>[];
      }
    }).handleError((error) {
      developer.log('Error loading alerts: $error');
      return <Alert>[];
    });
  }

  static Future<void> markAsRead(String alertId) async {
    try {
      await _firestore.collection('alerts').doc(alertId).update({
        'isRead': true,
      });
    } catch (e) {
      developer.log('Error marking alert as read: $e');
    }
  }

  static Future<void> dismissAlert(String alertId) async {
    try {
      await _firestore.collection('alerts').doc(alertId).update({
        'isDismissed': true,
      });
    } catch (e) {
      developer.log('Error dismissing alert: $e');
    }
  }

  static Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final alerts = await _firestore
          .collection('alerts')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in alerts.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      developer.log('Error marking all alerts as read: $e');
    }
  }

  // Auto-generate alerts based on goal events
  static Future<void> checkAndCreateGoalAlerts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get user's goals
      final goalsSnapshot = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: user.uid)
          .get();

      for (final doc in goalsSnapshot.docs) {
        final data = doc.data();
        final goal = Goal(
          id: doc.id,
          userId: data['userId'] ?? user.uid,
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
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          targetDate: (data['targetDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          points: (data['points'] ?? 0) as int,
        );

        // Check for due soon alerts (3 days before)
        final daysUntilDue = goal.targetDate.difference(DateTime.now()).inDays;
        if (daysUntilDue <= 3 && daysUntilDue > 0 && goal.status != GoalStatus.completed) {
          // Check if alert already exists
          final existingAlert = await _firestore
              .collection('alerts')
              .where('userId', isEqualTo: user.uid)
              .where('type', isEqualTo: AlertType.goalDueSoon.name)
              .where('relatedGoalId', isEqualTo: goal.id)
              .where('isDismissed', isEqualTo: false)
              .get();

          if (existingAlert.docs.isEmpty) {
            await createGoalAlert(
              userId: user.uid,
              goal: goal,
              type: AlertType.goalDueSoon,
            );
          }
        }

        // Check for overdue alerts
        if (daysUntilDue < 0 && goal.status != GoalStatus.completed) {
          final existingAlert = await _firestore
              .collection('alerts')
              .where('userId', isEqualTo: user.uid)
              .where('type', isEqualTo: AlertType.goalOverdue.name)
              .where('relatedGoalId', isEqualTo: goal.id)
              .where('isDismissed', isEqualTo: false)
              .get();

          if (existingAlert.docs.isEmpty) {
            await createGoalAlert(
              userId: user.uid,
              goal: goal,
              type: AlertType.goalOverdue,
            );
          }
        }
      }
    } catch (e) {
      developer.log('Error checking goal alerts: $e');
    }
  }

  // Get alert statistics
  static Future<Map<String, int>> getAlertStats(String userId) async {
    final alerts = await _firestore
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .where('isDismissed', isEqualTo: false)
        .get();

    int unread = 0;
    int urgent = 0;
    int dueSoon = 0;
    int overdue = 0;

    for (final doc in alerts.docs) {
      final alert = Alert.fromFirestore(doc);
      
      if (!alert.isRead) unread++;
      if (alert.priority == AlertPriority.urgent) urgent++;
      if (alert.type == AlertType.goalDueSoon) dueSoon++;
      if (alert.type == AlertType.goalOverdue) overdue++;
    }

    return {
      'unread': unread,
      'urgent': urgent,
      'dueSoon': dueSoon,
      'overdue': overdue,
    };
  }
}
