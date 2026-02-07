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
  final DateTime? proposedDateTime;
  final String? agenda;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OneOnOneMeeting({
    required this.meetingId,
    required this.managerId,
    required this.employeeId,
    required this.status,
    required this.waitingOn,
    required this.proposedDateTime,
    required this.agenda,
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

    return OneOnOneMeeting(
      meetingId: (data['meetingId']?.toString() ?? doc.id),
      managerId: data['managerId']?.toString() ?? '',
      employeeId: data['employeeId']?.toString() ?? '',
      status: parseStatus(data['status']),
      waitingOn: parseWaitingOn(data['waitingOn']),
      proposedDateTime: parseNullableDate(data['proposedDateTime']),
      agenda: data['agenda']?.toString(),
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
      'proposedDateTime':
          proposedDateTime != null ? Timestamp.fromDate(proposedDateTime!) : null,
      'agenda': agenda,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

