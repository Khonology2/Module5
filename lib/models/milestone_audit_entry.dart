// Milestone audit entry model for timeline tracking
import 'package:cloud_firestore/cloud_firestore.dart';

enum MilestoneAuditAction {
  created,
  updated,
  statusChanged,
  deleted,
}

enum MilestoneFieldChanged {
  title,
  description,
  dueDate,
  status,
  weight,
  goalId,
}

enum FieldType {
  string,
  number,
  boolean,
  dateTime,
  list,
  map,
}

class MilestoneAuditEntry {
  final String id;
  final String userId;
  final String action;
  final DateTime timestamp;
  final String? details;
  final Map<String, dynamic>? changes;
  final MilestoneFieldChanged? field;
  final FieldType? fieldType;
  final FieldChange? change;

  MilestoneAuditEntry({
    required this.id,
    required this.userId,
    required this.action,
    required this.timestamp,
    this.details,
    this.changes,
    this.field,
    this.fieldType,
    this.change,
  });

  factory MilestoneAuditEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MilestoneAuditEntry(
      id: doc.id,
      userId: data['userId'] ?? '',
      action: data['action'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      details: data['details'],
      changes: data['changes'],
      field: data['field'] != null ? MilestoneFieldChanged.values.firstWhere(
        (e) => e.name == data['field'],
        orElse: () => MilestoneFieldChanged.title,
      ) : null,
      fieldType: data['fieldType'] != null ? FieldType.values.firstWhere(
        (e) => e.name == data['fieldType'],
        orElse: () => FieldType.string,
      ) : null,
      change: data['change'] != null ? FieldChange.fromMap(data['change']) : null,
    );
  }
}

class FieldChange {
  final dynamic oldValue;
  final dynamic newValue;

  FieldChange({
    required this.oldValue,
    required this.newValue,
  });

  factory FieldChange.fromMap(Map<String, dynamic> map) {
    return FieldChange(
      oldValue: map['oldValue'],
      newValue: map['newValue'],
    );
  }
}
