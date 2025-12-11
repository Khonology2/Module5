import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/deleted_goal_log.dart';

class DeletedGoalService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream logs for current employee
  static Stream<List<DeletedGoalLog>> getEmployeeDeletedGoalsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _firestore
        .collection('deleted_goals')
        .where('deletedBy', isEqualTo: uid)
        .orderBy('deletedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => DeletedGoalLog.fromFirestore(d)).toList())
        .handleError((e) {
      developer.log('Error streaming deleted goals: $e');
      return <DeletedGoalLog>[];
    });
  }

  // Managers get all employees' deleted goals (optionally filter by department if stored)
  static Stream<List<DeletedGoalLog>> getManagerDeletedGoalsStream() {
    return _firestore
        .collection('deleted_goals')
        .orderBy('deletedAt', descending: true)
        .limit(500)
        .snapshots()
        .map((s) => s.docs.map((d) => DeletedGoalLog.fromFirestore(d)).toList())
        .handleError((e) {
      developer.log('Error streaming all deleted goals: $e');
      return <DeletedGoalLog>[];
    });
  }
}
