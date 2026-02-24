import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/audit_timeline_event.dart';

class TimelineService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Map<String, dynamic> buildEvent({
    required String eventType,
    required String description,
    String? actorIdOverride,
    String? actorNameOverride,
  }) {
    final user = _auth.currentUser;
    final actorId = actorIdOverride ?? user?.uid ?? '';

    String name = actorNameOverride ?? user?.displayName ?? '';
    if (name.trim().isEmpty) {
      final email = user?.email ?? '';
      if (email.isNotEmpty) {
        name = email.split('@').first;
      } else {
        name = 'Unknown';
      }
    }

    return {
      'eventType': eventType,
      'description': description,
      'timestamp': Timestamp.now(),
      'actorId': actorId,
      'actorName': name,
    };
  }

  static Future<void> logEvent(
    String entryId,
    Map<String, dynamic> event,
  ) async {
    final data = Map<String, dynamic>.from(event);
    data['timestamp'] = data['timestamp'] ?? Timestamp.now();
    await _firestore
        .collection('audit_entries')
        .doc(entryId)
        .collection('timeline')
        .add(data);
  }

  static Stream<List<AuditTimelineEvent>> getTimelineStream(String entryId) {
    return _firestore
        .collection('audit_entries')
        .doc(entryId)
        .collection('timeline')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AuditTimelineEvent.fromFirestore(doc))
              .toList(),
        );
  }
}
