import 'dart:developer' as developer;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:pdh/models/audit_entry.dart';
import 'package:pdh/models/repository_goal.dart';
import 'package:pdh/models/approved_goal_audit.dart';

class RepositoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _auditVerifiedSubscription;
  static bool _syncActive = false;

  static CollectionReference<Map<String, dynamic>> _userRepositoryCollection(
    String userId,
  ) {
    return _firestore
        .collection('repositories')
        .doc(userId)
        .collection('completedGoals');
  }

  // Triggered when an audit entry transitions to verified
  static Future<void> addVerifiedGoalToRepository(AuditEntry entry) async {
    try {
      final userId = entry.userId.isNotEmpty
          ? entry.userId
          : (_auth.currentUser?.uid ?? '');
      if (userId.isEmpty) {
        throw Exception('No userId available for repository write');
      }

      final repoGoal = RepositoryGoal(
        id: entry.goalId,
        goalId: entry.goalId,
        goalTitle: entry.goalTitle,
        goalDescription: null,
        completedDate: entry.completedDate,
        verifiedDate: DateTime.now(),
        managerAcknowledgedBy: entry.acknowledgedBy,
        score: entry.score,
        comments: entry.comments,
        evidence: entry.evidence,
        userId: userId,
        userDisplayName: entry.userDisplayName,
        userDepartment: entry.userDepartment,
      );

      await _userRepositoryCollection(
        userId,
      ).doc(entry.goalId).set(repoGoal.toFirestore(), SetOptions(merge: true));

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

    return _userRepositoryCollection(userId)
        .orderBy('verifiedDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RepositoryGoal.fromFirestore(doc))
              .toList(),
        )
        .handleError((error) {
          developer.log('Error getting repository goals: $error');
          return <RepositoryGoal>[];
        });
  }

  // Manager: stream all repository goals across users via collectionGroup
  static Stream<List<RepositoryGoal>> getAllRepositoryGoalsStream({String? department}) {
    try {
      final base = _firestore
          .collectionGroup('completedGoals')
          .orderBy('verifiedDate', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((d) => RepositoryGoal.fromFirestore(d))
              .where((g) {
                if (department == null || department.isEmpty) return true;
                return g.userDepartment == department;
              })
              .toList());
      return base.handleError((e) {
        developer.log('Error streaming all repository goals: $e');
        return <RepositoryGoal>[];
      });
    } catch (e) {
      developer.log('Error building all repository goals stream: $e');
      return Stream.value([]);
    }
  }

  static Stream<List<RepositoryGoal>> queryRepositoryGoals(
    String userId, {
    String? search,
    String? dateFilter, // format: 'YYYY-MM' for month filter
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
      await _userRepositoryCollection(userId).doc(goalId).delete();
      developer.log('Deleted repository goal $goalId for user $userId');
    } catch (e) {
      developer.log('Error deleting repository goal: $e');
      rethrow;
    }
  }

  // Start sync: listen to audit_entries where status == 'verified'
  static void startAutoSync() {
    if (_syncActive) {
      developer.log('Repository auto-sync already active');
      return;
    }
    _auditVerifiedSubscription?.cancel();
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      developer.log('Repository auto-sync: no current user');
      return;
    }

    // Only listen to verified entries for the CURRENT USER to avoid permission errors and reduce load
    _auditVerifiedSubscription = _firestore
        .collection('audit_entries')
        .where('status', isEqualTo: 'verified')
        .where('userId', isEqualTo: currentUser.uid)
        .snapshots()
        .listen(
          (snapshot) async {
            for (final change in snapshot.docChanges) {
              final doc = change.doc;
              final data = doc.data();
              if (data == null) continue;
              final userId = (data['userId'] as String?) ?? '';
              final goalId = (data['goalId'] as String?) ?? doc.id;
              if (userId.isEmpty || goalId.isEmpty) continue;

              if (change.type == DocumentChangeType.added ||
                  change.type == DocumentChangeType.modified) {
                // Verified-only query: always add/update
                final entry = AuditEntry.fromFirestore(doc);
                await addVerifiedGoalToRepository(entry);
              } else if (change.type == DocumentChangeType.removed) {
                // Remove from repository on deletion or leaving query (status changed)
                try {
                  await deleteRepositoryGoal(userId, goalId);
                } catch (_) {}
              }
            }
          },
          onError: (e, st) {
            developer.log('Auto-sync listener error: $e');
          },
        );
    developer.log('Repository auto-sync started');
    _syncActive = true;
  }

  static Future<void> stopAutoSync() async {
    await _auditVerifiedSubscription?.cancel();
    _auditVerifiedSubscription = null;
    developer.log('Repository auto-sync stopped');
    _syncActive = false;
  }

  // Backfill existing verified entries to repository (for employees)
  // This ensures previously verified entries are synced even if auto-sync missed them
  static Future<void> backfillVerifiedEntriesForUser(String userId) async {
    try {
      final verifiedEntries = await _firestore
          .collection('audit_entries')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'verified')
          .get();

      for (final doc in verifiedEntries.docs) {
        try {
          final entry = AuditEntry.fromFirestore(doc);
          await addVerifiedGoalToRepository(entry);
        } catch (e) {
          developer.log('Error backfilling entry ${doc.id}: $e');
        }
      }
      developer.log('Backfilled ${verifiedEntries.docs.length} verified entries for user $userId');
    } catch (e) {
      developer.log('Error backfilling verified entries: $e');
    }
  }

  // Backfill all verified entries for manager's department
  static Future<void> backfillVerifiedEntriesForDepartment(String department) async {
    try {
      final verifiedEntries = await _firestore
          .collection('audit_entries')
          .where('userDepartment', isEqualTo: department)
          .where('status', isEqualTo: 'verified')
          .limit(500) // Limit to prevent timeout
          .get();

      for (final doc in verifiedEntries.docs) {
        try {
          final entry = AuditEntry.fromFirestore(doc);
          await addVerifiedGoalToRepository(entry);
        } catch (e) {
          developer.log('Error backfilling entry ${doc.id}: $e');
        }
      }
      developer.log('Backfilled ${verifiedEntries.docs.length} verified entries for department $department');
    } catch (e) {
      developer.log('Error backfilling verified entries for department: $e');
    }
  }

  // Add approved goal audit to repository for offline persistence
  static Future<void> addApprovedGoalAudit(ApprovedGoalAudit audit) async {
    try {
      final userId = _auth.currentUser?.uid ?? '';
      final auditRef = _firestore
          .collection('repositories')
          .doc(userId)
          .collection('approvedGoalsAudit')
          .doc(audit.goalId);
      
      await auditRef.set({
        'goalId': audit.goalId,
        'goalTitle': audit.goalTitle,
        'employeeId': audit.employeeId,
        'employeeName': audit.employeeName,
        'department': audit.department,
        'approvedAt': audit.approvedAt.toIso8601String(),
        'approvedBy': audit.approvedBy,
        'approvedByName': audit.approvedByName,
        'timestamp': audit.timestamp.toIso8601String(),
        'syncedAt': DateTime.now().toIso8601String(),
      });
      
      developer.log('Added approved goal audit to repository: ${audit.goalId}');
    } catch (e) {
      developer.log('Error adding approved goal audit to repository: $e');
    }
  }

  // Sync approved goal audits from repository to Firestore
  static Future<void> syncApprovedGoalAudits() async {
    try {
      final userId = _auth.currentUser?.uid ?? '';
      final localAudits = await _firestore
          .collection('repositories')
          .doc(userId)
          .collection('approvedGoalsAudit')
          .get();
      
      for (final doc in localAudits.docs) {
        final data = doc.data();
        final goalId = data['goalId'] as String;
        
        // Check if already synced
        final existing = await _firestore
            .collection('approved_goals_audit')
            .where('goalId', isEqualTo: goalId)
            .get();
        
        if (existing.docs.isEmpty) {
          // Sync to Firestore
          await _firestore.collection('approved_goals_audit').add({
            'goalId': goalId,
            'goalTitle': data['goalTitle'],
            'employeeId': data['employeeId'],
            'employeeName': data['employeeName'],
            'department': data['department'],
            'approvedAt': Timestamp.fromDate(DateTime.parse(data['approvedAt'])),
            'approvedBy': data['approvedBy'],
            'approvedByName': data['approvedByName'],
            'timestamp': Timestamp.fromDate(DateTime.parse(data['timestamp'])),
          });
          
          developer.log('Synced approved goal audit: $goalId');
        }
      }
    } catch (e) {
      developer.log('Error syncing approved goal audits: $e');
    }
  }
}
