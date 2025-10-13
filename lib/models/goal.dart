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
  // Key Performance Area tag for persistent excellence grouping
  final String? kpa; // expected values: 'operational' | 'customer' | 'financial'

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
    this.kpa,
  });

  factory Goal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    final rawCategory = (data?['category'] ?? 'personal').toString().toLowerCase();
    final rawPriority = (data?['priority'] ?? 'medium').toString().toLowerCase();
    final rawStatus = (data?['status'] ?? 'notStarted').toString().toLowerCase();

    return Goal(
      id: doc.id,
      userId: data?['userId'] ?? '',
      title: data?['title'] ?? '',
      description: data?['description'] ?? '',
      category: GoalCategory.values.firstWhere(
          (e) => e.name.toLowerCase() == rawCategory,
          orElse: () => GoalCategory.personal,
      ),
      priority: GoalPriority.values.firstWhere(
          (e) => e.name.toLowerCase() == rawPriority,
          orElse: () => GoalPriority.medium,
      ),
      status: GoalStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == rawStatus ||
                // tolerate common alternative spellings/cases
                (rawStatus == 'in_progress' && e == GoalStatus.inProgress) ||
                (rawStatus == 'notstarted' && e == GoalStatus.notStarted),
        orElse: () => GoalStatus.notStarted,
      ),
      progress: (data?['progress'] ?? 0) as int,
      createdAt: (data?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      targetDate: (data?['targetDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      points: (data?['points'] ?? 0) as int,
      kpa: (data?['kpa'] as String?)?.toLowerCase(),
    );
  }

  static Goal fromMap(Map<String, dynamic> map, {String? id}) {
    final rawCategory = (map['category'] ?? 'personal').toString().toLowerCase();
    final rawPriority = (map['priority'] ?? 'medium').toString().toLowerCase();
    final rawStatus = (map['status'] ?? 'notStarted').toString().toLowerCase();

    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      final parsed = DateTime.tryParse(v?.toString() ?? '');
      return parsed ?? DateTime.now();
    }

    return Goal(
      id: id ?? (map['id']?.toString() ?? ''),
      userId: map['userId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      category: GoalCategory.values.firstWhere(
        (e) => e.name.toLowerCase() == rawCategory,
        orElse: () => GoalCategory.personal,
      ),
      priority: GoalPriority.values.firstWhere(
        (e) => e.name.toLowerCase() == rawPriority,
        orElse: () => GoalPriority.medium,
      ),
      status: GoalStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == rawStatus ||
            (rawStatus == 'in_progress' && e == GoalStatus.inProgress) ||
            (rawStatus == 'notstarted' && e == GoalStatus.notStarted),
        orElse: () => GoalStatus.notStarted,
      ),
      progress: (map['progress'] ?? 0) is int
          ? (map['progress'] as int)
          : int.tryParse(map['progress']?.toString() ?? '0') ?? 0,
      createdAt: parseDate(map['createdAt']),
      targetDate: parseDate(map['targetDate']),
      points: (map['points'] ?? 0) is int
          ? (map['points'] as int)
          : int.tryParse(map['points']?.toString() ?? '0') ?? 0,
      kpa: map['kpa']?.toString().toLowerCase(),
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
    String? kpa,
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
      kpa: kpa ?? this.kpa,
    );
  }
}


