import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/approved_goal_audit.dart';
import 'package:pdh/services/backend_auth_service.dart';

class ApprovedGoalAuditService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream approved goals for current employee
  static Stream<List<ApprovedGoalAudit>> getEmployeeApprovedGoalsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _pollApprovedGoalAudits(employeeId: uid);
  }

  // Stream approved goals for managers (all employees)
  static Stream<List<ApprovedGoalAudit>> getManagerApprovedGoalsStream() {
    return _pollApprovedGoalAudits();
  }

  // Log approved goal for audit trail
  static Future<void> logApprovedGoal({
    required String goalId,
    required String goalTitle,
    required String employeeId,
    required String employeeName,
    required String department,
    required String approvedBy,
    required String approvedByName,
  }) async {
    try {
      final audit = ApprovedGoalAudit(
        id: goalId,
        goalId: goalId,
        goalTitle: goalTitle,
        employeeId: employeeId,
        employeeName: employeeName,
        department: department,
        approvedAt: DateTime.now(),
        approvedBy: approvedBy,
        approvedByName: approvedByName,
        timestamp: DateTime.now(),
      );

      await BackendAuthService.instance.createApprovedGoalAudit(audit.toMap());

      developer.log('Approved goal audit logged: $goalId by $approvedByName');
    } catch (e) {
      developer.log('Error logging approved goal audit: $e');
      rethrow;
    }
  }

  // Sync offline audit entries when online
  static Future<void> syncOfflineAudits() async {
    try {
      developer.log('Approved goal audits are backed by Postgres; no sync required');
    } catch (e) {
      developer.log('Error syncing approved goal audits: $e');
    }
  }

  // Get audit by goal ID
  static Future<ApprovedGoalAudit?> getAuditByGoalId(String goalId) async {
    try {
      final item = await BackendAuthService.instance.getApprovedGoalAudit(goalId);
      if (item.isEmpty) return null;
      return ApprovedGoalAudit.fromMap(item);
    } catch (e) {
      developer.log('Error getting audit by goal ID: $e');
      return null;
    }
  }

  static Stream<List<ApprovedGoalAudit>> _pollApprovedGoalAudits({
    String? employeeId,
  }) async* {
    while (true) {
      try {
        final items = await BackendAuthService.instance.getApprovedGoalAudits(
          employeeId: employeeId,
        );
        yield items.map((item) => ApprovedGoalAudit.fromMap(item)).toList();
      } catch (e) {
        developer.log('Error streaming approved goals: $e');
        yield <ApprovedGoalAudit>[];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }
}
