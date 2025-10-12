import 'package:cloud_firestore/cloud_firestore.dart';

class RepositoryGoal {
  final String id; // Firestore doc ID
  final String goalId;
  final String goalTitle;
  final String? goalDescription;
  final DateTime? completedDate;
  final DateTime? verifiedDate;
  final String? managerAcknowledgedBy;
  final double? score;
  final String? comments;
  final List<String> evidence;
  final String userId;
  final String userDisplayName;
  final String userDepartment;

  RepositoryGoal({
    required this.id,
    required this.goalId,
    required this.goalTitle,
    this.goalDescription,
    this.completedDate,
    this.verifiedDate,
    this.managerAcknowledgedBy,
    this.score,
    this.comments,
    required this.evidence,
    required this.userId,
    required this.userDisplayName,
    required this.userDepartment,
  });

  factory RepositoryGoal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RepositoryGoal(
      id: doc.id,
      goalId: data['goalId'] ?? '',
      goalTitle: data['goalTitle'] ?? '',
      goalDescription: data['goalDescription'],
      completedDate: (data['completedDate'] as Timestamp?)?.toDate(),
      verifiedDate: (data['verifiedDate'] as Timestamp?)?.toDate(),
      managerAcknowledgedBy: data['managerAcknowledgedBy'],
      score: (data['score'] is int)
          ? (data['score'] as int).toDouble()
          : (data['score'] as num?)?.toDouble(),
      comments: data['comments'],
      evidence: List<String>.from(data['evidence'] ?? const []),
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? '',
      userDepartment: data['userDepartment'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'goalId': goalId,
      'goalTitle': goalTitle,
      'goalDescription': goalDescription,
      'completedDate': completedDate != null
          ? Timestamp.fromDate(completedDate!)
          : null,
      'verifiedDate': verifiedDate != null
          ? Timestamp.fromDate(verifiedDate!)
          : null,
      'managerAcknowledgedBy': managerAcknowledgedBy,
      'score': score,
      'comments': comments,
      'evidence': evidence,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userDepartment': userDepartment,
    };
  }
}
