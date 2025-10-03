import 'package:cloud_firestore/cloud_firestore.dart';

enum GoalCategory { personal, work, health, learning }

enum GoalPriority { low, medium, high }

enum GoalStatus { notStarted, inProgress, completed }

class Goal {
  final String id;
  final String userId;
  final String title;
  final String description;
  final GoalCategory category;
  final GoalPriority priority;
  final GoalStatus status;
  final int progress;
  final DateTime createdAt;
  final DateTime targetDate;
  final int points;

  const Goal({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    this.status = GoalStatus.notStarted,
    this.progress = 0,
    required this.createdAt,
    required this.targetDate,
    required this.points,
  });

  factory Goal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return Goal(
      id: doc.id,
      userId: data?['userId'] ?? '',
      title: data?['title'] ?? '',
      description: data?['description'] ?? '',
      category: GoalCategory.values.firstWhere(
          (e) => e.name == (data?['category'] ?? 'personal'),
          orElse: () => GoalCategory.personal,
      ),
      priority: GoalPriority.values.firstWhere(
          (e) => e.name == (data?['priority'] ?? 'medium'),
          orElse: () => GoalPriority.medium,
      ),
      status: GoalStatus.values.firstWhere(
          (e) => e.name == (data?['status'] ?? 'notStarted'),
          orElse: () => GoalStatus.notStarted,
      ),
      progress: (data?['progress'] ?? 0) as int,
      createdAt: (data?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      targetDate: (data?['targetDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      points: (data?['points'] ?? 0) as int,
    );
  }

  Goal copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    GoalCategory? category,
    GoalPriority? priority,
    GoalStatus? status,
    int? progress,
    DateTime? createdAt,
    DateTime? targetDate,
    int? points,
  }) {
    return Goal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      targetDate: targetDate ?? this.targetDate,
      points: points ?? this.points,
    );
  }
}


