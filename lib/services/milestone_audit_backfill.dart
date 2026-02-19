import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/milestone_audit_entry.dart';
import 'package:pdh/models/goal_milestone.dart';
import 'package:flutter/foundation.dart';

/// Service to create audit entries for existing milestones (one-time backfill)
class MilestoneAuditBackfill {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create audit entries for all existing milestones (one-time operation)
  static Future<void> backfillExistingMilestones() async {
    if (kDebugMode) {
      print('Starting milestone audit backfill...');
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get all goals
      final goalsSnapshot = await _firestore.collection('goals').get();

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
          final milestone = GoalMilestone.fromFirestore(milestoneDoc);
          final milestoneId = milestoneDoc.id;

          // Check if audit entry already exists for this milestone
          final existingAuditSnapshot = await _firestore
              .collection('milestone_audit_entries')
              .where('milestoneId', isEqualTo: milestoneId)
              .where('action', isEqualTo: MilestoneAuditAction.created.name)
              .limit(1)
              .get();

          if (existingAuditSnapshot.docs.isEmpty) {
            // Create audit entry for existing milestone
            final auditEntry = MilestoneAuditEntry.createCreationEntry(
              goalId: goalId,
              goalTitle: goalTitle,
              milestoneId: milestoneId,
              userId: milestone.createdBy,
              userName: milestone.createdByName,
              userRole: 'employee', // Default role
              userDepartment: 'Not specified', // Default department
              changeReason:
                  'Backfill: Existing milestone imported into audit trail',
            );

            await _firestore
                .collection('milestone_audit_entries')
                .add(auditEntry.toFirestore());

            auditEntriesCreated++;

            if (kDebugMode) {
              print(
                'Created audit entry for milestone: ${milestone.title} (${milestone.status.name})',
              );
            }
          } else {
            if (kDebugMode) {
              print(
                'Audit entry already exists for milestone: ${milestone.title}',
              );
            }
          }
        }
      }

      if (kDebugMode) {
        print('Backfill completed successfully!');
        print('Total milestones processed: $totalMilestones');
        print('Total audit entries created: $auditEntriesCreated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during backfill: $e');
      }
      rethrow;
    }
  }

  /// Create audit entries for milestones with status changes (for milestones that aren't in default status)
  static Future<void> backfillStatusChanges() async {
    if (kDebugMode) {
      print('Starting milestone status change backfill...');
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get all goals
      final goalsSnapshot = await _firestore.collection('goals').get();

      int statusChangesFound = 0;

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
          final milestone = GoalMilestone.fromFirestore(milestoneDoc);
          final milestoneId = milestoneDoc.id;

          // If milestone is not in default status, create a status change audit
          if (milestone.status != GoalMilestoneStatus.notStarted) {
            // Check if status change audit already exists
            final existingStatusAuditSnapshot = await _firestore
                .collection('milestone_audit_entries')
                .where('milestoneId', isEqualTo: milestoneId)
                .where(
                  'action',
                  isEqualTo: MilestoneAuditAction.statusChanged.name,
                )
                .limit(1)
                .get();

            if (existingStatusAuditSnapshot.docs.isEmpty) {
              // Create status change audit entry
              final fieldChange = FieldChange(
                oldValue: GoalMilestoneStatus.notStarted.name,
                newValue: milestone.status.name,
                fieldType: FieldType.string,
              );

              final auditEntry = MilestoneAuditEntry(
                id: '', // Will be set by Firestore
                goalId: goalId,
                goalTitle: goalTitle,
                milestoneId: milestoneId,
                action: MilestoneAuditAction.statusChanged,
                fieldChanges: {MilestoneFieldChanged.status: fieldChange},
                userId: milestone.createdBy,
                userName: milestone.createdByName,
                userRole: 'employee',
                userDepartment: 'Not specified',
                timestamp: milestone.createdAt, // Use milestone creation time
                changeReason:
                    'Backfill: Milestone status imported into audit trail',
              );

              await _firestore
                  .collection('milestone_audit_entries')
                  .add(auditEntry.toFirestore());

              statusChangesFound++;

              if (kDebugMode) {
                print(
                  'Created status audit for milestone: ${milestone.title} (${milestone.status.name})',
                );
              }
            }
          }
        }
      }

      if (kDebugMode) {
        print('Status backfill completed successfully!');
        print('Total status changes processed: $statusChangesFound');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during status backfill: $e');
      }
      rethrow;
    }
  }

  /// Run complete backfill (creation + status changes)
  static Future<void> runCompleteBackfill() async {
    try {
      await backfillExistingMilestones();
      await backfillStatusChanges();

      if (kDebugMode) {
        print('Complete backfill finished successfully!');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Complete backfill failed: $e');
      }
      rethrow;
    }
  }
}
