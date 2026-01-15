import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Centralized service for logging audit events and system actions
class AuditLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Logs a general audit action for a goal
  static Future<void> logAuditAction({
    required String goalId,
    required String actionType,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      final event = {
        'action': actionType,
        'goalId': goalId,
        'userId': user?.uid ?? 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'description': description,
        'metadata': metadata ?? {},
      };
      
      await _firestore.collection('audit_entries').add(event);
      developer.log('Audit action logged: $actionType for goal $goalId');
    } catch (e, stackTrace) {
      developer.log(
        'Error logging audit action: $e',
        error: e,
        stackTrace: stackTrace,
      );
      await _logError('audit_action', e, stackTrace);
    }
  }

  /// Logs a goal deletion event with detailed metadata
  static Future<void> logGoalDeletion({
    required String goalId,
    required String deletedBy,
    required Map<String, dynamic> goalData,
    String? reason,
    bool deletedByAdmin = false,
  }) async {
    try {
      final event = {
        'action': 'goal_deleted',
        'goalId': goalId,
        'userId': goalData['userId'] ?? 'unknown',
        'deletedBy': deletedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'goalTitle': goalData['title'] ?? 'Untitled Goal',
          'goalStatus': goalData['status'] ?? 'unknown',
          'deletionReason': reason,
          'deletedByAdmin': deletedByAdmin,
          'relatedEntitiesDeleted': true,
        },
      };

      await _firestore.collection('audit_entries').add(event);
      developer.log('Goal deletion logged: $goalId by $deletedBy');
    } catch (e, stackTrace) {
      developer.log(
        'Error logging goal deletion: $e',
        error: e,
        stackTrace: stackTrace,
      );
      await _logError('goal_deletion', e, stackTrace);
    }
  }

  /// Logs a system event (not tied to a specific goal)
  static Future<void> logSystemEvent({
    required String eventType,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      final event = {
        'action': eventType,
        'userId': user?.uid ?? 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'description': description,
        'metadata': metadata ?? {},
      };

      await _firestore.collection('audit_entries').add(event);
      developer.log('System event logged: $eventType - $description');
    } catch (e, stackTrace) {
      developer.log(
        'Error logging system event: $e',
        error: e,
        stackTrace: stackTrace,
      );
      await _logError('system_event', e, stackTrace);
    }
  }

  /// Internal method to log errors that occur during audit logging
  static Future<void> _logError(
    String errorType,
    dynamic error,
    StackTrace stackTrace,
  ) async {
    try {
      await _firestore.collection('audit_errors').add({
        'type': errorType,
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // If we can't log the error, at least print it
      developer.log('CRITICAL: Failed to log audit error: $e');
    }
  }
}
