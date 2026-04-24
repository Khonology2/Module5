import 'package:cloud_firestore/cloud_firestore.dart';

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
  /// Proposed meeting start time (local display; stored in Firestore as Timestamp).
  final DateTime? proposedStartDateTime;

  /// Proposed meeting end time (local display; stored in Firestore as Timestamp).
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

  factory OneOnOneMeeting.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    OneOnOneMeetingStatus parseStatus(dynamic v) {
      final raw = v?.toString() ?? OneOnOneMeetingStatus.requested.name;
      return OneOnOneMeetingStatus.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => OneOnOneMeetingStatus.requested,
      );
    }

    OneOnOneWaitingOn parseWaitingOn(dynamic v) {
      final raw = v?.toString() ?? OneOnOneWaitingOn.employee.name;
      return OneOnOneWaitingOn.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => OneOnOneWaitingOn.employee,
      );
    }

    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      final parsed = DateTime.tryParse(v?.toString() ?? '');
      return parsed ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic v) {
      if (v == null) return null;
      return parseDate(v);
    }

    final proposedStart =
        parseNullableDate(data['proposedStartDateTime']) ??
        // Backwards compatibility: older docs used a single proposedDateTime.
        parseNullableDate(data['proposedDateTime']);
    final proposedEnd = parseNullableDate(data['proposedEndDateTime']);

    return OneOnOneMeeting(
      meetingId: (data['meetingId']?.toString() ?? doc.id),
      managerId: data['managerId']?.toString() ?? '',
      employeeId: data['employeeId']?.toString() ?? '',
      status: parseStatus(data['status']),
      waitingOn: parseWaitingOn(data['waitingOn']),
      proposedStartDateTime: proposedStart,
      proposedEndDateTime: proposedEnd,
      agenda: data['agenda']?.toString(),
      employeeMessage: data['employeeMessage']?.toString(),
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'meetingId': meetingId,
      'managerId': managerId,
      'employeeId': employeeId,
      'status': status.name,
      'waitingOn': waitingOn.name,
      'proposedStartDateTime': proposedStartDateTime != null
          ? Timestamp.fromDate(proposedStartDateTime!)
          : null,
      'proposedEndDateTime':
          proposedEndDateTime != null ? Timestamp.fromDate(proposedEndDateTime!) : null,
      // Backwards compatibility for older clients expecting a single time.
      'proposedDateTime': proposedStartDateTime != null
          ? Timestamp.fromDate(proposedStartDateTime!)
          : null,
      'agenda': agenda,
      'employeeMessage': employeeMessage,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

