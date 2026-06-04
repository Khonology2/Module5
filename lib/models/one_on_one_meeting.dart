enum OneOnOneMeetingStatus {
  requested,
  proposed,
  accepted,
  rescheduled,
  cancelled,
}

enum OneOnOneWaitingOn {
  employee,
  manager,
  none,
}

class OneOnOneMeeting {
  final String meetingId;
  final String managerId;
  final String employeeId;
  final OneOnOneMeetingStatus status;
  final OneOnOneWaitingOn waitingOn;
  final DateTime? proposedStartDateTime;
  final DateTime? proposedEndDateTime;
  final String? agenda;
  final String? employeeMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OneOnOneMeeting({
    required this.meetingId,
    required this.managerId,
    required this.employeeId,
    required this.status,
    required this.waitingOn,
    required this.proposedStartDateTime,
    required this.proposedEndDateTime,
    required this.agenda,
    required this.employeeMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  static OneOnOneMeetingStatus _parseStatus(dynamic v) {
    final raw = v?.toString() ?? OneOnOneMeetingStatus.requested.name;
    return OneOnOneMeetingStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => OneOnOneMeetingStatus.requested,
    );
  }

  static OneOnOneWaitingOn _parseWaitingOn(dynamic v) {
    final raw = v?.toString() ?? OneOnOneWaitingOn.employee.name;
    return OneOnOneWaitingOn.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => OneOnOneWaitingOn.employee,
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v is DateTime) return v;
    final parsed = DateTime.tryParse(v?.toString() ?? '');
    return parsed ?? DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic v) {
    if (v == null) return null;
    return _parseDate(v);
  }

  factory OneOnOneMeeting.fromMap(Map<String, dynamic> data, {String? id}) {
    final proposedStart =
        _parseNullableDate(data['proposedStartDateTime']) ??
        _parseNullableDate(data['proposedDateTime']);
    final proposedEnd = _parseNullableDate(data['proposedEndDateTime']);

    return OneOnOneMeeting(
      meetingId: (data['meetingId'] ?? data['id'] ?? id ?? '').toString(),
      managerId: data['managerId']?.toString() ?? '',
      employeeId: data['employeeId']?.toString() ?? '',
      status: _parseStatus(data['status']),
      waitingOn: _parseWaitingOn(data['waitingOn']),
      proposedStartDateTime: proposedStart,
      proposedEndDateTime: proposedEnd,
      agenda: data['agenda']?.toString(),
      employeeMessage: data['employeeMessage']?.toString(),
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'meetingId': meetingId,
      'id': meetingId,
      'managerId': managerId,
      'employeeId': employeeId,
      'status': status.name,
      'waitingOn': waitingOn.name,
      'proposedStartDateTime': proposedStartDateTime?.toIso8601String(),
      'proposedEndDateTime': proposedEndDateTime?.toIso8601String(),
      'proposedDateTime': proposedStartDateTime?.toIso8601String(),
      'agenda': agenda,
      'employeeMessage': employeeMessage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
