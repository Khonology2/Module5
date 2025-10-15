import 'package:cloud_firestore/cloud_firestore.dart';

enum GoalCategory { personal, work, health, learning }

enum GoalPriority { low, medium, high }

enum GoalStatus { notStarted, inProgress, completed, paused, burnout }

enum GoalApprovalStatus { pending, approved, rejected }

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
  final GoalApprovalStatus approvalStatus;
  final String? approvedByUserId;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? rejectionReason;

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
    this.approvalStatus = GoalApprovalStatus.pending,
    this.approvedByUserId,
    this.approvedByName,
    this.approvedAt,
    this.rejectionReason,
  });

  factory Goal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    final rawCategory = (data?['category'] ?? 'personal').toString().toLowerCase();
    final rawPriority = (data?['priority'] ?? 'medium').toString().toLowerCase();
    final rawStatus = (data?['status'] ?? 'notStarted').toString().toLowerCase();
    final rawApproval = (data?['approvalStatus'] ?? 'approved').toString().toLowerCase();

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
        orElse: () => rawStatus == 'paused'
            ? GoalStatus.paused
            : rawStatus == 'burnout'
                ? GoalStatus.burnout
                : GoalStatus.notStarted,
      ),
      // Coerce numeric values safely to int (Firestore may store as double)
      progress: (() {
        final raw = data?['progress'];
        if (raw is int) return raw;
        if (raw is num) return raw.round();
        return 0;
      })(),
      createdAt: (data?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      targetDate: (data?['targetDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      points: (() {
        final raw = data?['points'];
        if (raw is int) return raw;
        if (raw is num) return raw.round();
        return 0;
      })(),
      kpa: (data?['kpa'] as String?)?.toLowerCase(),
      approvalStatus: GoalApprovalStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == rawApproval,
        orElse: () => GoalApprovalStatus.approved,
      ),
      approvedByUserId: data?['approvedByUserId'],
      approvedByName: data?['approvedByName'],
      approvedAt: (data?['approvedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data?['rejectionReason'],
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
    GoalApprovalStatus? approvalStatus,
    String? approvedByUserId,
    String? approvedByName,
    DateTime? approvedAt,
    String? rejectionReason,
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
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvedByUserId: approvedByUserId ?? this.approvedByUserId,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  static void fromMap(param0) {}
}


