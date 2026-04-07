import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/milestone_evidence_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/services/email_notification_service.dart';
import 'package:pdh/utils/firestore_safe.dart';

class AlertService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Determine alert audience based on type and context
  static AlertAudience _determineAudience(
    AlertType type, {
    bool isForManager = false,
  }) {
    // Personal alerts (manager-as-user)
    if (isForManager) {
      switch (type) {
        case AlertType.goalApprovalRequested:
        case AlertType.badgeEarned:
        case AlertType.pointsEarned:
        case AlertType.levelUp:
        case AlertType.oneOnOneRequested:
        case AlertType.oneOnOneProposed:
        case AlertType.oneOnOneAccepted:
        case AlertType.oneOnOneRescheduled:
        case AlertType.oneOnOneCancelled:
        case AlertType.managerGeneral:
          return AlertAudience.personal;
        default:
          return AlertAudience.personal;
      }
    }

    // Team alerts (manager-as-supervisor)
    switch (type) {
      case AlertType.goalOverdue:
      case AlertType.inactivity:
      case AlertType.milestoneRisk:
      case AlertType.seasonJoined:
      case AlertType.seasonProgressUpdate:
      case AlertType.seasonCompleted:
      case AlertType.goalMilestoneCompleted:
      case AlertType.milestoneDeletionRequest:
        return AlertAudience.team;
      default:
        return AlertAudience.personal;
    }
  }

  static String _formatMeetingTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  static String _formatMeetingRange(DateTime start, DateTime end) {
    String two(int n) => n.toString().padLeft(2, '0');
    String date(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
    String time(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    if (sameDay) {
      return '${date(start)} ${time(start)} - ${time(end)}';
    }
    return '${date(start)} ${time(start)} - ${date(end)} ${time(end)}';
  }

  /// Get alerts for a user filtered by audience
  static Stream<List<Alert>> getAlertsForUser(
    String userId, {
    AlertAudience? audience,
  }) {
    final collection = _firestore
        .collection('users')
        .doc(userId)
        .collection('alerts')
        .orderBy('createdAt', descending: true);

    if (audience != null) {
      return collection
          .where('audience', isEqualTo: audience.name)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map((doc) => Alert.fromFirestore(doc)).toList(),
          );
    }

    return collection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => Alert.fromFirestore(doc)).toList(),
    );
  }

  /// Get personal alerts for a manager (manager-as-user)
  static Stream<List<Alert>> getPersonalAlertsForManager(String managerId) {
    return getAlertsForUser(managerId, audience: AlertAudience.personal);
  }

  /// Get team alerts for a manager (manager-as-supervisor)
  static Stream<List<Alert>> getTeamAlertsForManager(String managerId) {
    return getAlertsForUser(managerId, audience: AlertAudience.team);
  }

  static Future<String> _displayNameForUser(String uid) async {
    try {
      final snap = await FirestoreSafe.getDoc(
        _firestore.collection('users').doc(uid),
      );
      final data = snap.data();
      final name = (data?['displayName'] ?? data?['name'] ?? '')
          .toString()
          .trim();
      return name.isNotEmpty ? name : 'Someone';
    } catch (_) {
      return 'Someone';
    }
  }

  static const String _managerWorkspaceAlertsRoute = '/manager_gw_menu_alerts';

  static Future<String> _alertsRouteForRecipient(String userId) async {
    try {
      final snap = await FirestoreSafe.getDoc(
        _firestore.collection('users').doc(userId),
      );
      final role = (snap.data()?['role'] ?? '').toString().trim().toLowerCase();
      if (role == 'manager') return _managerWorkspaceAlertsRoute;
    } catch (_) {
      // Fall back to default route if role cannot be determined.
    }
    return '/alerts_nudges';
  }

  /// Employee-facing: manager expressed intent (no time).
  static Future<void> createOneOnOneRequestedAlert({
    required String employeeId,
    required String managerId,
    required String meetingId,
    String? agenda,
    String? actionRouteOverride,
  }) async {
    final managerName = await _displayNameForUser(managerId);
    final actionRoute =
        actionRouteOverride ?? await _alertsRouteForRecipient(employeeId);
    final alert = Alert(
      id: '',
      userId: employeeId,
      type: AlertType.oneOnOneRequested,
      audience: _determineAudience(AlertType.oneOnOneRequested),
      priority: AlertPriority.medium,
      title: '1:1 Requested',
      message: '$managerName would like to have a 1:1 with you.',
      actionText: 'View',
      actionRoute: actionRoute,
      actionData: {
        'meetingId': meetingId,
        if (agenda != null && agenda.trim().isNotEmpty) 'agenda': agenda.trim(),
      },
      createdAt: DateTime.now(),
      fromUserId: managerId,
      fromUserName: managerName,
      expiresAt: DateTime.now().add(const Duration(days: 14)),
    );
    await _createAlert(alert);
  }

  /// Employee-facing: manager proposed a meeting time range.
  static Future<void> createOneOnOneProposedAlert({
    required String employeeId,
    required String managerId,
    required String meetingId,
    required DateTime proposedStartDateTime,
    required DateTime proposedEndDateTime,
    String? agenda,
    String? actionRouteOverride,
  }) async {
    final managerName = await _displayNameForUser(managerId);
    final actionRoute =
        actionRouteOverride ?? await _alertsRouteForRecipient(employeeId);
    final when = _formatMeetingRange(
      proposedStartDateTime,
      proposedEndDateTime,
    );
    final alert = Alert(
      id: '',
      userId: employeeId,
      type: AlertType.oneOnOneProposed,
      audience: _determineAudience(AlertType.oneOnOneProposed),
      priority: AlertPriority.high,
      title: '1:1 Proposed',
      message: '$managerName proposed a 1:1 from $when.',
      actionText: 'Respond',
      actionRoute: actionRoute,
      actionData: {
        'meetingId': meetingId,
        'proposedStartDateTime': Timestamp.fromDate(proposedStartDateTime),
        'proposedEndDateTime': Timestamp.fromDate(proposedEndDateTime),
        // Backwards compatibility for older routes/clients
        'proposedDateTime': Timestamp.fromDate(proposedStartDateTime),
        if (agenda != null && agenda.trim().isNotEmpty) 'agenda': agenda.trim(),
      },
      createdAt: DateTime.now(),
      fromUserId: managerId,
      fromUserName: managerName,
      expiresAt: DateTime.now().add(const Duration(days: 14)),
    );
    await _createAlert(alert);
  }

  /// Manager-facing: employee accepted the proposal.
  static Future<void> createOneOnOneAcceptedAlertToManager({
    required String managerId,
    required String employeeId,
    required String meetingId,
    DateTime? acceptedStartDateTime,
    DateTime? acceptedEndDateTime,
  }) async {
    final employeeName = await _displayNameForUser(employeeId);
    String when = '';
    if (acceptedStartDateTime != null && acceptedEndDateTime != null) {
      when =
          ' for ${_formatMeetingRange(acceptedStartDateTime, acceptedEndDateTime)}';
    } else if (acceptedStartDateTime != null) {
      when = ' on ${_formatMeetingTime(acceptedStartDateTime)}';
    }
    final alert = Alert(
      id: '',
      userId: managerId,
      type: AlertType.oneOnOneAccepted,
      audience: _determineAudience(
        AlertType.oneOnOneAccepted,
        isForManager: true,
      ),
      priority: AlertPriority.medium,
      title: '1:1 Accepted',
      message: '$employeeName accepted your 1:1 request$when.',
      actionText: 'View',
      actionRoute: '/manager_inbox',
      actionData: {'meetingId': meetingId},
      createdAt: DateTime.now(),
      fromUserId: employeeId,
      fromUserName: employeeName,
      expiresAt: DateTime.now().add(const Duration(days: 14)),
    );
    await _createAlert(alert);
  }

  /// Manager-facing: employee suggested a new time.
  static Future<void> createOneOnOneRescheduledAlertToManager({
    required String managerId,
    required String employeeId,
    required String meetingId,
    required DateTime proposedStartDateTime,
    required DateTime proposedEndDateTime,
  }) async {
    final employeeName = await _displayNameForUser(employeeId);
    final when = _formatMeetingRange(
      proposedStartDateTime,
      proposedEndDateTime,
    );
    final alert = Alert(
      id: '',
      userId: managerId,
      type: AlertType.oneOnOneRescheduled,
      audience: _determineAudience(
        AlertType.oneOnOneRescheduled,
        isForManager: true,
      ),
      priority: AlertPriority.high,
      title: '1:1 Rescheduled',
      message: '$employeeName suggested a new time: $when.',
      actionText: 'Review',
      actionRoute: '/manager_inbox',
      actionData: {
        'meetingId': meetingId,
        'proposedStartDateTime': Timestamp.fromDate(proposedStartDateTime),
        'proposedEndDateTime': Timestamp.fromDate(proposedEndDateTime),
      },
      createdAt: DateTime.now(),
      fromUserId: employeeId,
      fromUserName: employeeName,
      expiresAt: DateTime.now().add(const Duration(days: 14)),
    );
    await _createAlert(alert);
  }

  static Future<void> createGeneralAlert({
    required String userId,
    required String title,
    required String message,
    AlertType type = AlertType.managerGeneral,
    AlertPriority priority = AlertPriority.medium,
    String? actionText,
    String? actionRoute,
    Map<String, dynamic>? actionData,
    String? fromUserId,
    String? fromUserName,
    Duration ttl = const Duration(days: 14),
  }) async {
    final resolvedActionRoute =
        actionRoute ?? await _alertsRouteForRecipient(userId);
    final alert = Alert(
      id: '',
      userId: userId,
      type: type,
      audience: _determineAudience(type),
      priority: priority,
      title: title,
      message: message,
      actionText: actionText,
      actionRoute: resolvedActionRoute,
      actionData: actionData,
      createdAt: DateTime.now(),
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      expiresAt: DateTime.now().add(ttl),
    );
    await _createAlert(alert);
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
    Map<String, dynamic>? actionData;
    AlertPriority priority;

    switch (type) {
      case AlertType.goalCreated:
        title = 'New Goal Created!';
        message =
            'You have created a goal: "${goal.title}". Time to work on it! 🎯';
        actionText = 'View Goal';
        actionRoute = await _alertsRouteForRecipient(userId);
        actionData = {'goalId': goal.id};
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
        actionRoute = '/employee_dashboard';
        actionData = {'goalId': goal.id};
        priority = AlertPriority.high; // Amber in UI
        break;
      case AlertType.goalOverdue:
        final daysOverdue = DateTime.now().difference(goal.targetDate).inDays;
        title = 'Goal Overdue ⚠️';
        message =
            '"${goal.title}" is overdue by $daysOverdue day${daysOverdue == 1 ? '' : 's'}. Don\'t give up!';
        actionText = 'Reschedule';
        actionRoute = '/employee_dashboard';
        actionData = {'goalId': goal.id};
        priority = AlertPriority.urgent; // Red in UI
        break;
      case AlertType.inactivity:
        title = 'We\'re here to help';
        message =
            'No progress on "${goal.title}" recently. Try the next step to get moving again.';
        actionText = 'Next Step';
        actionRoute = '/employee_dashboard';
        actionData = {'goalId': goal.id};
        priority = AlertPriority.medium; // Calm, informational
        break;
      case AlertType.milestoneRisk:
        title = 'Milestone at Risk';
        message =
            'A dependency changed and may impact "${goal.title}". Review the plan.';
        actionText = 'Review Plan';
        actionRoute = '/employee_dashboard';
        actionData = {'goalId': goal.id};
        priority = AlertPriority.high; // Amber emphasis
        break;
      default:
        return;
    }

    final alert = Alert(
      id: '',
      userId: userId,
      type: type,
      audience: _determineAudience(type),
      priority: priority,
      title: title,
      message: message,
      actionText: actionText,
      actionRoute: actionRoute,
      actionData: actionData,
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
    String approverRole = 'manager',
  }) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(employeeId)
          .get();
      final employeeName = userDoc.data()?['displayName'] ?? 'An employee';

      final normalizedApproverRole = approverRole.trim().toLowerCase();
      final directRecipients = await _firestore
          .collection('users')
          .where('role', isEqualTo: normalizedApproverRole)
          .get();
      List<QueryDocumentSnapshot<Map<String, dynamic>>> recipientsDocs =
          directRecipients.docs;

      // Fallback for legacy/inconsistent role casing in Firestore data
      // (e.g. "Admin", "ADMIN ", " Manager").
      if (recipientsDocs.isEmpty) {
        final allUsers = await _firestore.collection('users').get();
        final normalized = allUsers.docs.where((doc) {
          final role = (doc.data()['role'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          return role == normalizedApproverRole;
        }).toList();
        recipientsDocs = normalized;
      }

      if (recipientsDocs.isEmpty) {
        developer.log(
          'WARNING: No $normalizedApproverRole users found to notify for goal approval',
        );
        developer.log(
          'Employee ID: $employeeId, Goal ID: $goalId, Goal Title: $goalTitle',
        );
        return;
      }

      developer.log(
        'Found ${recipientsDocs.length} $normalizedApproverRole(s) to notify for goal approval',
      );

      for (final recipient in recipientsDocs) {
        final alert = Alert(
          id: '',
          userId: recipient.id,
          type: AlertType.goalApprovalRequested,
          audience: _determineAudience(
            AlertType.goalApprovalRequested,
            isForManager: true,
          ),
          priority: AlertPriority.high,
          title: 'Goal Approval Needed',
          message:
              '$employeeName submitted a new goal: "$goalTitle". Approve or reject.',
          actionText: 'Review Goal',
          actionRoute: normalizedApproverRole == 'admin'
              ? '/admin_inbox'
              : '/manager_inbox',
          createdAt: DateTime.now(),
          relatedGoalId: goalId,
          expiresAt: DateTime.now().add(const Duration(days: 14)),
        );
        await _createAlert(alert);
      }
      developer.log(
        'Successfully created approval request alerts for ${recipientsDocs.length} $normalizedApproverRole(s)',
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

    final actionRoute = await _alertsRouteForRecipient(employeeId);
    final alert = Alert(
      id: '',
      userId: employeeId,
      type: approved
          ? AlertType.goalApprovalApproved
          : AlertType.goalApprovalRejected,
      audience: _determineAudience(
        approved
            ? AlertType.goalApprovalApproved
            : AlertType.goalApprovalRejected,
      ),
      priority: approved ? AlertPriority.medium : AlertPriority.high,
      title: title,
      message: msg,
      actionText: 'View Goal',
      actionRoute: actionRoute,
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
    String? milestoneId, // NEW: Optional milestone ID for evidence checking
  }) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(goal.userId)
          .get();
      final employeeName = userDoc.data()?['displayName'] ?? 'An employee';
      final dept = userDoc.data()?['department'] as String?;

      // NEW: Check for evidence if milestone ID provided (additive extension)
      String evidenceInfo = '';
      if (milestoneId != null) {
        try {
          final evidence = await MilestoneEvidenceService.getMilestoneEvidence(
            goalId: goal.id,
            milestoneId: milestoneId,
          );
          if (evidence.isNotEmpty) {
            evidenceInfo =
                ' (${evidence.length} evidence file${evidence.length == 1 ? '' : 's'} submitted)';
          }
        } catch (e) {
          developer.log('Error checking milestone evidence: $e');
        }
      }

      Query mgrQuery = _firestore
          .collection('users')
          .where('role', isEqualTo: 'manager');
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
              '$employeeName finished "$milestoneTitle"$evidenceInfo for goal "${goal.title}".',
          'actionText': 'Review Goal',
          'actionRoute': '/manager_portal',
          'actionData': {
            'initialRoute': '/manager_review_team_dashboard',
            'goalId': goal.id,
            'milestoneId':
                milestoneId, // NEW: Include milestone ID for direct access
          },
          'relatedGoalId': goal.id,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'isDismissed': false,
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
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
      audience: AlertAudience.personal,
      priority: AlertPriority.medium,
      title: 'Points Earned! ',
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
      audience: AlertAudience.personal,
      priority: AlertPriority.low,
      title: 'Keep Going! 💪',
      message: message,
      actionText: goalId != null ? 'View Goal' : null,
      actionRoute: goalId != null ? '/employee_dashboard' : null,
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
      audience: AlertAudience.personal,
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
      audience: AlertAudience.personal,
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
      audience: AlertAudience.personal,
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
      audience: AlertAudience.team,
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
      audience: AlertAudience.personal,
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

  // NEW: Helper method to get managers for an employee
  static Future<List<DocumentSnapshot>> _getManagersForEmployee(
    String employeeId,
  ) async {
    try {
      // Get employee's department
      final employeeDoc = await _firestore
          .collection('users')
          .doc(employeeId)
          .get();
      final department = employeeDoc.data()?['department'] as String?;

      // Find managers in the same department (or all managers if no department)
      Query managerQuery = _firestore
          .collection('users')
          .where('role', isEqualTo: 'manager');
      if (department != null && department.isNotEmpty) {
        managerQuery = managerQuery.where('department', isEqualTo: department);
      }

      final managerSnapshot = await managerQuery.get();
      return managerSnapshot.docs;
    } catch (e) {
      developer.log('Error getting managers for employee: $e');
      return [];
    }
  }

  // NEW: Create alert for milestone evidence submission
  static Future<void> createMilestoneEvidenceSubmittedAlert({
    required String employeeId,
    required String goalId,
    required String milestoneId,
    required String milestoneTitle,
    required int evidenceCount,
  }) async {
    try {
      // Get employee details
      final employeeDoc = await _firestore
          .collection('users')
          .doc(employeeId)
          .get();
      final employeeName =
          employeeDoc.data()?['displayName'] ??
          employeeDoc.data()?['name'] ??
          'Employee';

      // Get goal details
      final goalDoc = await _firestore.collection('goals').doc(goalId).get();
      final goalTitle = goalDoc.data()?['title'] ?? 'Goal';

      // Find managers based on employee's department
      final managers = await _getManagersForEmployee(employeeId);

      // Create alerts for all managers
      final alerts = managers
          .map(
            (manager) => {
              'userId': manager.id,
              'type':
                  AlertType.goalMilestoneCompleted.name, // Reuse existing type
              'priority': AlertPriority.high.name,
              'title': 'Milestone Evidence Submitted',
              'message':
                  '$employeeName submitted evidence for milestone "$milestoneTitle" in goal "$goalTitle". ($evidenceCount evidence file(s))',
              'createdAt': Timestamp.now(),
              'isRead': false,
              'actionRoute': '/my_pdp',
              'actionData': {
                'goalId': goalId,
                'milestoneId': milestoneId,
                'employeeId': employeeId,
                'evidenceCount': evidenceCount,
              },
            },
          )
          .toList();

      // Batch write alerts
      final batch = _firestore.batch();
      for (final alertData in alerts) {
        final alertRef = _firestore.collection('alerts').doc();
        batch.set(alertRef, alertData);
      }
      await batch.commit();
    } catch (e) {
      developer.log('Error creating milestone evidence submitted alert: $e');
      rethrow;
    }
  }

  // NEW: Create alert for milestone acknowledgement
  static Future<void> createMilestoneAcknowledgedAlert({
    required String employeeId,
    required String goalId,
    required String milestoneId,
    required String milestoneTitle,
    required String managerName,
    String? checkInNotes,
  }) async {
    try {
      final alert = Alert(
        id: '',
        userId: employeeId,
        type: AlertType.goalApprovalApproved, // Reuse existing type
        audience: AlertAudience.personal,
        priority: AlertPriority.high,
        title: 'Milestone Acknowledged! ✅',
        message:
            '$managerName has acknowledged your milestone "$milestoneTitle".${checkInNotes != null && checkInNotes.isNotEmpty ? '\n\nManager notes: $checkInNotes' : ''}',
        actionText: 'View Progress',
        actionRoute: '/employee_dashboard',
        actionData: {'goalId': goalId},
        createdAt: DateTime.now(),
        relatedGoalId: goalId,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      await _createAlert(alert);
    } catch (e) {
      developer.log('Error creating milestone acknowledged alert: $e');
      rethrow;
    }
  }

  /// Helper to create alerts for managers, often used for approval requests or notifications
  static Future<void> createManagerAlert({
    required String goalId,
    required String goalTitle,
    required String ownerId,
    required String ownerName,
    required String managerId,
    required String
    type, // e.g., 'milestoneDeletionRequest', 'milestoneDeleted', 'milestoneDeletionRejected'
    String? message,
  }) async {
    try {
      String alertTitle;
      String alertMessage;
      AlertType alertType;

      switch (type) {
        case 'milestoneDeletionRequest':
          alertTitle = 'Milestone Deletion Request';
          alertMessage =
              '$ownerName has requested to delete a milestone from goal "$goalTitle". Please review.';
          alertType = AlertType.milestoneDeletionRequest;
          break;
        case 'milestoneDeleted':
          alertTitle = 'Milestone Deleted';
          alertMessage =
              message ?? 'A milestone from goal "$goalTitle" has been deleted.';
          alertType = AlertType.milestoneDeleted;
          break;
        case 'milestoneDeletionRejected':
          alertTitle = 'Milestone Deletion Rejected';
          alertMessage =
              message ??
              'The request to delete a milestone from goal "$goalTitle" has been rejected.';
          alertType = AlertType.milestoneDeletionRejected;
          break;
        default:
          alertTitle = 'Manager Alert';
          alertMessage =
              message ??
              'An action requires your attention regarding goal "$goalTitle".';
          alertType = AlertType.managerGeneral;
      }

      final alert = Alert(
        id: '',
        userId: managerId,
        type: alertType,
        audience: AlertAudience.team,
        priority: AlertPriority.high,
        title: alertTitle,
        message: alertMessage,
        actionText: 'Review',
        actionRoute: '/manager_alerts_nudges',
        actionData: {'goalId': goalId, 'employeeId': ownerId},
        createdAt: DateTime.now(),
        fromUserId: ownerId,
        fromUserName: ownerName,
        relatedGoalId: goalId,
        expiresAt: DateTime.now().add(const Duration(days: 14)),
      );

      await _createAlert(alert);
      developer.log(
        'Created manager alert of type $type for manager $managerId',
      );
    } catch (e) {
      developer.log('Error creating manager alert: $e');
      rethrow;
    }
  }

  /// Create manager nudge alert with enhanced data
  static Future<void> createManagerNudgeAlertEnhanced({
    required String userId,
    required String goalId,
    required String managerId,
    required String managerName,
    required String goalTitle,
    required String nudgeMessage,
    String? actionRouteOverride,
  }) async {
    try {
      final actionRoute =
          actionRouteOverride ?? await _alertsRouteForRecipient(userId);
      // Create alert using _createAlert to ensure email is sent
      final alert = Alert(
        id: '',
        userId: userId,
        type: AlertType.managerNudge,
        audience: AlertAudience.personal,
        priority: AlertPriority.high,
        title: 'Manager Nudge 📢',
        message:
            '$managerName sent you a nudge about "$goalTitle": $nudgeMessage',
        actionText: 'View Nudge',
        actionRoute: actionRoute,
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
      audience: AlertAudience.personal,
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
      await FirestoreSafe.addDoc<Map<String, dynamic>>(
        _firestore.collection('alerts'),
        alert.toFirestore(),
      );

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

  static Stream<List<Alert>> getUserAlertsStream(
    String userId, {
    int? maxItems = 50,
  }) {
    return FirestoreSafe.stream(
      _firestore
          .collection('alerts')
          .where('userId', isEqualTo: userId)
          .where('isDismissed', isEqualTo: false)
          .snapshots(),
    ).map((snapshot) {
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
            case AlertType.oneOnOneRequested:
            case AlertType.oneOnOneProposed:
            case AlertType.oneOnOneAccepted:
            case AlertType.oneOnOneRescheduled:
            case AlertType.oneOnOneCancelled:
              final mid = (a.actionData?['meetingId'] ?? '').toString();
              return '${a.type.name}|$mid';
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

        if (maxItems != null && maxItems > 0) {
          return deduped.take(maxItems).toList();
        }
        return deduped;
      } catch (e) {
        developer.log('Error processing alerts: $e');
        return <Alert>[];
      }
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
    // NOTE:
    // The manager inbox should show manager-facing alerts addressed to the manager
    // (userId == managerId). Previously, "Team" mode also fetched employee alerts
    // from the manager's department and merged them in, which caused managers to
    // see employee-facing cards like "Goal Overdue ⚠️" that they cannot action.

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

            // In personal mode, keep only alerts addressed to the manager.
            // (getUserAlertsStream already scopes by userId, this is defensive.)
            items = items.where((a) => a.userId == managerId).toList();

            // Personal communications/routine alerts belong in Manager Workspace
            // Alerts & Nudges, not in Manager Inbox.
            items = items
                .where((a) => a.actionRoute != _managerWorkspaceAlertsRoute)
                .toList();

            // Apply type filter if specified
            if (typeFilter != null) {
              items = items.where((a) {
                switch (typeFilter) {
                  case 'alert':
                    // "Alerts" excludes nudges and approvals.
                    return a.type != AlertType.managerNudge &&
                        a.type != AlertType.goalApprovalRequested;
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
      // Team mode: show manager-facing alerts addressed to the manager.
      // (Employee-facing alerts should never appear in the manager inbox.)
      final baseStream = getUserAlertsStream(managerId);
      return baseStream.map((alerts) {
        var items = alerts.where((a) => a.userId == managerId).toList();

        // Personal communications/routine alerts belong in Manager Workspace
        // Alerts & Nudges, not in Manager Inbox.
        items = items
            .where((a) => a.actionRoute != _managerWorkspaceAlertsRoute)
            .toList();

        if (typeFilter != null) {
          items = items.where((a) {
            switch (typeFilter) {
              case 'alert':
                return a.type != AlertType.managerNudge &&
                    a.type != AlertType.goalApprovalRequested;
              case 'nudge':
                return a.type == AlertType.managerNudge;
              case 'approval_request':
                return a.type == AlertType.goalApprovalRequested;
              case 'all':
              default:
                return true;
            }
          }).toList();
        }

        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (limit < items.length) {
          items = items.take(limit).toList();
        }
        return items;
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

  static Future<void> markGoalRelatedAlertsAsRead(
    String userId,
    String goalId,
  ) async {
    try {
      final batch = _firestore.batch();
      final alerts = await _firestore
          .collection('alerts')
          .where('userId', isEqualTo: userId)
          .where('relatedGoalId', isEqualTo: goalId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in alerts.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      developer.log(
        'Marked ${alerts.docs.length} alerts as read for goal $goalId',
      );
    } catch (e) {
      developer.log('Error marking goal-related alerts as read: $e');
    }
  }

  static Future<void> markGoalApprovalAlertsAsFinalized({
    required String userId,
    required String goalId,
    required bool approved,
  }) async {
    try {
      final batch = _firestore.batch();
      final nextType = approved
          ? AlertType.goalApprovalApproved.name
          : AlertType.goalApprovalRejected.name;
      final alerts = await _firestore
          .collection('alerts')
          .where('userId', isEqualTo: userId)
          .where('relatedGoalId', isEqualTo: goalId)
          .where('type', isEqualTo: AlertType.goalApprovalRequested.name)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in alerts.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'type': nextType,
        });
      }

      await batch.commit();
      developer.log(
        'Marked ${alerts.docs.length} goal approval alert(s) as read and changed to $nextType for userId: $userId, goalId: $goalId',
      );

      // Debug: Log the alert types being updated
      for (final doc in alerts.docs) {
        final alertData = doc.data();
        final currentType = alertData['type'];
        final newType = nextType;
        developer.log(
          'Updating alert ${doc.id}: type $currentType -> $newType',
        );
      }
    } catch (e) {
      developer.log('Error marking goal approval alerts as read: $e');
    }
  }

  static Future<void> markGoalApprovalAlertsAsRead(
    String userId,
    String goalId,
  ) async {
    await markGoalApprovalAlertsAsFinalized(
      userId: userId,
      goalId: goalId,
      approved: true,
    );
  }

  // MIGRATION: Update existing finalized goal alerts so history appears in Archive.
  static Future<void> migrateExistingFinalizedGoalAlerts() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final reviewer = FirebaseAuth.instance.currentUser;
      if (reviewer == null) return;

      // Get all goals that are approved or rejected.
      final approvedGoals = await firestore
          .collection('goals')
          .where('approvalStatus', isEqualTo: GoalApprovalStatus.approved.name)
          .get();
      final rejectedGoals = await firestore
          .collection('goals')
          .where('approvalStatus', isEqualTo: GoalApprovalStatus.rejected.name)
          .get();
      final finalizedGoals = [...approvedGoals.docs, ...rejectedGoals.docs];

      developer.log(
        'Found ${finalizedGoals.length} finalized goals to migrate',
      );

      for (final goalDoc in finalizedGoals) {
        final goalId = goalDoc.id;
        final goalData = goalDoc.data();
        final status = (goalData['approvalStatus'] ?? '').toString();
        final targetType = status == GoalApprovalStatus.rejected.name
            ? AlertType.goalApprovalRejected.name
            : AlertType.goalApprovalApproved.name;

        // Find any existing approval request alerts for this goal
        final existingAlerts = await firestore
            .collection('alerts')
            .where('userId', isEqualTo: reviewer.uid)
            .where('relatedGoalId', isEqualTo: goalId)
            .where(
              'type',
              isEqualTo: AlertType.goalApprovalRequested.name,
            )
            .get();

        // Update them to the finalized decision type.
        final batch = firestore.batch();
        for (final alertDoc in existingAlerts.docs) {
          batch.update(alertDoc.reference, {
            'type': targetType,
            'isRead': true,
          });
        }

        if (existingAlerts.docs.isNotEmpty) {
          await batch.commit();
          developer.log(
            'Migrated ${existingAlerts.docs.length} alerts for goal $goalId to $targetType',
          );
        }
      }
    } catch (e) {
      developer.log('Error migrating finalized goal alerts: $e');
    }
  }

  static Future<void> migrateExistingApprovedGoalAlerts() async {
    await migrateExistingFinalizedGoalAlerts();
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
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          targetDate:
              (data['targetDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          points: (data['points'] ?? 0) as int,
        );

        // Upsert today's daily progress snapshot for burndown/burnup
        try {
          final today = DateTime.now();
          final dayKey =
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          final progressDocId = '${doc.id}__$dayKey';
          await _firestore
              .collection('goal_daily_progress')
              .doc(progressDocId)
              .set({
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
        if (daysUntilDue <= 7 &&
            daysUntilDue > 0 &&
            goal.status != GoalStatus.completed) {
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
              final userDoc = await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .get();
              final dept = userDoc.data()?['department'] as String?;
              Query mgrQuery = _firestore
                  .collection('users')
                  .where('role', isEqualTo: 'manager');
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
                  'message':
                      "${userDoc.data()?['displayName'] ?? 'An employee'}'s goal \"${goal.title}\" is 1 day overdue. Review and decide next step.",
                  'actionText': 'Review Goal',
                  'actionRoute': '/manager_alerts_nudges',
                  'createdAt': FieldValue.serverTimestamp(),
                  'relatedGoalId': goal.id,
                  'isRead': false,
                  'isDismissed': false,
                  'expiresAt': Timestamp.fromDate(
                    DateTime.now().add(const Duration(days: 7)),
                  ),
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
              ? (lastActivityDoc.docs.first.data()['date'] as Timestamp)
                    .toDate()
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
              await createGoalAlert(
                userId: user.uid,
                goal: goal,
                type: AlertType.inactivity,
              );
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
