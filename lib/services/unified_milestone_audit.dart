import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'dart:async';

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

  /// Get milestone audit entries for a goal (simplified to prevent assertions)
  static Stream<List<Map<String, dynamic>>> getMilestoneAuditStream(
    String goalId,
  ) async* {
    try {
      // Simplified query to prevent Firestore assertions
      final stream = _firestore
          .collection('audit_entries')
          .where('goalId', isEqualTo: goalId)
          .orderBy('timestamp', descending: true)
          .limit(20) // Reduced limit to prevent overwhelming
          .snapshots();

      await for (final snapshot in stream) {
        try {
          final audits = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .where((audit) {
                // Client-side filtering for milestone actions
                final action = audit['action'] as String? ?? '';
                return [
                  'milestone_created',
                  'milestone_updated',
                  'milestone_status_changed',
                ].contains(action);
              })
              .toList();
          yield audits;
        } catch (e, stackTrace) {
          developer.log(
            'Error processing audit snapshot: $e',
            error: e,
            stackTrace: stackTrace,
          );
          yield []; // Fallback to empty list on error
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in getMilestoneAuditStream: $e',
        error: e,
        stackTrace: stackTrace,
      );
      yield []; // Fallback to empty list
    }
  }

  /// Get all milestone audit entries (for current user's goals only)
  static Stream<List<Map<String, dynamic>>>
  getAllMilestoneAuditStream() async* {
    try {
      // Simplified query to prevent Firestore assertions
      final stream = _firestore
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
          .limit(20) // Reduced limit to prevent overwhelming
          .snapshots();

      await for (final snapshot in stream) {
        try {
          final audits = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .where((audit) {
                // Simple client-side filtering
                final action = audit['action'] as String? ?? '';
                final userId = audit['userId'] as String? ?? '';
                final currentUserId = _auth.currentUser?.uid;

                return currentUserId != null &&
                    userId == currentUserId &&
                    [
                      'milestone_created',
                      'milestone_updated',
                      'milestone_status_changed',
                    ].contains(action);
              })
              .toList();
          yield audits;
        } catch (e, stackTrace) {
          developer.log(
            'Error processing milestone audit snapshot: $e',
            error: e,
            stackTrace: stackTrace,
          );
          yield []; // Fallback to empty list on error
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in getAllMilestoneAuditStream: $e',
        error: e,
        stackTrace: stackTrace,
      );
      yield []; // Fallback to empty list
    }
  }

  /// Backfill existing milestones using unified audit system
  static Future<void> backfillExistingMilestones() async {
    if (kDebugMode) {
      print('Starting unified milestone audit backfill...');
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('User not authenticated for backfill');
        }
        return;
      }

      // Only get user's own goals to prevent permission errors
      final goalsSnapshot = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: user.uid)
          .get();

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
