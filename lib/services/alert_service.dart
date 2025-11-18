import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/services/email_notification_service.dart';

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
        priority = AlertPriority.high; // Amber in UI
        break;
      case AlertType.goalOverdue:
        final daysOverdue = DateTime.now().difference(goal.targetDate).inDays;
        title = 'Goal Overdue ⚠️';
        message = '"${goal.title}" is overdue by $daysOverdue day${daysOverdue == 1 ? '' : 's'}. Don\'t give up!';
        actionText = 'Reschedule';
        actionRoute = '/my_goal_workspace';
        priority = AlertPriority.urgent; // Red in UI
        break;
      case AlertType.inactivity:
        title = 'We\'re here to help';
        message = 'No progress on "${goal.title}" recently. Try the next step to get moving again.';
        actionText = 'Next Step';
        actionRoute = '/my_goal_workspace';
        priority = AlertPriority.medium; // Calm, informational
        break;
      case AlertType.milestoneRisk:
        title = 'Milestone at Risk';
        message = 'A dependency changed and may impact "${goal.title}". Review the plan.';
        actionText = 'Review Plan';
        actionRoute = '/my_goal_workspace';
        priority = AlertPriority.high; // Amber emphasis
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

  static Future<void> createGoalApprovalRequestedAlert({
    required String employeeId,
    required String goalId,
    required String goalTitle,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(employeeId).get();
      final employeeName = userDoc.data()?['displayName'] ?? 'An employee';

      Query mgrQuery = _firestore.collection('users').where('role', isEqualTo: 'manager');
      final dept = userDoc.data()?['department'] as String?;
      if (dept != null && dept.isNotEmpty) {
        mgrQuery = mgrQuery.where('department', isEqualTo: dept);
      }
      var mgrs = await mgrQuery.get();
      // Fallback: if no managers found in the department, notify all managers
      if (mgrs.docs.isEmpty) {
        mgrs = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'manager')
            .get();
      }

      for (final mgr in mgrs.docs) {
        final alert = Alert(
          id: '',
          userId: mgr.id,
          type: AlertType.goalApprovalRequested,
          priority: AlertPriority.high,
          title: 'Goal Approval Needed',
          message: '$employeeName submitted a new goal: "$goalTitle". Approve or reject.',
          actionText: 'Review Goal',
          actionRoute: '/manager_alerts_nudges',
          createdAt: DateTime.now(),
          relatedGoalId: goalId,
          expiresAt: DateTime.now().add(const Duration(days: 14)),
        );
        await _createAlert(alert);
      }
    } catch (e) {
      developer.log('Error creating approval request alerts: $e');
    }
  }

  static Future<void> createGoalApprovalDecisionAlert({
    required String employeeId,
    required String goalId,
    required String goalTitle,
    required bool approved,
    String? reason,
  }) async {
    final title = approved ? 'Goal Approved ✅' : 'Goal Rejected ❌';
    final msg = approved
        ? 'Your goal "$goalTitle" has been approved. You can start working on your goal.'
        : 'Your goal "$goalTitle" was rejected${reason != null && reason.isNotEmpty ? ': $reason' : '.'}';

    final alert = Alert(
      id: '',
      userId: employeeId,
      type: approved ? AlertType.goalApprovalApproved : AlertType.goalApprovalRejected,
      priority: approved ? AlertPriority.medium : AlertPriority.high,
      title: title,
      message: msg,
      actionText: 'View Goal',
      actionRoute: '/my_goal_workspace',
      actionData: {'goalId': goalId},
      createdAt: DateTime.now(),
      relatedGoalId: goalId,
      expiresAt: DateTime.now().add(const Duration(days: 14)),
    );

    await _createAlert(alert);
  }

  static Future<void> createManagerMilestoneAlert({
    required Goal goal,
    required String milestoneTitle,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(goal.userId).get();
      final employeeName = userDoc.data()?['displayName'] ?? 'An employee';
      final dept = userDoc.data()?['department'] as String?;

      Query mgrQuery =
          _firestore.collection('users').where('role', isEqualTo: 'manager');
      if (dept != null && dept.isNotEmpty) {
        mgrQuery = mgrQuery.where('department', isEqualTo: dept);
      }
      final mgrs = await mgrQuery.get();
      if (mgrs.docs.isEmpty) return;

      for (final mgr in mgrs.docs) {
        await _firestore.collection('alerts').add({
          'userId': mgr.id,
          'type': AlertType.goalMilestoneCompleted.name,
          'priority': AlertPriority.medium.name,
          'title': 'Milestone Completed',
          'message':
              '$employeeName finished "$milestoneTitle" for goal "${goal.title}".',
          'actionText': 'Review Goal',
          'actionRoute': '/manager_portal',
          'actionData': {'initialRoute': '/manager_review_team_dashboard'},
          'relatedGoalId': goal.id,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'isDismissed': false,
          'expiresAt':
              Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        });
      }
    } catch (e) {
      developer.log('Error creating manager milestone alert: $e');
    }
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
    bool isManager = false,
  }) async {
    final title = isManager ? 'Team Badge Earned! 🏅' : 'Badge Earned! 🏆';
    final message = isManager
        ? 'Your team\'s performance has earned you the "$badgeName" badge!'
        : 'You\'ve earned the "$badgeName" badge! Keep up the great work!';

    final alert = Alert(
      id: '',
      userId: userId,
      type: AlertType.badgeEarned,
      priority: AlertPriority.high,
      title: title,
      message: message,
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
      actionText: 'Review Team',
      actionRoute: '/manager_review_team_dashboard',
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
      // Create alert using _createAlert to ensure email is sent
      final alert = Alert(
        id: '',
        userId: userId,
        type: AlertType.managerNudge,
        priority: AlertPriority.high,
        title: 'Manager Nudge 📢',
        message: '$managerName sent you a nudge about "$goalTitle": $nudgeMessage',
        actionText: 'View Goal',
        actionRoute: '/my_goal_workspace',
        actionData: {'goalId': goalId},
        createdAt: DateTime.now(),
        fromUserId: managerId,
        fromUserName: managerName,
        relatedGoalId: goalId,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
      
      // Try top-level alerts collection first
      try {
        await _createAlert(alert);
      } on FirebaseException catch (fe) {
        // If permission denied, try user subcollection (but email still sent)
        if (fe.code == 'permission-denied') {
          try {
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('alerts')
                .add(alert.toFirestore());
            // Still send email even if using subcollection
            await EmailNotificationService.sendAlertEmail(
              userId: userId,
              alertType: alert.type.name,
              title: alert.title,
              message: alert.message,
              relatedGoalId: alert.relatedGoalId,
              metadata: {
                if (alert.fromUserName != null) 'managerName': alert.fromUserName,
              },
            );
          } catch (e) {
            developer.log('Error creating alert in subcollection: $e');
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      // Best-effort activity record; ignore permission issues per stricter rulesets
      try {
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
      } catch (activityError) {
        developer.log('Activity logging skipped due to rules: $activityError');
      }

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
      
      // Send email notification via free Vercel API (no billing required)
      try {
        await EmailNotificationService.sendAlertEmail(
          userId: alert.userId,
          alertType: alert.type.name,
          title: alert.title,
          message: alert.message,
          relatedGoalId: alert.relatedGoalId,
          metadata: {
            if (alert.fromUserName != null) 'managerName': alert.fromUserName,
          },
        );
      } catch (e) {
        developer.log('Email notification failed (non-critical): $e');
      }
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

        // Deduplicate by a stable composite key to avoid doubles in UI
        final seen = <String>{};
        final deduped = <Alert>[];
        String keyFor(Alert a) {
          switch (a.type) {
            case AlertType.goalDueSoon:
            case AlertType.goalOverdue:
            case AlertType.inactivity:
            case AlertType.goalApprovalRequested:
            case AlertType.goalApprovalApproved:
            case AlertType.goalApprovalRejected:
            case AlertType.teamGoalAvailable:
            case AlertType.employeeJoinedTeamGoal:
              return '${a.type.name}|${a.relatedGoalId ?? ''}';
            case AlertType.managerNudge:
              return '${a.type.name}|${a.relatedGoalId ?? ''}|${a.fromUserId ?? ''}|${a.message}';
            default:
              return '${a.type.name}|${a.relatedGoalId ?? ''}|${a.title}|${a.message}';
          }
        }
        for (final a in alerts) {
          final key = keyFor(a);
          if (seen.add(key)) {
            deduped.add(a);
          }
        }

        return deduped.take(50).toList();
      } catch (e) {
        developer.log('Error processing alerts: $e');
        return <Alert>[];
      }
    }).handleError((error) {
      developer.log('Error loading alerts: $error');
      return <Alert>[];
    });
  }
  /// Stream alerts for the manager inbox with optional filters.
  /// - personal: when true, returns the manager's own alerts.
  /// - typeFilter: 'nudge' maps to AlertType.managerNudge, 'approval_request' maps to AlertType.goalApprovalRequested, null means no type filter.
  /// - limit: max number of alerts returned after filtering and sorting.
  static Stream<List<Alert>> getManagerInboxStream({
    required String managerId,
    required bool personal,
    String? typeFilter,
    int limit = 200,
  }) {
    // For now, personal inbox is the manager's own alerts. Team inbox can be expanded later.
    final baseStream = getUserAlertsStream(managerId);

    return baseStream.map((alerts) {
      List<Alert> items = List<Alert>.from(alerts);

      // Team-only alert types (manager-facing team insights)
      final Set<AlertType> teamOnly = {
        AlertType.teamGoalAvailable,
        AlertType.employeeJoinedTeamGoal,
        AlertType.seasonJoined,
        AlertType.seasonProgressUpdate,
        AlertType.seasonCompleted,
        AlertType.goalMilestoneCompleted,
      };

      if (typeFilter != null) {
        items = items.where((a) {
          switch (typeFilter) {
            case 'alert':
              // Show generic alerts only (exclude nudges, approvals, and team-only types)
              return a.type != AlertType.managerNudge &&
                     a.type != AlertType.goalApprovalRequested &&
                     !teamOnly.contains(a.type);
            case 'nudge':
              return a.type == AlertType.managerNudge;
            case 'approval_request':
              return a.type == AlertType.goalApprovalRequested;
            default:
              return true;
          }
        }).toList();
      }

      // Default behavior: in personal inbox, hide team-only alerts
      if (personal) {
        items = items.where((a) => !teamOnly.contains(a.type)).toList();
      }

      // Already sorted in getUserAlertsStream; just apply the limit override if larger than default 50
      if (limit < items.length) {
        items = items.take(limit).toList();
      }
      return items;
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

        // Upsert today's daily progress snapshot for burndown/burnup
        try {
          final today = DateTime.now();
          final dayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          final progressDocId = '${doc.id}__$dayKey';
          await _firestore.collection('goal_daily_progress').doc(progressDocId).set({
            'id': progressDocId,
            'goalId': doc.id,
            'userId': user.uid,
            'date': dayKey,
            'progress': goal.progress,
            'remaining': (100 - goal.progress).clamp(0, 100),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          // Non-critical, ignore failures
        }

        // Due Soon: within typical effort window; using 7 days as illustrative
        final daysUntilDue = goal.targetDate.difference(DateTime.now()).inDays;
        if (daysUntilDue <= 7 && daysUntilDue > 0 && goal.status != GoalStatus.completed) {
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

        // Overdue alerts (employee) and notify manager when 1 day overdue
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

          // If exactly 1 day overdue, notify manager(s)
          if (daysUntilDue == -1) {
            try {
              final userDoc = await _firestore.collection('users').doc(user.uid).get();
              final dept = userDoc.data()?['department'] as String?;
              Query mgrQuery = _firestore.collection('users').where('role', isEqualTo: 'manager');
              if (dept != null && dept.isNotEmpty) {
                mgrQuery = mgrQuery.where('department', isEqualTo: dept);
              }
              final mgrs = await mgrQuery.get();
              for (final mgr in mgrs.docs) {
                await _firestore.collection('alerts').add({
                  'userId': mgr.id,
                  'type': AlertType.goalOverdue.name,
                  'priority': AlertPriority.high.name,
                  'title': 'Employee Goal Overdue',
                  'message': '${userDoc.data()?['displayName'] ?? 'An employee'}\'s goal "${goal.title}" is 1 day overdue. Review and decide next step.',
                  'actionText': 'Review Goal',
                  'actionRoute': '/manager_alerts_nudges',
                  'createdAt': FieldValue.serverTimestamp(),
                  'relatedGoalId': goal.id,
                  'isRead': false,
                  'isDismissed': false,
                  'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
                });
              }
            } catch (_) {
              // Soft-fail on manager notification
            }
          }
        }

        // Inactivity: no progress for N days while in active period
        if (goal.status == GoalStatus.inProgress) {
          final lastActivityDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('daily_activities')
              .orderBy('date', descending: true)
              .limit(1)
              .get();
          final lastActivityDate = lastActivityDoc.docs.isNotEmpty
              ? (lastActivityDoc.docs.first.data()['date'] as Timestamp).toDate()
              : null;
          final daysSinceActivity = lastActivityDate != null
              ? DateTime.now().difference(lastActivityDate).inDays
              : 999;
          if (daysSinceActivity >= 5) {
            // Avoid creating duplicate inactivity alerts for the same goal
            final existingInactivity = await _firestore
                .collection('alerts')
                .where('userId', isEqualTo: user.uid)
                .where('type', isEqualTo: AlertType.inactivity.name)
                .where('relatedGoalId', isEqualTo: goal.id)
                .where('isDismissed', isEqualTo: false)
                .get();

            if (existingInactivity.docs.isEmpty) {
              await createGoalAlert(userId: user.uid, goal: goal, type: AlertType.inactivity);
            }
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
