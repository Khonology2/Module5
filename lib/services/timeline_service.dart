import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/audit_timeline_event.dart';
import 'package:pdh/services/backend_auth_service.dart';

class TimelineService {
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
      'timestamp': DateTime.now().toIso8601String(),
      'actorId': actorId,
      'actorName': name,
    };
  }

  static Future<void> logEvent(
    String entryId,
    Map<String, dynamic> event,
  ) async {
    await BackendAuthService.instance.addAuditTimelineEvent(
      entryId,
      Map<String, dynamic>.from(event),
    );
  }

  static Stream<List<AuditTimelineEvent>> getTimelineStream(String entryId) {
    return _pollTimeline(entryId);
  }

  static Stream<List<AuditTimelineEvent>> _pollTimeline(String entryId) async* {
    while (true) {
      try {
        final items = await BackendAuthService.instance.getAuditTimeline(entryId);
        yield items.map((item) => AuditTimelineEvent.fromMap(item)).toList();
      } catch (_) {
        yield <AuditTimelineEvent>[];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }
}
