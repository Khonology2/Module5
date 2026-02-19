import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

/// Unified Milestone Audit Service - tracks milestones using same system as goals
class UnifiedMilestoneAudit {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Log milestone creation (same pattern as AuditLogger.logAuditAction)
  static Future<void> logMilestoneCreated({
    required String goalId,
    required String milestoneId,
    required String milestoneTitle,
    required String goalTitle,
    String? userId,
  }) async {
    try {
      final user = _auth.currentUser;
      final event = {
        'action': 'milestone_created',
        'goalId': goalId,
        'milestoneId': milestoneId,
        'userId': userId ?? user?.uid ?? 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'description':
            'Milestone created: $milestoneTitle for goal: $goalTitle',
        'metadata': {
          'milestoneTitle': milestoneTitle,
          'goalTitle': goalTitle,
          'milestoneId': milestoneId,
        },
      };

      await _firestore.collection('audit_entries').add(event);
      developer.log(
        'Milestone created logged: $milestoneTitle for goal $goalId',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error logging milestone creation: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log milestone update (same pattern as AuditLogger.logAuditAction)
  static Future<void> logMilestoneUpdated({
    required String goalId,
    required String milestoneId,
    required String milestoneTitle,
    required String goalTitle,
    required Map<String, dynamic> changes,
  }) async {
    try {
      final user = _auth.currentUser;
      final event = {
        'action': 'milestone_updated',
        'goalId': goalId,
        'milestoneId': milestoneId,
        'userId': user?.uid ?? 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'description':
            'Milestone updated: $milestoneTitle for goal: $goalTitle',
        'metadata': {
          'milestoneTitle': milestoneTitle,
          'goalTitle': goalTitle,
          'milestoneId': milestoneId,
          'changes': changes,
        },
      };

      await _firestore.collection('audit_entries').add(event);
      developer.log(
        'Milestone updated logged: $milestoneTitle for goal $goalId',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error logging milestone update: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log milestone status change (same pattern as AuditLogger.logAuditAction)
  static Future<void> logMilestoneStatusChanged({
    required String goalId,
    required String milestoneId,
    required String milestoneTitle,
    required String goalTitle,
    required String oldStatus,
    required String newStatus,
  }) async {
    try {
      final user = _auth.currentUser;
      final event = {
        'action': 'milestone_status_changed',
        'goalId': goalId,
        'milestoneId': milestoneId,
        'userId': user?.uid ?? 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'description':
            'Milestone status changed: $milestoneTitle from $oldStatus to $newStatus',
        'metadata': {
          'milestoneTitle': milestoneTitle,
          'goalTitle': goalTitle,
          'milestoneId': milestoneId,
          'oldStatus': oldStatus,
          'newStatus': newStatus,
        },
      };

      await _firestore.collection('audit_entries').add(event);
      developer.log(
        'Milestone status changed logged: $milestoneTitle from $oldStatus to $newStatus',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error logging milestone status change: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get milestone audit entries for a goal (same pattern as existing goal audit)
  static Stream<List<Map<String, dynamic>>> getMilestoneAuditStream(
    String goalId,
  ) {
    try {
      return _firestore
          .collection('audit_entries')
          .where('goalId', isEqualTo: goalId)
          .where(
            'action',
            whereIn: [
              'milestone_created',
              'milestone_updated',
              'milestone_status_changed',
            ],
          )
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              final data = doc.data();
              return {'id': doc.id, ...data};
            }).toList();
          });
    } catch (e) {
      developer.log('Error getting milestone audit stream: $e');
      return Stream.value([]);
    }
  }

  /// Get all milestone audit entries (for managers)
  static Stream<List<Map<String, dynamic>>> getAllMilestoneAuditStream() {
    try {
      return _firestore
          .collection('audit_entries')
          .where(
            'action',
            whereIn: [
              'milestone_created',
              'milestone_updated',
              'milestone_status_changed',
            ],
          )
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              final data = doc.data();
              return {'id': doc.id, ...data};
            }).toList();
          });
    } catch (e) {
      developer.log('Error getting all milestone audit stream: $e');
      return Stream.value([]);
    }
  }

  /// Backfill existing milestones using unified audit system
  static Future<void> backfillExistingMilestones() async {
    if (kDebugMode) {
      print('Starting unified milestone audit backfill...');
    }

    try {
      final goalsSnapshot = await _firestore.collection('goals').get();

      int totalMilestones = 0;
      int auditEntriesCreated = 0;

      for (final goalDoc in goalsSnapshot.docs) {
        final goalData = goalDoc.data();
        final goalId = goalDoc.id;
        final goalTitle = goalData['title'] ?? 'Unknown Goal';

        // Get all milestones for this goal
        final milestonesSnapshot = await _firestore
            .collection('goals')
            .doc(goalId)
            .collection('milestones')
            .get();

        for (final milestoneDoc in milestonesSnapshot.docs) {
          totalMilestones++;
          final milestoneData = milestoneDoc.data();
          final milestoneId = milestoneDoc.id;
          final milestoneTitle = milestoneData['title'] ?? 'Unknown Milestone';

          // Check if audit entry already exists for this milestone
          final existingAuditSnapshot = await _firestore
              .collection('audit_entries')
              .where('milestoneId', isEqualTo: milestoneId)
              .where('action', isEqualTo: 'milestone_created')
              .limit(1)
              .get();

          if (existingAuditSnapshot.docs.isEmpty) {
            // Create audit entry using unified system
            await logMilestoneCreated(
              goalId: goalId,
              milestoneId: milestoneId,
              milestoneTitle: milestoneTitle,
              goalTitle: goalTitle,
              userId: milestoneData['createdBy'] ?? 'unknown',
            );

            auditEntriesCreated++;

            if (kDebugMode) {
              print(
                'Created unified audit entry for milestone: $milestoneTitle',
              );
            }
          }
        }
      }

      if (kDebugMode) {
        print('Unified backfill completed!');
        print('Total milestones processed: $totalMilestones');
        print('Audit entries created: $auditEntriesCreated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during unified backfill: $e');
      }
      rethrow;
    }
  }
}
