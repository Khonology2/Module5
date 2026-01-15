import 'package:cloud_firestore/cloud_firestore.dart';

class DeletedGoalLog {
  final String id;
  final String goalId;
  final String goalTitle;
  final DateTime deletedAt;
  final String deletedBy;
  final String? deletedByName;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? employeeName;
  final String? department;

  DeletedGoalLog({
    required this.id,
    required this.goalId,
    required this.goalTitle,
    required this.deletedAt,
    required this.deletedBy,
    this.deletedByName,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.employeeName,
    this.department,
  });

  factory DeletedGoalLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final goalData = data['goalData'] as Map<String, dynamic>? ?? {};
    return DeletedGoalLog(
      id: doc.id,
      goalId: data['goalId'] ?? doc.id,
      goalTitle: goalData['title'] ?? data['goalTitle'] ?? 'Untitled',
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deletedBy: data['deletedBy'] ?? '',
      deletedByName: data['deletedByName'],
      approvedBy: data['approvedBy'],
      approvedByName: data['approvedByName'],
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      employeeName: goalData['employeeName'] ?? data['employeeName'],
      department: goalData['department'] ?? data['department'],
    );
  }
}
