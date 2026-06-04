import 'package:pdh/utils/date_parse.dart';

enum AlertType {
  goalCreated,
  goalCompleted,
  goalDueSoon,
  goalOverdue,
  goalApprovalRequested,
  goalApprovalApproved,
  goalApprovalRejected,
  pointsEarned,
  levelUp,
  badgeEarned,
  teamAssigned,
  managerNudge,
  achievementUnlocked,
  streakMilestone,
  deadlineReminder,
  teamGoalAvailable,
  employeeJoinedTeamGoal, // New alert type for managers
  inactivity, // No progress for N days
  milestoneRisk, // Behind schedule vs timeline/dependencies
  seasonJoined, // Employee joined a season (manager-facing)
  seasonProgressUpdate, // Employee completed a season goal / progress (manager-facing)
  seasonCompleted, // Season fully completed (manager-facing)
  goalMilestoneCompleted, // Employee milestone completion surfaced to managers
  milestoneDeletionRequest, // NEW: Milestone deletion request sent to manager
  milestoneDeleted, // NEW: Milestone deleted by manager (notification to employee)
  milestoneDeletionRejected, // NEW: Milestone deletion rejected by manager (notification to employee)
  managerGeneral, // NEW: Generic manager alert
  // 1:1 Meetings (requested/proposed/accepted/rescheduled/cancelled)
  oneOnOneRequested,
  oneOnOneProposed,
  oneOnOneAccepted,
  oneOnOneRescheduled,
  oneOnOneCancelled,
  // Legacy / free-form types used in older writes
  recognition,
}

enum AlertAudience {
  personal, // For the manager themselves
  team, // For the manager as supervisor of their team
}

enum AlertPriority { low, medium, high, urgent }

class Alert {
  final String id;
  final String userId;
  final AlertType type;
  final AlertAudience audience;
  final AlertPriority priority;
  final String title;
  final String message;
  final String? actionText;
  final String? actionRoute;
  final Map<String, dynamic>? actionData;
  final DateTime createdAt;
  final bool isRead;
  final bool isDismissed;
  final DateTime? expiresAt;
  final String? relatedGoalId;
  final String? fromUserId; // For manager nudges
  final String? fromUserName; // For manager nudges

  const Alert({
    required this.id,
    required this.userId,
    required this.type,
    required this.audience,
    required this.priority,
    required this.title,
    required this.message,
    this.actionText,
    this.actionRoute,
    this.actionData,
    required this.createdAt,
    this.isRead = false,
    this.isDismissed = false,
    this.expiresAt,
    this.relatedGoalId,
    this.fromUserId,
    this.fromUserName,
  });

  static AlertAudience _parseAlertAudience(String? raw) {
    // Default to personal for backwards compatibility
    if (raw == null || raw.isEmpty) return AlertAudience.personal;
    return AlertAudience.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AlertAudience.personal,
    );
  }

  static AlertType parseAlertType(String raw) {
    // Legacy strings written directly by older services
    switch (raw) {
      case 'meeting_scheduled':
        // Old behavior: treated as "scheduled". New behavior: it’s a proposal.
        return AlertType.oneOnOneProposed;
      case 'recognition':
        return AlertType.recognition;
    }

    return AlertType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AlertType.goalCreated,
    );
  }

  static Map<String, dynamic> _mergeActionData(Map<String, dynamic> data) {
    final rawActionData = data['actionData'];
    final actionData = rawActionData is Map
        ? Map<String, dynamic>.from(rawActionData)
        : <String, dynamic>{};

    final topBadgeId = data['badgeId'];
    if (topBadgeId != null && actionData['badgeId'] == null) {
      actionData['badgeId'] = topBadgeId.toString();
    }
    final topBadgeCategory = data['badgeCategory'];
    if (topBadgeCategory != null && actionData['badgeCategory'] == null) {
      actionData['badgeCategory'] = topBadgeCategory.toString();
    }
    final topRequestedByUserId = data['requestedByUserId'];
    if (topRequestedByUserId != null &&
        actionData['requestedByUserId'] == null) {
      actionData['requestedByUserId'] = topRequestedByUserId.toString();
    }
    final topRequiredApproverRole = data['requiredApproverRole'];
    if (topRequiredApproverRole != null &&
        actionData['requiredApproverRole'] == null) {
      actionData['requiredApproverRole'] = topRequiredApproverRole.toString();
    }
    final topApprovalChain = data['approvalChain'];
    if (topApprovalChain != null && actionData['approvalChain'] == null) {
      actionData['approvalChain'] = topApprovalChain.toString();
    }
    return actionData;
  }

  static Alert fromMap(Map<String, dynamic> map, {String? id}) {
    final actionData = _mergeActionData(map);

    return Alert(
      id: id ?? (map['id']?.toString() ?? ''),
      userId: map['userId']?.toString() ?? '',
      type: parseAlertType((map['type'] ?? 'goalCreated').toString()),
      audience: _parseAlertAudience(map['audience']?.toString()),
      priority: AlertPriority.values.firstWhere(
        (e) => e.name == (map['priority'] ?? 'medium'),
        orElse: () => AlertPriority.medium,
      ),
      title: map['title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      actionText: map['actionText']?.toString(),
      actionRoute: map['actionRoute']?.toString(),
      actionData: actionData.isEmpty ? null : actionData,
      createdAt: parseDate(map['createdAt']),
      isRead: (map['isRead'] ?? false) == true,
      isDismissed: (map['isDismissed'] ?? false) == true,
      expiresAt:
          map['expiresAt'] != null ? parseNullableDate(map['expiresAt']) : null,
      relatedGoalId: map['relatedGoalId']?.toString(),
      fromUserId: map['fromUserId']?.toString(),
      fromUserName: map['fromUserName']?.toString(),
    );
  }

  static dynamic _serializeValue(dynamic value) {
    if (value is DateTime) return value.toIso8601String();
    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(k.toString(), _serializeValue(v)),
      );
    }
    return value;
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    final requestedByUserId = actionData?['requestedByUserId']?.toString();
    final requiredApproverRole =
        actionData?['requiredApproverRole']?.toString();
    final approvalChain = actionData?['approvalChain']?.toString();
    final serializedActionData = actionData?.map((k, v) => MapEntry(k, _serializeValue(v)));
    return {
      if (includeId && id.isNotEmpty) 'id': id,
      'userId': userId,
      'type': type.name,
      'audience': audience.name,
      'priority': priority.name,
      'title': title,
      'message': message,
      'actionText': actionText,
      'actionRoute': actionRoute,
      'actionData': serializedActionData,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'isDismissed': isDismissed,
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      'relatedGoalId': relatedGoalId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      if (requestedByUserId != null && requestedByUserId.isNotEmpty)
        'requestedByUserId': requestedByUserId,
      if (requiredApproverRole != null && requiredApproverRole.isNotEmpty)
        'requiredApproverRole': requiredApproverRole,
      if (approvalChain != null && approvalChain.isNotEmpty)
        'approvalChain': approvalChain,
    };
  }

  Alert copyWith({
    String? id,
    String? userId,
    AlertType? type,
    AlertAudience? audience,
    AlertPriority? priority,
    String? title,
    String? message,
    String? actionText,
    String? actionRoute,
    Map<String, dynamic>? actionData,
    DateTime? createdAt,
    bool? isRead,
    bool? isDismissed,
    DateTime? expiresAt,
    String? relatedGoalId,
    String? fromUserId,
    String? fromUserName,
  }) {
    return Alert(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      audience: audience ?? this.audience,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      message: message ?? this.message,
      actionText: actionText ?? this.actionText,
      actionRoute: actionRoute ?? this.actionRoute,
      actionData: actionData ?? this.actionData,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isDismissed: isDismissed ?? this.isDismissed,
      expiresAt: expiresAt ?? this.expiresAt,
      relatedGoalId: relatedGoalId ?? this.relatedGoalId,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
    );
  }
}
