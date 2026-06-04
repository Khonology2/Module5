import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/utils/backend_polling_stream.dart';

/// Simple, Professional Milestone Audit Service
/// Working implementation from 4 days ago - restored for stability
class UnifiedMilestoneAudit {
  static final BackendAuthService _backend = BackendAuthService.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const List<String> _milestoneActions = [
    'milestone_created',
    'milestone_updated',
    'milestone_status_changed',
    'milestone_completed',
    'milestone_acknowledged',
    'milestone_pending_review',
    'milestone_rejected',
    'milestone_dismissed',
  ];

  static String _displayNameFromUserData(Map<String, dynamic> userData) {
    return (userData['displayName'] ??
            userData['fullName'] ??
            userData['name'] ??
            userData['email'] ??
            '')
        .toString()
        .trim();
  }

  static Future<Map<String, String>> _resolveGoalOwnerContext(
    String goalId,
  ) async {
    try {
      final goals = await _backend.getGoals(goalId: goalId, limit: 1);
      if (goals.isEmpty) {
        return const <String, String>{
          'goalOwnerId': '',
          'goalOwnerName': '',
          'goalOwnerDepartment': '',
        };
      }
      final goalData = goals.first;
      final ownerId = (goalData['userId'] ?? '').toString().trim();
      if (ownerId.isEmpty) {
        return const <String, String>{
          'goalOwnerId': '',
          'goalOwnerName': '',
          'goalOwnerDepartment': '',
        };
      }
      final ownerData = await _backend.getUser(ownerId);
      return <String, String>{
        'goalOwnerId': ownerId,
        'goalOwnerName': _displayNameFromUserData(ownerData),
        'goalOwnerDepartment': (ownerData['department'] ?? '').toString().trim(),
      };
    } catch (_) {
      return const <String, String>{
        'goalOwnerId': '',
        'goalOwnerName': '',
        'goalOwnerDepartment': '',
      };
    }
  }

  static Future<Map<String, String>> _resolveCurrentUserContext() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const {
        'userName': 'System',
        'userEmail': 'system',
        'userRole': 'system',
        'userDepartment': '',
      };
    }

    try {
      final userData = await _backend.getUser(user.uid);
      return {
        'userName': _displayNameFromUserData(userData).isNotEmpty
            ? _displayNameFromUserData(userData)
            : (user.email ?? 'Unknown User'),
        'userEmail': user.email ?? 'unknown',
        'userRole': (userData['role'] ?? 'employee').toString(),
        'userDepartment': (userData['department'] ?? '').toString().trim(),
      };
    } catch (_) {
      return {
        'userName': user.email ?? 'Unknown User',
        'userEmail': user.email ?? 'unknown',
        'userRole': 'employee',
        'userDepartment': '',
      };
    }
  }

  static List<Map<String, dynamic>> _filterMilestoneActions(
    List<Map<String, dynamic>> entries,
  ) {
    return entries.where((audit) {
      final action = audit['action']?.toString() ?? '';
      return _milestoneActions.contains(action);
    }).toList();
  }

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
      final timestamp = DateTime.now().toIso8601String();
      final userContext = await _resolveCurrentUserContext();
      final owner = await _resolveGoalOwnerContext(goalId);

      final event = {
        'action': 'milestone_created',
        'goalId': goalId,
        'goalTitle': goalTitle,
        'milestoneId': milestoneId,
        'milestoneTitle': milestoneTitle,
        'status': 'created',
        'userId': user?.uid ?? userId ?? 'system',
        'userDisplayName': userContext['userName'],
        'userDepartment': userContext['userDepartment'],
        'goalOwnerId': owner['goalOwnerId'] ?? '',
        'goalOwnerName': owner['goalOwnerName'] ?? '',
        'goalOwnerDepartment': owner['goalOwnerDepartment'] ?? '',
        'userName': userContext['userName'],
        'userEmail': userContext['userEmail'],
        'userRole': userContext['userRole'],
        'timestamp': timestamp,
        'description':
            'New milestone created: "$milestoneTitle" for goal "$goalTitle"',
        'metadata': {
          'milestoneTitle': milestoneTitle,
          'goalTitle': goalTitle,
          'milestoneId': milestoneId,
          'goalId': goalId,
          'goalOwnerId': owner['goalOwnerId'] ?? '',
          'goalOwnerName': owner['goalOwnerName'] ?? '',
          'goalOwnerDepartment': owner['goalOwnerDepartment'] ?? '',
          'createdBy': user?.uid ?? userId ?? 'system',
          'creatorName': userContext['userName'],
          'creatorEmail': userContext['userEmail'],
          'creatorRole': userContext['userRole'],
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

      await _backend.createAuditEntry(event);
      developer.log(
        '✅ Comprehensive milestone creation logged: "$milestoneTitle" for goal "$goalTitle" by ${userContext['userName']}',
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
      final timestamp = DateTime.now().toIso8601String();
      final userContext = await _resolveCurrentUserContext();
      final owner = await _resolveGoalOwnerContext(goalId);

      final event = {
        'action': 'milestone_status_changed',
        'goalId': goalId,
        'goalTitle': goalTitle,
        'milestoneId': milestoneId,
        'milestoneTitle': milestoneTitle,
        'status': _formatStatus(newStatus),
        'userId': user?.uid ?? 'system',
        'userDisplayName': userContext['userName'],
        'userDepartment': userContext['userDepartment'],
        'goalOwnerId': owner['goalOwnerId'] ?? '',
        'goalOwnerName': owner['goalOwnerName'] ?? '',
        'goalOwnerDepartment': owner['goalOwnerDepartment'] ?? '',
        'userName': userContext['userName'],
        'userEmail': userContext['userEmail'],
        'userRole': userContext['userRole'],
        'timestamp': timestamp,
        'description':
            'Milestone status updated: "$milestoneTitle" changed from "$_formatStatus(oldStatus)" to "$_formatStatus(newStatus)"',
        'metadata': {
          'milestoneTitle': milestoneTitle,
          'goalTitle': goalTitle,
          'milestoneId': milestoneId,
          'goalId': goalId,
          'goalOwnerId': owner['goalOwnerId'] ?? '',
          'goalOwnerName': owner['goalOwnerName'] ?? '',
          'goalOwnerDepartment': owner['goalOwnerDepartment'] ?? '',
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

      await _backend.createAuditEntry(event);
      developer.log(
        '✅ Comprehensive milestone status change logged: "$milestoneTitle" from "$oldStatus" to "$newStatus" by ${userContext['userName']}',
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error logging milestone status change: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

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

  static bool _isProgressChange(String oldStatus, String newStatus) {
    const progressStatuses = [
      'NotStarted',
      'InProgress',
      'PendingReview',
      'Completed',
    ];
    return progressStatuses.contains(oldStatus) &&
        progressStatuses.contains(newStatus);
  }

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

  static Stream<List<Map<String, dynamic>>> getMilestoneAuditStream(
    String goalId,
  ) {
    return backendPollingStream<List<Map<String, dynamic>>>(
      initialValue: const [],
      fetch: () async {
        final entries = await _backend.getAuditEntriesWithActions(
          goalId: goalId,
          limit: 50,
        );
        return _filterMilestoneActions(entries);
      },
    );
  }

  static Stream<List<Map<String, dynamic>>> getAllMilestoneAuditStream() {
    return backendPollingStream<List<Map<String, dynamic>>>(
      initialValue: const [],
      fetch: () async {
        final entries = await _backend.getAuditEntriesWithActions(limit: 120);
        return _filterMilestoneActions(entries);
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getMilestoneAudits({
    bool forManager = false,
    bool organizationWide = false,
    Set<String>? allowedUserIds,
    int limit = 120,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }

      final capped = limit.clamp(10, 500);
      final snapshot = await _backend.getAuditEntriesWithActions(limit: capped);
      final allowSet = allowedUserIds ?? const <String>{};
      final enforceUserAllowList = forManager && !organizationWide;
      final audits = _filterMilestoneActions(snapshot).where((audit) {
        final userId = audit['userId']?.toString() ?? '';

        if (organizationWide) {
          return true;
        }
        if (forManager) {
          if (!enforceUserAllowList || allowSet.isEmpty) return false;
          return allowSet.contains(userId);
        } else {
          return userId == user.uid;
        }
      }).toList();

      developer.log(
        'Future query: Found ${audits.length} milestone audits (forManager: $forManager)',
      );
      return audits;
    } catch (e) {
      developer.log('Error in getMilestoneAudits: $e');
      return [];
    }
  }

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

      final goals = await _backend.getGoals(userId: user.uid);
      int totalMilestones = 0;
      int auditEntriesCreated = 0;

      for (final goalData in goals) {
        final goalId = (goalData['id'] ?? '').toString();
        if (goalId.isEmpty) continue;
        final goalTitle = goalData['title']?.toString() ?? 'Unknown Goal';

        final milestones = await _backend.getMilestones(goalId: goalId);
        for (final milestoneData in milestones) {
          totalMilestones++;
          final milestoneId = (milestoneData['id'] ?? '').toString();
          final milestoneTitle =
              milestoneData['title']?.toString() ?? 'Unknown Milestone';

          final existingAudits = await _backend.getAuditEntriesWithActions(
            goalId: goalId,
            action: 'milestone_created',
            limit: 500,
          );
          final alreadyLogged = existingAudits.any(
            (entry) => entry['milestoneId']?.toString() == milestoneId,
          );

          if (!alreadyLogged) {
            await logMilestoneCreated(
              goalId: goalId,
              milestoneId: milestoneId,
              milestoneTitle: milestoneTitle,
              goalTitle: goalTitle,
              userId: milestoneData['createdBy']?.toString() ?? 'unknown',
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
