import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UnifiedGoalDeletionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Unified goal deletion system
  /// Handles both approved and unapproved goals with consistent logic
  static Future<DeletionResult> deleteGoal({
    required String goalId,
    String? reason,
    bool forceDelete = false,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return DeletionResult.failure('User not authenticated');
      }

      developer.log('=== UNIFIED DELETION SYSTEM ===');
      developer.log('GoalId: $goalId');
      developer.log('UserId: $userId');
      developer.log('Force Delete: $forceDelete');

      // Get goal and verify existence
      final goalDoc = await _firestore.collection('goals').doc(goalId).get();
      if (!goalDoc.exists) {
        return DeletionResult.failure('Goal not found');
      }

      final goalData = goalDoc.data()!;
      final ownerId = goalData['userId'] as String;
      final approvalStatus = goalData['approvalStatus'] as String? ?? 'pending';

      developer.log('Goal Owner: $ownerId');
      developer.log('Approval Status: $approvalStatus');

      // Get user role and permissions
      final userRole = await _getUserRole(userId);
      final permissions = await _getUserPermissions(userId, ownerId, userRole);

      developer.log('User Role: $userRole');
      developer.log('Permissions: $permissions');

      // Determine deletion strategy
      if (approvalStatus == 'approved' && !permissions.canDeleteApprovedGoals && !forceDelete) {
        // Create deletion request for approved goals
        return await _createDeletionRequest(
          goalId: goalId,
          goalData: goalData,
          ownerId: ownerId,
          requesterId: userId,
          reason: reason ?? '',
        );
      } else {
        // Direct deletion for unapproved goals or with force permissions
        return await _performDirectDeletion(
          goalId: goalId,
          goalData: goalData,
          requesterId: userId,
          userRole: userRole,
          permissions: permissions,
        );
      }
    } catch (e) {
      developer.log('Deletion failed: $e');
      return DeletionResult.failure('Deletion failed: ${e.toString()}');
    }
  }

  /// Create a deletion request for approved goals
  static Future<DeletionResult> _createDeletionRequest({
    required String goalId,
    required Map<String, dynamic> goalData,
    required String ownerId,
    required String requesterId,
    required String reason,
  }) async {
    try {
      // Get owner information
      final ownerDoc = await _firestore.collection('users').doc(ownerId).get();
      final ownerData = ownerDoc.data() ?? {};

      // Create deletion request
      final requestRef = await _firestore.collection('goal_deletion_requests').add({
        'goalId': goalId,
        'goalTitle': goalData['title'] ?? '',
        'userId': ownerId,
        'reason': reason,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'employeeName': ownerData['displayName'] ?? ownerData['name'] ?? 'Employee',
        'employeeEmail': ownerData['email'] ?? '',
        'department': ownerData['department'] ?? '',
      });

      // Mark goal as pending deletion
      await _firestore.collection('goals').doc(goalId).update({
        'deletionStatus': 'pending',
        'deletionRequestedAt': FieldValue.serverTimestamp(),
        'deletionReason': reason,
        'deletionRequestId': requestRef.id,
      });

      // Create alert for manager
      await _createManagerAlert(
        goalId: goalId,
        goalTitle: goalData['title'] ?? '',
        ownerId: ownerId,
        ownerName: ownerData['displayName'] ?? ownerData['name'] ?? 'Employee',
        managerId: ownerData['managerId'],
        type: 'goalDeletionRequest',
      );

      developer.log('Deletion request created successfully');
      return DeletionResult.success('Deletion request submitted for manager approval');
    } catch (e) {
      developer.log('Failed to create deletion request: $e');
      return DeletionResult.failure('Failed to create deletion request: ${e.toString()}');
    }
  }

  /// Perform direct deletion of goal
  static Future<DeletionResult> _performDirectDeletion({
    required String goalId,
    required Map<String, dynamic> goalData,
    required String requesterId,
    required String userRole,
    required UserPermissions permissions,
  }) async {
    try {
      // Get user information for audit
      final userDoc = await _firestore.collection('users').doc(requesterId).get();
      final userData = userDoc.data() ?? {};

      final batch = _firestore.batch();

      // Create audit log entry
      final deletedGoalRef = _firestore.collection('deleted_goals').doc(goalId);
      batch.set(deletedGoalRef, {
        'goalId': goalId,
        'goalData': {
          ...goalData,
          'employeeName': userData['displayName'] ?? userData['name'] ?? 'Unknown',
          'department': userData['department'] ?? '',
        },
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': requesterId,
        'deletedByName': userData['displayName'] ?? userData['name'] ?? 'Unknown',
        'deletedByRole': userRole,
        // Include approver info if deleted by manager/admin
        if (permissions.canDeleteApprovedGoals) ...{
          'approvedBy': requesterId,
          'approvedByName': userData['displayName'] ?? userData['name'] ?? 'Unknown',
          'approvedAt': FieldValue.serverTimestamp(),
        },
      });

      // Delete the goal
      batch.delete(_firestore.collection('goals').doc(goalId));

      // Delete related data
      await _deleteRelatedData(batch, goalId);

      // Commit the batch
      await batch.commit();

      developer.log('Goal deleted successfully');
      return DeletionResult.success('Goal deleted successfully');
    } catch (e) {
      developer.log('Direct deletion failed: $e');
      return DeletionResult.failure('Direct deletion failed: ${e.toString()}');
    }
  }

  /// Delete all related data for a goal
  static Future<void> _deleteRelatedData(WriteBatch batch, String goalId) async {
    try {
      // Delete alerts
      final alerts = await _firestore
          .collection('alerts')
          .where('relatedGoalId', isEqualTo: goalId)
          .get();
      for (final alert in alerts.docs) {
        batch.delete(alert.reference);
      }
    } catch (e) {
      developer.log('Failed to delete alerts: $e');
    }

    try {
      // Delete daily progress
      final progress = await _firestore
          .collection('goal_daily_progress')
          .where('goalId', isEqualTo: goalId)
          .get();
      for (final prog in progress.docs) {
        batch.delete(prog.reference);
      }
    } catch (e) {
      developer.log('Failed to delete daily progress: $e');
    }

    try {
      // Delete milestones
      final milestones = await _firestore
          .collection('goals')
          .doc(goalId)
          .collection('milestones')
          .get();
      for (final milestone in milestones.docs) {
        batch.delete(milestone.reference);
      }
    } catch (e) {
      developer.log('Failed to delete milestones: $e');
    }
  }

  /// Create manager alert for deletion requests
  static Future<void> _createManagerAlert({
    required String goalId,
    required String goalTitle,
    required String ownerId,
    required String ownerName,
    required String? managerId,
    required String type,
  }) async {
    try {
      if (managerId != null && managerId.isNotEmpty) {
        await _firestore.collection('alerts').add({
          'userId': managerId,
          'relatedGoalId': goalId,
          'type': type,
          'title': type == 'goalDeletionRequest' ? 'Deletion approval needed' : 'Goal deleted',
          'message': '$ownerName requests deletion of "$goalTitle"',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (e) {
      developer.log('Failed to create manager alert: $e');
    }
  }

  /// Get user role
  static Future<String> _getUserRole(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return (userDoc.data()?['role'] ?? 'employee') as String;
    } catch (e) {
      developer.log('Failed to get user role: $e');
      return 'employee';
    }
  }

  /// Get user permissions
  static Future<UserPermissions> _getUserPermissions(
    String userId,
    String goalOwnerId,
    String userRole,
  ) async {
    final isOwner = userId == goalOwnerId;
    final isManager = userRole == 'manager';
    final isAdmin = userRole == 'admin';

    return UserPermissions(
      canDeleteOwnGoals: isOwner,
      canDeleteApprovedGoals: isManager || isAdmin,
      canDeleteAnyGoal: isAdmin,
      isOwner: isOwner,
      isManager: isManager,
      isAdmin: isAdmin,
    );
  }

  /// Process deletion request approval/rejection
  static Future<DeletionResult> processDeletionRequest({
    required String requestId,
    required bool approved,
    String? reason,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return DeletionResult.failure('User not authenticated');
      }

      final requestDoc = await _firestore
          .collection('goal_deletion_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        return DeletionResult.failure('Deletion request not found');
      }

      final requestData = requestDoc.data()!;
      final goalId = requestData['goalId'] as String;

      final batch = _firestore.batch();

      if (approved) {
        // Approve deletion - perform actual deletion
        final goalDoc = await _firestore.collection('goals').doc(goalId).get();
        if (goalDoc.exists) {
          final goalData = goalDoc.data()!;
          final userRole = await _getUserRole(userId);
          final permissions = await _getUserPermissions(userId, goalData['userId'], userRole);

          if (!permissions.canDeleteApprovedGoals) {
            return DeletionResult.failure('Not authorized to approve this deletion');
          }

          // Update request status
          batch.update(requestDoc.reference, {
            'status': 'approved',
            'resolvedAt': FieldValue.serverTimestamp(),
            'resolvedBy': userId,
            'resolutionReason': reason ?? '',
          });

          // Perform deletion
          await _performDirectDeletion(
            goalId: goalId,
            goalData: goalData,
            requesterId: userId,
            userRole: userRole,
            permissions: permissions,
          );
        }
      } else {
        // Reject deletion
        batch.update(requestDoc.reference, {
          'status': 'rejected',
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': userId,
          'resolutionReason': reason ?? '',
        });

        // Restore goal access
        batch.update(_firestore.collection('goals').doc(goalId), {
          'deletionStatus': null,
          'deletionRequestedAt': null,
          'deletionReason': null,
          'deletionRequestId': null,
        });
      }

      await batch.commit();

      return DeletionResult.success(
        approved ? 'Deletion approved and completed' : 'Deletion request rejected',
      );
    } catch (e) {
      developer.log('Failed to process deletion request: $e');
      return DeletionResult.failure('Failed to process request: ${e.toString()}');
    }
  }
}

/// User permissions for goal deletion
class UserPermissions {
  final bool canDeleteOwnGoals;
  final bool canDeleteApprovedGoals;
  final bool canDeleteAnyGoal;
  final bool isOwner;
  final bool isManager;
  final bool isAdmin;

  UserPermissions({
    required this.canDeleteOwnGoals,
    required this.canDeleteApprovedGoals,
    required this.canDeleteAnyGoal,
    required this.isOwner,
    required this.isManager,
    required this.isAdmin,
  });

  @override
  String toString() {
    return 'UserPermissions(canDeleteOwn: $canDeleteOwnGoals, canDeleteApproved: $canDeleteApprovedGoals, canDeleteAny: $canDeleteAnyGoal, isOwner: $isOwner, isManager: $isManager, isAdmin: $isAdmin)';
  }
}

/// Deletion result
class DeletionResult {
  final bool success;
  final String message;

  DeletionResult.success(this.message) : success = true;
  DeletionResult.failure(this.message) : success = false;

  @override
  String toString() {
    return 'DeletionResult(success: $success, message: $message)';
  }
}
