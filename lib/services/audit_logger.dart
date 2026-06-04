import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/backend_auth_service.dart';

/// Centralized service for logging audit events and system actions
class AuditLogger {
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
        'timestamp': DateTime.now().toIso8601String(),
        'description': description,
        'metadata': metadata ?? {},
      };

      await BackendAuthService.instance.createAuditEntry(event);
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
        'timestamp': DateTime.now().toIso8601String(),
        'description': description,
        'metadata': metadata ?? {},
      };

      await BackendAuthService.instance.createAuditEntry(event);
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
      await BackendAuthService.instance.createAuditEntry({
        'action': errorType,
        'status': 'error',
        'goalId': 'system',
        'userId': _auth.currentUser?.uid ?? 'system',
        'type': errorType,
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'description': 'Audit logging error',
        'metadata': {
          'stackTrace': stackTrace.toString(),
        },
      });
    } catch (e) {
      // If we can't log the error, at least print it
      developer.log('CRITICAL: Failed to log audit error: $e');
    }
  }
}
