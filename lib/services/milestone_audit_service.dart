import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/goal_milestone.dart';
import 'package:pdh/models/milestone_audit_entry.dart';

class MilestoneAuditService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Log milestone creation in audit trail
  static Future<void> logMilestoneCreation({
    required String goalId,
    required String goalTitle,
    required String milestoneId,
    String? changeReason,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user details
      final userDetails = await _getUserDetails(user.uid);

      final auditEntry = MilestoneAuditEntry.createCreationEntry(
        milestoneId: milestoneId,
        goalId: goalId,
        goalTitle: goalTitle,
        userId: user.uid,
        userName: userDetails['displayName'],
        userRole: userDetails['role'],
        userDepartment: userDetails['department'],
        changeReason: changeReason,
        metadata: metadata,
      );

      await _firestore
          .collection('milestone_audit_entries')
          .add(auditEntry.toFirestore());

      developer.log(
        'Milestone creation logged: $milestoneId for goal $goalId',
        name: 'MilestoneAuditService',
      );
    } catch (e) {
      developer.log(
        'Error logging milestone creation: $e',
        name: 'MilestoneAuditService',
        error: e,
      );
      // Don't throw - audit logging shouldn't break the main flow
    }
  }

  /// Log milestone update with field changes in audit trail
  static Future<void> logMilestoneUpdate({
    required String goalId,
    required String goalTitle,
    required String milestoneId,
    required GoalMilestone previousMilestone,
    required GoalMilestone updatedMilestone,
    String? changeReason,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Detect field changes
      final fieldChanges = _detectFieldChanges(
        previousMilestone,
        updatedMilestone,
      );

      // Only log if there are actual changes
      if (fieldChanges.isEmpty) {
        developer.log(
          'No field changes detected for milestone $milestoneId - skipping audit log',
          name: 'MilestoneAuditService',
        );
        return;
      }

      // Get user details
      final userDetails = await _getUserDetails(user.uid);

      final auditEntry = MilestoneAuditEntry.createUpdateEntry(
        milestoneId: milestoneId,
        goalId: goalId,
        goalTitle: goalTitle,
        fieldChanges: fieldChanges,
        userId: user.uid,
        userName: userDetails['displayName'],
        userRole: userDetails['role'],
        userDepartment: userDetails['department'],
        changeReason: changeReason,
        metadata: metadata,
      );

      await _firestore
          .collection('milestone_audit_entries')
          .add(auditEntry.toFirestore());

      developer.log(
        'Milestone update logged: $milestoneId with ${fieldChanges.length} field changes',
        name: 'MilestoneAuditService',
      );
    } catch (e) {
      developer.log(
        'Error logging milestone update: $e',
        name: 'MilestoneAuditService',
        error: e,
      );
      // Don't throw - audit logging shouldn't break the main flow
    }
  }

  /// Log milestone status change specifically
  static Future<void> logMilestoneStatusChange({
    required String goalId,
    required String goalTitle,
    required String milestoneId,
    required GoalMilestoneStatus previousStatus,
    required GoalMilestoneStatus newStatus,
    String? changeReason,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user details
      final userDetails = await _getUserDetails(user.uid);

      final fieldChanges = {
        MilestoneFieldChanged.status: FieldChange(
          oldValue: previousStatus.name,
          newValue: newStatus.name,
          fieldType: FieldType.string,
        ),
      };

      final auditEntry = MilestoneAuditEntry.createUpdateEntry(
        milestoneId: milestoneId,
        goalId: goalId,
        goalTitle: goalTitle,
        fieldChanges: fieldChanges,
        userId: user.uid,
        userName: userDetails['displayName'],
        userRole: userDetails['role'],
        userDepartment: userDetails['department'],
        changeReason: changeReason,
        metadata: metadata,
      );

      await _firestore
          .collection('milestone_audit_entries')
          .add(auditEntry.toFirestore());

      developer.log(
        'Milestone status change logged: $milestoneId from $previousStatus to $newStatus',
        name: 'MilestoneAuditService',
      );
    } catch (e) {
      developer.log(
        'Error logging milestone status change: $e',
        name: 'MilestoneAuditService',
        error: e,
      );
      // Don't throw - audit logging shouldn't break the main flow
    }
  }

  /// Get audit entries for a specific milestone
  static Stream<List<MilestoneAuditEntry>> getMilestoneAuditStream(
    String milestoneId,
  ) {
    try {
      return _firestore
          .collection('milestone_audit_entries')
          .where('milestoneId', isEqualTo: milestoneId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => MilestoneAuditEntry.fromFirestore(doc))
                .toList();
          })
          .handleError((error, stackTrace) {
            developer.log(
              'Error getting milestone audit stream: $error',
              name: 'MilestoneAuditService',
              error: error,
              stackTrace: stackTrace,
            );
            return <MilestoneAuditEntry>[];
          });
    } catch (e) {
      developer.log(
        'Error building milestone audit stream: $e',
        name: 'MilestoneAuditService',
        error: e,
      );
      return Stream.value(<MilestoneAuditEntry>[]);
    }
  }

  /// Get audit entries for a goal (all milestones in that goal)
  static Stream<List<MilestoneAuditEntry>> getGoalAuditStream(String goalId) {
    try {
      return _firestore
          .collection('milestone_audit_entries')
          .where('goalId', isEqualTo: goalId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => MilestoneAuditEntry.fromFirestore(doc))
                .toList();
          })
          .handleError((error, stackTrace) {
            developer.log(
              'Error getting goal audit stream: $error',
              name: 'MilestoneAuditService',
              error: error,
              stackTrace: stackTrace,
            );
            return <MilestoneAuditEntry>[];
          });
    } catch (e) {
      developer.log(
        'Error building goal audit stream: $e',
        name: 'MilestoneAuditService',
        error: e,
      );
      return Stream.value(<MilestoneAuditEntry>[]);
    }
  }

  /// Get all milestone audit entries (for debugging)
  static Future<List<MilestoneAuditEntry>> getAllMilestoneAudits() async {
    try {
      final snapshot = await _firestore
          .collection('milestone_audit_entries')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final audits = snapshot.docs
          .map((doc) => MilestoneAuditEntry.fromFirestore(doc))
          .toList();

      developer.log('Found ${audits.length} milestone audit entries');
      for (final audit in audits) {
        developer.log(
          'Audit: ${audit.action} on ${audit.goalTitle} by ${audit.userName}',
        );
      }

      return audits;
    } catch (e) {
      developer.log('Error getting all milestone audits: $e');
      return [];
    }
  }

  /// Get all milestone audit entries (simple stream for testing)
  static Stream<List<MilestoneAuditEntry>> getAllMilestoneAuditStream() {
    try {
      return _firestore
          .collection('milestone_audit_entries')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .map((snapshot) {
            try {
              return snapshot.docs
                  .map((doc) => MilestoneAuditEntry.fromFirestore(doc))
                  .toList();
            } catch (e) {
              developer.log(
                'Error processing all milestone audit entries: $e',
                name: 'MilestoneAuditService',
              );
              return <MilestoneAuditEntry>[];
            }
          })
          .handleError((error, stackTrace) {
            developer.log(
              'All milestone audit stream error: $error',
              name: 'MilestoneAuditService',
              error: error,
              stackTrace: stackTrace,
            );
            return <MilestoneAuditEntry>[];
          });
    } catch (e) {
      developer.log(
        'Error building all milestone audit stream: $e',
        name: 'MilestoneAuditService',
        error: e,
      );
      return Stream.value(<MilestoneAuditEntry>[]);
    }
  }

  /// Get audit entries for managers (all milestone changes in their department)
  static Stream<List<MilestoneAuditEntry>> getManagerAuditStream({
    String? goalId,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    try {
      Query query = _firestore.collection('milestone_audit_entries');

      if (goalId != null && goalId.isNotEmpty) {
        query = query.where('goalId', isEqualTo: goalId);
      }

      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      query = query.orderBy('timestamp', descending: true).limit(200);

      return query
          .snapshots()
          .map((snapshot) {
            try {
              List<MilestoneAuditEntry> entries = snapshot.docs
                  .map((doc) => MilestoneAuditEntry.fromFirestore(doc))
                  .toList();

              // Apply search filter if provided
              if (searchQuery != null && searchQuery.isNotEmpty) {
                final lowercaseQuery = searchQuery.toLowerCase();
                entries = entries.where((entry) {
                  return entry.goalTitle.toLowerCase().contains(
                        lowercaseQuery,
                      ) ||
                      entry.milestoneId.toLowerCase().contains(
                        lowercaseQuery,
                      ) ||
                      (entry.userName?.toLowerCase().contains(lowercaseQuery) ??
                          false) ||
                      (entry.userDepartment?.toLowerCase().contains(
                            lowercaseQuery,
                          ) ??
                          false);
                }).toList();
              }

              return entries;
            } catch (e) {
              developer.log(
                'Error processing manager audit entries: $e',
                name: 'MilestoneAuditService',
              );
              return <MilestoneAuditEntry>[];
            }
          })
          .handleError((error, stackTrace) {
            developer.log(
              'Manager audit stream error: $error',
              name: 'MilestoneAuditService',
              error: error,
              stackTrace: stackTrace,
            );
            return <MilestoneAuditEntry>[];
          });
    } catch (e) {
      developer.log(
        'Error building manager audit stream: $e',
        name: 'MilestoneAuditService',
        error: e,
      );
      return Stream.value(<MilestoneAuditEntry>[]);
    }
  }

  /// Detect changes between two milestone instances
  static Map<MilestoneFieldChanged, FieldChange> _detectFieldChanges(
    GoalMilestone previous,
    GoalMilestone updated,
  ) {
    final changes = <MilestoneFieldChanged, FieldChange>{};

    // Check title change
    if (previous.title != updated.title) {
      changes[MilestoneFieldChanged.title] = FieldChange(
        oldValue: previous.title,
        newValue: updated.title,
        fieldType: FieldType.string,
      );
    }

    // Check description change
    if (previous.description != updated.description) {
      changes[MilestoneFieldChanged.description] = FieldChange(
        oldValue: previous.description,
        newValue: updated.description,
        fieldType: FieldType.string,
      );
    }

    // Check due date change
    if (previous.dueDate != updated.dueDate) {
      changes[MilestoneFieldChanged.dueDate] = FieldChange(
        oldValue: previous.dueDate.toIso8601String(),
        newValue: updated.dueDate.toIso8601String(),
        fieldType: FieldType.dateTime,
      );
    }

    // Check status change
    if (previous.status != updated.status) {
      changes[MilestoneFieldChanged.status] = FieldChange(
        oldValue: previous.status.name,
        newValue: updated.status.name,
        fieldType: FieldType.string,
      );
    }

    // Check goal ID change (rare but possible)
    if (previous.goalId != updated.goalId) {
      changes[MilestoneFieldChanged.goalId] = FieldChange(
        oldValue: previous.goalId,
        newValue: updated.goalId,
        fieldType: FieldType.string,
      );
    }

    return changes;
  }

  /// Get user details for audit logging
  static Future<Map<String, String?>> _getUserDetails(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};

      return {
        'displayName': userData['displayName']?.toString(),
        'role': userData['role']?.toString(),
        'department': userData['department']?.toString(),
      };
    } catch (e) {
      developer.log(
        'Error getting user details: $e',
        name: 'MilestoneAuditService',
      );
      return {'displayName': null, 'role': null, 'department': null};
    }
  }

  /// Get audit statistics for managers
  static Future<Map<String, dynamic>> getMilestoneAuditStats({
    String? department,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('milestone_audit_entries');

      if (department != null && department.isNotEmpty) {
        query = query.where('userDepartment', isEqualTo: department);
      }

      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.limit(1000).get();
      final entries = snapshot.docs
          .map((doc) => MilestoneAuditEntry.fromFirestore(doc))
          .toList();

      final stats = <String, dynamic>{
        'total': entries.length,
        'created': entries
            .where((e) => e.action == MilestoneAuditAction.created)
            .length,
        'updated': entries
            .where((e) => e.action == MilestoneAuditAction.updated)
            .length,
        'statusChanges': entries
            .where(
              (e) => e.fieldChanges.containsKey(MilestoneFieldChanged.status),
            )
            .length,
        'byUser': <String, int>{},
        'byAction': <String, int>{},
        'recentActivity': <Map<String, dynamic>>[],
      };

      // Group by user
      for (final entry in entries) {
        final userName = entry.userName ?? 'Unknown';
        stats['byUser'][userName] = (stats['byUser'][userName] ?? 0) + 1;
      }

      // Group by action
      for (final entry in entries) {
        final action = entry.action.name;
        stats['byAction'][action] = (stats['byAction'][action] ?? 0) + 1;
      }

      // Recent activity
      stats['recentActivity'] = entries
          .take(10)
          .map(
            (entry) => {
              'milestoneId': entry.milestoneId,
              'goalTitle': entry.goalTitle,
              'action': entry.action.name,
              'userName': entry.userName,
              'timestamp': entry.timestamp.toIso8601String(),
              'fieldCount': entry.fieldChanges.length,
            },
          )
          .toList();

      return stats;
    } catch (e) {
      developer.log(
        'Error getting milestone audit stats: $e',
        name: 'MilestoneAuditService',
      );
      return {
        'total': 0,
        'created': 0,
        'updated': 0,
        'statusChanges': 0,
        'byUser': <String, int>{},
        'byAction': <String, int>{},
        'recentActivity': <Map<String, dynamic>>[],
      };
    }
  }
}
