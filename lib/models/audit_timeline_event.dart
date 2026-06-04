import 'package:pdh/utils/date_parse.dart';

class AuditTimelineEvent {
  final String id; // Backend record id
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

  factory AuditTimelineEvent.fromMap(Map<String, dynamic> data, {String? fallbackId}) {
    return AuditTimelineEvent(
      id: (data['id'] ?? fallbackId ?? '').toString(),
      eventType: (data['eventType'] ?? 'update').toString(),
      timestamp: parseDate(data['timestamp'] ?? data['createdAt']),
      actorId: (data['actorId'] ?? '').toString(),
      actorName: (data['actorName'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'eventType': eventType,
      'timestamp': timestamp.toIso8601String(),
      'actorId': actorId,
      'actorName': actorName,
      'description': description,
    };
  }
}
