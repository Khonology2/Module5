import 'package:cloud_firestore/cloud_firestore.dart';

class GoalDeletionRequest {
  final String id;
  final String goalId;
  final String goalTitle;
  final String userId;
  final String reason;
  final String status; // pending | approved | rejected
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? employeeName;
  final String? employeeEmail;
  final String? department;

  GoalDeletionRequest({
    required this.id,
    required this.goalId,
    required this.goalTitle,
    required this.userId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.employeeName,
    this.employeeEmail,
    this.department,
  });

  factory GoalDeletionRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GoalDeletionRequest(
      id: doc.id,
      goalId: data['goalId'] ?? '',
      goalTitle: data['goalTitle'] ?? '',
      userId: data['userId'] ?? '',
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedBy: data['resolvedBy'],
      employeeName: data['employeeName'],
      employeeEmail: data['employeeEmail'],
      department: data['department'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'goalId': goalId,
      'goalTitle': goalTitle,
      'userId': userId,
      'reason': reason,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
      if (resolvedBy != null) 'resolvedBy': resolvedBy,
      if (employeeName != null) 'employeeName': employeeName,
      if (employeeEmail != null) 'employeeEmail': employeeEmail,
      if (department != null) 'department': department,
    };
  }
}
