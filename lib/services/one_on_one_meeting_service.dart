import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/one_on_one_meeting.dart';
import 'package:pdh/utils/firestore_safe.dart';

class OneOnOneMeetingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('one_on_one_meetings');

  static Stream<List<OneOnOneMeeting>> streamForEmployee(String employeeId) {
    final query = _col.where('employeeId', isEqualTo: employeeId);
    return FirestoreSafe.stream(query.snapshots()).map((snapshot) {
      final items = snapshot.docs
          .map((d) => OneOnOneMeeting.fromFirestore(d))
          .where((m) => m.meetingId.isNotEmpty)
          .toList();
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    });
  }

  static Stream<List<OneOnOneMeeting>> streamForManager(String managerId) {
    final query = _col.where('managerId', isEqualTo: managerId);
    return FirestoreSafe.stream(query.snapshots()).map((snapshot) {
      final items = snapshot.docs
          .map((d) => OneOnOneMeeting.fromFirestore(d))
          .where((m) => m.meetingId.isNotEmpty)
          .toList();
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    });
  }

  static Stream<OneOnOneMeeting?> streamMeeting(String meetingId) {
    return FirestoreSafe.stream(_col.doc(meetingId).snapshots()).map((snap) {
      if (!snap.exists) return null;
      return OneOnOneMeeting.fromFirestore(snap);
    });
  }

  static Future<OneOnOneMeeting?> getMeeting(String meetingId) async {
    try {
      final snap = await FirestoreSafe.getDoc(_col.doc(meetingId));
      if (!snap.exists) return null;
      return OneOnOneMeeting.fromFirestore(snap);
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
      final q = _col
          .where('managerId', isEqualTo: managerId)
          .where('employeeId', isEqualTo: employeeId)
          .limit(20);
      final snap = await FirestoreSafe.getQuery(q);
      final items = snap.docs.map((d) => OneOnOneMeeting.fromFirestore(d)).toList();
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

  /// Manager creates intent only (no time yet).
  static Future<String> requestOneOnOne({
    required String managerId,
    required String employeeId,
    String? agenda,
  }) async {
    final ref = _col.doc();
    await FirestoreSafe.setDoc(ref, {
      'meetingId': ref.id,
      'managerId': managerId,
      'employeeId': employeeId,
      'status': OneOnOneMeetingStatus.requested.name,
      'waitingOn': OneOnOneWaitingOn.employee.name,
      'proposedStartDateTime': null,
      'proposedEndDateTime': null,
      // Backwards compatibility for older clients
      'proposedDateTime': null,
      'agenda': (agenda ?? '').trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Manager proposes a meeting time range.
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
    final ref = _col.doc();
    await FirestoreSafe.setDoc(ref, {
      'meetingId': ref.id,
      'managerId': managerId,
      'employeeId': employeeId,
      'status': OneOnOneMeetingStatus.proposed.name,
      'waitingOn': OneOnOneWaitingOn.employee.name,
      'proposedStartDateTime': Timestamp.fromDate(proposedStartDateTime),
      'proposedEndDateTime': Timestamp.fromDate(proposedEndDateTime),
      // Backwards compatibility for older clients
      'proposedDateTime': Timestamp.fromDate(proposedStartDateTime),
      'agenda': (agenda ?? '').trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> employeeAccept({
    required String meetingId,
  }) async {
    await acceptMeeting(meetingId: meetingId);
  }

  static Future<void> acceptMeeting({
    required String meetingId,
  }) async {
    await FirestoreSafe.updateDoc(_col.doc(meetingId), {
      'status': OneOnOneMeetingStatus.accepted.name,
      'waitingOn': OneOnOneWaitingOn.none.name,
      'updatedAt': FieldValue.serverTimestamp(),
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
    await FirestoreSafe.updateDoc(_col.doc(meetingId), {
      'status': OneOnOneMeetingStatus.rescheduled.name,
      'waitingOn': OneOnOneWaitingOn.manager.name,
      'proposedStartDateTime': Timestamp.fromDate(proposedStartDateTime),
      'proposedEndDateTime': Timestamp.fromDate(proposedEndDateTime),
      // Backwards compatibility for older clients
      'proposedDateTime': Timestamp.fromDate(proposedStartDateTime),
      if (agenda != null) 'agenda': agenda.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  /// Employee acknowledges an intent-only request without proposing a time.
  ///
  /// This keeps status = requested, but flips "waitingOn" to manager so both sides
  /// can clearly see who should act next.
  static Future<void> employeeAcknowledgeRequest({
    required String meetingId,
    String? message,
  }) async {
    await FirestoreSafe.updateDoc(_col.doc(meetingId), {
      'status': OneOnOneMeetingStatus.requested.name,
      'waitingOn': OneOnOneWaitingOn.manager.name,
      if (message != null && message.trim().isNotEmpty)
        'employeeMessage': message.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
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
    await FirestoreSafe.updateDoc(_col.doc(meetingId), {
      'status': OneOnOneMeetingStatus.proposed.name,
      'waitingOn': OneOnOneWaitingOn.employee.name,
      'proposedStartDateTime': Timestamp.fromDate(proposedStartDateTime),
      'proposedEndDateTime': Timestamp.fromDate(proposedEndDateTime),
      // Backwards compatibility for older clients
      'proposedDateTime': Timestamp.fromDate(proposedStartDateTime),
      if (agenda != null) 'agenda': agenda.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  static Future<void> cancel({
    required String meetingId,
  }) async {
    await FirestoreSafe.updateDoc(_col.doc(meetingId), {
      'status': OneOnOneMeetingStatus.cancelled.name,
      'waitingOn': OneOnOneWaitingOn.none.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }
}

