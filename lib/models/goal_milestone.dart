import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory MilestoneEvidence.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MilestoneEvidence(
      id: doc.id,
      fileUrl: data['fileUrl']?.toString() ?? '',
      fileName: data['fileName']?.toString() ?? '',
      fileType: data['fileType']?.toString() ?? '',
      fileSize: data['fileSize']?.toInt() ?? 0,
      uploadedBy: data['uploadedBy']?.toString() ?? '',
      uploadedByName: data['uploadedByName']?.toString(),
      uploadedAt: _parseDate(data['uploadedAt']) ?? DateTime.now(),
      status: _evidenceStatusFromString(data['status']?.toString()),
      reviewedBy: data['reviewedBy']?.toString(),
      reviewedByName: data['reviewedByName']?.toString(),
      reviewedAt: _parseDate(data['reviewedAt']),
      reviewNotes: data['reviewNotes']?.toString(),
    );
  }

  static MilestoneEvidenceStatus _evidenceStatusFromString(String? value) {
    if (value == null)
      return MilestoneEvidenceStatus.pendingReview; // UPDATED: New default
    return MilestoneEvidenceStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () =>
          MilestoneEvidenceStatus.pendingReview, // UPDATED: New default
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
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'uploadedBy': uploadedBy,
      'uploadedByName': uploadedByName,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'status': status.name,
      'reviewedBy': reviewedBy,
      'reviewedByName': reviewedByName,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
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
      uploadedAt: _parseDate(map['uploadedAt']) ?? DateTime.now(),
      status: _evidenceStatusFromString(map['status']?.toString()),
      reviewedBy: map['reviewedBy']?.toString(),
      reviewedByName: map['reviewedByName']?.toString(),
      reviewedAt: _parseDate(map['reviewedAt']),
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

  factory GoalMilestone.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse evidence list for backward compatibility
    List<MilestoneEvidence> parsedEvidence = [];
    if (data['evidence'] != null) {
      final evidenceData = data['evidence'] as List;
      parsedEvidence = evidenceData
          .map((e) => MilestoneEvidence.fromMap(e))
          .toList();
    }

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
      // REMOVED: requiresEvidence and manager fields - no longer needed
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
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      // REMOVED: requiresEvidence and manager fields - no longer needed
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
