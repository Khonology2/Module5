import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/goal_deletion_request.dart';
import 'package:pdh/services/database_service.dart';

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

  // Approve and perform deletion
  static Future<void> approveRequest(GoalDeletionRequest req) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final batch = _firestore.batch();
      final reqRef =
          _firestore.collection('goal_deletion_requests').doc(req.id);
      batch.update(reqRef, {
        'status': 'approved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': user.uid,
      });
      await batch.commit();

      // Perform actual deletion (will log internally)
      await DatabaseService.deleteGoal(
        goalId: req.goalId,
        requesterId: user.uid,
      );
    } catch (e) {
      developer.log('Error approving deletion request: $e');
      rethrow;
    }
  }

  static Future<void> rejectRequest(GoalDeletionRequest req, String reason) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');
      await _firestore
          .collection('goal_deletion_requests')
          .doc(req.id)
          .update({
        'status': 'rejected',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': user.uid,
        'rejectReason': reason,
      });
    } catch (e) {
      developer.log('Error rejecting deletion request: $e');
      rethrow;
    }
  }
}
