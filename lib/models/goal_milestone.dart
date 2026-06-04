import 'package:pdh/utils/date_parse.dart';

enum GoalMilestoneStatus {
  notStarted,
  inProgress,
  pendingManagerReview, // Evidence submitted, awaiting manager review
  completed,
  completedAcknowledged, // NEW: Manager acknowledged completion
  blocked,
}

enum MilestoneEvidenceStatus {
  pendingReview, // NEW: Evidence submitted, awaiting manager review
  approved, // NEW: Evidence approved by manager
  rejected, // NEW: Evidence rejected by manager
}

class MilestoneEvidence {
  final String id;
  final String fileUrl;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String uploadedBy;
  final String? uploadedByName;
  final DateTime uploadedAt;
  final MilestoneEvidenceStatus status;
  final String? reviewedBy;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final String? reviewNotes;

  const MilestoneEvidence({
    required this.id,
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.uploadedBy,
    this.uploadedByName,
    required this.uploadedAt,
    this.status =
        MilestoneEvidenceStatus.pendingReview, // UPDATED: New default status
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedAt,
    this.reviewNotes,
  });

  static MilestoneEvidenceStatus _evidenceStatusFromString(String? value) {
    if (value == null) {
      return MilestoneEvidenceStatus.pendingReview; // UPDATED: New default
    }
    return MilestoneEvidenceStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () =>
          MilestoneEvidenceStatus.pendingReview, // UPDATED: New default
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'uploadedBy': uploadedBy,
      'uploadedByName': uploadedByName,
      'uploadedAt': uploadedAt.toIso8601String(),
      'status': status.name,
      'reviewedBy': reviewedBy,
      'reviewedByName': reviewedByName,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewNotes': reviewNotes,
    };
  }

  static MilestoneEvidence fromMap(Map<String, dynamic> map) {
    return MilestoneEvidence(
      id: map['id']?.toString() ?? '',
      fileUrl: map['fileUrl']?.toString() ?? '',
      fileName: map['fileName']?.toString() ?? '',
      fileType: map['fileType']?.toString() ?? '',
      fileSize: map['fileSize']?.toInt() ?? 0,
      uploadedBy: map['uploadedBy']?.toString() ?? '',
      uploadedByName: map['uploadedByName']?.toString(),
      uploadedAt: parseDate(map['uploadedAt']),
      status: _evidenceStatusFromString(map['status']?.toString()),
      reviewedBy: map['reviewedBy']?.toString(),
      reviewedByName: map['reviewedByName']?.toString(),
      reviewedAt: parseNullableDate(map['reviewedAt']),
      reviewNotes: map['reviewNotes']?.toString(),
    );
  }
}

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
  // REMOVED: requiresEvidence field - no longer needed
  // NEW: Evidence list for workflow-based system
  final List<MilestoneEvidence> evidence;

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
    // REMOVED: requiresEvidence parameter
    this.evidence = const [], // Evidence list for new workflow
  });

  factory GoalMilestone.fromMap(
    Map<String, dynamic> map, {
    String? id,
    String? goalId,
  }) {
    List<MilestoneEvidence> parsedEvidence = [];
    if (map['evidence'] != null) {
      final evidenceData = map['evidence'] as List;
      parsedEvidence = evidenceData
          .map((e) => MilestoneEvidence.fromMap(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    }

    return GoalMilestone(
      id: id ?? map['id']?.toString() ?? '',
      goalId: goalId ?? map['goalId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      status: _statusFromString(map['status']?.toString()),
      dueDate: parseDate(map['dueDate']),
      createdBy: map['createdBy']?.toString() ?? '',
      createdByName: map['createdByName']?.toString(),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      completedAt: parseNullableDate(map['completedAt']),
      evidence: parsedEvidence,
    );
  }

  static GoalMilestoneStatus _statusFromString(String? value) {
    if (value == null) return GoalMilestoneStatus.notStarted;
    return GoalMilestoneStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GoalMilestoneStatus.notStarted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goalId': goalId,
      'title': title,
      'description': description,
      'status': status.name,
      'dueDate': dueDate.toIso8601String(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'evidence': evidence.map((e) => e.toMap()).toList(),
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
    // REMOVED: requiresEvidence and manager parameters - no longer needed
    List<MilestoneEvidence>? evidence,
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
      // NEW: Evidence fields for additive extension
      evidence: evidence ?? this.evidence,
      // REMOVED: requiresEvidence and manager fields - no longer needed
    );
  }
}
