import 'package:cloud_firestore/cloud_firestore.dart';

class AuditTimelineEvent {
  final String id; // Firestore doc ID
  final String eventType; // submission, verification, rejection, update, etc.
  final DateTime timestamp;
  final String actorId;
  final String actorName;
  final String description;

  AuditTimelineEvent({
    required this.id,
    required this.eventType,
    required this.timestamp,
    required this.actorId,
    required this.actorName,
    required this.description,
  });

  factory AuditTimelineEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditTimelineEvent(
      id: doc.id,
      eventType: data['eventType'] ?? 'update',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      actorId: data['actorId'] ?? '',
      actorName: data['actorName'] ?? '',
      description: data['description'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventType': eventType,
      'timestamp': Timestamp.fromDate(timestamp),
      'actorId': actorId,
      'actorName': actorName,
      'description': description,
    };
  }
}
