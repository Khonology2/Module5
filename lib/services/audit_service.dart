import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/audit_entry.dart';
import 'package:pdh/services/timeline_service.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/services/repository_service.dart';

class AuditService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final BackendAuthService _backend = BackendAuthService.instance;

  // Check if a goal has already been submitted for audit
  static Future<bool> hasGoalBeenSubmittedForAudit(
    String goalId,
    String userId,
  ) async {
    try {
      final existingEntries = await _backend.getAuditEntries(
        userId: userId,
        goalId: goalId,
        limit: 1,
      );
      return existingEntries.isNotEmpty;
    } catch (e) {
      developer.log('Error checking if goal submitted for audit: $e');
      return false; // Return false on error to allow retry
    }
  }

  // Submit a completed goal for audit
  static Future<void> submitGoalForAudit(
    Goal goal,
    List<String> evidence,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final existingEntries = await _backend.getAuditEntries(
        userId: user.uid,
        goalId: goal.id,
        limit: 1,
      );

      if (existingEntries.isNotEmpty) {
        throw Exception('This goal has already been submitted for audit');
      }

      final userData = await _backend.getUser(user.uid);

      final rawDepartment = (userData['department'] as String?)?.trim() ?? '';
      final department = rawDepartment.isEmpty ? 'Unknown' : rawDepartment;

      final auditEntry = AuditEntry(
        id: '',
        userId: user.uid,
        goalId: goal.id,
        goalTitle: goal.title,
        completedDate: DateTime.now(),
        submittedDate: DateTime.now(),
        status: 'pending',
        evidence: evidence,
        userDisplayName:
            userData['displayName'] ?? user.displayName ?? 'Unknown User',
        userDepartment: department,
      );

      final createdEntry = AuditEntry.fromMap(
        await _backend.createAuditEntry(auditEntry.toMap(includeId: false)),
      );

      try {
        final event = TimelineService.buildEvent(
          eventType: 'submission',
          description: 'Goal submitted for audit: ${goal.title}',
        );
        await _backend.addAuditTimelineEvent(createdEntry.id, event);
      } catch (e) {
        developer.log('Failed to log submission timeline event: $e');
      }
    } catch (e) {
      developer.log('Error submitting goal for audit: $e');
      rethrow;
    }
  }

  // Re-request acknowledgement for a previously submitted goal.
  // This intentionally updates the existing audit entry to prevent silent
  // duplicate rows while still logging an explicit re-request event.
  static Future<void> resubmitGoalForAudit({
    required Goal goal,
    required List<String> evidence,
    required String reason,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final normalizedReason = reason.trim();
      if (normalizedReason.isEmpty) {
        throw Exception('A reason is required to re-request acknowledgement');
      }

      final existingEntries = await _backend.getAuditEntries(
        userId: user.uid,
        goalId: goal.id,
        limit: 1,
      );

      if (existingEntries.isEmpty) {
        await submitGoalForAudit(goal, evidence);
        return;
      }

      final entry = AuditEntry.fromMap(existingEntries.first);
      final now = DateTime.now().toIso8601String();

      await _backend.patchAuditEntry(entry.id, {
        'goalTitle': goal.title,
        'completedDate': now,
        'submittedDate': now,
        'status': 'pending',
        'evidence': evidence,
        'rejectionReason': null,
        'verifiedDate': null,
        'rejectedDate': null,
        'approvedDate': null,
        'lastRerequestReason': normalizedReason,
        'lastRerequestedAt': now,
        'rerequestCount': 1,
      });

      try {
        final event = TimelineService.buildEvent(
          eventType: 'submission',
          description:
              'Acknowledgement re-requested for "${goal.title}". Reason: $normalizedReason',
        );
        await _backend.addAuditTimelineEvent(entry.id, event);
      } catch (e) {
        developer.log('Failed to log re-request timeline event: $e');
      }
    } catch (e) {
      developer.log('Error re-requesting goal for audit: $e');
      rethrow;
    }
  }

  // Get audit entries stream for managers (department-scoped, fail-closed)
  static Stream<List<AuditEntry>> getManagerAuditEntriesStream({
    String? status,
    String? searchQuery,
  }) {
    final user = _auth.currentUser;
    if (user == null) {
      developer.log(
        'Manager audit entries: No current user',
        name: 'AuditService',
      );
      return Stream.value(<AuditEntry>[]);
    }

    return _pollManagerAuditEntries(
      userId: user.uid,
      status: status,
      searchQuery: searchQuery,
    );
  }

  // Get comprehensive audit statistics for managers - ALL EMPLOYEES DATA
  static Stream<Map<String, dynamic>> getManagerAuditStatsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(<String, dynamic>{
        'total': 0,
        'created': 0,
        'approved': 0,
        'pending': 0,
        'verified': 0,
        'rejected': 0,
        'byDepartment': <String, Map<String, int>>{},
        'byEmployee': <String, Map<String, int>>{},
        'recentActivity': <Map<String, dynamic>>[],
        'topPerformers': <Map<String, dynamic>>[],
      });
    }

    final emptyStats = <String, dynamic>{
      'total': 0,
      'created': 0,
      'approved': 0,
      'pending': 0,
      'verified': 0,
      'rejected': 0,
      'byDepartment': <String, Map<String, int>>{},
      'byEmployee': <String, Map<String, int>>{},
      'recentActivity': <Map<String, dynamic>>[],
      'topPerformers': <Map<String, dynamic>>[],
    };

    return _pollManagerAuditStats(userId: user.uid, emptyStats: emptyStats);
  }

  // Get audit entries stream for employees (their own entries)
  static Stream<List<AuditEntry>> getEmployeeAuditEntriesStream({
    String? status,
    String? searchQuery,
  }) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _pollEmployeeAuditEntries(
      userId: user.uid,
      status: status,
      searchQuery: searchQuery,
    );
  }

  // Verify an audit entry (manager action)
  static Future<void> verifyAuditEntry(
    String entryId,
    double score,
    String? comments,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userData = await _backend.getUser(user.uid);

      final entryData = await _backend.getAuditEntry(entryId);
      if (entryData.isEmpty) throw Exception('Audit entry not found');

      final entry = AuditEntry.fromMap(entryData);

      await _backend.patchAuditEntry(entryId, {
        'status': 'verified',
        'score': score,
        'comments': comments,
        'acknowledgedBy':
            userData['displayName'] ?? user.displayName ?? 'Manager',
        'acknowledgedById': user.uid,
        'verifiedDate': DateTime.now().toIso8601String(),
      });

      // Immediately sync verified entry to employee's repository
      try {
        final updatedEntry = AuditEntry(
          id: entry.id,
          userId: entry.userId,
          goalId: entry.goalId,
          goalTitle: entry.goalTitle,
          completedDate: entry.completedDate,
          submittedDate: entry.submittedDate,
          status: 'verified',
          evidence: entry.evidence,
          acknowledgedBy:
              userData['displayName'] ?? user.displayName ?? 'Manager',
          acknowledgedById: user.uid,
          score: score,
          comments: comments,
          userDisplayName: entry.userDisplayName,
          userDepartment: entry.userDepartment,
        );
        await RepositoryService.addVerifiedGoalToRepository(updatedEntry);
      } catch (e) {
        developer.log('Failed to sync verified entry to repository: $e');
        // Don't throw - verification succeeded even if repository sync fails
      }

      // Log timeline event: verification
      try {
        final actorName =
            userData['displayName'] ?? user.displayName ?? 'Manager';
        final event = TimelineService.buildEvent(
          eventType: 'verification',
          description: 'Entry verified with score ${score.toStringAsFixed(1)}',
          actorIdOverride: user.uid,
          actorNameOverride: actorName,
        );
        await _backend.addAuditTimelineEvent(entryId, event);
      } catch (e) {
        developer.log('Failed to log verification timeline event: $e');
      }
    } catch (e) {
      developer.log('Error verifying audit entry: $e');
      rethrow;
    }
  }

  // Manager acknowledgement for a completed goal (with or without a prior request)
  static Future<void> acknowledgeCompletedGoal({
    required Goal goal,
    required String employeeId,
    required String employeeName,
    required String employeeDepartment,
    double? score,
    String? comments,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userData = await _backend.getUser(user.uid);
      final managerName =
          userData['displayName'] ?? user.displayName ?? 'Manager';

      final existingEntries = await _backend.getAuditEntries(
        userId: employeeId,
        goalId: goal.id,
        limit: 1,
      );

      if (existingEntries.isNotEmpty) {
        final entry = AuditEntry.fromMap(existingEntries.first);

        await _backend.patchAuditEntry(entry.id, {
          'status': 'verified',
          'score': score,
          'comments': comments,
          'acknowledgedBy': managerName,
          'acknowledgedById': user.uid,
          'verifiedDate': DateTime.now().toIso8601String(),
          'rejectionReason': null,
        });

        await _backend.patchGoal(goal.id, {
          'status': 'acknowledged',
          'acknowledgedAt': DateTime.now().toIso8601String(),
          'acknowledgedBy': managerName,
          'acknowledgedById': user.uid,
        });

        final updatedEntry = AuditEntry(
          id: entry.id,
          userId: entry.userId,
          goalId: entry.goalId,
          goalTitle: entry.goalTitle,
          completedDate: entry.completedDate,
          submittedDate: entry.submittedDate,
          status: 'verified',
          evidence: entry.evidence,
          acknowledgedBy: managerName,
          acknowledgedById: user.uid,
          score: score ?? entry.score,
          comments: comments ?? entry.comments,
          userDisplayName: entry.userDisplayName,
          userDepartment: entry.userDepartment,
          verifiedDate: DateTime.now(),
        );

        await RepositoryService.addVerifiedGoalToRepository(updatedEntry);

        final event = TimelineService.buildEvent(
          eventType: 'verification',
          description: 'Goal acknowledged by manager',
          actorIdOverride: user.uid,
          actorNameOverride: managerName,
        );
        await _backend.addAuditTimelineEvent(entry.id, event);
        return;
      }

      final now = DateTime.now();
      final auditEntry = AuditEntry(
        id: '',
        userId: employeeId,
        goalId: goal.id,
        goalTitle: goal.title,
        completedDate: now,
        submittedDate: now,
        verifiedDate: now,
        status: 'verified',
        evidence: goal.evidence,
        acknowledgedBy: managerName,
        acknowledgedById: user.uid,
        score: score,
        comments: comments,
        userDisplayName: employeeName,
        userDepartment: employeeDepartment.isEmpty
            ? 'Unknown'
            : employeeDepartment,
      );

      final createdEntry = AuditEntry.fromMap(
        await _backend.createAuditEntry(auditEntry.toMap(includeId: false)),
      );

      await _backend.patchGoal(goal.id, {
        'status': 'acknowledged',
        'acknowledgedAt': now.toIso8601String(),
        'acknowledgedBy': managerName,
        'acknowledgedById': user.uid,
      });

      final storedEntry = AuditEntry(
        id: createdEntry.id,
        userId: auditEntry.userId,
        goalId: auditEntry.goalId,
        goalTitle: auditEntry.goalTitle,
        completedDate: auditEntry.completedDate,
        submittedDate: auditEntry.submittedDate,
        verifiedDate: auditEntry.verifiedDate,
        status: auditEntry.status,
        evidence: auditEntry.evidence,
        acknowledgedBy: auditEntry.acknowledgedBy,
        acknowledgedById: auditEntry.acknowledgedById,
        score: auditEntry.score,
        comments: auditEntry.comments,
        userDisplayName: auditEntry.userDisplayName,
        userDepartment: auditEntry.userDepartment,
      );

      await RepositoryService.addVerifiedGoalToRepository(storedEntry);

      final event = TimelineService.buildEvent(
        eventType: 'verification',
        description: 'Goal acknowledged by manager',
        actorIdOverride: user.uid,
        actorNameOverride: managerName,
      );
      await _backend.addAuditTimelineEvent(storedEntry.id, event);
    } catch (e) {
      developer.log('Error acknowledging completed goal: $e');
      rethrow;
    }
  }

  // Request changes for an audit entry (manager action)
  static Future<void> requestChanges(String entryId, String reason) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userData = await _backend.getUser(user.uid);

      await _backend.patchAuditEntry(entryId, {
        'status': 'rejected',
        'rejectionReason': reason,
        'acknowledgedBy':
            userData['displayName'] ?? user.displayName ?? 'Manager',
        'acknowledgedById': user.uid,
        'rejectedDate': DateTime.now().toIso8601String(),
      });

      // Log timeline event: rejection
      try {
        final event = TimelineService.buildEvent(
          eventType: 'rejection',
          description: 'Changes requested: $reason',
        );
        await _backend.addAuditTimelineEvent(entryId, event);
      } catch (e) {
        developer.log('Failed to log rejection timeline event: $e');
      }
    } catch (e) {
      developer.log('Error requesting changes: $e');
      rethrow;
    }
  }

  // Get audit statistics
  static Future<Map<String, int>> getAuditStats({
    String? userId,
    String? department,
  }) async {
    try {
      final items = await _backend.getAuditEntries(
        userId: userId,
        department: department,
        limit: 500,
      );
      final entries = items
          .where((item) => item['action'] == null)
          .map((item) => AuditEntry.fromMap(item))
          .toList();

      return {
        'total': entries.length,
        'verified': entries.where((e) => e.status == 'verified').length,
        'pending': entries.where((e) => e.status == 'pending').length,
        'rejected': entries.where((e) => e.status == 'rejected').length,
      };
    } catch (e) {
      developer.log('Error getting audit stats: $e');
      return {'total': 0, 'verified': 0, 'pending': 0, 'rejected': 0};
    }
  }

  static Stream<List<AuditEntry>> _pollEmployeeAuditEntries({
    required String userId,
    String? status,
    String? searchQuery,
  }) async* {
    while (true) {
      try {
        final items = await _backend.getAuditEntries(
          userId: userId,
          status: status,
          limit: 100,
        );
        var entries = items
            .where((item) => (item['action'] == null))
            .where((item) => (item['goalId'] ?? '').toString().isNotEmpty)
            .map(AuditEntry.fromMap)
            .toList();
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final lowercaseQuery = searchQuery.toLowerCase();
          entries = entries.where((entry) {
            return entry.goalTitle.toLowerCase().contains(lowercaseQuery) ||
                entry.evidence.any(
                  (evidence) => evidence.toLowerCase().contains(lowercaseQuery),
                );
          }).toList();
        }
        yield entries;
      } catch (e) {
        developer.log('Error processing employee audit entries: $e');
        yield <AuditEntry>[];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  static Stream<List<AuditEntry>> _pollManagerAuditEntries({
    required String userId,
    String? status,
    String? searchQuery,
  }) async* {
    String dept = '';
    try {
      final userData = await _backend.getUser(userId);
      dept = (userData['department'] ?? '').toString().trim();
    } catch (e) {
      developer.log(
        'Manager audit entries: failed to load manager profile: $e',
        name: 'AuditService',
      );
      yield <AuditEntry>[];
      return;
    }

    if (dept.isEmpty) {
      developer.log(
        'Manager audit entries: missing manager department; returning empty stream',
        name: 'AuditService',
      );
      yield <AuditEntry>[];
      return;
    }

    while (true) {
      try {
        final items = await _backend.getAuditEntries(
          department: dept,
          status: status,
          limit: 200,
        );
        var entries = items
            .where((item) => (item['action'] == null))
            .where((item) => (item['goalId'] ?? '').toString().isNotEmpty)
            .map(AuditEntry.fromMap)
            .toList();

        if (searchQuery != null && searchQuery.isNotEmpty) {
          final lowercaseQuery = searchQuery.toLowerCase();
          entries = entries.where((entry) {
            return entry.goalTitle.toLowerCase().contains(lowercaseQuery) ||
                entry.userDisplayName.toLowerCase().contains(lowercaseQuery) ||
                entry.userDepartment.toLowerCase().contains(lowercaseQuery) ||
                entry.evidence.any(
                  (evidence) => evidence.toLowerCase().contains(lowercaseQuery),
                );
          }).toList();
        }

        yield entries;
      } catch (e) {
        developer.log(
          'Error processing manager audit entries: $e',
          name: 'AuditService',
        );
        yield <AuditEntry>[];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  static Stream<Map<String, dynamic>> _pollManagerAuditStats({
    required String userId,
    required Map<String, dynamic> emptyStats,
  }) async* {
    String dept = '';
    try {
      final userData = await _backend.getUser(userId);
      dept = (userData['department'] ?? '').toString().trim();
    } catch (e) {
      developer.log('Manager audit stats: failed to load profile: $e');
      yield emptyStats;
      return;
    }
    if (dept.isEmpty) {
      yield emptyStats;
      return;
    }

    yield emptyStats;
    while (true) {
      try {
        final items = await _backend.getAuditEntries(
          department: dept,
          limit: 200,
        );
        final entries = items
            .where((item) => (item['goalId'] ?? '').toString().isNotEmpty)
            .map(AuditEntry.fromMap)
            .toList();

        final stats = <String, dynamic>{
          'total': entries.length,
          'created': entries.where((e) => e.status == 'created').length,
          'approved': entries.where((e) => e.status == 'approved').length,
          'pending': entries.where((e) => e.status == 'pending').length,
          'verified': entries.where((e) => e.status == 'verified').length,
          'rejected': entries.where((e) => e.status == 'rejected').length,
          'byDepartment': <String, Map<String, int>>{},
          'byEmployee': <String, Map<String, int>>{},
          'recentActivity': <Map<String, dynamic>>[],
          'topPerformers': <Map<String, dynamic>>[],
        };

        final departmentGroups = <String, List<AuditEntry>>{};
        for (final entry in entries) {
          departmentGroups.putIfAbsent(entry.userDepartment, () => []).add(entry);
        }
        for (final deptKey in departmentGroups.keys) {
          final deptEntries = departmentGroups[deptKey]!;
          stats['byDepartment'][deptKey] = {
            'total': deptEntries.length,
            'created': deptEntries.where((e) => e.status == 'created').length,
            'approved': deptEntries.where((e) => e.status == 'approved').length,
            'pending': deptEntries.where((e) => e.status == 'pending').length,
            'verified': deptEntries.where((e) => e.status == 'verified').length,
            'rejected': deptEntries.where((e) => e.status == 'rejected').length,
          };
        }

        final employeeGroups = <String, List<AuditEntry>>{};
        for (final entry in entries) {
          employeeGroups.putIfAbsent(entry.userId, () => []).add(entry);
        }
        for (final empId in employeeGroups.keys) {
          final empEntries = employeeGroups[empId]!;
          final empName = empEntries.first.userDisplayName;
          final empDept = empEntries.first.userDepartment;
          final verifiedCount =
              empEntries.where((e) => e.status == 'verified').length;
          final totalScore = empEntries
              .where((e) => e.score != null)
              .fold(0.0, (acc, e) => acc + e.score!);
          final avgScore = verifiedCount > 0 ? totalScore / verifiedCount : 0.0;

          stats['byEmployee'][empName] = {
            'total': empEntries.length,
            'created': empEntries.where((e) => e.status == 'created').length,
            'approved': empEntries.where((e) => e.status == 'approved').length,
            'pending': empEntries.where((e) => e.status == 'pending').length,
            'verified': verifiedCount,
            'rejected': empEntries.where((e) => e.status == 'rejected').length,
            'department': empDept,
            'averageScore': avgScore,
            'userId': empId,
          };
        }

        stats['recentActivity'] = entries
            .take(10)
            .map(
              (entry) => {
                'goalTitle': entry.goalTitle,
                'employeeName': entry.userDisplayName,
                'department': entry.userDepartment,
                'status': entry.status,
                'submittedDate': entry.submittedDate.toIso8601String(),
                'score': entry.score,
              },
            )
            .toList();

        final employeePerformance = <String, Map<String, dynamic>>{};
        for (final empId in employeeGroups.keys) {
          final empEntries = employeeGroups[empId]!;
          final verifiedEntries =
              empEntries.where((e) => e.status == 'verified').toList();
          final totalScore = verifiedEntries
              .where((e) => e.score != null)
              .fold(0.0, (acc, e) => acc + e.score!);
          final avgScore =
              verifiedEntries.isNotEmpty && verifiedEntries.any((e) => e.score != null)
                  ? totalScore /
                      verifiedEntries.where((e) => e.score != null).length
                  : 0.0;

          employeePerformance[empId] = {
            'name': empEntries.first.userDisplayName,
            'department': empEntries.first.userDepartment,
            'verifiedGoals': verifiedEntries.length,
            'averageScore': avgScore,
            'totalScore': totalScore,
            'userId': empId,
          };
        }

        final sortedPerformers = employeePerformance.values.toList()
          ..sort((a, b) {
            final goalComparison =
                (b['verifiedGoals'] as int).compareTo(a['verifiedGoals'] as int);
            if (goalComparison != 0) return goalComparison;
            return (b['averageScore'] as double).compareTo(a['averageScore'] as double);
          });

        stats['topPerformers'] = sortedPerformers.take(10).toList();
        yield stats;
      } catch (e) {
        developer.log('Error processing audit stats: $e');
        yield emptyStats;
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }
}
