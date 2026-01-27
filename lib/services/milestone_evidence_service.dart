import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/goal_milestone.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/models/goal.dart';

class MilestoneEvidenceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int _maxEvidenceSize = 10 * 1024 * 1024; // 10MB
  static const List<String> _allowedFileTypes = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'mp4',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    'zip',
    'rar',
    '7z',
    'tar',
    'gz',
  ];

  /// Upload evidence for a milestone (additive extension)
  static Future<MilestoneEvidence> uploadEvidence({
    required String milestoneId,
    required String goalId,
    required String fileUrl,
    required String fileName,
    required String fileType,
    required int fileSize,
  }) async {
    try {
      // Validate file
      _validateFile(fileType, fileSize);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user name for display
      String? uploadedByName;
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        uploadedByName = userDoc.data()?['displayName']?.toString();
      } catch (e) {
        developer.log('Error getting user name: $e');
      }

      final evidence = MilestoneEvidence(
        id: _firestore.collection('milestone_evidence').doc().id,
        fileUrl: fileUrl,
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
        uploadedBy: currentUser.uid,
        uploadedByName: uploadedByName,
        uploadedAt: DateTime.now(),
        status: MilestoneEvidenceStatus.pendingReview, // UPDATED: New status
      );

      // Add evidence to milestone (additive update)
      await _firestore
          .collection('goals')
          .doc(goalId)
          .collection('milestones')
          .doc(milestoneId)
          .update({
            'evidence': FieldValue.arrayUnion([evidence.toMap()]),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      developer.log('Evidence uploaded for milestone $milestoneId');
      return evidence;
    } catch (e) {
      developer.log('Error uploading evidence: $e');
      rethrow;
    }
  }

  /// Get all evidence for a milestone
  static Future<List<MilestoneEvidence>> getMilestoneEvidence({
    required String goalId,
    required String milestoneId,
  }) async {
    try {
      final milestoneDoc = await _firestore
          .collection('goals')
          .doc(goalId)
          .collection('milestones')
          .doc(milestoneId)
          .get();

      if (!milestoneDoc.exists) return [];

      final data = milestoneDoc.data();
      if (data == null || data['evidence'] == null) return [];

      final evidenceList = data['evidence'] as List;
      return evidenceList.map((e) => MilestoneEvidence.fromMap(e)).toList();
    } catch (e) {
      developer.log('Error getting milestone evidence: $e');
      return [];
    }
  }

  /// Review evidence (manager action)
  static Future<void> reviewEvidence({
    required String goalId,
    required String milestoneId,
    required String evidenceId,
    required MilestoneEvidenceStatus status,
    required String reviewNotes,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get manager name
      String? reviewedByName;
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        reviewedByName = userDoc.data()?['displayName']?.toString();
      } catch (e) {
        developer.log('Error getting manager name: $e');
      }

      // Get current milestone data
      final milestoneDoc = await _firestore
          .collection('goals')
          .doc(goalId)
          .collection('milestones')
          .doc(milestoneId)
          .get();

      if (!milestoneDoc.exists) {
        throw Exception('Milestone not found');
      }

      final data = milestoneDoc.data() as Map<String, dynamic>;
      List<dynamic> evidenceList = data['evidence'] as List? ?? [];

      // Update the specific evidence
      evidenceList = evidenceList.map((e) {
        final evidenceMap = Map<String, dynamic>.from(e);
        if (evidenceMap['id'] == evidenceId) {
          evidenceMap['status'] = status.name;
          evidenceMap['reviewedBy'] = currentUser.uid;
          evidenceMap['reviewedByName'] = reviewedByName;
          evidenceMap['reviewedAt'] = Timestamp.now();
          evidenceMap['reviewNotes'] = reviewNotes;
        }
        return evidenceMap;
      }).toList();

      // Update milestone with reviewed evidence
      await _firestore
          .collection('goals')
          .doc(goalId)
          .collection('milestones')
          .doc(milestoneId)
          .update({
            'evidence': evidenceList,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Send notification to employee about evidence review
      await _sendEvidenceReviewNotification(
        goalId: goalId,
        milestoneId: milestoneId,
        evidenceId: evidenceId,
        status: status,
        reviewedByName: reviewedByName,
      );

      developer.log(
        'Evidence $evidenceId reviewed with status: ${status.name}',
      );
    } catch (e) {
      developer.log('Error reviewing evidence: $e');
      rethrow;
    }
  }

  /// Check if milestone can be completed (evidence validation)
  static Future<bool> canCompleteMilestone({
    required String goalId,
    required String milestoneId,
  }) async {
    try {
      final milestoneDoc = await _firestore
          .collection('goals')
          .doc(goalId)
          .collection('milestones')
          .doc(milestoneId)
          .get();

      if (!milestoneDoc.exists) return false;

      final data = milestoneDoc.data() as Map<String, dynamic>;
      final requiresEvidence = data['requiresEvidence'] == true;

      if (!requiresEvidence) return true;

      // Check if there's approved evidence
      final evidenceList = data['evidence'] as List? ?? [];
      final hasApprovedEvidence = evidenceList.any((e) {
        final evidence = Map<String, dynamic>.from(e);
        return evidence['status'] == MilestoneEvidenceStatus.approved.name;
      });

      return hasApprovedEvidence;
    } catch (e) {
      developer.log('Error checking milestone completion eligibility: $e');
      return false;
    }
  }

  /// Set milestone evidence requirement (additive)
  static Future<void> setEvidenceRequirement({
    required String goalId,
    required String milestoneId,
    required bool requiresEvidence,
  }) async {
    try {
      await _firestore
          .collection('goals')
          .doc(goalId)
          .collection('milestones')
          .doc(milestoneId)
          .update({
            'requiresEvidence': requiresEvidence,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      developer.log(
        'Evidence requirement set to $requiresEvidence for milestone $milestoneId',
      );
    } catch (e) {
      developer.log('Error setting evidence requirement: $e');
      rethrow;
    }
  }

  /// Manager acknowledgement of milestone completion
  static Future<void> acknowledgeMilestone({
    required String goalId,
    required String milestoneId,
    required String notes,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get manager name
      String? managerName;
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        managerName = userDoc.data()?['displayName']?.toString();
      } catch (e) {
        developer.log('Error getting manager name: $e');
      }

      // Update milestone with acknowledgement
      await _firestore
          .collection('goals')
          .doc(goalId)
          .collection('milestones')
          .doc(milestoneId)
          .update({
            'managerAcknowledgedBy': currentUser.uid,
            'managerAcknowledgedByName': managerName,
            'managerAcknowledgedAt': FieldValue.serverTimestamp(),
            'managerNotes': notes,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Send acknowledgement notification to employee
      await _sendAcknowledgementNotification(
        goalId: goalId,
        milestoneId: milestoneId,
        managerName: managerName,
      );

      developer.log('Milestone $milestoneId acknowledged by manager');
    } catch (e) {
      developer.log('Error acknowledging milestone: $e');
      rethrow;
    }
  }

  static void _validateFile(String fileType, int fileSize) {
    // Check file size
    if (fileSize > _maxEvidenceSize) {
      throw Exception('File size exceeds 10MB limit');
    }

    // Check file type
    final extension = fileType.toLowerCase().split('.').last;
    if (!_allowedFileTypes.contains(extension)) {
      throw Exception(
        'File type not allowed. Allowed types: ${_allowedFileTypes.join(', ')}',
      );
    }
  }

  static Future<void> _sendEvidenceReviewNotification({
    required String goalId,
    required String milestoneId,
    required String evidenceId,
    required MilestoneEvidenceStatus status,
    String? reviewedByName,
  }) async {
    try {
      // Get goal and milestone details
      final goalDoc = await _firestore.collection('goals').doc(goalId).get();
      final milestoneDoc = await _firestore
          .collection('goals')
          .doc(goalId)
          .collection('milestones')
          .doc(milestoneId)
          .get();

      if (!goalDoc.exists || !milestoneDoc.exists) return;

      final goal = Goal.fromFirestore(goalDoc);
      final milestone = GoalMilestone.fromFirestore(milestoneDoc);

      final statusText = status == MilestoneEvidenceStatus.approved
          ? 'approved'
          : 'rejected';

      await _firestore.collection('alerts').add({
        'userId': goal.userId,
        'type': AlertType.managerGeneral.name,
        'priority': AlertPriority.medium.name,
        'title': 'Evidence Review',
        'message':
            'Your evidence for milestone "${milestone.title}" has been $statusText by ${reviewedByName ?? 'your manager'}.',
        'actionText': 'View Milestone',
        'actionRoute': '/my_goal_workspace',
        'actionData': {'goalId': goalId},
        'relatedGoalId': goalId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDismissed': false,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
      });
    } catch (e) {
      developer.log('Error sending evidence review notification: $e');
    }
  }

  static Future<void> _sendAcknowledgementNotification({
    required String goalId,
    required String milestoneId,
    String? managerName,
  }) async {
    try {
      // Get goal and milestone details
      final goalDoc = await _firestore.collection('goals').doc(goalId).get();
      final milestoneDoc = await _firestore
          .collection('goals')
          .doc(goalId)
          .collection('milestones')
          .doc(milestoneId)
          .get();

      if (!goalDoc.exists || !milestoneDoc.exists) return;

      final goal = Goal.fromFirestore(goalDoc);
      final milestone = GoalMilestone.fromFirestore(milestoneDoc);

      await _firestore.collection('alerts').add({
        'userId': goal.userId,
        'type': AlertType.managerGeneral.name,
        'priority': AlertPriority.medium.name,
        'title': 'Milestone Acknowledged',
        'message':
            'Your completed milestone "${milestone.title}" has been acknowledged by ${managerName ?? 'your manager'}.',
        'actionText': 'View Milestone',
        'actionRoute': '/my_goal_workspace',
        'actionData': {'goalId': goalId},
        'relatedGoalId': goalId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDismissed': false,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
      });
    } catch (e) {
      developer.log('Error sending acknowledgement notification: $e');
    }
  }
}
