import 'package:cloud_firestore/cloud_firestore.dart';

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
}

enum AlertPriority {
  low,
  medium,
  high,
  urgent,
}

class Alert {
  final String id;
  final String userId;
  final AlertType type;
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

  factory Alert.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Alert(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: AlertType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'goalCreated'),
        orElse: () => AlertType.goalCreated,
      ),
      priority: AlertPriority.values.firstWhere(
        (e) => e.name == (data['priority'] ?? 'medium'),
        orElse: () => AlertPriority.medium,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      actionText: data['actionText'],
      actionRoute: data['actionRoute'],
      actionData: data['actionData'] != null 
          ? Map<String, dynamic>.from(data['actionData'])
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      isDismissed: data['isDismissed'] ?? false,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      relatedGoalId: data['relatedGoalId'],
      fromUserId: data['fromUserId'],
      fromUserName: data['fromUserName'],
    );
  }

  static Alert fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      final parsed = DateTime.tryParse(v?.toString() ?? '');
      return parsed ?? DateTime.now();
    }

    return Alert(
      id: id ?? (map['id']?.toString() ?? ''),
      userId: map['userId']?.toString() ?? '',
      type: AlertType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'goalCreated'),
        orElse: () => AlertType.goalCreated,
      ),
      priority: AlertPriority.values.firstWhere(
        (e) => e.name == (map['priority'] ?? 'medium'),
        orElse: () => AlertPriority.medium,
      ),
      title: map['title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      actionText: map['actionText']?.toString(),
      actionRoute: map['actionRoute']?.toString(),
      actionData: map['actionData'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['actionData'])
          : null,
      createdAt: parseDate(map['createdAt']),
      isRead: (map['isRead'] ?? false) == true,
      isDismissed: (map['isDismissed'] ?? false) == true,
      expiresAt: map['expiresAt'] != null ? parseDate(map['expiresAt']) : null,
      relatedGoalId: map['relatedGoalId']?.toString(),
      fromUserId: map['fromUserId']?.toString(),
      fromUserName: map['fromUserName']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.name,
      'priority': priority.name,
      'title': title,
      'message': message,
      'actionText': actionText,
      'actionRoute': actionRoute,
      'actionData': actionData,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'isDismissed': isDismissed,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'relatedGoalId': relatedGoalId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
    };
  }

  Alert copyWith({
    String? id,
    String? userId,
    AlertType? type,
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
