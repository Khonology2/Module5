import 'package:cloud_firestore/cloud_firestore.dart';

enum MilestoneAuditAction { created, updated, statusChanged, deleted }

enum MilestoneFieldChanged {
  title,
  description,
  dueDate,
  status,
  weight,
  goalId,
}

class MilestoneAuditEntry {
  final String id;
  final String milestoneId;
  final String goalId;
  final String goalTitle;
  final MilestoneAuditAction action;
  final Map<MilestoneFieldChanged, FieldChange> fieldChanges;
  final String userId;
  final String? userName;
  final String? userRole;
  final String? userDepartment;
  final DateTime timestamp;
  final String? changeReason;
  final Map<String, dynamic>? metadata;

  const MilestoneAuditEntry({
    required this.id,
    required this.milestoneId,
    required this.goalId,
    required this.goalTitle,
    required this.action,
    required this.fieldChanges,
    required this.userId,
    this.userName,
    this.userRole,
    this.userDepartment,
    required this.timestamp,
    this.changeReason,
    this.metadata,
  });

  factory MilestoneAuditEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse field changes
    final fieldChangesData =
        data['fieldChanges'] as Map<String, dynamic>? ?? {};
    final fieldChanges = <MilestoneFieldChanged, FieldChange>{};

    for (final entry in fieldChangesData.entries) {
      final field = _milestoneFieldFromString(entry.key);
      if (field != null) {
        final changeData = entry.value as Map<String, dynamic>;
        fieldChanges[field] = FieldChange(
          oldValue: changeData['oldValue'],
          newValue: changeData['newValue'],
          fieldType: _stringToFieldType(changeData['fieldType']),
        );
      }
    }

    return MilestoneAuditEntry(
      id: doc.id,
      milestoneId: data['milestoneId'] ?? '',
      goalId: data['goalId'] ?? '',
      goalTitle: data['goalTitle'] ?? '',
      action: _actionFromString(data['action']),
      fieldChanges: fieldChanges,
      userId: data['userId'] ?? '',
      userName: data['userName'],
      userRole: data['userRole'],
      userDepartment: data['userDepartment'],
      timestamp: _parseDate(data['timestamp']) ?? DateTime.now(),
      changeReason: data['changeReason'],
      metadata: data['metadata'],
    );
  }

  static MilestoneAuditAction _actionFromString(String? value) {
    if (value == null) return MilestoneAuditAction.updated;
    return MilestoneAuditAction.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MilestoneAuditAction.updated,
    );
  }

  static MilestoneFieldChanged? _milestoneFieldFromString(String? value) {
    if (value == null) return null;
    return MilestoneFieldChanged.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MilestoneFieldChanged.title,
    );
  }

  static FieldType _stringToFieldType(String? value) {
    if (value == null) return FieldType.string;
    return FieldType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FieldType.string,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    final parsed = DateTime.tryParse(v.toString());
    return parsed;
  }

  Map<String, dynamic> toFirestore() {
    final fieldChangesMap = <String, dynamic>{};
    for (final entry in fieldChanges.entries) {
      fieldChangesMap[entry.key.name] = {
        'oldValue': entry.value.oldValue,
        'newValue': entry.value.newValue,
        'fieldType': entry.value.fieldType.name,
      };
    }

    return {
      'milestoneId': milestoneId,
      'goalId': goalId,
      'goalTitle': goalTitle,
      'action': action.name,
      'fieldChanges': fieldChangesMap,
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'userDepartment': userDepartment,
      'timestamp': Timestamp.fromDate(timestamp),
      'changeReason': changeReason,
      'metadata': metadata,
    };
  }

  /// Create an audit entry for milestone creation
  static MilestoneAuditEntry createCreationEntry({
    required String milestoneId,
    required String goalId,
    required String goalTitle,
    required String userId,
    String? userName,
    String? userRole,
    String? userDepartment,
    String? changeReason,
    Map<String, dynamic>? metadata,
  }) {
    return MilestoneAuditEntry(
      id: '', // Will be set by Firestore
      milestoneId: milestoneId,
      goalId: goalId,
      goalTitle: goalTitle,
      action: MilestoneAuditAction.created,
      fieldChanges: {},
      userId: userId,
      userName: userName,
      userRole: userRole,
      userDepartment: userDepartment,
      timestamp: DateTime.now(),
      changeReason: changeReason,
      metadata: metadata,
    );
  }

  /// Create an audit entry for milestone update with field changes
  static MilestoneAuditEntry createUpdateEntry({
    required String milestoneId,
    required String goalId,
    required String goalTitle,
    required Map<MilestoneFieldChanged, FieldChange> fieldChanges,
    required String userId,
    String? userName,
    String? userRole,
    String? userDepartment,
    String? changeReason,
    Map<String, dynamic>? metadata,
  }) {
    return MilestoneAuditEntry(
      id: '', // Will be set by Firestore
      milestoneId: milestoneId,
      goalId: goalId,
      goalTitle: goalTitle,
      action: MilestoneAuditAction.updated,
      fieldChanges: fieldChanges,
      userId: userId,
      userName: userName,
      userRole: userRole,
      userDepartment: userDepartment,
      timestamp: DateTime.now(),
      changeReason: changeReason,
      metadata: metadata,
    );
  }
}

class FieldChange {
  final dynamic oldValue;
  final dynamic newValue;
  final FieldType fieldType;

  const FieldChange({
    required this.oldValue,
    required this.newValue,
    required this.fieldType,
  });

  @override
  String toString() {
    return '$fieldType: $oldValue → $newValue';
  }
}

enum FieldType { string, number, boolean, dateTime, list, map }
