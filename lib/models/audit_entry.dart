import 'package:cloud_firestore/cloud_firestore.dart';

class AuditEntry {
  final String id;
  final String userId;
  final String goalId;
  final String goalTitle;
  final DateTime completedDate;
  final DateTime submittedDate;
<<<<<<< HEAD
=======
  final DateTime? verifiedDate;
  final DateTime? rejectedDate;
>>>>>>> 05122a8 (Audit&Repo-Emp&Man)
  final String status; // 'pending', 'verified', 'rejected'
  final List<String> evidence;
  final String? acknowledgedBy;
  final String? acknowledgedById;
  final double? score;
  final String? comments;
  final String? rejectionReason;
  final String userDisplayName;
  final String userDepartment;

  AuditEntry({
    required this.id,
    required this.userId,
    required this.goalId,
    required this.goalTitle,
    required this.completedDate,
    required this.submittedDate,
<<<<<<< HEAD
=======
    this.verifiedDate,
    this.rejectedDate,
>>>>>>> 05122a8 (Audit&Repo-Emp&Man)
    required this.status,
    required this.evidence,
    this.acknowledgedBy,
    this.acknowledgedById,
    this.score,
    this.comments,
    this.rejectionReason,
    required this.userDisplayName,
    required this.userDepartment,
  });

  factory AuditEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditEntry(
      id: doc.id,
      userId: data['userId'] ?? '',
      goalId: data['goalId'] ?? '',
      goalTitle: data['goalTitle'] ?? '',
      completedDate:
          (data['completedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      submittedDate:
          (data['submittedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
<<<<<<< HEAD
=======
      verifiedDate: (data['verifiedDate'] as Timestamp?)?.toDate(),
      rejectedDate: (data['rejectedDate'] as Timestamp?)?.toDate(),
>>>>>>> 05122a8 (Audit&Repo-Emp&Man)
      status: data['status'] ?? 'pending',
      evidence: List<String>.from(data['evidence'] ?? []),
      acknowledgedBy: data['acknowledgedBy'],
      acknowledgedById: data['acknowledgedById'],
      score: data['score']?.toDouble(),
      comments: data['comments'],
      rejectionReason: data['rejectionReason'],
      userDisplayName: data['userDisplayName'] ?? 'Unknown User',
      userDepartment: data['userDepartment'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'goalId': goalId,
      'goalTitle': goalTitle,
      'completedDate': Timestamp.fromDate(completedDate),
      'submittedDate': Timestamp.fromDate(submittedDate),
<<<<<<< HEAD
=======
      'verifiedDate': verifiedDate != null
          ? Timestamp.fromDate(verifiedDate!)
          : null,
      'rejectedDate': rejectedDate != null
          ? Timestamp.fromDate(rejectedDate!)
          : null,
>>>>>>> 05122a8 (Audit&Repo-Emp&Man)
      'status': status,
      'evidence': evidence,
      'acknowledgedBy': acknowledgedBy,
      'acknowledgedById': acknowledgedById,
      'score': score,
      'comments': comments,
      'rejectionReason': rejectionReason,
      'userDisplayName': userDisplayName,
      'userDepartment': userDepartment,
    };
  }
}
