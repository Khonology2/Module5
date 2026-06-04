import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/goal_milestone.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/backend_auth_service.dart';

class MilestoneEvidenceService {
  static final BackendAuthService _backend = BackendAuthService.instance;
  static const int _maxEvidenceSize = 10 * 1024 * 1024;
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

  static Map<String, dynamic> _evidenceToBackendMap(MilestoneEvidence evidence) {
    return {
      'id': evidence.id,
      'fileUrl': evidence.fileUrl,
      'fileName': evidence.fileName,
      'fileType': evidence.fileType,
      'fileSize': evidence.fileSize,
      'uploadedBy': evidence.uploadedBy,
      'uploadedByName': evidence.uploadedByName,
      'uploadedAt': evidence.uploadedAt.toIso8601String(),
      'status': evidence.status.name,
      'reviewedBy': evidence.reviewedBy,
      'reviewedByName': evidence.reviewedByName,
      'reviewedAt': evidence.reviewedAt?.toIso8601String(),
      'reviewNotes': evidence.reviewNotes,
    };
  }

  static Future<Map<String, dynamic>?> _fetchMilestoneSnapshot({
    required String goalId,
    required String milestoneId,
  }) async {
    final milestones = await _backend.getMilestones(goalId: goalId);
    for (final milestone in milestones) {
      if (milestone['id']?.toString() == milestoneId) {
        return milestone;
      }
    }
    return null;
  }

  static Future<MilestoneEvidence> uploadEvidence({
    required String milestoneId,
    required String goalId,
    required String fileUrl,
    required String fileName,
    required String fileType,
    required int fileSize,
  }) async {
    try {
      _validateFile(fileType, fileSize);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      String? uploadedByName;
      try {
        final userData = await _backend.getUser(currentUser.uid);
        uploadedByName = userData['displayName']?.toString();
      } catch (e) {
        developer.log('Error getting user name: $e');
      }

      final evidenceId = '${DateTime.now().microsecondsSinceEpoch}';
      final evidence = MilestoneEvidence(
        id: evidenceId,
        fileUrl: fileUrl,
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
        uploadedBy: currentUser.uid,
        uploadedByName: uploadedByName,
        uploadedAt: DateTime.now(),
        status: MilestoneEvidenceStatus.pendingReview,
      );

      final milestoneSnapshot = await _fetchMilestoneSnapshot(
        goalId: goalId,
        milestoneId: milestoneId,
      );
      if (milestoneSnapshot == null) {
        throw Exception('Milestone not found');
      }

      final existingEvidence = List<dynamic>.from(
        milestoneSnapshot['evidence'] ?? const [],
      );
      existingEvidence.add(_evidenceToBackendMap(evidence));

      await _backend.patchMilestone(milestoneId, {
        'goalId': goalId,
        'evidence': existingEvidence,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      try {
        await _backend.createMilestoneEvidence({
          ..._evidenceToBackendMap(evidence),
          'goalId': goalId,
          'milestoneId': milestoneId,
        });
      } catch (e) {
        developer.log('Error storing milestone evidence record: $e');
      }

      developer.log('Evidence uploaded for milestone $milestoneId');
      return evidence;
    } catch (e) {
      developer.log('Error uploading evidence: $e');
      rethrow;
    }
  }

  static Future<List<MilestoneEvidence>> getMilestoneEvidence({
    required String goalId,
    required String milestoneId,
  }) async {
    try {
      final milestoneSnapshot = await _fetchMilestoneSnapshot(
        goalId: goalId,
        milestoneId: milestoneId,
      );
      if (milestoneSnapshot == null) return [];

      final evidenceList = milestoneSnapshot['evidence'];
      if (evidenceList == null) return [];

      return (evidenceList as List)
          .map((e) => MilestoneEvidence.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      developer.log('Error getting milestone evidence: $e');
      return [];
    }
  }

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

      String? reviewedByName;
      try {
        final userData = await _backend.getUser(currentUser.uid);
        reviewedByName = userData['displayName']?.toString();
      } catch (e) {
        developer.log('Error getting manager name: $e');
      }

      final milestoneSnapshot = await _fetchMilestoneSnapshot(
        goalId: goalId,
        milestoneId: milestoneId,
      );
      if (milestoneSnapshot == null) {
        throw Exception('Milestone not found');
      }

      final evidenceList = (milestoneSnapshot['evidence'] as List? ?? [])
          .map((e) {
            final evidenceMap = Map<String, dynamic>.from(e as Map);
            if (evidenceMap['id']?.toString() == evidenceId) {
              evidenceMap['status'] = status.name;
              evidenceMap['reviewedBy'] = currentUser.uid;
              evidenceMap['reviewedByName'] = reviewedByName;
              evidenceMap['reviewedAt'] = DateTime.now().toIso8601String();
              evidenceMap['reviewNotes'] = reviewNotes;
            }
            return evidenceMap;
          })
          .toList();

      await _backend.patchMilestone(milestoneId, {
        'goalId': goalId,
        'evidence': evidenceList,
        'updatedAt': DateTime.now().toIso8601String(),
      });

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

  static Future<bool> canCompleteMilestone({
    required String goalId,
    required String milestoneId,
  }) async {
    try {
      final milestoneSnapshot = await _fetchMilestoneSnapshot(
        goalId: goalId,
        milestoneId: milestoneId,
      );
      if (milestoneSnapshot == null) return false;

      final requiresEvidence = milestoneSnapshot['requiresEvidence'] == true;
      if (!requiresEvidence) return true;

      final evidenceList = milestoneSnapshot['evidence'] as List? ?? [];
      return evidenceList.any((e) {
        final evidence = Map<String, dynamic>.from(e as Map);
        return evidence['status'] == MilestoneEvidenceStatus.approved.name;
      });
    } catch (e) {
      developer.log('Error checking milestone completion eligibility: $e');
      return false;
    }
  }

  static Future<void> setEvidenceRequirement({
    required String goalId,
    required String milestoneId,
    required bool requiresEvidence,
  }) async {
    try {
      await _backend.patchMilestone(milestoneId, {
        'goalId': goalId,
        'requiresEvidence': requiresEvidence,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      developer.log(
        'Evidence requirement set to $requiresEvidence for milestone $milestoneId',
      );
    } catch (e) {
      developer.log('Error setting evidence requirement: $e');
      rethrow;
    }
  }

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

      String? managerName;
      try {
        final userData = await _backend.getUser(currentUser.uid);
        managerName = userData['displayName']?.toString();
      } catch (e) {
        developer.log('Error getting manager name: $e');
      }

      await _backend.patchMilestone(milestoneId, {
        'goalId': goalId,
        'managerAcknowledgedBy': currentUser.uid,
        'managerAcknowledgedByName': managerName,
        'managerAcknowledgedAt': DateTime.now().toIso8601String(),
        'managerNotes': notes,
        'updatedAt': DateTime.now().toIso8601String(),
      });

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
    if (fileSize > _maxEvidenceSize) {
      throw Exception('File size exceeds 10MB limit');
    }

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
      final goals = await _backend.getGoals(goalId: goalId, limit: 1);
      final milestones = await _backend.getMilestones(goalId: goalId);
      if (goals.isEmpty) return;

      final goal = Goal.fromMap(goals.first, id: goalId);
      final milestoneData = milestones.firstWhere(
        (item) => item['id']?.toString() == milestoneId,
        orElse: () => const {},
      );
      if (milestoneData.isEmpty) return;

      final milestone = GoalMilestone.fromMap(
        milestoneData,
        id: milestoneId,
        goalId: goalId,
      );

      final statusText = status == MilestoneEvidenceStatus.approved
          ? 'approved'
          : 'rejected';

      await _backend.createAlert(goal.userId, {
        'type': AlertType.managerGeneral.name,
        'priority': AlertPriority.medium.name,
        'title': 'Evidence Review',
        'message':
            'Your evidence for milestone "${milestone.title}" has been $statusText by ${reviewedByName ?? 'your manager'}.',
        'actionText': 'View Milestone',
        'actionRoute': '/my_goal_workspace',
        'actionData': {'goalId': goalId},
        'relatedGoalId': goalId,
        'createdAt': DateTime.now().toIso8601String(),
        'isRead': false,
        'isDismissed': false,
        'expiresAt': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
        'metadata': {'evidenceId': evidenceId, 'milestoneId': milestoneId},
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
      final goals = await _backend.getGoals(goalId: goalId, limit: 1);
      final milestones = await _backend.getMilestones(goalId: goalId);
      if (goals.isEmpty) return;

      final goal = Goal.fromMap(goals.first, id: goalId);
      final milestoneData = milestones.firstWhere(
        (item) => item['id']?.toString() == milestoneId,
        orElse: () => const {},
      );
      if (milestoneData.isEmpty) return;

      final milestone = GoalMilestone.fromMap(
        milestoneData,
        id: milestoneId,
        goalId: goalId,
      );

      await AlertService.createMilestoneAcknowledgedAlert(
        employeeId: goal.userId,
        goalId: goalId,
        milestoneId: milestoneId,
        milestoneTitle: milestone.title,
        managerName: managerName ?? 'your manager',
      );
    } catch (e) {
      developer.log('Error sending acknowledgement notification: $e');
    }
  }
}
