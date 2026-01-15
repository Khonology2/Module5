import 'package:cloud_firestore/cloud_firestore.dart';

class ApprovedGoalAudit {
  final String id;
  final String goalId;
  final String goalTitle;
  final String employeeId;
  final String employeeName;
  final String department;
  final DateTime approvedAt;
  final String approvedBy;
  final String approvedByName;
  final DateTime timestamp;

  ApprovedGoalAudit({
    required this.id,
    required this.goalId,
    required this.goalTitle,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.approvedAt,
    required this.approvedBy,
    required this.approvedByName,
    required this.timestamp,
  });

  factory ApprovedGoalAudit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ApprovedGoalAudit(
      id: doc.id,
      goalId: data['goalId'] ?? '',
      goalTitle: data['goalTitle'] ?? '',
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      department: data['department'] ?? '',
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedBy: data['approvedBy'] ?? '',
      approvedByName: data['approvedByName'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'goalId': goalId,
      'goalTitle': goalTitle,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'department': department,
      'approvedAt': Timestamp.fromDate(approvedAt),
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
