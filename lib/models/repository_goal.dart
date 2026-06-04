import 'package:pdh/utils/date_parse.dart';

class RepositoryGoal {
  final String id; // Backend record id
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

  factory RepositoryGoal.fromMap(Map<String, dynamic> data) {
    List<String> parseEvidence(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return const [];
    }

    return RepositoryGoal(
      id: (data['id'] ?? data['goalId'] ?? '').toString(),
      goalId: (data['goalId'] ?? data['id'] ?? '').toString(),
      goalTitle: (data['goalTitle'] ?? data['title'] ?? '').toString(),
      goalDescription: data['goalDescription']?.toString(),
      completedDate: parseNullableDate(data['completedDate']),
      verifiedDate: parseNullableDate(data['verifiedDate']),
      managerAcknowledgedBy: data['managerAcknowledgedBy']?.toString(),
      score: (data['score'] is num)
          ? (data['score'] as num).toDouble()
          : double.tryParse(data['score']?.toString() ?? ''),
      comments: data['comments']?.toString(),
      evidence: parseEvidence(data['evidence']),
      userId: (data['userId'] ?? '').toString(),
      userDisplayName: (data['userDisplayName'] ?? '').toString(),
      userDepartment: (data['userDepartment'] ?? '').toString(),
    );
  }

}
