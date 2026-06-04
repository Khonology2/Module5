import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/services/email_notification_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/services/milestone_evidence_service.dart';
import 'package:pdh/utils/backend_polling_stream.dart';

class AlertService {
  static final BackendAuthService _backend = BackendAuthService.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String _userIdFromMap(Map<String, dynamic> data) {
    return (data['id'] ?? data['uid'] ?? data['userId'] ?? '').toString();
  }

  static Alert _alertFromMap(Map<String, dynamic> map) {
    final id = (map['id'] ?? '').toString();
    return Alert.fromMap(map, id: id.isNotEmpty ? id : null);
  }

  static List<Alert> _mapsToAlerts(List<Map<String, dynamic>> items) {
    return items.map(_alertFromMap).toList();
  }

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
    return backendPollingStream<List<Alert>>(
      initialValue: const [],
      fetch: () async {
        final items = await _backend.getAlerts(userId, limit: 500);
        var alerts = _mapsToAlerts(items);
        if (audience != null) {
          alerts = alerts.where((a) => a.audience == audience).toList();
        }
        alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return alerts;
      },
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
      final data = await BackendAuthService.instance.getUser(uid);
      final name = (data['displayName'] ?? data['name'] ?? '').toString().trim();
      return name.isNotEmpty ? name : 'Someone';
    } catch (_) {
      return 'Someone';
    }
  }

  static const String _managerWorkspaceAlertsRoute = '/manager_gw_menu_alerts';

  static Future<String> _alertsRouteForRecipient(String userId) async {
    try {
      final data = await BackendAuthService.instance.getUser(userId);
      final role = (data['role'] ?? '').toString().trim().toLowerCase();
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
    final alert = Alert(
      id: '',
      userId: employeeId,
      type: AlertType.oneOnOneRequested,
      audience: _determineAudience(AlertType.oneOnOneRequested),
      priority: AlertPriority.medium,
      title: '1:1 Requested',
      message: '$managerName would like to have a 1:1 with you.',
      actionText: 'View',
      actionRoute: actionRouteOverride ?? '/one_on_one_thread',
      actionData: {
        'meetingId': meetingId,
        'employeeId': employeeId,
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
      actionRoute: actionRouteOverride ?? '/one_on_one_thread',
      actionData: {
        'meetingId': meetingId,
        'employeeId': employeeId,
        'proposedStartDateTime': proposedStartDateTime.toIso8601String(),
        'proposedEndDateTime': proposedEndDateTime.toIso8601String(),
        // Backwards compatibility for older routes/clients
        'proposedDateTime': proposedStartDateTime.toIso8601String(),
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
    String? actionRouteOverride,
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
      actionRoute: actionRouteOverride ?? '/one_on_one_thread',
      actionData: {
        'meetingId': meetingId,
        'employeeId': employeeId,
        if (acceptedStartDateTime != null)
          'meetingStartDateTime': acceptedStartDateTime.toIso8601String(),
        if (acceptedEndDateTime != null)
          'meetingEndDateTime': acceptedEndDateTime.toIso8601String(),
      },
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
    String? actionRouteOverride,
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
      actionRoute: actionRouteOverride ?? '/one_on_one_thread',
      actionData: {
        'meetingId': meetingId,
        'employeeId': employeeId,
        'proposedStartDateTime': proposedStartDateTime.toIso8601String(),
        'proposedEndDateTime': proposedEndDateTime.toIso8601String(),
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

  static Future<Map<String, dynamic>> createGoalApprovalRequestedAlert({
    required String employeeId,
    required String goalId,
    required String goalTitle,
    String approverRole = 'manager',
  }) async {
    try {
      bool roleMatchesApprover(String role, String approverRoleNormalized) {
        final normalized = role.trim().toLowerCase();
        if (approverRoleNormalized == 'admin') {
          return normalized == 'admin' ||
              normalized == 'administrator' ||
              normalized == 'super_admin' ||
              normalized == 'superadmin' ||
              normalized.contains('admin');
        }
        if (approverRoleNormalized == 'manager') {
          return normalized == 'manager' ||
              normalized == 'line_manager' ||
              normalized == 'linemanager' ||
              normalized.contains('manager');
        }
        return normalized == approverRoleNormalized;
      }

      final employeeData = await _backend.getUser(employeeId);
      final employeeName = employeeData['displayName'] ?? 'An employee';
      final managerId = (employeeData['managerId'] as String?)?.trim();

      final normalizedApproverRole = approverRole.trim().toLowerCase();
      final recipientsById = <String>{};
      final recipientEmailsById = <String, String>{};

      void considerUser(Map<String, dynamic> data) {
        final uid = _userIdFromMap(data);
        if (uid.isEmpty) return;
        final role = (data['role'] ?? '').toString();
        final email = (data['email'] ?? '').toString().trim();
        final isAdminFlag = data['isAdmin'] == true;
        final canApproveManagerGoals = data['canApproveManagerGoals'] == true;
        final permissions = (data['permissions'] is List)
            ? (data['permissions'] as List)
                  .map((e) => e.toString().toLowerCase())
                  .toList()
            : const <String>[];
        final hasApprovalPermission =
            permissions.contains('approve_manager_goals') ||
            permissions.contains('approve_goals');

        if (roleMatchesApprover(role, normalizedApproverRole) ||
            isAdminFlag ||
            canApproveManagerGoals ||
            hasApprovalPermission) {
          recipientsById.add(uid);
          if (email.isNotEmpty) {
            recipientEmailsById[uid] = email;
          }
        }
      }

      if (normalizedApproverRole == 'admin') {
        final allUsers = await _backend.listUsers(limit: 500);
        for (final data in allUsers) {
          considerUser(data);
        }
      } else {
        if (managerId != null && managerId.isNotEmpty) {
          try {
            final mgrData = await _backend.getUser(managerId);
            final role = (mgrData['role'] as String? ?? '').trim().toLowerCase();
            if (roleMatchesApprover(role, normalizedApproverRole)) {
              recipientsById.add(managerId);
              final email = (mgrData['email'] ?? '').toString().trim();
              if (email.isNotEmpty) {
                recipientEmailsById[managerId] = email;
              }
            }
          } catch (_) {
            // Manager profile missing; fall through to role-based lookup.
          }
        }

        if (recipientsById.isEmpty) {
          final allUsers = await _backend.listUsers(limit: 500);
          for (final data in allUsers) {
            final role = (data['role'] ?? '').toString();
            if (roleMatchesApprover(role, normalizedApproverRole)) {
              final uid = _userIdFromMap(data);
              if (uid.isEmpty) continue;
              recipientsById.add(uid);
              final email = (data['email'] ?? '').toString().trim();
              if (email.isNotEmpty) {
                recipientEmailsById[uid] = email;
              }
            }
          }
        }
      }

      if (recipientsById.isEmpty) {
        final allUsers = await _backend.listUsers(limit: 500);
        for (final data in allUsers) {
          final role = (data['role'] ?? '').toString().trim().toLowerCase();
          if (!roleMatchesApprover(role, normalizedApproverRole)) continue;
          final uid = _userIdFromMap(data);
          if (uid.isEmpty) continue;
          recipientsById.add(uid);
          final email = (data['email'] ?? '').toString().trim();
          if (email.isNotEmpty) {
            recipientEmailsById[uid] = email;
          }
        }
      }

      final recipientIds = recipientsById.toList();

      if (recipientIds.isEmpty) {
        developer.log(
          'WARNING: No $normalizedApproverRole users found to notify for goal approval',
        );
        developer.log(
          'Employee ID: $employeeId, Goal ID: $goalId, Goal Title: $goalTitle',
        );

        // Surface a clear personal alert so the submitter knows why no inbox
        // approval appeared (instead of silently failing).
        final fallbackActionRoute = await _alertsRouteForRecipient(employeeId);
        final configAlert = Alert(
          id: '',
          userId: employeeId,
          type: AlertType.managerGeneral,
          audience: _determineAudience(
            AlertType.managerGeneral,
            isForManager: true,
          ),
          priority: AlertPriority.high,
          title: 'Approval Routing Needs Attention',
          message:
              'No $normalizedApproverRole account was found for goal "$goalTitle". Please contact support/admin.',
          actionText: 'View Goal',
          actionRoute: fallbackActionRoute,
          actionData: {'goalId': goalId},
          createdAt: DateTime.now(),
          relatedGoalId: goalId,
          expiresAt: DateTime.now().add(const Duration(days: 7)),
        );
        await _createAlert(configAlert);
        throw Exception(
          'No approver recipients resolved for role: $normalizedApproverRole',
        );
      }

      developer.log(
        'Found ${recipientIds.length} $normalizedApproverRole(s) to notify for goal approval',
      );

      var successfulWrites = 0;
      for (final recipientId in recipientIds) {
        final alert = Alert(
          id: '',
          userId: recipientId,
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
          actionData: {
            'goalId': goalId,
            'requestedByUserId': employeeId,
            'requiredApproverRole': normalizedApproverRole,
            'approvalChain': normalizedApproverRole == 'admin'
                ? 'manager_to_admin'
                : 'employee_to_manager',
          },
          createdAt: DateTime.now(),
          fromUserId: employeeId,
          fromUserName: employeeName.toString(),
          relatedGoalId: goalId,
          expiresAt: DateTime.now().add(const Duration(days: 14)),
        );
        await _createAlertStrict(alert);
        successfulWrites++;
      }

      if (successfulWrites == 0) {
        throw Exception(
          'Approval alert dispatch failed: no recipient alerts were persisted',
        );
      }
      developer.log(
        'Successfully created approval request alerts for $successfulWrites/${recipientIds.length} $normalizedApproverRole(s)',
      );
      return {
        'approverRole': normalizedApproverRole,
        'recipientIds': recipientIds,
        'recipientEmails': recipientIds
            .map((id) => recipientEmailsById[id])
            .whereType<String>()
            .toList(),
        'successfulWrites': successfulWrites,
      };
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
      final userData = await _backend.getUser(goal.userId);
      final employeeName = userData['displayName'] ?? 'An employee';
      final dept = userData['department']?.toString();

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

      final managers = await _backend.listUsers(
        role: 'manager',
        department: (dept != null && dept.isNotEmpty) ? dept : null,
        limit: 500,
      );
      if (managers.isEmpty) return;

      for (final mgr in managers) {
        final managerId = _userIdFromMap(mgr);
        if (managerId.isEmpty) continue;
        final alert = Alert(
          id: '',
          userId: managerId,
          type: AlertType.goalMilestoneCompleted,
          audience: AlertAudience.team,
          priority: AlertPriority.medium,
          title: 'Milestone Completed',
          message:
              '$employeeName finished "$milestoneTitle"$evidenceInfo for goal "${goal.title}".',
          actionText: 'Review Goal',
          actionRoute: '/manager_portal',
          actionData: {
            'initialRoute': '/manager_review_team_dashboard',
            'goalId': goal.id,
            'milestoneId': ?milestoneId,
          },
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

  static Future<List<Map<String, dynamic>>> _getManagersForEmployee(
    String employeeId,
  ) async {
    try {
      final employeeData = await _backend.getUser(employeeId);
      final department = employeeData['department']?.toString();
      return _backend.listUsers(
        role: 'manager',
        department: (department != null && department.isNotEmpty)
            ? department
            : null,
        limit: 500,
      );
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
      final employeeData = await _backend.getUser(employeeId);
      final employeeName =
          employeeData['displayName'] ??
          employeeData['name'] ??
          'Employee';

      final goals = await _backend.getGoals(goalId: goalId, limit: 1);
      final goalTitle = goals.isNotEmpty
          ? (goals.first['title'] ?? 'Goal').toString()
          : 'Goal';

      final managers = await _getManagersForEmployee(employeeId);
      for (final manager in managers) {
        final managerId = _userIdFromMap(manager);
        if (managerId.isEmpty) continue;
        final alert = Alert(
          id: '',
          userId: managerId,
          type: AlertType.goalMilestoneCompleted,
          audience: AlertAudience.team,
          priority: AlertPriority.high,
          title: 'Milestone Evidence Submitted',
          message:
              '$employeeName submitted evidence for milestone "$milestoneTitle" in goal "$goalTitle". ($evidenceCount evidence file(s))',
          actionRoute: '/my_pdp',
          actionData: {
            'goalId': goalId,
            'milestoneId': milestoneId,
            'employeeId': employeeId,
            'evidenceCount': evidenceCount,
          },
          createdAt: DateTime.now(),
          relatedGoalId: goalId,
          expiresAt: DateTime.now().add(const Duration(days: 7)),
        );
        await _createAlert(alert);
      }
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

      await _createAlert(alert);

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

  static Future<void> _createAlertStrict(Alert alert) async {
    await _backend.createAlert(alert.userId, alert.toMap(includeId: false));
  }

  static Future<void> _createAlert(Alert alert) async {
    try {
      await _createAlertStrict(alert);

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

  static String _dedupeKeyFor(Alert a) {
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

  static List<Alert> _processUserAlerts(
    List<Alert> alerts, {
    int? maxItems,
  }) {
    try {
      final active = alerts.where((alert) {
        if (alert.isDismissed) return false;
        if (alert.expiresAt != null &&
            alert.expiresAt!.isBefore(DateTime.now())) {
          return false;
        }
        return true;
      }).toList();

      active.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final seen = <String>{};
      final deduped = <Alert>[];
      for (final a in active) {
        final key = _dedupeKeyFor(a);
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
  }

  static Future<List<Alert>> _fetchUserAlerts(
    String userId, {
    int? maxItems,
    int? serverFetchLimit,
  }) async {
    final int effectiveMax = maxItems ?? 100;
    final int fetchCap = serverFetchLimit ??
        (effectiveMax <= 0 ? 500 : (effectiveMax * 5).clamp(150, 600));
    final items = await _backend.getAlerts(userId, limit: fetchCap);
    return _processUserAlerts(_mapsToAlerts(items), maxItems: maxItems);
  }

  /// Live alerts for a user. Polls the backend on an interval so large inboxes
  /// stay bounded without downloading the entire collection each tick.
  static Stream<List<Alert>> getUserAlertsStream(
    String userId, {
    int? maxItems = 100,
    int? serverFetchLimit,
  }) {
    return createManagedPollingStream<List<Alert>>(
      initialValue: const [],
      fetch: () => _fetchUserAlerts(
        userId,
        maxItems: maxItems,
        serverFetchLimit: serverFetchLimit,
      ),
    );
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

    final inboxFetch = (limit * 4).clamp(200, 600);

    if (personal) {
      // Personal mode: Only manager's own alerts
      final baseStream = getUserAlertsStream(
        managerId,
        maxItems: limit,
        serverFetchLimit: inboxFetch,
      );
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
      final baseStream = getUserAlertsStream(
        managerId,
        maxItems: limit,
        serverFetchLimit: inboxFetch,
      );
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
      final uid = _auth.currentUser?.uid;
      if (uid == null || alertId.isEmpty) return;
      await _backend.patchAlert(uid, alertId, {'isRead': true});
    } catch (e) {
      developer.log('Error marking alert as read: $e');
    }
  }

  static Future<void> dismissAlert(String alertId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null || alertId.isEmpty) return;
      await _backend.patchAlert(uid, alertId, {'isDismissed': true});
    } catch (e) {
      developer.log('Error dismissing alert: $e');
    }
  }

  static Future<void> markAllAsRead(String userId) async {
    try {
      await _backend.patchAlertsBatch(userId, {'markAllRead': true});
    } catch (e) {
      developer.log('Error marking all alerts as read: $e');
    }
  }

  static Future<void> _patchAlertsByIds(
    String userId,
    List<String> alertIds,
    Map<String, dynamic> patch,
  ) async {
    if (alertIds.isEmpty) return;
    await _backend.patchAlertsBatch(userId, {
      'updates': {
        'alertIds': alertIds,
        ...patch,
      },
    });
  }

  static Future<void> markGoalRelatedAlertsAsRead(
    String userId,
    String goalId,
  ) async {
    try {
      final items = await _backend.getAlerts(userId, limit: 500);
      final alertIds = items
          .where((m) {
            final related = (m['relatedGoalId'] ?? '').toString();
            final isRead = (m['isRead'] ?? false) == true;
            return related == goalId && !isRead;
          })
          .map((m) => (m['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      await _patchAlertsByIds(userId, alertIds, {'isRead': true});
      developer.log(
        'Marked ${alertIds.length} alerts as read for goal $goalId',
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
      final nextType = approved
          ? AlertType.goalApprovalApproved.name
          : AlertType.goalApprovalRejected.name;
      final items = await _backend.getAlerts(userId, limit: 500);
      final matching = items.where((m) {
        final related = (m['relatedGoalId'] ?? '').toString();
        final type = (m['type'] ?? '').toString();
        final isRead = (m['isRead'] ?? false) == true;
        return related == goalId &&
            type == AlertType.goalApprovalRequested.name &&
            !isRead;
      }).toList();

      for (final m in matching) {
        final alertId = (m['id'] ?? '').toString();
        if (alertId.isEmpty) continue;
        await _backend.patchAlert(userId, alertId, {
          'isRead': true,
          'type': nextType,
        });
        developer.log(
          'Updating alert $alertId: type ${m['type']} -> $nextType',
        );
      }

      developer.log(
        'Marked ${matching.length} goal approval alert(s) as read and changed to $nextType for userId: $userId, goalId: $goalId',
      );
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

  /// Fixes alerts still typed as [goalApprovalRequested] when the linked goal is
  /// already approved/rejected. Only scans this user's approval-request alerts
  /// (bounded), never the entire `goals` collection — required for web on large DBs.
  static Future<void> migrateStuckGoalApprovalAlertsForSignedInUser({
    int maxAlerts = 200,
  }) async {
    try {
      final reviewer = _auth.currentUser;
      if (reviewer == null) return;

      final items = await _backend.getAlerts(reviewer.uid, limit: maxAlerts);
      final pending = items
          .where(
            (m) =>
                (m['type'] ?? '').toString() ==
                AlertType.goalApprovalRequested.name,
          )
          .toList();
      if (pending.isEmpty) return;

      for (final data in pending) {
        final goalId = (data['relatedGoalId'] ?? '').toString().trim();
        final alertId = (data['id'] ?? '').toString();
        if (goalId.isEmpty || alertId.isEmpty) continue;

        final goals = await _backend.getGoals(goalId: goalId, limit: 1);
        if (goals.isEmpty) continue;
        final status = (goals.first['approvalStatus'] ?? '').toString();
        if (status != GoalApprovalStatus.approved.name &&
            status != GoalApprovalStatus.rejected.name) {
          continue;
        }

        final targetType = status == GoalApprovalStatus.rejected.name
            ? AlertType.goalApprovalRejected.name
            : AlertType.goalApprovalApproved.name;

        await _backend.patchAlert(reviewer.uid, alertId, {
          'type': targetType,
          'isRead': true,
        });
      }
    } catch (e) {
      developer.log('migrateStuckGoalApprovalAlertsForSignedInUser: $e');
    }
  }

  // MIGRATION: Update existing finalized goal alerts so history appears in Archive.
  /// Delegates to [migrateStuckGoalApprovalAlertsForSignedInUser]; the previous
  /// implementation scanned every approved/rejected goal in the project and froze web.
  static final Map<String, Future<void>> _finalizeGoalAlertsMigration = {};

  static Future<void> migrateExistingFinalizedGoalAlerts() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    return _finalizeGoalAlertsMigration.putIfAbsent(
      uid,
      () => migrateStuckGoalApprovalAlertsForSignedInUser(maxAlerts: 250),
    );
  }

  static Future<void> migrateExistingApprovedGoalAlerts() async {
    await migrateExistingFinalizedGoalAlerts();
  }

  static Future<bool> _hasActiveAlert({
    required String userId,
    required AlertType type,
    required String goalId,
  }) async {
    final items = await _backend.getAlerts(userId, limit: 200);
    return items.any((m) {
      final alert = _alertFromMap(m);
      return alert.type == type &&
          alert.relatedGoalId == goalId &&
          !alert.isDismissed &&
          (alert.expiresAt == null ||
              !alert.expiresAt!.isBefore(DateTime.now()));
    });
  }

  static DateTime? _parseActivityDate(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  // Auto-generate alerts based on goal events
  static Future<void> checkAndCreateGoalAlerts() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final goalMaps = await _backend.getGoals(userId: user.uid, limit: 200);

      for (final data in goalMaps) {
        final goalId = (data['id'] ?? '').toString();
        if (goalId.isEmpty) continue;
        final goal = Goal.fromMap(data, id: goalId);

        try {
          final today = DateTime.now();
          final dayKey =
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          final progressDocId = '${goal.id}__$dayKey';
          await _backend.createGoalDailyProgress({
            'id': progressDocId,
            'goalId': goal.id,
            'userId': user.uid,
            'date': dayKey,
            'progress': goal.progress,
            'remaining': (100 - goal.progress).clamp(0, 100),
            'createdAt': DateTime.now().toIso8601String(),
          });
        } catch (_) {
          // Non-critical, ignore failures
        }

        final daysUntilDue = goal.targetDate.difference(DateTime.now()).inDays;
        if (daysUntilDue <= 7 &&
            daysUntilDue > 0 &&
            goal.isEligibleForOverdueTeamAlert) {
          if (!await _hasActiveAlert(
            userId: user.uid,
            type: AlertType.goalDueSoon,
            goalId: goal.id,
          )) {
            await createGoalAlert(
              userId: user.uid,
              goal: goal,
              type: AlertType.goalDueSoon,
            );
          }
        }

        if (daysUntilDue < 0 && goal.isEligibleForOverdueTeamAlert) {
          if (!await _hasActiveAlert(
            userId: user.uid,
            type: AlertType.goalOverdue,
            goalId: goal.id,
          )) {
            await createGoalAlert(
              userId: user.uid,
              goal: goal,
              type: AlertType.goalOverdue,
            );
          }

          if (daysUntilDue == -1) {
            try {
              final userData = await _backend.getUser(user.uid);
              final dept = userData['department']?.toString();
              final employeeName = userData['displayName'] ?? 'An employee';
              final managers = await _backend.listUsers(
                role: 'manager',
                department: (dept != null && dept.isNotEmpty) ? dept : null,
                limit: 500,
              );
              for (final mgr in managers) {
                final managerId = _userIdFromMap(mgr);
                if (managerId.isEmpty) continue;
                final alert = Alert(
                  id: '',
                  userId: managerId,
                  type: AlertType.goalOverdue,
                  audience: AlertAudience.team,
                  priority: AlertPriority.high,
                  title: 'Employee Goal Overdue',
                  message:
                      "$employeeName's goal \"${goal.title}\" is 1 day overdue. Review and decide next step.",
                  actionText: 'Review Goal',
                  actionRoute: '/manager_alerts_nudges',
                  createdAt: DateTime.now(),
                  relatedGoalId: goal.id,
                  expiresAt: DateTime.now().add(const Duration(days: 7)),
                );
                await _createAlert(alert);
              }
            } catch (_) {
              // Soft-fail on manager notification
            }
          }
        }

        if (goal.status == GoalStatus.inProgress) {
          final activities =
              await _backend.getDailyActivities(user.uid, limit: 1);
          DateTime? lastActivityDate;
          if (activities.isNotEmpty) {
            activities.sort((a, b) {
              final ad = _parseActivityDate(a['date']);
              final bd = _parseActivityDate(b['date']);
              if (ad == null && bd == null) return 0;
              if (ad == null) return 1;
              if (bd == null) return -1;
              return bd.compareTo(ad);
            });
            lastActivityDate = _parseActivityDate(activities.first['date']);
          }
          final daysSinceActivity = lastActivityDate != null
              ? DateTime.now().difference(lastActivityDate).inDays
              : 999;
          if (daysSinceActivity >= 5) {
            if (!await _hasActiveAlert(
              userId: user.uid,
              type: AlertType.inactivity,
              goalId: goal.id,
            )) {
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
    final items = await _backend.getAlerts(userId, limit: 500);
    final alerts = _processUserAlerts(_mapsToAlerts(items));

    int unread = 0;
    int urgent = 0;
    int dueSoon = 0;
    int overdue = 0;

    for (final alert in alerts) {
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
