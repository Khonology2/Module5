import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';

import 'package:pdh/models/audit_entry.dart';
import 'package:pdh/models/repository_goal.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/utils/backend_polling_stream.dart';

class RepositoryService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final BackendAuthService _backend = BackendAuthService.instance;

  static Future<void> addVerifiedGoalToRepository(AuditEntry entry) async {
    try {
      final userId = entry.userId.isNotEmpty
          ? entry.userId
          : (_auth.currentUser?.uid ?? '');
      if (userId.isEmpty) {
        throw Exception('No userId available for repository write');
      }

      await _backend.upsertRepository(userId, {
        'id': entry.goalId,
        'goalId': entry.goalId,
        'goalTitle': entry.goalTitle,
        'goalDescription': null,
        'completedDate': entry.completedDate.toIso8601String(),
        'verifiedDate': DateTime.now().toIso8601String(),
        'managerAcknowledgedBy': entry.acknowledgedBy,
        'score': entry.score,
        'comments': entry.comments,
        'evidence': entry.evidence,
        'userId': userId,
        'userDisplayName': entry.userDisplayName,
        'userDepartment': entry.userDepartment,
      });

      developer.log(
        'Repository goal stored for user $userId, goal ${entry.goalId}',
      );
    } catch (e) {
      developer.log('Error adding verified goal to repository: $e');
      rethrow;
    }
  }

  static Stream<List<RepositoryGoal>> getRepositoryGoalsStream(String userId) {
    if (userId.isEmpty) {
      return Stream.value([]);
    }

    return backendPollingListStream<RepositoryGoal>(
      fetch: () => _backend.getRepositories(userId),
      mapper: RepositoryGoal.fromMap,
    ).map((goals) {
      goals.sort((a, b) {
        final ad =
            a.verifiedDate ??
            a.completedDate ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bd =
            b.verifiedDate ??
            b.completedDate ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      return goals;
    });
  }

  static Stream<List<RepositoryGoal>> getAllRepositoryGoalsStream({
    String? department,
  }) {
    return backendPollingListStream<RepositoryGoal>(
      fetch: () => _backend.getAllRepositories(),
      mapper: RepositoryGoal.fromMap,
    ).map((goals) {
      final filtered = goals.where((g) {
        if (department == null || department.isEmpty) return true;
        return g.userDepartment == department;
      }).toList()
        ..sort((a, b) {
          final ad =
              a.verifiedDate ??
              a.completedDate ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bd =
              b.verifiedDate ??
              b.completedDate ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
      return filtered;
    });
  }

  static Stream<List<RepositoryGoal>> queryRepositoryGoals(
    String userId, {
    String? search,
    String? dateFilter,
    double? minScore,
  }) {
    final base = getRepositoryGoalsStream(userId);
    return base.map((goals) {
      Iterable<RepositoryGoal> filtered = goals;

      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        filtered = filtered.where(
          (g) =>
              g.goalTitle.toLowerCase().contains(q) ||
              g.evidence.any((e) => e.toLowerCase().contains(q)),
        );
      }

      if (dateFilter != null && dateFilter.isNotEmpty) {
        filtered = filtered.where((g) {
          final d = g.completedDate;
          if (d == null) return false;
          final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
          return key == dateFilter;
        });
      }

      if (minScore != null) {
        filtered = filtered.where((g) => (g.score ?? 0) >= minScore);
      }

      return filtered.toList()..sort((a, b) {
        final ad =
            a.verifiedDate ??
            a.completedDate ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bd =
            b.verifiedDate ??
            b.completedDate ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    });
  }

  static Future<void> deleteRepositoryGoal(String userId, String goalId) async {
    try {
      await _backend.deleteRepository(userId, goalId);
      developer.log('Deleted repository goal $goalId for user $userId');
    } catch (e) {
      developer.log('Error deleting repository goal: $e');
      rethrow;
    }
  }

  static Future<void> backfillVerifiedEntriesForUser(String userId) async {
    try {
      final verifiedEntries = await _backend.getAuditEntries(
        userId: userId,
        status: 'verified',
        limit: 500,
      );

      for (final item in verifiedEntries) {
        try {
          final entry = AuditEntry.fromMap(item);
          await addVerifiedGoalToRepository(entry);
        } catch (e) {
          developer.log('Error backfilling entry ${item['id']}: $e');
        }
      }
      developer.log(
        'Backfilled ${verifiedEntries.length} verified entries for user $userId',
      );
    } catch (e) {
      developer.log('Error backfilling verified entries: $e');
    }
  }

  static Future<void> backfillVerifiedEntriesForDepartment(
    String department,
  ) async {
    try {
      final verifiedEntries = await _backend.getAuditEntries(
        department: department,
        status: 'verified',
        limit: 500,
      );

      for (final item in verifiedEntries) {
        try {
          final entry = AuditEntry.fromMap(item);
          await addVerifiedGoalToRepository(entry);
        } catch (e) {
          developer.log('Error backfilling entry ${item['id']}: $e');
        }
      }
      developer.log(
        'Backfilled ${verifiedEntries.length} verified entries for department $department',
      );
    } catch (e) {
      developer.log('Error backfilling verified entries for department: $e');
    }
  }
}
