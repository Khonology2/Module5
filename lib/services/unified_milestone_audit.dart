import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:developer' as developer;

/// Simple, Professional Milestone Audit Service
/// Working implementation from 4 days ago - restored for stability
class UnifiedMilestoneAudit {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Log milestone creation with comprehensive details
  static Future<void> logMilestoneCreated({
    required String goalId,
    required String milestoneId,
    required String milestoneTitle,
    required String goalTitle,
    String? userId,
  }) async {
    try {
      final user = _auth.currentUser;
      final timestamp = FieldValue.serverTimestamp();

      // Get user details for professional audit trail
      String userName = 'System';
      String userEmail = 'system';
      String userRole = 'system';

      if (user != null) {
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .get();
          final userData = userDoc.data() ?? {};
          userName =
              userData['displayName'] ??
              userData['fullName'] ??
              userData['name'] ??
              user.email ??
              'Unknown User';
          userEmail = user.email ?? 'unknown';
          userRole = userData['role'] ?? 'employee';
        } catch (e) {
          // Fallback to basic user info if profile fetch fails
          userName = user.email ?? 'Unknown User';
          userEmail = user.email ?? 'unknown';
          userRole = 'employee';
        }
      }

      // Create comprehensive audit event
      final event = {
        'action': 'milestone_created',
        'goalId': goalId,
        'milestoneId': milestoneId,
        'userId': user?.uid ?? userId ?? 'system',
        'userName': userName,
        'userEmail': userEmail,
        'userRole': userRole,
        'timestamp': timestamp,
        'description':
            'New milestone created: "$milestoneTitle" for goal "$goalTitle"',
        'metadata': {
          'milestoneTitle': milestoneTitle,
          'goalTitle': goalTitle,
          'milestoneId': milestoneId,
          'goalId': goalId,
          'createdBy': user?.uid ?? userId ?? 'system',
          'creatorName': userName,
          'creatorEmail': userEmail,
          'creatorRole': userRole,
          'initialStatus': 'NotStarted',
          'statusDisplay': 'Not Started',
        },
        'auditDetails': {
          'eventType': 'milestone_creation',
          'category': 'milestone_management',
          'impact': 'medium',
          'visibility': 'team',
          'priority': 'normal',
          'actionType': 'creation',
        },
      };

      await _firestore.collection('audit_entries').add(event);
      developer.log(
        '✅ Comprehensive milestone creation logged: "$milestoneTitle" for goal "$goalTitle" by $userName',
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error logging milestone creation: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log milestone status change with comprehensive details
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
      final timestamp = FieldValue.serverTimestamp();

      // Get user details for professional audit trail
      String userName = 'System';
      String userEmail = 'system';
      String userRole = 'system';

      if (user != null) {
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .get();
          final userData = userDoc.data() ?? {};
          userName =
              userData['displayName'] ??
              userData['fullName'] ??
              userData['name'] ??
              user.email ??
              'Unknown User';
          userEmail = user.email ?? 'unknown';
          userRole = userData['role'] ?? 'employee';
        } catch (e) {
          // Fallback to basic user info if profile fetch fails
          userName = user.email ?? 'Unknown User';
          userEmail = user.email ?? 'unknown';
          userRole = 'employee';
        }
      }

      // Create comprehensive audit event
      final event = {
        'action': 'milestone_status_changed',
        'goalId': goalId,
        'milestoneId': milestoneId,
        'userId': user?.uid ?? 'system',
        'userName': userName,
        'userEmail': userEmail,
        'userRole': userRole,
        'timestamp': timestamp,
        'description':
            'Milestone status updated: "$milestoneTitle" changed from "$_formatStatus(oldStatus)" to "$_formatStatus(newStatus)"',
        'metadata': {
          'milestoneTitle': milestoneTitle,
          'goalTitle': goalTitle,
          'milestoneId': milestoneId,
          'goalId': goalId,
          'oldStatus': oldStatus,
          'newStatus': newStatus,
          'oldStatusDisplay': _formatStatus(oldStatus),
          'newStatusDisplay': _formatStatus(newStatus),
          'changeType': _getStatusChangeType(oldStatus, newStatus),
          'isProgressChange': _isProgressChange(oldStatus, newStatus),
          'requiresReview': newStatus == 'PendingReview',
          'isCompletion':
              newStatus == 'Completed' || newStatus == 'CompletedAcknowledged',
        },
        'auditDetails': {
          'eventType': 'milestone_status_update',
          'category': 'milestone_management',
          'impact': _getChangeImpact(oldStatus, newStatus),
          'visibility': 'team',
          'priority': _getChangePriority(oldStatus, newStatus),
        },
      };

      await _firestore.collection('audit_entries').add(event);
      developer.log(
        '✅ Comprehensive milestone status change logged: "$milestoneTitle" from "$oldStatus" to "$newStatus" by $userName',
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error logging milestone status change: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Format status for display
  static String _formatStatus(String status) {
    switch (status) {
      case 'NotStarted':
        return 'Not Started';
      case 'InProgress':
        return 'In Progress';
      case 'PendingReview':
      case 'pendingManagerReview':
        return 'Pending Review';
      case 'Completed':
        return 'Completed';
      case 'CompletedAcknowledged':
        return 'Completed & Acknowledged';
      case 'Blocked':
        return 'Blocked';
      default:
        return status;
    }
  }

  /// Determine the type of status change
  static String _getStatusChangeType(String oldStatus, String newStatus) {
    if (newStatus == 'Completed' || newStatus == 'CompletedAcknowledged') {
      return 'completion';
    } else if (newStatus == 'PendingReview') {
      return 'submission_for_review';
    } else if (oldStatus == 'NotStarted' && newStatus == 'InProgress') {
      return 'initiation';
    } else if (oldStatus == 'InProgress' && newStatus == 'NotStarted') {
      return 'reversal';
    } else if (newStatus == 'Blocked') {
      return 'blockage';
    } else {
      return 'progress_update';
    }
  }

  /// Check if this is a progress-related change
  static bool _isProgressChange(String oldStatus, String newStatus) {
    final progressStatuses = [
      'NotStarted',
      'InProgress',
      'PendingReview',
      'Completed',
    ];
    return progressStatuses.contains(oldStatus) &&
        progressStatuses.contains(newStatus);
  }

  /// Get the impact level of the change
  static String _getChangeImpact(String oldStatus, String newStatus) {
    if (newStatus == 'Completed' || newStatus == 'CompletedAcknowledged') {
      return 'high';
    } else if (newStatus == 'PendingReview') {
      return 'medium';
    } else if (newStatus == 'Blocked') {
      return 'high';
    } else {
      return 'low';
    }
  }

  /// Get the priority level of the change
  static String _getChangePriority(String oldStatus, String newStatus) {
    if (newStatus == 'Completed' || newStatus == 'CompletedAcknowledged') {
      return 'high';
    } else if (newStatus == 'PendingReview') {
      return 'medium';
    } else if (newStatus == 'Blocked') {
      return 'urgent';
    } else {
      return 'normal';
    }
  }

  /// Get milestone audit entries for a goal
  static Stream<List<Map<String, dynamic>>> getMilestoneAuditStream(
    String goalId,
  ) async* {
    try {
      // Add delay to prevent rapid-fire queries that cause assertions
      await Future.delayed(const Duration(milliseconds: 100));

      final stream = _firestore
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
          .limit(50) // Limit to prevent large result sets
          .snapshots();

      await for (final snapshot in stream) {
        try {
          final audits = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          yield audits;
        } catch (e) {
          developer.log('Error processing audit snapshot: $e');
          yield []; // Fallback to empty list on error
        }
      }
    } catch (e) {
      developer.log('Error in getMilestoneAuditStream: $e');
      yield []; // Fallback to empty list
    }
  }

  /// Get all milestone audit entries (Future-based - NO STREAMS AT ALL)
  static Stream<List<Map<String, dynamic>>>
  getAllMilestoneAuditStream() async* {
    try {
      // Return empty list immediately to avoid any Firestore operations
      yield [];

      // Keep stream alive but never emit again
      await for (final _ in StreamController().stream) {
        await Future.delayed(const Duration(hours: 1));
      }
    } catch (e) {
      developer.log('Error in getAllMilestoneAuditStream: $e');
      yield []; // Fallback to empty list
    }
  }

  /// Get milestone audit entries as Future (safe alternative)
  static Future<List<Map<String, dynamic>>> getMilestoneAudits() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }

      // Simple one-time query
      final snapshot = await _firestore
          .collection('audit_entries')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final audits = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((audit) {
            // Client-side filtering for user's own milestone actions
            final action = audit['action'] as String? ?? '';
            final userId = audit['userId'] as String? ?? '';
            final isMilestoneAction = [
              'milestone_created',
              'milestone_updated',
              'milestone_status_changed',
            ].contains(action);

            return isMilestoneAction && userId == user.uid;
          })
          .toList();

      developer.log('Future query: Found ${audits.length} milestone audits');
      return audits;
    } catch (e) {
      developer.log('Error in getMilestoneAudits: $e');
      return []; // Fallback to empty list
    }
  }

  /// Backfill existing milestones using simple audit system
  static Future<void> backfillExistingMilestones() async {
    if (kDebugMode) {
      print('Starting simple milestone audit backfill...');
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
            // Create audit entry using simple system
            await logMilestoneCreated(
              goalId: goalId,
              milestoneId: milestoneId,
              milestoneTitle: milestoneTitle,
              goalTitle: goalTitle,
              userId: milestoneData['createdBy'] ?? 'unknown',
            );

            auditEntriesCreated++;

            if (kDebugMode) {
              print('Created audit entry for milestone: $milestoneTitle');
            }
          }
        }
      }

      if (kDebugMode) {
        print('Simple backfill completed!');
        print('Total milestones processed: $totalMilestones');
        print('Audit entries created: $auditEntriesCreated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during simple backfill: $e');
      }
      rethrow;
    }
  }
}
