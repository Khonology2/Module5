import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/audit_timeline_event.dart';
import 'package:pdh/models/milestone_audit_entry.dart';
import 'package:pdh/services/milestone_audit_service.dart';
import 'dart:async';

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
    // Get regular timeline events
    final timelineStream = _firestore
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

    // Get milestone audit entries and convert them to timeline events
    final milestoneAuditStream = MilestoneAuditService.getManagerAuditStream()
        .map((milestoneAudits) {
          return milestoneAudits.where((audit) => audit.goalId == entryId).map((
            audit,
          ) {
            return AuditTimelineEvent(
              id: audit.id,
              eventType: _mapMilestoneActionToEventType(audit.action),
              timestamp: audit.timestamp,
              actorId: audit.userId,
              actorName: audit.userName ?? 'Unknown User',
              description: _buildMilestoneAuditDescription(audit),
            );
          }).toList();
        });

    // Combine both streams using a controller for better control
    final controller = StreamController<List<AuditTimelineEvent>>();
    List<AuditTimelineEvent> allEvents = [];

    timelineStream.listen((timelineEvents) {
      allEvents = [...allEvents, ...timelineEvents];
      allEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      controller.add(allEvents);
    });

    milestoneAuditStream.listen((milestoneEvents) {
      allEvents = [...allEvents, ...milestoneEvents];
      allEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      controller.add(allEvents);
    });

    return controller.stream;
  }

  static String _mapMilestoneActionToEventType(MilestoneAuditAction action) {
    switch (action) {
      case MilestoneAuditAction.created:
        return 'milestone_created';
      case MilestoneAuditAction.updated:
        return 'milestone_updated';
      case MilestoneAuditAction.statusChanged:
        return 'milestone_status_changed';
      case MilestoneAuditAction.deleted:
        return 'milestone_deleted';
    }
  }

  static String _buildMilestoneAuditDescription(MilestoneAuditEntry audit) {
    final fieldChanges = audit.fieldChanges.entries
        .map((entry) {
          final fieldName = _getFieldDisplayName(entry.key);
          return '$fieldName: ${entry.value.oldValue} → ${entry.value.newValue}';
        })
        .join(', ');

    switch (audit.action) {
      case MilestoneAuditAction.created:
        return 'Milestone "${audit.milestoneId}" was created';
      case MilestoneAuditAction.updated:
        return 'Milestone "${audit.milestoneId}" was updated: $fieldChanges';
      case MilestoneAuditAction.statusChanged:
        return 'Milestone "${audit.milestoneId}" status changed: $fieldChanges';
      case MilestoneAuditAction.deleted:
        return 'Milestone "${audit.milestoneId}" was deleted';
    }
  }

  static String _getFieldDisplayName(MilestoneFieldChanged field) {
    switch (field) {
      case MilestoneFieldChanged.title:
        return 'Title';
      case MilestoneFieldChanged.description:
        return 'Description';
      case MilestoneFieldChanged.dueDate:
        return 'Due Date';
      case MilestoneFieldChanged.status:
        return 'Status';
      case MilestoneFieldChanged.weight:
        return 'Weight';
      case MilestoneFieldChanged.goalId:
        return 'Goal';
    }
  }
}
