import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> logAuditAction({
    required String goalId,
    required String actionType,
    required String description,
  }) async {
    try {
      final user = _auth.currentUser;
      final event = {
        'eventType': actionType,
        'timestamp': FieldValue.serverTimestamp(),
        'actorId': user?.uid ?? '',
        'actorName': user?.displayName ?? 'Unknown',
        'description': description,
      };
      await _firestore
          .collection('audit_entries')
          .doc(goalId)
          .collection('timeline')
          .add(event);
      developer.log('Audit action logged: $actionType for $goalId');
    } catch (e) {
      developer.log('Error logging audit action: $e');
    }
  }
}
