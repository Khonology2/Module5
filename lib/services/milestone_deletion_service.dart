import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/milestone_deletion_request.dart';
import 'package:pdh/services/unified_goal_deletion_service.dart'; // For DeletionResult and _createManagerAlert
import 'package:pdh/services/alert_service.dart'; // NEW
// import 'package:pdh/models/goal.dart'; // Removed as no longer directly used

class MilestoneDeletionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initiates a milestone deletion request for manager approval.
  static Future<DeletionResult> requestMilestoneDeletion({
    required String goalId,
    required String milestoneId,
    required String reason,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return DeletionResult.failure('User not authenticated');
      }

      // Get goal and milestone data
      final goalDoc = await _firestore.collection('goals').doc(goalId).get();
      if (!goalDoc.exists) {
        return DeletionResult.failure('Goal not found');
      }
      final goalData = goalDoc.data()!;
      final goalOwnerId = goalData['userId'] as String;

      if (goalOwnerId != userId) {
        return DeletionResult.failure('You can only request deletion for your own milestones.');
      }

      final milestoneDoc = await _firestore.collection('goals').doc(goalId).collection('milestones').doc(milestoneId).get();
      if (!milestoneDoc.exists) {
        return DeletionResult.failure('Milestone not found');
      }
      final milestoneData = milestoneDoc.data()!;
      final milestoneTitle = milestoneData['title'] as String;

      // Get employee information for the request
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};
      final employeeName = userData['displayName'] ?? userData['name'] ?? 'Employee';
      final employeeEmail = userData['email'];
      final department = userData['department'];
      final managerId = userData['managerId'];

      // Create milestone deletion request
      final requestRef = await _firestore.collection('milestone_deletion_requests').add({
        'milestoneId': milestoneId,
        'goalId': goalId,
        'userId': userId,
        'milestoneTitle': milestoneTitle,
        'reason': reason,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'employeeName': employeeName,
        'employeeEmail': employeeEmail,
        'department': department,
      });

      // Update milestone to reflect pending deletion status
      await _firestore.collection('goals').doc(goalId).collection('milestones').doc(milestoneId).update({
        'deletionStatus': 'pending',
        'deletionRequestedAt': FieldValue.serverTimestamp(),
        'deletionReason': reason,
        'deletionRequestId': requestRef.id,
      });

      // Create alert for manager (reusing AlertService helper)
      if (managerId != null && managerId.isNotEmpty) {
        await AlertService.createManagerAlert(
          goalId: goalId,
          goalTitle: milestoneTitle, // Use milestone title as goal title for alert
          ownerId: userId,
          ownerName: employeeName,
          managerId: managerId,
          type: 'milestoneDeletionRequest',
        );
      }

      developer.log('Milestone deletion request created: ${requestRef.id}');
      return DeletionResult.success('Milestone deletion request submitted for manager approval');
    } catch (e, stackTrace) {
      developer.log('Failed to create milestone deletion request: $e\n$stackTrace');
      return DeletionResult.failure('Failed to create milestone deletion request: ${e.toString()}');
    }
  }

  /// Streams pending milestone deletion requests for managers.
  static Stream<List<MilestoneDeletionRequest>> getManagerPendingRequestsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }
    // Managers view all pending for now (department filter could be added based on manager's department)
    return _firestore
        .collection('milestone_deletion_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MilestoneDeletionRequest.fromFirestore(d))
            .toList())
        .handleError((e) {
      developer.log('Error streaming milestone deletion requests: $e');
      return <MilestoneDeletionRequest>[];
    });
  }

  /// Approves a milestone deletion request and performs the actual deletion.
  static Future<DeletionResult> approveMilestoneDeletion({
    required String requestId,
    String? resolutionReason,
  }) async {
    try {
      final managerId = _auth.currentUser?.uid;
      if (managerId == null) {
        return DeletionResult.failure('Manager not authenticated');
      }

      final requestDoc = await _firestore.collection('milestone_deletion_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        return DeletionResult.failure('Milestone deletion request not found');
      }
      final requestData = requestDoc.data()!;

      final goalId = requestData['goalId'] as String;
      final milestoneId = requestData['milestoneId'] as String;
      final userId = requestData['userId'] as String;
      final milestoneTitle = requestData['milestoneTitle'] as String;
      // Fetch goal title for alert message
      final goalDoc = await _firestore.collection('goals').doc(goalId).get();
      final goalTitle = (goalDoc.data()?['title'] ?? 'Unknown Goal') as String;

      // Perform the actual deletion of the milestone
      await _performDirectMilestoneDeletion(goalId, milestoneId);

      // Update the request status to approved
      await requestDoc.reference.update({
        'status': 'approved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': managerId,
        'resolutionReason': resolutionReason,
      });

      // Create alert for employee (milestone deleted)
      if (userId.isNotEmpty) {
        await AlertService.createManagerAlert(
          goalId: goalId,
          goalTitle: milestoneTitle, // Use milestone title
          ownerId: managerId, // Sender is manager
          ownerName: (await _firestore.collection('users').doc(managerId).get()).data()?['displayName'] ?? 'Manager',
          managerId: userId, // Recipient is employee
          type: 'milestoneDeleted',
          message: 'Your milestone "$milestoneTitle" for goal "$goalTitle" has been deleted.',
        );
      }

      developer.log('Milestone deletion approved and performed: $milestoneId');
      return DeletionResult.success('Milestone deletion approved and completed');
    } catch (e, stackTrace) {
      developer.log('Failed to approve milestone deletion: $e\n$stackTrace');
      return DeletionResult.failure('Failed to approve milestone deletion: ${e.toString()}');
    }
  }

  /// Rejects a milestone deletion request and restores the milestone.
  static Future<DeletionResult> rejectMilestoneDeletion({
    required String requestId,
    String? resolutionReason,
  }) async {
    try {
      final managerId = _auth.currentUser?.uid;
      if (managerId == null) {
        return DeletionResult.failure('Manager not authenticated');
      }

      final requestDoc = await _firestore.collection('milestone_deletion_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        return DeletionResult.failure('Milestone deletion request not found');
      }
      final requestData = requestDoc.data()!;

      final goalId = requestData['goalId'] as String;
      final milestoneId = requestData['milestoneId'] as String;
      final userId = requestData['userId'] as String;
      final milestoneTitle = requestData['milestoneTitle'] as String;
      // Fetch goal title for alert message
      final goalDoc = await _firestore.collection('goals').doc(goalId).get();
      final goalTitle = (goalDoc.data()?['title'] ?? 'Unknown Goal') as String;

      // Update the request status to rejected
      await requestDoc.reference.update({
        'status': 'rejected',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': managerId,
        'resolutionReason': resolutionReason,
      });

      // Restore milestone by removing deletion status fields
      await _firestore.collection('goals').doc(goalId).collection('milestones').doc(milestoneId).update({
        'deletionStatus': FieldValue.delete(),
        'deletionRequestedAt': FieldValue.delete(),
        'deletionReason': FieldValue.delete(),
        'deletionRequestId': FieldValue.delete(),
      });

      // Create alert for employee (milestone deletion rejected)
      if (userId.isNotEmpty) {
        await AlertService.createManagerAlert(
          goalId: goalId,
          goalTitle: milestoneTitle, // Use milestone title
          ownerId: managerId, // Sender is manager
          ownerName: (await _firestore.collection('users').doc(managerId).get()).data()?['displayName'] ?? 'Manager',
          managerId: userId, // Recipient is employee
          type: 'milestoneDeletionRejected',
          message: 'Your request to delete milestone "$milestoneTitle" from goal "$goalTitle" has been rejected.',
        );
      }

      developer.log('Milestone deletion request rejected: $milestoneId');
      return DeletionResult.success('Milestone deletion request rejected');
    } catch (e, stackTrace) {
      developer.log('Failed to reject milestone deletion: $e\n$stackTrace');
      return DeletionResult.failure('Failed to reject milestone deletion: ${e.toString()}');
    }
  }

  /// Performs the direct deletion of a milestone from Firestore.
  static Future<void> _performDirectMilestoneDeletion(String goalId, String milestoneId) async {
    try {
      final milestoneRef = _firestore.collection('goals').doc(goalId).collection('milestones').doc(milestoneId);
      await milestoneRef.delete();
      // Optionally, update goal progress based on milestone deletion
      // await DatabaseService.syncGoalProgressWithMilestones(goalId);
      developer.log('Milestone $milestoneId deleted for goal $goalId');
    } catch (e, stackTrace) {
      developer.log('Failed to perform direct milestone deletion: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Helper to create manager alerts, reused from UnifiedGoalDeletionService
  // This function is defined as static in UnifiedGoalDeletionService
  // and thus can be called directly. No need to redefine here.

}
