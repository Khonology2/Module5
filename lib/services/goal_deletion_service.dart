import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/unified_goal_deletion_service.dart';
import 'package:pdh/models/goal_deletion_request.dart';

class GoalDeletionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream pending requests for current manager's department
  static Stream<List<GoalDeletionRequest>> getManagerPendingRequestsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }
    // Managers view all pending for now (department filter could be added)
    return _firestore
        .collection('goal_deletion_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => GoalDeletionRequest.fromFirestore(d))
            .toList())
        .handleError((e) {
      developer.log('Error streaming deletion requests: $e');
      return <GoalDeletionRequest>[];
    });
  }

  // Stream whether current user has pending deletion request for a goal
  static Stream<bool> hasPendingRequestStream(String goalId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return _firestore
        .collection('goal_deletion_requests')
        .where('goalId', isEqualTo: goalId)
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isNotEmpty);
  }

  // Approve and perform deletion
  static Future<void> approveRequest(GoalDeletionRequest req) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Use unified service to process approval and perform deletion
      final result = await UnifiedGoalDeletionService.processDeletionRequest(
        requestId: req.id,
        approved: true,
        reason: 'Approved by manager/admin via GoalDeletionService',
      );

      if (!result.success) {
        throw Exception(result.message);
      }
    } catch (e) {
      developer.log('Error approving deletion request: $e');
      rethrow;
    }
  }

  static Future<void> rejectRequest(GoalDeletionRequest req, String reason) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');
      
      final batch = _firestore.batch();
      
      // Update the deletion request
      final reqRef = _firestore.collection('goal_deletion_requests').doc(req.id);
      batch.update(reqRef, {
        'status': 'rejected',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': user.uid,
        'rejectReason': reason,
      });
      
      // Restore goal accessibility by removing deletion status
      final goalRef = _firestore.collection('goals').doc(req.goalId);
      batch.update(goalRef, {
        'deletionStatus': FieldValue.delete(),
        'deletionRequestedAt': FieldValue.delete(),
        'deletionReason': FieldValue.delete(),
      });
      
      await batch.commit();
    } catch (e) {
      developer.log('Error rejecting deletion request: $e');
      rethrow;
    }
  }
}
