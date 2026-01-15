import 'package:cloud_firestore/cloud_firestore.dart';

enum GoalMilestoneStatus { notStarted, inProgress, completed, blocked }

class GoalMilestone {
  final String id;
  final String goalId;
  final String title;
  final String description;
  final GoalMilestoneStatus status;
  final DateTime dueDate;
  final String createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? deletionStatus; // 'pending', 'approved', 'rejected'
  final DateTime? deletionRequestedAt;
  final String? deletionReason;
  final String? deletionRequestId;

  const GoalMilestone({
    required this.id,
    required this.goalId,
    required this.title,
    required this.description,
    required this.status,
    required this.dueDate,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.deletionStatus,
    this.deletionRequestedAt,
    this.deletionReason,
    this.deletionRequestId,
  });

  factory GoalMilestone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GoalMilestone(
      id: doc.id,
      goalId: doc.reference.parent.parent?.id ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      status: _statusFromString(data['status']?.toString()),
      dueDate: _parseDate(data['dueDate']) ?? DateTime.now(),
      createdBy: data['createdBy']?.toString() ?? '',
      createdByName: data['createdByName']?.toString(),
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt']) ?? DateTime.now(),
      completedAt: _parseDate(data['completedAt']),
      deletionStatus: data['deletionStatus']?.toString(),
      deletionRequestedAt: _parseDate(data['deletionRequestedAt']),
      deletionReason: data['deletionReason']?.toString(),
      deletionRequestId: data['deletionRequestId']?.toString(),
    );
  }

  static GoalMilestoneStatus _statusFromString(String? value) {
    if (value == null) return GoalMilestoneStatus.notStarted;
    return GoalMilestoneStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GoalMilestoneStatus.notStarted,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    final parsed = DateTime.tryParse(v.toString());
    return parsed;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'status': status.name,
      'dueDate': Timestamp.fromDate(dueDate),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  GoalMilestone copyWith({
    String? id,
    String? goalId,
    String? title,
    String? description,
    GoalMilestoneStatus? status,
    DateTime? dueDate,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? deletionStatus,
    DateTime? deletionRequestedAt,
    String? deletionReason,
    String? deletionRequestId,
  }) {
    return GoalMilestone(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      deletionStatus: deletionStatus ?? this.deletionStatus,
      deletionRequestedAt: deletionRequestedAt ?? this.deletionRequestedAt,
      deletionReason: deletionReason ?? this.deletionReason,
      deletionRequestId: deletionRequestId ?? this.deletionRequestId,
    );
  }
}

