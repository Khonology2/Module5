import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'dart:async';

/// Unified Milestone Audit Service - tracks milestones using same system as goals
class UnifiedMilestoneAudit {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get user details for richer audit trail
  static Future<Map<String, dynamic>> _getUserDetails(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return {
          'displayName': userDoc.data()?['displayName'] ?? 'Unknown User',
          'role': userDoc.data()?['role'] ?? 'employee',
          'department': userDoc.data()?['department'] ?? 'unknown',
        };
      }
    } catch (e) {
      developer.log('Error getting user details: $e');
    }
    return {
      'displayName': 'Unknown User',
      'role': 'employee',
      'department': 'unknown',
    };
  }

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
  ) async* {
    try {
      // Add delay to prevent rapid-fire queries that cause assertions
      await Future.delayed(const Duration(milliseconds: 100));

      try {
        // Working solution - simple query pattern
        final stream = _firestore
            .collection('audit_entries')
            .where('goalId', isEqualTo: goalId)
            .orderBy('timestamp', descending: true)
            .limit(50)
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
                    'milestone_pending_review',
                    'milestone_acknowledged',
                    'milestone_rejected',
                    'milestone_dismissed',
                  ].contains(action);
                })
                .toList();
            yield audits;
          } catch (e) {
            developer.log('Error processing audit snapshot: $e');
            yield []; // Fallback to empty list
          }
        }
      } catch (e) {
        // If collection doesn't exist or permission error, return empty for consistent UI
        developer.log('Audit entries collection not accessible for goal: $e');
        yield [];
      }
    } catch (e) {
      developer.log('Error in getMilestoneAuditStream: $e');
      yield []; // Fallback to empty list
    }
  }

  /// Get all milestone audit entries (for current user's goals only)
  static Stream<List<Map<String, dynamic>>>
  getAllMilestoneAuditStream() async* {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        yield [];
        return;
      }

      // Add delay to prevent rapid-fire queries that cause assertions
      await Future.delayed(const Duration(milliseconds: 100));

      try {
        if (kDebugMode) {
          print('DEBUG: Getting audit entries for user: ${user.uid}');
        }

        // RESTORED: Use orderBy now that indexes will be created manually
        final stream = _firestore
            .collection('audit_entries')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots();

        await for (final snapshot in stream) {
          try {
            if (kDebugMode) {
              print(
                'DEBUG: Got ${snapshot.docs.length} audit entries from Firestore',
              );
            }

            final audits = snapshot.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .where((audit) {
                  // Client-side filtering for milestone actions
                  final action = audit['action'] as String? ?? '';
                  final isMilestoneAction = [
                    'milestone_created',
                    'milestone_updated',
                    'milestone_status_changed',
                    'milestone_pending_review',
                    'milestone_acknowledged',
                    'milestone_rejected',
                    'milestone_dismissed',
                  ].contains(action);

                  if (kDebugMode && isMilestoneAction) {
                    developer.log(
                      'DEBUG: Found milestone audit entry: ${audit['action']} for ${audit['goalId']}',
                    );
                  }

                  return isMilestoneAction;
                })
                .toList();

            if (kDebugMode) {
              print(
                'DEBUG: Filtered to ${audits.length} milestone audit entries',
              );
            }

            yield audits;
          } catch (e) {
            developer.log('Error processing audit snapshot: $e');
            yield []; // Fallback to empty list
          }
        }
      } catch (e) {
        // If collection doesn't exist or permission error, return mock data for consistent UI
        developer.log('Audit entries collection not accessible: $e');
        if (kDebugMode) {
          print('DEBUG: Audit entries collection not accessible: $e');
        }
        yield [];
      }
    } catch (e) {
      developer.log('Error in getAllMilestoneAuditStream: $e');
      yield []; // Fallback to empty list
    }
  }

  /// Log milestone status change to pending review
  static Future<void> logMilestonePendingReview({
    required String goalId,
    required String milestoneId,
    required String milestoneTitle,
    required String goalTitle,
  }) async {
    try {
      final user = _auth.currentUser;
      final event = {
        'action': 'milestone_pending_review',
        'goalId': goalId,
        'milestoneId': milestoneId,
        'userId': user?.uid ?? 'system',
        'userName': user?.displayName ?? 'System',
        'userRole': 'system',
        'userDepartment': 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'milestoneTitle': milestoneTitle,
        'goalTitle': goalTitle,
        'description':
            'Milestone submitted for review: $milestoneTitle for goal: $goalTitle',
        'metadata': {
          'milestoneTitle': milestoneTitle,
          'goalTitle': goalTitle,
          'milestoneId': milestoneId,
        },
      };

      // Fetch user details for richer audit trail
      if (user != null) {
        final userDetails = await _getUserDetails(user.uid);
        event['userName'] = userDetails['displayName'];
        event['userRole'] = userDetails['role'];
        event['userDepartment'] = userDetails['department'];
      }
      await _firestore.collection('audit_entries').add(event);
      developer.log(
        'Milestone pending review logged: $milestoneId for goal $goalId',
        name: 'UnifiedMilestoneAudit',
      );
    } catch (e) {
      developer.log(
        'Failed to log milestone pending review audit: $e',
        name: 'UnifiedMilestoneAudit',
      );
    }
  }

  /// Log milestone acknowledgement
  static Future<void> logMilestoneAcknowledged({
    required String goalId,
    required String milestoneId,
    required String milestoneTitle,
    required String goalTitle,
    required String acknowledgedBy,
    required String acknowledgedByName,
  }) async {
    try {
      final user = _auth.currentUser;
      final event = {
        'action': 'milestone_acknowledged',
        'goalId': goalId,
        'milestoneId': milestoneId,
        'userId': user?.uid ?? 'system',
        'userName': user?.displayName ?? 'System',
        'userRole': 'system',
        'userDepartment': 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'milestoneTitle': milestoneTitle,
        'goalTitle': goalTitle,
        'acknowledgedBy': acknowledgedBy,
        'acknowledgedByName': acknowledgedByName,
        'description':
            'Milestone acknowledged: $milestoneTitle for goal: $goalTitle',
        'metadata': {
          'milestoneTitle': milestoneTitle,
          'goalTitle': goalTitle,
          'milestoneId': milestoneId,
          'acknowledgedBy': acknowledgedBy,
          'acknowledgedByName': acknowledgedByName,
        },
      };

      // Fetch user details for richer audit trail
      if (user != null) {
        final userDetails = await _getUserDetails(user.uid);
        event['userName'] = userDetails['displayName'];
        event['userRole'] = userDetails['role'];
        event['userDepartment'] = userDetails['department'];
      }
      await _firestore.collection('audit_entries').add(event);
      developer.log(
        'Milestone acknowledgement logged: $milestoneId for goal $goalId',
        name: 'UnifiedMilestoneAudit',
      );
    } catch (e) {
      developer.log(
        'Failed to log milestone acknowledgement audit: $e',
        name: 'UnifiedMilestoneAudit',
      );
    }
  }

  /// Log milestone rejection
  static Future<void> logMilestoneRejected({
    required String goalId,
    required String milestoneId,
    required String milestoneTitle,
    required String goalTitle,
    required String rejectedBy,
    required String rejectedByName,
    required String rejectionReason,
  }) async {
    try {
      final user = _auth.currentUser;
      final event = {
        'action': 'milestone_rejected',
        'goalId': goalId,
        'milestoneId': milestoneId,
        'userId': user?.uid ?? 'system',
        'userName': user?.displayName ?? 'System',
        'userRole': 'system',
        'userDepartment': 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'milestoneTitle': milestoneTitle,
        'goalTitle': goalTitle,
        'rejectedBy': rejectedBy,
        'rejectedByName': rejectedByName,
        'rejectionReason': rejectionReason,
        'description':
            'Milestone rejected: $milestoneTitle for goal: $goalTitle',
        'metadata': {
          'milestoneTitle': milestoneTitle,
          'goalTitle': goalTitle,
          'milestoneId': milestoneId,
          'rejectedBy': rejectedBy,
          'rejectedByName': rejectedByName,
          'rejectionReason': rejectionReason,
        },
      };

      // Fetch user details for richer audit trail
      if (user != null) {
        final userDetails = await _getUserDetails(user.uid);
        event['userName'] = userDetails['displayName'];
        event['userRole'] = userDetails['role'];
        event['userDepartment'] = userDetails['department'];
      }
      await _firestore.collection('audit_entries').add(event);
      developer.log(
        'Milestone rejection logged: $milestoneId for goal $goalId',
        name: 'UnifiedMilestoneAudit',
      );
    } catch (e) {
      developer.log(
        'Failed to log milestone rejection audit: $e',
        name: 'UnifiedMilestoneAudit',
      );
    }
  }

  /// Get milestone audit status counts for current user
  static Future<Map<String, int>> getMilestoneAuditCounts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      // Get all audit entries for user's goals
      final goalsSnapshot = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: user.uid)
          .get();

      final goalIds = goalsSnapshot.docs.map((doc) => doc.id).toList();

      if (goalIds.isEmpty) return {};

      // Get audit entries for user's goals
      final auditSnapshot = await _firestore
          .collection('audit_entries')
          .where('goalId', whereIn: goalIds)
          .get();

      final counts = <String, int>{
        'milestone_created': 0,
        'milestone_updated': 0,
        'milestone_pending_review': 0,
        'milestone_acknowledged': 0,
        'milestone_rejected': 0,
        'milestone_dismissed': 0,
      };

      for (final doc in auditSnapshot.docs) {
        final action = doc.data()['action'] as String? ?? '';
        if (counts.containsKey(action)) {
          counts[action] = (counts[action] ?? 0) + 1;
        }
      }

      return counts;
    } catch (e) {
      developer.log('Error getting milestone audit counts: $e');
      return {};
    }
  }

  /// Get milestone audit status counts as stream for real-time updates
  static Stream<Map<String, int>> getMilestoneAuditCountsStream() async* {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        yield {};
        return;
      }

      // Get user's goals first
      final goalsSnapshot = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: user.uid)
          .get();

      final goalIds = goalsSnapshot.docs.map((doc) => doc.id).toList();

      if (goalIds.isEmpty) {
        yield {};
        return;
      }

      // Stream audit entries for user's goals
      final stream = _firestore
          .collection('audit_entries')
          .where('goalId', whereIn: goalIds)
          .snapshots();

      await for (final snapshot in stream) {
        final counts = <String, int>{
          'milestone_created': 0,
          'milestone_updated': 0,
          'milestone_pending_review': 0,
          'milestone_acknowledged': 0,
          'milestone_rejected': 0,
          'milestone_dismissed': 0,
        };

        for (final doc in snapshot.docs) {
          final action = doc.data()['action'] as String? ?? '';
          if (counts.containsKey(action)) {
            counts[action] = (counts[action] ?? 0) + 1;
          }
        }

        yield counts;
      }
    } catch (e) {
      developer.log('Error in milestone audit counts stream: $e');
      yield {};
    }
  }

  /// Reconstruct historical phases for existing milestones based on current status
  static Future<void> _reconstructHistoricalPhases({
    required String goalId,
    required String goalTitle,
    required String milestoneId,
    required String milestoneTitle,
    required Map<String, dynamic> milestoneData,
  }) async {
    try {
      final status = milestoneData['status'] as String? ?? 'notStarted';
      final completedAt = milestoneData['completedAt'] as Timestamp?;
      final createdBy = milestoneData['createdBy'] as String? ?? 'unknown';

      // Simulate historical phases based on current milestone status
      switch (status) {
        case 'completedAcknowledged':
          // Milestone went through: created → pending review → acknowledged → completed
          await _createHistoricalAuditEntry(
            goalId: goalId,
            goalTitle: goalTitle,
            milestoneId: milestoneId,
            milestoneTitle: milestoneTitle,
            action: 'milestone_pending_review',
            timestamp: completedAt ?? Timestamp.now(),
            userId: createdBy,
          );

          await _createHistoricalAuditEntry(
            goalId: goalId,
            goalTitle: goalTitle,
            milestoneId: milestoneId,
            milestoneTitle: milestoneTitle,
            action: 'milestone_acknowledged',
            timestamp: completedAt ?? Timestamp.now(),
            userId: 'system',
            acknowledgedBy: 'system',
            acknowledgedByName: 'System Backfill',
          );
          break;

        case 'completed':
          // Milestone went through: created → pending review → completed
          await _createHistoricalAuditEntry(
            goalId: goalId,
            goalTitle: goalTitle,
            milestoneId: milestoneId,
            milestoneTitle: milestoneTitle,
            action: 'milestone_pending_review',
            timestamp: completedAt ?? Timestamp.now(),
            userId: createdBy,
          );
          break;

        case 'pendingManagerReview':
          // Milestone went through: created → pending review
          // No additional phases needed - already at pending review
          break;

        case 'blocked':
          // Milestone was blocked after creation
          await _createHistoricalAuditEntry(
            goalId: goalId,
            goalTitle: goalTitle,
            milestoneId: milestoneId,
            milestoneTitle: milestoneTitle,
            action: 'milestone_rejected',
            timestamp: completedAt ?? Timestamp.now(),
            userId: 'system',
            rejectedBy: 'system',
            rejectedByName: 'System Backfill',
            rejectionReason: 'Milestone was blocked',
          );
          break;
      }

      if (kDebugMode) {
        print(
          'Reconstructed historical phases for milestone: $milestoneTitle (status: $status)',
        );
      }
    } catch (e) {
      developer.log('Error reconstructing historical phases: $e');
    }
  }

  /// Create historical audit entry with custom timestamp
  static Future<void> _createHistoricalAuditEntry({
    required String goalId,
    required String goalTitle,
    required String milestoneId,
    required String milestoneTitle,
    required String action,
    required Timestamp timestamp,
    required String userId,
    String? acknowledgedBy,
    String? acknowledgedByName,
    String? rejectedBy,
    String? rejectedByName,
    String? rejectionReason,
  }) async {
    try {
      final user = _auth.currentUser;
      final event = {
        'action': action,
        'goalId': goalId,
        'milestoneId': milestoneId,
        'userId': userId,
        'userName': user?.displayName ?? 'System',
        'userRole': 'system',
        'userDepartment': 'system',
        'timestamp': timestamp,
        'milestoneTitle': milestoneTitle,
        'goalTitle': goalTitle,
        'description': _getHistoricalDescription(
          action,
          milestoneTitle,
          goalTitle,
        ),
        'metadata': {
          'milestoneTitle': milestoneTitle,
          'goalTitle': goalTitle,
          'milestoneId': milestoneId,
          'acknowledgedBy': acknowledgedBy ?? '',
          'acknowledgedByName': acknowledgedByName ?? '',
          'rejectedBy': rejectedBy ?? '',
          'rejectedByName': rejectedByName ?? '',
          'rejectionReason': rejectionReason ?? '',
          'isHistorical': true,
        },
      };

      await _firestore.collection('audit_entries').add(event);
      developer.log(
        'Historical audit entry created: $action for $milestoneTitle',
        name: 'UnifiedMilestoneAudit',
      );
    } catch (e) {
      developer.log('Failed to create historical audit entry: $e');
    }
  }

  /// Get description for historical audit entries
  static String _getHistoricalDescription(
    String action,
    String milestoneTitle,
    String goalTitle,
  ) {
    switch (action) {
      case 'milestone_pending_review':
        return 'Milestone submitted for review (historical): $milestoneTitle for goal: $goalTitle';
      case 'milestone_acknowledged':
        return 'Milestone acknowledged (historical): $milestoneTitle for goal: $goalTitle';
      case 'milestone_rejected':
        return 'Milestone rejected (historical): $milestoneTitle for goal: $goalTitle';
      default:
        return 'Historical milestone action: $action for $milestoneTitle';
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

            // ENHANCED: Reconstruct historical phases based on current status
            await _reconstructHistoricalPhases(
              goalId: goalId,
              goalTitle: goalTitle,
              milestoneId: milestoneId,
              milestoneTitle: milestoneTitle,
              milestoneData: milestoneData,
            );
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
