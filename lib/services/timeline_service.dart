import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:pdh/models/audit_timeline_event.dart';

class TimelineService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> _timelineCollection(
    String goalId,
  ) {
    return _firestore
        .collection('audit_entries')
        .doc(goalId)
        .collection('timeline');
  }

  static Future<void> logEvent(String goalId, AuditTimelineEvent event) async {
    try {
      await _timelineCollection(goalId).add(event.toFirestore());
      developer.log(
        'Timeline event logged: ${event.eventType} for goal $goalId',
      );
    } catch (e) {
      developer.log('Error logging timeline event: $e');
      rethrow;
    }
  }

  static Stream<List<AuditTimelineEvent>> getTimelineStream(String goalId) {
    return _timelineCollection(goalId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AuditTimelineEvent.fromFirestore(doc))
              .toList(),
        );
  }

  // Helper to create an event with current user as actor
  static AuditTimelineEvent buildEvent({
    required String eventType,
    required String description,
  }) {
    final user = _auth.currentUser;
    return AuditTimelineEvent(
      id: '',
      eventType: eventType,
      timestamp: DateTime.now(),
      actorId: user?.uid ?? '',
      actorName: user?.displayName ?? 'Unknown',
      description: description,
    );
  }
}
