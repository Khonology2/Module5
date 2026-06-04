import 'package:pdh/utils/date_parse.dart';

enum GoalCategory { personal, work, health, learning }

enum GoalPriority { low, medium, high }

enum GoalStatus {
  notStarted,
  inProgress,
  completed,
  acknowledged,
  paused,
  burnout,
}

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
  final bool isSeasonGoal;
  // Key Performance Area tag for persistent excellence grouping
  final String?
  kpa; // expected values: 'operational' | 'customer' | 'financial' | 'organisational' | 'people'

  static const List<String> kpaKeys = <String>[
    'operational',
    'customer',
    'financial',
    'organisational',
    'people',
  ];

  static const Map<String, String> kpaKeyToLabel = <String, String>{
    'operational': 'Operational Excellence',
    'customer': 'Customer Excellence',
    'financial': 'Financial Excellence',
    'organisational': 'Organisational Excellence',
    'people': 'People Excellence',
  };

  static String? normalizeKpaKey(String? input) {
    final raw = input?.trim();
    if (raw == null || raw.isEmpty) return null;

    final lower = raw.toLowerCase();
    if (kpaKeyToLabel.containsKey(lower)) return lower;

    for (final entry in kpaKeyToLabel.entries) {
      if (entry.value.toLowerCase() == lower) return entry.key;
    }
    return null;
  }

  static String? kpaLabel(String? input) {
    final key = normalizeKpaKey(input);
    if (key == null) return null;
    return kpaKeyToLabel[key];
  }

  final List<String> evidence; // List of evidence attachments
  final GoalApprovalStatus approvalStatus;
  final String? approvedByUserId;
  final String? approvedByName;
  final DateTime? approvedAt;
  final DateTime? approvalRequestedAt;
  final String? rejectionReason;

  /// Goals that are finished, acknowledged, paused, or already at 100% must not
  /// drive overdue / team supervision alerts (matches manager PDP semantics).
  bool get isEligibleForOverdueTeamAlert {
    if (progress >= 100) return false;
    if (status == GoalStatus.completed || status == GoalStatus.acknowledged) {
      return false;
    }
    if (status == GoalStatus.paused) return false;
    return true;
  }

  /// Partial/empty goal records sometimes exist in the backend; never show
  /// them in team review, PDP lists, or aggregates.
  bool get isDisplayableGoal =>
      title.trim().isNotEmpty || description.trim().isNotEmpty;

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
    this.isSeasonGoal = false,
    this.kpa,
    this.evidence = const [],
    this.approvalStatus = GoalApprovalStatus.pending,
    this.approvedByUserId,
    this.approvedByName,
    this.approvedAt,
    this.approvalRequestedAt,
    this.rejectionReason,
  });

  static Goal fromMap(Map<String, dynamic> map, {String? id}) {
    final rawCategory = (map['category'] ?? 'personal')
        .toString()
        .toLowerCase();
    final rawPriority = (map['priority'] ?? 'medium').toString().toLowerCase();
    final rawStatus = (map['status'] ?? 'notStarted').toString().toLowerCase();
    final rawApproval = (map['approvalStatus'] ?? 'pending')
        .toString()
        .toLowerCase();

    DateTime parseGoalDate(dynamic v) => parseDate(v);

    List<String> parseEvidence(dynamic v) {
      if (v is List) {
        return v
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
      if (v is String && v.trim().isNotEmpty) {
        return <String>[v.trim()];
      }
      return const <String>[];
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
        (e) =>
            e.name.toLowerCase() == rawStatus ||
            (rawStatus == 'in_progress' && e == GoalStatus.inProgress) ||
            (rawStatus == 'notstarted' && e == GoalStatus.notStarted),
        orElse: () => GoalStatus.notStarted,
      ),
      progress: (map['progress'] ?? 0) is int
          ? (map['progress'] as int)
          : int.tryParse(map['progress']?.toString() ?? '0') ?? 0,
      createdAt: parseGoalDate(map['createdAt']),
      // tolerate older schemas that used 'dueDate'
      targetDate: parseGoalDate(map['targetDate'] ?? map['dueDate']),
      points: (map['points'] ?? 0) is int
          ? (map['points'] as int)
          : int.tryParse(map['points']?.toString() ?? '0') ?? 0,
      isSeasonGoal: (map['isSeasonGoal'] ?? false) == true,
      kpa: map['kpa']?.toString().toLowerCase(),
      evidence: parseEvidence(map['evidence']),
      approvalStatus: GoalApprovalStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == rawApproval,
        orElse: () => GoalApprovalStatus.pending,
      ),
      approvedByUserId: map['approvedByUserId']?.toString(),
      approvedByName: map['approvedByName']?.toString(),
      approvedAt: map['approvedAt'] != null
          ? parseGoalDate(map['approvedAt'])
          : null,
      approvalRequestedAt: map['approvalRequestedAt'] != null
          ? parseGoalDate(map['approvalRequestedAt'])
          : null,
      rejectionReason: map['rejectionReason']?.toString(),
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
    bool? isSeasonGoal,
    String? kpa,
    List<String>? evidence,
    GoalApprovalStatus? approvalStatus,
    String? approvedByUserId,
    String? approvedByName,
    DateTime? approvedAt,
    DateTime? approvalRequestedAt,
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
      isSeasonGoal: isSeasonGoal ?? this.isSeasonGoal,
      kpa: kpa ?? this.kpa,
      evidence: evidence ?? this.evidence,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvedByUserId: approvedByUserId ?? this.approvedByUserId,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedAt: approvedAt ?? this.approvedAt,
      approvalRequestedAt: approvalRequestedAt ?? this.approvalRequestedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
