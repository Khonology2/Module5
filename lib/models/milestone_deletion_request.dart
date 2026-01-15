import 'package:cloud_firestore/cloud_firestore.dart';

class MilestoneDeletionRequest {
  final String id;
  final String milestoneId;
  final String goalId;
  final String userId; // The ID of the employee who owns the goal/milestone
  final String milestoneTitle;
  final String reason;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final String employeeName;
  final String? employeeEmail;
  final String? department;
  final DateTime? resolvedAt;
  final String? resolvedBy; // ID of manager/admin who resolved it
  final String? resolutionReason; // Manager/admin's reason for approval/rejection

  MilestoneDeletionRequest({
    required this.id,
    required this.milestoneId,
    required this.goalId,
    required this.userId,
    required this.milestoneTitle,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.employeeName,
    this.employeeEmail,
    this.department,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionReason,
  });

  factory MilestoneDeletionRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MilestoneDeletionRequest(
      id: doc.id,
      milestoneId: data['milestoneId'] ?? '',
      goalId: data['goalId'] ?? '',
      userId: data['userId'] ?? '',
      milestoneTitle: data['milestoneTitle'] ?? '',
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      employeeName: data['employeeName'] ?? 'Unknown Employee',
      employeeEmail: data['employeeEmail'],
      department: data['department'],
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedBy: data['resolvedBy'],
      resolutionReason: data['resolutionReason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'milestoneId': milestoneId,
      'goalId': goalId,
      'userId': userId,
      'milestoneTitle': milestoneTitle,
      'reason': reason,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'employeeName': employeeName,
      'employeeEmail': employeeEmail,
      'department': department,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolvedBy': resolvedBy,
      'resolutionReason': resolutionReason,
    };
  }
}
