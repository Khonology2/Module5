import 'package:cloud_firestore/cloud_firestore.dart';

class DeletedGoalLog {
  final String id;
  final String goalId;
  final String goalTitle;
  final DateTime deletedAt;
  final String deletedBy;

  DeletedGoalLog({
    required this.id,
    required this.goalId,
    required this.goalTitle,
    required this.deletedAt,
    required this.deletedBy,
  });

  factory DeletedGoalLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final goalData = data['goalData'] as Map<String, dynamic>? ?? {};
    return DeletedGoalLog(
      id: doc.id,
      goalId: data['goalId'] ?? doc.id,
      goalTitle: goalData['title'] ?? data['goalTitle'] ?? 'Untitled',
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deletedBy: data['deletedBy'] ?? '',
    );
  }
}
