import 'package:pdh/utils/date_parse.dart';

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

  factory ApprovedGoalAudit.fromMap(Map<String, dynamic> data, {String? fallbackId}) {
    return ApprovedGoalAudit(
      id: (data['id'] ?? fallbackId ?? '').toString(),
      goalId: (data['goalId'] ?? '').toString(),
      goalTitle: (data['goalTitle'] ?? '').toString(),
      employeeId: (data['employeeId'] ?? data['userId'] ?? '').toString(),
      employeeName: (data['employeeName'] ?? '').toString(),
      department: (data['department'] ?? '').toString(),
      approvedAt: parseDate(data['approvedAt']),
      approvedBy: (data['approvedBy'] ?? '').toString(),
      approvedByName: (data['approvedByName'] ?? '').toString(),
      timestamp: parseDate(data['timestamp'] ?? data['createdAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'goalId': goalId,
      'goalTitle': goalTitle,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'department': department,
      'approvedAt': approvedAt.toIso8601String(),
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
