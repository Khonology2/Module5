import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/services/email_notification_service.dart';

class AlertService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate goal-specific effort window based on category and priority
  static int _getGoalSpecificEffortWindow(Goal goal) {
    // Base days by category - different goal types need different lead times
    final categoryBaseDays = {
      GoalCategory.learning: 35,    // 5 weeks for courses/certifications
      GoalCategory.work: 14,        // 2 weeks for work projects
      GoalCategory.health: 7,       // 1 week for health goals
      GoalCategory.personal: 10,   // 1.5 weeks for personal goals
    };

    // Priority multipliers - high priority needs more warning time
    final priorityMultiplier = {
      GoalPriority.low: 0.7,      // 30% less warning time
      GoalPriority.medium: 1.0,    // Standard warning time
      GoalPriority.high: 1.5,      // 50% more warning time
    };

    final baseDays = categoryBaseDays[goal.category] ?? 14;
    final multiplier = priorityMultiplier[goal.priority] ?? 1.0;
    
    // Season goals get extra buffer time
    final seasonBonus = goal.isSeasonGoal ? 7 : 0;
    
    return ((baseDays * multiplier) + seasonBonus).round();
  }

  /// Generate contextual inactivity message using AI
  static Future<String> _generateContextualInactivityMessage(Goal goal) async {
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        systemInstruction: Content.text(
          'You are an AI assistant specialized in personal development and goal achievement. '
          'Generate a personalized, encouraging message for someone who hasn\'t made progress on their goal recently. '
          'The message should be specific to the goal type and suggest a concrete next step. '
          'Keep it concise (under 150 characters) and motivational. '
          'Focus on actionable next steps, not generic encouragement.'
        ),
      );

      final prompt = Content.text(
        'Goal: "${goal.title}"\n'
        'Category: ${goal.category.name}\n'
        'Progress: ${goal.progress}%\n'
        'Priority: ${goal.priority.name}\n'
        'Description: ${goal.description}\n\n'
        'Generate a specific, actionable next step message. Examples:\n'
        '- For courses: "Book capstone assessment" or "Complete Module 3 quiz"\n'
        '- For work projects: "Schedule team meeting" or "Submit draft for review"\n'
        '- For health goals: "Schedule workout session" or "Log today\'s progress"\n'
        '- For personal goals: "Set up reminder system" or "Complete first small task"\n\n'
        'Make it specific to this goal and encouraging.'
      );

      final response = await model.generateContent([prompt]);
      final aiMessage = response.text?.trim() ?? 
          'No progress on "${goal.title}" recently. Try the next step to get moving again.';
      
      // Fallback to generic message if AI fails
      if (aiMessage.isEmpty || aiMessage.length > 150) {
        return 'No progress on "${goal.title}" recently. Try the next step to get moving again.';
      }
      
      return aiMessage;
    } catch (e) {
      developer.log('Error generating contextual inactivity message: $e');
      // Fallback to generic message
      return 'No progress on "${goal.title}" recently. Try next step to get moving again.';
    }
  }

  /// Generate dependency risk message with propagation analysis
  static Future<String> _generateDependencyRiskMessage(Goal goal) async {
    try {
      // Get related goals that might be affected
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'A dependency changed and may impact "${goal.title}". Review the plan.';
      
      final relatedGoals = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['notStarted', 'inProgress'])
          .get();

      // Analyze potential impact using AI
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        systemInstruction: Content.text(
          'You are an AI assistant specialized in project dependency analysis. '
          'Analyze goal changes and identify potential cascading impacts on related goals. '
          'Generate a concise message explaining the risk and affected areas. '
          'Focus on actionable insights and specific dependencies.'
        ),
      );

      final relatedGoalsData = relatedGoals.docs
          .where((doc) => doc.id != goal.id)
          .map((doc) => 'Related: ${doc.data()['title']} (Progress: ${doc.data()['progress']}%)')
          .join('\n');

      final prompt = Content.text(
        'Primary Goal: "${goal.title}"\n'
        'Progress: ${goal.progress}%\n'
        'Status: ${goal.status.name}\n'
        'Category: ${goal.category.name}\n\n'
        'Related Goals:\n$relatedGoalsData\n\n'
        'Analyze potential dependency impacts and generate a risk message that:\n'
        '1. Identifies specific areas at risk\n'
        '2. Mentions cascading effects if any\n'
        '3. Suggests immediate action\n'
        'Keep it under 200 characters and actionable.'
      );

      final response = await model.generateContent([prompt]);
      final aiMessage = response.text?.trim() ?? 
          'A dependency changed and may impact "${goal.title}". Review the plan.';
      
      // Fallback if AI fails
      if (aiMessage.isEmpty || aiMessage.length > 200) {
        return 'A dependency changed and may impact "${goal.title}". Review the plan.';
      }
      
      // Propagate alerts to dependent goals
      await _propagateDependencyAlerts(goal, relatedGoals.docs);
      
      return aiMessage;
    } catch (e) {
      developer.log('Error generating dependency risk message: $e');
      return 'A dependency changed and may impact "${goal.title}". Review the plan.';
    }
  }

  /// Propagate dependency alerts to related goals
  static Future<void> _propagateDependencyAlerts(
    Goal sourceGoal, 
    List<QueryDocumentSnapshot> relatedGoals
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      for (final doc in relatedGoals) {
        final relatedGoalId = doc.id;
        final relatedGoalData = doc.data() as Map<String, dynamic>;
        
        // Check if dependency alert already exists
        final existingAlert = await _firestore
            .collection('alerts')
            .where('userId', isEqualTo: user.uid)
            .where('type', isEqualTo: AlertType.milestoneRisk.name)
            .where('relatedGoalId', isEqualTo: relatedGoalId)
            .where('isDismissed', isEqualTo: false)
            .get();

        if (existingAlert.docs.isEmpty) {
          final relatedGoalTitle = relatedGoalData['title'] ?? 'Related goal';
          
          final alert = Alert(
            id: '',
            userId: user.uid,
            type: AlertType.milestoneRisk,
            priority: AlertPriority.high,
            title: 'Dependency Risk',
            message: '"${sourceGoal.title}" changes may affect "$relatedGoalTitle".',
            actionText: 'Review Dependencies',
            actionRoute: '/my_goal_workspace',
            createdAt: DateTime.now(),
            relatedGoalId: relatedGoalId,
            expiresAt: DateTime.now().add(const Duration(days: 7)),
          );

          await _createAlert(alert);
        }
      }
    } catch (e) {
      developer.log('Error propagating dependency alerts: $e');
    }
  }

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
        message =
            'You have created a goal: "${goal.title}". Time to work on it! 🎯';
        actionText = 'View Goal';
        actionRoute = '/my_goal_workspace';
        priority = AlertPriority.medium;
        break;
      case AlertType.goalCompleted:
        title = 'Goal Completed! 🎉';
        message =
            'Congratulations! You completed "${goal.title}" and earned ${goal.points} points!';
        actionText = 'View Progress';
        actionRoute = '/progress_visuals';
        priority = AlertPriority.high;
        break;
      case AlertType.goalDueSoon:
        final daysLeft = goal.targetDate.difference(DateTime.now()).inDays;
        title = 'Goal Due Soon ⏰';
        message =
            '"${goal.title}" is due in $daysLeft day${daysLeft == 1 ? '' : 's'}. Keep pushing!';
        actionText = 'Update Progress';
        actionRoute = '/my_goal_workspace';
        priority = AlertPriority.high; // Amber in UI
        break;
      case AlertType.goalOverdue:
        final daysOverdue = DateTime.now().difference(goal.targetDate).inDays;
        title = 'Goal Overdue ⚠️';
        message =
            '"${goal.title}" is overdue by $daysOverdue day${daysOverdue == 1 ? '' : 's'}. Don\'t give up!';
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
      expiresAt: DateTime.now().add(
        const Duration(days: 7),
      ), // Expire after 7 days
    );

    await _createAlert(alert);
  }

  static Future<void> createGoalApprovalRequestedAlert({
    required String employeeId,
    required String goalId,
    required String goalTitle,
  }) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(employeeId)
          .get();
      final employeeName = userDoc.data()?['displayName'] ?? 'An employee';

      // Notify all managers regardless of department (managers can see all employees)
      final mgrs = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'manager')
          .get();

      if (mgrs.docs.isEmpty) {
        developer.log('WARNING: No managers found to notify for goal approval');
        developer.log('Employee ID: $employeeId, Goal ID: $goalId, Goal Title: $goalTitle');
        return;
      }

      developer.log('Found ${mgrs.docs.length} manager(s) to notify for goal approval');

      for (final mgr in mgrs.docs) {
        final alert = Alert(
          id: '',
          userId: mgr.id,
          type: AlertType.goalApprovalRequested,
          priority: AlertPriority.high,
          title: 'Goal Approval Needed',
          message:
              '$employeeName submitted a new goal: "$goalTitle". Approve or reject.',
          actionText: 'Review Goal',
          actionRoute: '/manager_alerts_nudges',
          createdAt: DateTime.now(),
          relatedGoalId: goalId,
          expiresAt: DateTime.now().add(const Duration(days: 14)),
        );
        await _createAlert(alert);
      }
      developer.log(
        'Successfully created approval request alerts for ${mgrs.docs.length} manager(s)',
      );
    } catch (e) {
      developer.log('Error creating approval request alerts: $e');
      rethrow; // Re-throw to help with debugging
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
      type: approved
          ? AlertType.goalApprovalApproved
          : AlertType.goalApprovalRejected,
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
      final userDoc = await _firestore
          .collection('users')
          .doc(goal.userId)
          .get();
      final employeeName = userDoc.data()?['displayName'] ?? 'An employee';
      final dept = userDoc.data()?['department'] as String?;
      
      // Notify all managers in the department
      final mgrs = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'manager')
          .where('department', isEqualTo: dept)
          .get();

      if (mgrs.docs.isEmpty) {
        developer.log('WARNING: No managers found in department $dept to notify for milestone');
        return;
      }

      for (final mgr in mgrs.docs) {
        final alert = Alert(
          id: '',
          userId: mgr.id,
          type: AlertType.goalMilestoneCompleted,
          priority: AlertPriority.medium,
          title: 'Milestone Completed! 🎯',
          message: '$employeeName completed milestone: "$milestoneTitle" for goal "${goal.title}"',
          actionText: 'View Progress',
          actionRoute: '/manager_review_team_dashboard',
          createdAt: DateTime.now(),
          relatedGoalId: goal.id,
          expiresAt: DateTime.now().add(const Duration(days: 7)),
        );
        await _createAlert(alert);
      }
    } catch (e) {
      developer.log('Error creating manager milestone alert: $e');
    }
  }

  /// Check goals and create appropriate alerts
  static Future<void> checkAndCreateGoalAlerts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final goalsSnapshot = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['notStarted', 'inProgress'])
          .get();

      for (final doc in goalsSnapshot.docs) {
        final goal = Goal.fromFirestore(doc);
        
        // Check for overdue goals
        if (goal.targetDate.isBefore(DateTime.now())) {
          await createGoalAlert(
            userId: user.uid,
            goal: goal,
            type: AlertType.goalOverdue,
          );
        }
        // Check for goals due soon (within 3 days)
        else if (goal.targetDate.difference(DateTime.now()).inDays <= 3) {
          await createGoalAlert(
            userId: user.uid,
            goal: goal,
            type: AlertType.goalDueSoon,
          );
        }
      }
    } catch (e) {
      developer.log('Error checking and creating goal alerts: $e');
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
      message:
          '$managerName created a new team goal: "$teamGoalTitle". Join your team and earn $points points by ${deadline.day}/${deadline.month}/${deadline.year}!',
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
      message:
          '$employeeName joined your team goal "$teamGoalTitle". The team is growing stronger!',
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
      message:
          '$managerName sent you a nudge about "$goalTitle": $nudgeMessage',
      actionText: 'View Nudge',
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
        message:
            '$managerName sent you a nudge about "$goalTitle": $nudgeMessage',
        actionText: 'View Nudge',
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
                if (alert.fromUserName != null)
                  'managerName': alert.fromUserName,
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
        .handleError((error) {
          // Silently handle errors to prevent unmount errors
          developer.log('Error in getUserAlertsStream: $error');
        })
        .map((snapshot) {
          try {
            final alerts = snapshot.docs
                .map((doc) => Alert.fromFirestore(doc))
                .where((alert) {
                  // Filter out expired alerts
                  if (alert.expiresAt != null &&
                      alert.expiresAt!.isBefore(DateTime.now())) {
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
        })
        .handleError((error) {
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
    // Team-only alert types (manager-facing team insights)
    final Set<AlertType> teamOnly = {
      AlertType.teamGoalAvailable,
      AlertType.employeeJoinedTeamGoal,
      AlertType.seasonJoined,
      AlertType.seasonProgressUpdate,
      AlertType.seasonCompleted,
      AlertType.goalMilestoneCompleted,
    };

    // Goal-related alert types that should appear in team alerts
    final Set<AlertType> employeeGoalAlerts = {
      AlertType.goalOverdue,
      AlertType.goalDueSoon,
      AlertType.goalCompleted,
      AlertType.goalCreated,
      AlertType.goalMilestoneCompleted,
    };

    if (personal) {
      // Personal mode: Only manager's own alerts
      final baseStream = getUserAlertsStream(managerId);
      return baseStream
          .handleError((error) {
            // Silently handle errors to prevent unmount errors
            developer.log('Error in getManagerInboxStream (personal): $error');
          })
          .map((alerts) {
            List<Alert> items = List<Alert>.from(alerts);

            // In personal mode, exclude team-only types but allow approval requests
            // Approval requests are important for managers even in personal mode
            items = items.where((a) {
              if (teamOnly.contains(a.type)) return false;
              // Allow approval requests in personal mode - they're manager-facing
              return true;
            }).toList();

            // Apply type filter if specified
            if (typeFilter != null) {
              items = items.where((a) {
                switch (typeFilter) {
                  case 'alert':
                    return a.type != AlertType.managerNudge &&
                        a.type != AlertType.goalApprovalRequested &&
                        !teamOnly.contains(a.type);
                  case 'nudge':
                    return a.type == AlertType.managerNudge;
                  case 'approval_request':
                    // Allow approval requests in personal mode too
                    return a.type == AlertType.goalApprovalRequested;
                  default:
                    return true;
                }
              }).toList();
            }

            // Sort and limit
            items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            if (limit < items.length) {
              items = items.take(limit).toList();
            }
            return items;
          });
    } else {
      // Team mode: Get manager's alerts and team employee alerts
      final managerAlertsStream = getUserAlertsStream(managerId);

      // Get manager's department to query team employee alerts
      return managerAlertsStream
          .handleError((error) {
            // Silently handle errors to prevent unmount errors
            developer.log('Error in getManagerInboxStream (team): $error');
          })
          .asyncMap((managerAlerts) async {
            try {
              // Get manager's department
              final managerDoc = await _firestore
                  .collection('users')
                  .doc(managerId)
                  .get();
              final managerDept = managerDoc.data()?['department'] as String?;

              List<Alert> allItems = List<Alert>.from(managerAlerts);

              // If filtering for alerts or all, get team employee alerts
              if (typeFilter == null ||
                  typeFilter == 'alert' ||
                  typeFilter == 'all') {
                if (managerDept != null && managerDept.isNotEmpty) {
                  // Get all employees in manager's department
                  final employeesSnapshot = await _firestore
                      .collection('users')
                      .where('department', isEqualTo: managerDept)
                      .where('role', isEqualTo: 'employee')
                      .get();

                  final employeeIds = employeesSnapshot.docs
                      .map((doc) => doc.id)
                      .toList();

                  if (employeeIds.isNotEmpty) {
                    // Query alerts for all employees in the department
                    // Note: Firestore 'in' queries are limited to 10 items, so we need to batch
                    final List<Alert> employeeAlerts = [];
                    for (int i = 0; i < employeeIds.length; i += 10) {
                      final batch = employeeIds.skip(i).take(10).toList();
                      final alertsSnapshot = await _firestore
                          .collection('alerts')
                          .where('userId', whereIn: batch)
                          .where('isDismissed', isEqualTo: false)
                          .get();

                      for (final doc in alertsSnapshot.docs) {
                        try {
                          final alert = Alert.fromFirestore(doc);
                          // Filter out expired alerts
                          if (alert.expiresAt != null &&
                              alert.expiresAt!.isBefore(DateTime.now())) {
                            continue;
                          }
                          // Only include employee goal-related alerts
                          if (employeeGoalAlerts.contains(alert.type)) {
                            employeeAlerts.add(alert);
                          }
                        } catch (e) {
                          developer.log('Error parsing alert: $e');
                        }
                      }
                    }
                    allItems.addAll(employeeAlerts);
                  }
                }
              }

              // Apply type filter
              if (typeFilter != null) {
                allItems = allItems.where((a) {
                  switch (typeFilter) {
                    case 'alert':
                      // Show only employee goal alerts (not manager's own alerts)
                      return employeeGoalAlerts.contains(a.type) &&
                          a.userId != managerId;
                    case 'nudge':
                      return a.type == AlertType.managerNudge;
                    case 'approval_request':
                      // Only show approval requests (these have manager's userId)
                      return a.type == AlertType.goalApprovalRequested;
                    case 'all':
                      // Show all team-related alerts: approvals, employee goal alerts, and team-only types
                      return a.type == AlertType.goalApprovalRequested ||
                          employeeGoalAlerts.contains(a.type) ||
                          teamOnly.contains(a.type);
                    default:
                      return true;
                  }
                }).toList();
              } else {
                // No type filter: show all team-related alerts
                allItems = allItems.where((a) {
                  return a.type == AlertType.goalApprovalRequested ||
                      employeeGoalAlerts.contains(a.type) ||
                      teamOnly.contains(a.type);
                }).toList();
              }

              // Sort by creation date (newest first)
              allItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              // Apply limit
              if (limit < allItems.length) {
                allItems = allItems.take(limit).toList();
              }

              return allItems;
            } catch (e) {
              developer.log('Error in getManagerInboxStream: $e');
              // Fallback to just manager's alerts
              return managerAlerts;
            }
          });
    }
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
