import 'package:pdh/utils/date_parse.dart';

class LearningAssignment {
  final String id;
  final String tutorialId;
  final String employeeUserId;
  final String managerId;
  final String? goalId;
  final String title;
  final String status;
  final DateTime? dueDate;
  final DateTime? assignedAt;
  final DateTime? completedAt;
  final int points;
  final int watchProgress;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? videoUrl;
  final String? tutorialTitle;
  final String? tutorialDescription;
  final int? durationMinutes;

  const LearningAssignment({
    required this.id,
    required this.tutorialId,
    required this.employeeUserId,
    required this.managerId,
    this.goalId,
    required this.title,
    required this.status,
    this.dueDate,
    this.assignedAt,
    this.completedAt,
    this.points = 10,
    this.watchProgress = 0,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.videoUrl,
    this.tutorialTitle,
    this.tutorialDescription,
    this.durationMinutes,
  });

  /// Client-side overdue when not completed and past due.
  String get effectiveStatus {
    if (status == 'completed' || status == 'cancelled') return status;
    final due = dueDate;
    if (due != null && DateTime.now().isAfter(due)) return 'overdue';
    return status;
  }

  factory LearningAssignment.fromMap(Map<String, dynamic> map) {
    return LearningAssignment(
      id: (map['id'] ?? '').toString(),
      tutorialId: (map['tutorialId'] ?? map['tutorial_id'] ?? '').toString(),
      employeeUserId:
          (map['employeeUserId'] ?? map['employee_user_id'] ?? '').toString(),
      managerId: (map['managerId'] ?? map['manager_id'] ?? '').toString(),
      goalId: map['goalId']?.toString() ?? map['goal_id']?.toString(),
      title: (map['title'] ?? '').toString(),
      status: (map['status'] ?? 'assigned').toString(),
      dueDate: parseNullableDate(map['dueDate'] ?? map['due_date']),
      assignedAt: parseNullableDate(map['assignedAt'] ?? map['assigned_at']),
      completedAt: parseNullableDate(map['completedAt'] ?? map['completed_at']),
      points: _parseIntWithFallback(map['points'], fallback: 10),
      watchProgress: _parseIntWithFallback(
        map['watchProgress'] ?? map['watch_progress'],
        fallback: 0,
      ),
      notes: map['notes']?.toString(),
      createdAt: parseNullableDate(map['createdAt'] ?? map['created_at']),
      updatedAt: parseNullableDate(map['updatedAt'] ?? map['updated_at']),
      videoUrl: map['videoUrl']?.toString() ?? map['video_url']?.toString(),
      tutorialTitle: map['tutorialTitle']?.toString(),
      tutorialDescription: map['tutorialDescription']?.toString(),
      durationMinutes: _parseOptionalInt(
        map['durationMinutes'] ?? map['duration_minutes'],
      ),
    );
  }

  static int? _parseOptionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  Map<String, dynamic> toAssignPayload({
    required String managerId,
    required String tutorialId,
    required String employeeUserId,
    required DateTime dueDate,
    int points = 10,
    String? notes,
  }) {
    return {
      'managerId': managerId,
      'tutorialId': tutorialId,
      'employeeUserId': employeeUserId,
      'dueDate': dueDate.toUtc().toIso8601String(),
      'points': points,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
  }

  static int _parseIntWithFallback(dynamic value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
