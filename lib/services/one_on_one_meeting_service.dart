import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';

import 'package:pdh/models/one_on_one_meeting.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/utils/backend_polling_stream.dart';

class OneOnOneMeetingService {
  static final BackendAuthService _backend = BackendAuthService.instance;

  static Stream<List<OneOnOneMeeting>> streamForEmployee(String employeeId) {
    return backendPollingListStream<OneOnOneMeeting>(
      fetch: () => _backend.getOneOnOneMeetings(employeeId: employeeId),
      mapper: OneOnOneMeeting.fromMap,
    ).map((items) {
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    });
  }

  static Stream<List<OneOnOneMeeting>> streamForManager(String managerId) {
    return backendPollingListStream<OneOnOneMeeting>(
      fetch: () => _backend.getOneOnOneMeetings(managerId: managerId),
      mapper: OneOnOneMeeting.fromMap,
    ).map((items) {
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    });
  }

  static Stream<OneOnOneMeeting?> streamMeeting(String meetingId) {
    return backendPollingStream<OneOnOneMeeting?>(
      fetch: () async {
        final items = await _backend.getOneOnOneMeetings(meetingId: meetingId, limit: 1);
        if (items.isEmpty) return null;
        return OneOnOneMeeting.fromMap(items.first);
      },
    );
  }

  static Future<OneOnOneMeeting?> getMeeting(String meetingId) async {
    try {
      final items = await _backend.getOneOnOneMeetings(meetingId: meetingId, limit: 1);
      if (items.isEmpty) return null;
      return OneOnOneMeeting.fromMap(items.first);
    } catch (e) {
      developer.log('Error getting one-on-one meeting: $e');
      return null;
    }
  }

  static Future<OneOnOneMeeting?> getLatestBetween({
    required String managerId,
    required String employeeId,
    bool includeCancelled = false,
  }) async {
    try {
      final items = (await _backend.getOneOnOneMeetings(
        managerId: managerId,
        employeeId: employeeId,
        limit: 20,
      )).map(OneOnOneMeeting.fromMap).toList();
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      for (final m in items) {
        if (includeCancelled) return m;
        if (m.status != OneOnOneMeetingStatus.cancelled) return m;
      }
      return null;
    } catch (e) {
      developer.log('Error getting latest one-on-one meeting between users: $e');
      return null;
    }
  }

  static Future<String> requestOneOnOne({
    required String managerId,
    required String employeeId,
    String? agenda,
  }) async {
    final now = DateTime.now().toIso8601String();
    final created = await _backend.createOneOnOneMeeting({
      'managerId': managerId,
      'employeeId': employeeId,
      'status': OneOnOneMeetingStatus.requested.name,
      'waitingOn': OneOnOneWaitingOn.employee.name,
      'proposedStartDateTime': null,
      'proposedEndDateTime': null,
      'proposedDateTime': null,
      'agenda': (agenda ?? '').trim(),
      'createdAt': now,
      'updatedAt': now,
    });
    return (created['id'] ?? created['meetingId'] ?? '').toString();
  }

  static Future<String> proposeTime({
    required String managerId,
    required String employeeId,
    required DateTime proposedStartDateTime,
    required DateTime proposedEndDateTime,
    String? agenda,
  }) async {
    if (!proposedEndDateTime.isAfter(proposedStartDateTime)) {
      throw ArgumentError('End time must be after start time.');
    }
    final now = DateTime.now().toIso8601String();
    final created = await _backend.createOneOnOneMeeting({
      'managerId': managerId,
      'employeeId': employeeId,
      'status': OneOnOneMeetingStatus.proposed.name,
      'waitingOn': OneOnOneWaitingOn.employee.name,
      'proposedStartDateTime': proposedStartDateTime.toIso8601String(),
      'proposedEndDateTime': proposedEndDateTime.toIso8601String(),
      'proposedDateTime': proposedStartDateTime.toIso8601String(),
      'agenda': (agenda ?? '').trim(),
      'createdAt': now,
      'updatedAt': now,
    });
    return (created['id'] ?? created['meetingId'] ?? '').toString();
  }

  static Future<void> employeeAccept({required String meetingId}) async {
    await acceptMeeting(meetingId: meetingId);
  }

  static Future<void> acceptMeeting({required String meetingId}) async {
    await _backend.patchOneOnOneMeeting(meetingId, {
      'status': OneOnOneMeetingStatus.accepted.name,
      'waitingOn': OneOnOneWaitingOn.none.name,
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  static Future<void> employeeSuggestNewTime({
    required String meetingId,
    required DateTime proposedStartDateTime,
    required DateTime proposedEndDateTime,
    String? agenda,
  }) async {
    if (!proposedEndDateTime.isAfter(proposedStartDateTime)) {
      throw ArgumentError('End time must be after start time.');
    }
    await _backend.patchOneOnOneMeeting(meetingId, {
      'status': OneOnOneMeetingStatus.rescheduled.name,
      'waitingOn': OneOnOneWaitingOn.manager.name,
      'proposedStartDateTime': proposedStartDateTime.toIso8601String(),
      'proposedEndDateTime': proposedEndDateTime.toIso8601String(),
      'proposedDateTime': proposedStartDateTime.toIso8601String(),
      if (agenda != null) 'agenda': agenda.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  static Future<void> employeeAcknowledgeRequest({
    required String meetingId,
    String? message,
  }) async {
    await _backend.patchOneOnOneMeeting(meetingId, {
      'status': OneOnOneMeetingStatus.requested.name,
      'waitingOn': OneOnOneWaitingOn.manager.name,
      if (message != null && message.trim().isNotEmpty)
        'employeeMessage': message.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  static Future<void> managerProposeNewTime({
    required String meetingId,
    required DateTime proposedStartDateTime,
    required DateTime proposedEndDateTime,
    String? agenda,
  }) async {
    if (!proposedEndDateTime.isAfter(proposedStartDateTime)) {
      throw ArgumentError('End time must be after start time.');
    }
    await _backend.patchOneOnOneMeeting(meetingId, {
      'status': OneOnOneMeetingStatus.proposed.name,
      'waitingOn': OneOnOneWaitingOn.employee.name,
      'proposedStartDateTime': proposedStartDateTime.toIso8601String(),
      'proposedEndDateTime': proposedEndDateTime.toIso8601String(),
      'proposedDateTime': proposedStartDateTime.toIso8601String(),
      if (agenda != null) 'agenda': agenda.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  static Future<void> cancel({required String meetingId}) async {
    await _backend.patchOneOnOneMeeting(meetingId, {
      'status': OneOnOneMeetingStatus.cancelled.name,
      'waitingOn': OneOnOneWaitingOn.none.name,
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }
}
