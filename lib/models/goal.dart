import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String? courseProvider;
  final String? courseUrl;
  final String? courseTitle;
  final String? courseSyncProvider;
  final String? courseExternalId;
  final int? courseProviderProgress;
  final int? courseCompletedSteps;
  final int? courseTotalSteps;
  final DateTime? courseLastSyncedAt;
  final String? courseSyncStatus;
  final String? courseSyncError;

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

  /// Partial/empty `goals` documents sometimes exist in Firestore; never show
  /// them in team review, PDP lists, or aggregates.
  bool get isDisplayableGoal =>
      title.trim().isNotEmpty || description.trim().isNotEmpty;

  bool get hasLinkedCourse => courseUrl?.trim().isNotEmpty == true;

  bool get isUdemyCourseGoal {
    final provider = (courseSyncProvider ?? courseProvider ?? '')
        .trim()
        .toLowerCase();
    final url = (courseUrl ?? '').trim().toLowerCase();
    return hasLinkedCourse && (provider.contains('udemy') || url.contains('udemy.'));
  }

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
    this.courseProvider,
    this.courseUrl,
    this.courseTitle,
    this.courseSyncProvider,
    this.courseExternalId,
    this.courseProviderProgress,
    this.courseCompletedSteps,
    this.courseTotalSteps,
    this.courseLastSyncedAt,
    this.courseSyncStatus,
    this.courseSyncError,
  });

  factory Goal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    final rawCategory = (data?['category'] ?? 'personal')
        .toString()
        .toLowerCase();
    final rawPriority = (data?['priority'] ?? 'medium')
        .toString()
        .toLowerCase();
    final rawStatus = (data?['status'] ?? 'notStarted')
        .toString()
        .toLowerCase();
    // Must match goals awaiting review: missing field means pending, not approved.
    final rawApproval = (data?['approvalStatus'] ?? 'pending')
        .toString()
        .toLowerCase();

    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      final parsed = DateTime.tryParse(v?.toString() ?? '');
      return parsed ?? DateTime.now();
    }

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
        (e) =>
            e.name.toLowerCase() == rawStatus ||
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
      createdAt: parseDate(data?['createdAt']),
      // tolerate older schemas that used 'dueDate'
      targetDate: parseDate(data?['targetDate'] ?? data?['dueDate']),
      points: (() {
        final raw = data?['points'];
        if (raw is int) return raw;
        if (raw is num) return raw.round();
        return 0;
      })(),
      isSeasonGoal: (data?['isSeasonGoal'] ?? false) == true,
      kpa: (data?['kpa'] as String?)?.toLowerCase(),
      evidence: parseEvidence(data?['evidence']),
      approvalStatus: GoalApprovalStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == rawApproval,
        orElse: () => GoalApprovalStatus.pending,
      ),
      approvedByUserId: data?['approvedByUserId']?.toString(),
      approvedByName: data?['approvedByName']?.toString(),
      approvedAt: data?['approvedAt'] != null
          ? parseDate(data?['approvedAt'])
          : null,
      approvalRequestedAt: data?['approvalRequestedAt'] != null
          ? parseDate(data?['approvalRequestedAt'])
          : null,
      rejectionReason: data?['rejectionReason']?.toString(),
      courseProvider: data?['courseProvider']?.toString(),
      courseUrl: data?['courseUrl']?.toString(),
      courseTitle: data?['courseTitle']?.toString(),
      courseSyncProvider: data?['courseSyncProvider']?.toString(),
      courseExternalId: data?['courseExternalId']?.toString(),
      courseProviderProgress: (() {
        final raw = data?['courseProviderProgress'];
        if (raw is int) return raw;
        if (raw is num) return raw.round();
        return null;
      })(),
      courseCompletedSteps: (() {
        final raw = data?['courseCompletedSteps'];
        if (raw is int) return raw;
        if (raw is num) return raw.round();
        return null;
      })(),
      courseTotalSteps: (() {
        final raw = data?['courseTotalSteps'];
        if (raw is int) return raw;
        if (raw is num) return raw.round();
        return null;
      })(),
      courseLastSyncedAt: data?['courseLastSyncedAt'] != null
          ? parseDate(data?['courseLastSyncedAt'])
          : null,
      courseSyncStatus: data?['courseSyncStatus']?.toString(),
      courseSyncError: data?['courseSyncError']?.toString(),
    );
  }

  static Goal fromMap(Map<String, dynamic> map, {String? id}) {
    final rawCategory = (map['category'] ?? 'personal')
        .toString()
        .toLowerCase();
    final rawPriority = (map['priority'] ?? 'medium').toString().toLowerCase();
    final rawStatus = (map['status'] ?? 'notStarted').toString().toLowerCase();
    final rawApproval = (map['approvalStatus'] ?? 'pending')
        .toString()
        .toLowerCase();

    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      final parsed = DateTime.tryParse(v?.toString() ?? '');
      return parsed ?? DateTime.now();
    }

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
      createdAt: parseDate(map['createdAt']),
      // tolerate older schemas that used 'dueDate'
      targetDate: parseDate(map['targetDate'] ?? map['dueDate']),
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
          ? parseDate(map['approvedAt'])
          : null,
      approvalRequestedAt: map['approvalRequestedAt'] != null
          ? parseDate(map['approvalRequestedAt'])
          : null,
      rejectionReason: map['rejectionReason']?.toString(),
      courseProvider: map['courseProvider']?.toString(),
      courseUrl: map['courseUrl']?.toString(),
      courseTitle: map['courseTitle']?.toString(),
      courseSyncProvider: map['courseSyncProvider']?.toString(),
      courseExternalId: map['courseExternalId']?.toString(),
      courseProviderProgress: (map['courseProviderProgress'] ?? 0) is int
          ? map['courseProviderProgress'] as int?
          : int.tryParse(map['courseProviderProgress']?.toString() ?? ''),
      courseCompletedSteps: (map['courseCompletedSteps'] ?? 0) is int
          ? map['courseCompletedSteps'] as int?
          : int.tryParse(map['courseCompletedSteps']?.toString() ?? ''),
      courseTotalSteps: (map['courseTotalSteps'] ?? 0) is int
          ? map['courseTotalSteps'] as int?
          : int.tryParse(map['courseTotalSteps']?.toString() ?? ''),
      courseLastSyncedAt: map['courseLastSyncedAt'] != null
          ? parseDate(map['courseLastSyncedAt'])
          : null,
      courseSyncStatus: map['courseSyncStatus']?.toString(),
      courseSyncError: map['courseSyncError']?.toString(),
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
    String? courseProvider,
    String? courseUrl,
    String? courseTitle,
    String? courseSyncProvider,
    String? courseExternalId,
    int? courseProviderProgress,
    int? courseCompletedSteps,
    int? courseTotalSteps,
    DateTime? courseLastSyncedAt,
    String? courseSyncStatus,
    String? courseSyncError,
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
      courseProvider: courseProvider ?? this.courseProvider,
      courseUrl: courseUrl ?? this.courseUrl,
      courseTitle: courseTitle ?? this.courseTitle,
      courseSyncProvider: courseSyncProvider ?? this.courseSyncProvider,
      courseExternalId: courseExternalId ?? this.courseExternalId,
      courseProviderProgress:
          courseProviderProgress ?? this.courseProviderProgress,
      courseCompletedSteps: courseCompletedSteps ?? this.courseCompletedSteps,
      courseTotalSteps: courseTotalSteps ?? this.courseTotalSteps,
      courseLastSyncedAt: courseLastSyncedAt ?? this.courseLastSyncedAt,
      courseSyncStatus: courseSyncStatus ?? this.courseSyncStatus,
      courseSyncError: courseSyncError ?? this.courseSyncError,
    );
  }
}
