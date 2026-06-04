import 'package:pdh/utils/date_parse.dart';

class AuditEntry {
  final String id;
  final String userId;
  final String goalId;
  final String goalTitle;
  final DateTime completedDate;
  final DateTime submittedDate;
  final DateTime? verifiedDate;
  final DateTime? rejectedDate;
  final DateTime? approvedDate;
  final DateTime? createdDate;
  final String
  status; // 'created', 'pending','approved',  'verified', 'rejected'
  final List<String> evidence;
  final String? acknowledgedBy;
  final String? acknowledgedById;
  final double? score;
  final String? comments;
  final String? rejectionReason;
  final String? requiredApproverRole;
  final String? approvalChain;
  final String userDisplayName;
  final String userDepartment;

  AuditEntry({
    required this.id,
    required this.userId,
    required this.goalId,
    required this.goalTitle,
    required this.completedDate,
    required this.submittedDate,
    this.verifiedDate,
    this.rejectedDate,
    this.approvedDate,
    this.createdDate,
    required this.status,
    required this.evidence,
    this.acknowledgedBy,
    this.acknowledgedById,
    this.score,
    this.comments,
    this.rejectionReason,
    this.requiredApproverRole,
    this.approvalChain,
    required this.userDisplayName,
    required this.userDepartment,
  });

  factory AuditEntry.fromMap(Map<String, dynamic> data, {String? fallbackId}) {
    DateTime parseAuditDate(dynamic value) => parseDate(value);

    List<String> parseEvidence(dynamic value) {
      if (value is List) {
        return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      }
      if (value is String && value.trim().isNotEmpty) {
        return <String>[value.trim()];
      }
      return const <String>[];
    }

    return AuditEntry(
      id: (data['id'] ?? fallbackId ?? '').toString(),
      userId: (data['userId'] ?? data['user_id'] ?? '').toString(),
      goalId: (data['goalId'] ?? '').toString(),
      goalTitle: (data['goalTitle'] ?? '').toString(),
      completedDate: parseAuditDate(data['completedDate'] ?? data['completed_date']),
      submittedDate: parseAuditDate(data['submittedDate'] ?? data['submitted_date']),
      verifiedDate: data['verifiedDate'] != null ? parseAuditDate(data['verifiedDate']) : null,
      rejectedDate: data['rejectedDate'] != null ? parseAuditDate(data['rejectedDate']) : null,
      approvedDate: data['approvedDate'] != null ? parseAuditDate(data['approvedDate']) : null,
      createdDate: data['createdDate'] != null ? parseAuditDate(data['createdDate']) : null,
      status: (data['status'] ?? 'pending').toString(),
      evidence: parseEvidence(data['evidence']),
      acknowledgedBy: data['acknowledgedBy']?.toString(),
      acknowledgedById: data['acknowledgedById']?.toString(),
      score: (data['score'] is num) ? (data['score'] as num).toDouble() : double.tryParse(data['score']?.toString() ?? ''),
      comments: data['comments']?.toString(),
      rejectionReason: data['rejectionReason']?.toString(),
      requiredApproverRole: data['requiredApproverRole']?.toString(),
      approvalChain: data['approvalChain']?.toString(),
      userDisplayName: (data['userDisplayName'] ?? 'Unknown User').toString(),
      userDepartment: (data['userDepartment'] ?? 'Unknown').toString(),
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'userId': userId,
      'goalId': goalId,
      'goalTitle': goalTitle,
      'completedDate': completedDate.toIso8601String(),
      'submittedDate': submittedDate.toIso8601String(),
      'verifiedDate': verifiedDate?.toIso8601String(),
      'rejectedDate': rejectedDate?.toIso8601String(),
      'approvedDate': approvedDate?.toIso8601String(),
      'createdDate': createdDate?.toIso8601String(),
      'status': status,
      'evidence': evidence,
      'acknowledgedBy': acknowledgedBy,
      'acknowledgedById': acknowledgedById,
      'score': score,
      'comments': comments,
      'rejectionReason': rejectionReason,
      'requiredApproverRole': requiredApproverRole,
      'approvalChain': approvalChain,
      'userDisplayName': userDisplayName,
      'userDepartment': userDepartment,
    };
  }
}
