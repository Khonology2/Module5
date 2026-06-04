// Milestone audit entry model for timeline tracking
import 'package:pdh/utils/date_parse.dart';

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

  factory MilestoneAuditEntry.fromMap(
    Map<String, dynamic> data, {
    String? fallbackId,
  }) {
    return MilestoneAuditEntry(
      id: (data['id'] ?? fallbackId ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      action: (data['action'] ?? '').toString(),
      timestamp: parseDate(data['timestamp']),
      details: data['details']?.toString(),
      changes: data['changes'] is Map
          ? Map<String, dynamic>.from(data['changes'] as Map)
          : null,
      field: data['field'] != null
          ? MilestoneFieldChanged.values.firstWhere(
              (e) => e.name == data['field'],
              orElse: () => MilestoneFieldChanged.title,
            )
          : null,
      fieldType: data['fieldType'] != null
          ? FieldType.values.firstWhere(
              (e) => e.name == data['fieldType'],
              orElse: () => FieldType.string,
            )
          : null,
      change: data['change'] is Map
          ? FieldChange.fromMap(Map<String, dynamic>.from(data['change'] as Map))
          : null,
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
