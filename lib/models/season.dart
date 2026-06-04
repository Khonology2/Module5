import 'package:pdh/utils/date_parse.dart';

enum SeasonStatus { planning, active, completed, cancelled }

enum ChallengeType { learning, skill, collaboration, innovation, wellness }

enum MilestoneStatus { notStarted, inProgress, completed, overdue }

enum ChallengeSubmissionStatus { notSubmitted, submitted, approved, rejected }

class Season {
  final String id;
  final String title;
  final String description;
  final String theme;
  final SeasonStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final String createdBy;
  final String createdByName;
  final String? department;
  final List<SeasonChallenge> challenges;
  final List<String> participantIds;
  final Map<String, SeasonParticipation> participations;
  final SeasonMetrics metrics;
  final Map<String, dynamic> settings;

  const Season({
    required this.id,
    required this.title,
    required this.description,
    required this.theme,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    this.department,
    required this.challenges,
    required this.participantIds,
    required this.participations,
    required this.metrics,
    required this.settings,
  });

  static DateTime _parseDate(dynamic value, {DateTime? fallback}) {
    return parseDate(value, fallback: fallback);
  }

  factory Season.fromMap(Map<String, dynamic> data, {String? id}) {
    return Season(
      id: (id ?? data['id'] ?? '').toString(),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      theme: data['theme'] ?? '',
      status: SeasonStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'planning'),
        orElse: () => SeasonStatus.planning,
      ),
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      createdAt: _parseDate(data['createdAt']),
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'] ?? '',
      department: data['department'],
      challenges: (data['challenges'] as List<dynamic>? ?? [])
          .map((c) => SeasonChallenge.fromMap(c as Map<String, dynamic>))
          .toList(),
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participations: Map<String, SeasonParticipation>.from(
        (data['participations'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(
            key,
            SeasonParticipation.fromMap(value as Map<String, dynamic>),
          ),
        ),
      ),
      metrics: SeasonMetrics.fromMap(
        data['metrics'] as Map<String, dynamic>? ?? {},
      ),
      settings: {
        ...Map<String, dynamic>.from(data['settings'] ?? {}),
        if (data['createdByRole'] != null)
          'createdByRole': data['createdByRole'],
      },
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'title': title,
      'description': description,
      'theme': theme,
      'status': status.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'department': department,
      'challenges': challenges.map((c) => c.toMap()).toList(),
      'participantIds': participantIds,
      'participations': participations.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'metrics': metrics.toMapForBackend(),
      'settings': settings,
    };
  }

  Season copyWith({
    String? id,
    String? title,
    String? description,
    String? theme,
    SeasonStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    String? createdBy,
    String? createdByName,
    String? department,
    List<SeasonChallenge>? challenges,
    List<String>? participantIds,
    Map<String, SeasonParticipation>? participations,
    SeasonMetrics? metrics,
    Map<String, dynamic>? settings,
  }) {
    return Season(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      theme: theme ?? this.theme,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      department: department ?? this.department,
      challenges: challenges ?? this.challenges,
      participantIds: participantIds ?? this.participantIds,
      participations: participations ?? this.participations,
      metrics: metrics ?? this.metrics,
      settings: settings ?? this.settings,
    );
  }
}

class SeasonChallenge {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final int points;
  final List<SeasonMilestone> milestones;
  final Map<String, dynamic> requirements;
  final List<SeasonCourseResource> resources;
  final bool proofRequired;
  final String? proofType;
  final String? courseLevel;
  final int? estimatedHours;
  final bool isOptional;

  const SeasonChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.points,
    required this.milestones,
    required this.requirements,
    this.resources = const [],
    this.proofRequired = false,
    this.proofType,
    this.courseLevel,
    this.estimatedHours,
    this.isOptional = false,
  });

  factory SeasonChallenge.fromMap(Map<String, dynamic> map) {
    final challengeId = map['id'] ?? '';
    return SeasonChallenge(
      id: challengeId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: ChallengeType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'learning'),
        orElse: () => ChallengeType.learning,
      ),
      points: map['points'] ?? 0,
      milestones: (map['milestones'] as List<dynamic>? ?? [])
          .map((m) => SeasonMilestone.fromMap(m as Map<String, dynamic>, challengeId))
          .toList(),
      requirements: Map<String, dynamic>.from(map['requirements'] ?? {}),
      resources: (map['resources'] as List<dynamic>? ?? [])
          .map(
            (resource) => SeasonCourseResource.fromMap(
              Map<String, dynamic>.from(resource as Map),
            ),
          )
          .toList(),
      proofRequired: map['proofRequired'] ?? false,
      proofType: map['proofType'] as String?,
      courseLevel: map['courseLevel'] as String?,
      estimatedHours: map['estimatedHours'] as int?,
      isOptional: map['isOptional'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'points': points,
      'milestones': milestones.map((m) => m.toMap()).toList(),
      'requirements': requirements,
      'resources': resources.map((resource) => resource.toMap()).toList(),
      'proofRequired': proofRequired,
      'proofType': proofType,
      'courseLevel': courseLevel,
      'estimatedHours': estimatedHours,
      'isOptional': isOptional,
    };
  }
}

class SeasonCourseResource {
  final String title;
  final String provider;
  final String url;
  final bool isFreeResource;

  const SeasonCourseResource({
    required this.title,
    required this.provider,
    required this.url,
    this.isFreeResource = true,
  });

  factory SeasonCourseResource.fromMap(Map<String, dynamic> map) {
    return SeasonCourseResource(
      title: map['title'] ?? '',
      provider: map['provider'] ?? '',
      url: map['url'] ?? '',
      isFreeResource: map['isFreeResource'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'provider': provider,
      'url': url,
      'isFreeResource': isFreeResource,
    };
  }
}

class SeasonMilestone {
  final String id;
  final String title;
  final String description;
  final int points;
  final DateTime? targetDate;
  final Map<String, dynamic> criteria;
  final String challengeId;

  const SeasonMilestone({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    this.targetDate,
    required this.criteria,
    required this.challengeId,
  });

  factory SeasonMilestone.fromMap(Map<String, dynamic> map, String challengeId) {
    return SeasonMilestone(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      points: map['points'] ?? 0,
      targetDate: parseNullableDate(map['targetDate']),
      criteria: Map<String, dynamic>.from(map['criteria'] ?? {}),
      challengeId: challengeId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'points': points,
      'targetDate': targetDate?.toIso8601String(),
      'criteria': criteria,
    };
  }
}

class SeasonParticipation {
  final String userId;
  final String userName;
  final DateTime joinedAt;
  final Map<String, MilestoneStatus> milestoneProgress;
  final Map<String, SeasonChallengeSubmission> challengeSubmissions;
  final Map<String, dynamic> customGoals;
  final int totalPoints;
  final List<String> badgesEarned;
  final int completedChallenges;
  final DateTime? lastActivity;

  const SeasonParticipation({
    required this.userId,
    required this.userName,
    required this.joinedAt,
    required this.milestoneProgress,
    this.challengeSubmissions = const {},
    required this.customGoals,
    required this.totalPoints,
    required this.badgesEarned,
    this.completedChallenges = 0,
    this.lastActivity,
  });

  factory SeasonParticipation.fromMap(Map<String, dynamic> map) {
    return SeasonParticipation(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      joinedAt: parseDate(map['joinedAt']),
      milestoneProgress: Map<String, MilestoneStatus>.from(
        (map['milestoneProgress'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(
            key,
            MilestoneStatus.values.firstWhere(
              (e) => e.name == (value ?? 'notStarted'),
              orElse: () => MilestoneStatus.notStarted,
            ),
          ),
        ),
      ),
      challengeSubmissions: Map<String, SeasonChallengeSubmission>.from(
        (map['challengeSubmissions'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(
            key,
            SeasonChallengeSubmission.fromMap(
              Map<String, dynamic>.from(value as Map),
            ),
          ),
        ),
      ),
      customGoals: Map<String, dynamic>.from(map['customGoals'] ?? {}),
      totalPoints: map['totalPoints'] ?? 0,
      badgesEarned: List<String>.from(map['badgesEarned'] ?? []),
      completedChallenges: map['completedChallenges'] ?? 0,
      lastActivity: parseNullableDate(map['lastActivity']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'joinedAt': joinedAt.toIso8601String(),
      'milestoneProgress': milestoneProgress.map(
        (key, value) => MapEntry(key, value.name),
      ),
      'challengeSubmissions': challengeSubmissions.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'customGoals': customGoals,
      'totalPoints': totalPoints,
      'badgesEarned': badgesEarned,
      'completedChallenges': completedChallenges,
      'lastActivity': lastActivity?.toIso8601String(),
    };
  }
}

class SeasonChallengeSubmission {
  final String challengeId;
  final String evidence;
  final ChallengeSubmissionStatus status;
  final String submittedBy;
  final DateTime submittedAt;
  final String? feedback;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  const SeasonChallengeSubmission({
    required this.challengeId,
    required this.evidence,
    required this.status,
    required this.submittedBy,
    required this.submittedAt,
    this.feedback,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory SeasonChallengeSubmission.fromMap(Map<String, dynamic> map) {
    return SeasonChallengeSubmission(
      challengeId: map['challengeId'] ?? '',
      evidence: map['evidence'] ?? '',
      status: ChallengeSubmissionStatus.values.firstWhere(
        (value) => value.name == (map['status'] ?? 'notSubmitted'),
        orElse: () => ChallengeSubmissionStatus.notSubmitted,
      ),
      submittedBy: map['submittedBy'] ?? '',
      submittedAt: parseDate(map['submittedAt']),
      feedback: map['feedback'] as String?,
      reviewedBy: map['reviewedBy'] as String?,
      reviewedAt: parseNullableDate(map['reviewedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'challengeId': challengeId,
      'evidence': evidence,
      'status': status.name,
      'submittedBy': submittedBy,
      'submittedAt': submittedAt.toIso8601String(),
      'feedback': feedback,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt?.toIso8601String(),
    };
  }
}

class SeasonMetrics {
  final int totalParticipants;
  final int activeParticipants;
  final int completedChallenges;
  final int totalChallenges;
  final int totalPointsEarned;
  final double averageProgress;
  final Map<ChallengeType, int> challengeCompletions;
  final DateTime lastUpdated;
  final int totalTeamPoints;
  final int completedTeamChallenges;
  final List<String> managerBadgesEarned;
  final int managerPointsEarned;

  const SeasonMetrics({
    required this.totalParticipants,
    required this.activeParticipants,
    required this.completedChallenges,
    required this.totalChallenges,
    required this.totalPointsEarned,
    required this.averageProgress,
    required this.challengeCompletions,
    required this.lastUpdated,
    this.totalTeamPoints = 0,
    this.completedTeamChallenges = 0,
    this.managerBadgesEarned = const [],
    this.managerPointsEarned = 0,
  });

  factory SeasonMetrics.fromMap(Map<String, dynamic> map) {
    return SeasonMetrics(
      totalParticipants: map['totalParticipants'] ?? 0,
      activeParticipants: map['activeParticipants'] ?? 0,
      completedChallenges: map['completedChallenges'] ?? 0,
      totalChallenges: map['totalChallenges'] ?? 0,
      totalPointsEarned: map['totalPointsEarned'] ?? 0,
      averageProgress: (map['averageProgress'] ?? 0.0).toDouble(),
      challengeCompletions: Map<ChallengeType, int>.from(
        (map['challengeCompletions'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(
            ChallengeType.values.firstWhere(
              (e) => e.name == key,
              orElse: () => ChallengeType.learning,
            ),
            value as int,
          ),
        ),
      ),
      lastUpdated: Season._parseDate(map['lastUpdated']),
      totalTeamPoints: map['totalTeamPoints'] ?? 0,
      completedTeamChallenges: map['completedTeamChallenges'] ?? 0,
      managerBadgesEarned: List<String>.from(map['managerBadgesEarned'] ?? []),
      managerPointsEarned: map['managerPointsEarned'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return toMapForBackend();
  }

  Map<String, dynamic> toMapForBackend() {
    return {
      'totalParticipants': totalParticipants,
      'activeParticipants': activeParticipants,
      'completedChallenges': completedChallenges,
      'totalChallenges': totalChallenges,
      'totalPointsEarned': totalPointsEarned,
      'averageProgress': averageProgress,
      'challengeCompletions': challengeCompletions.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'lastUpdated': lastUpdated.toIso8601String(),
      'totalTeamPoints': totalTeamPoints,
      'completedTeamChallenges': completedTeamChallenges,
      'managerBadgesEarned': managerBadgesEarned,
      'managerPointsEarned': managerPointsEarned,
    };
  }
}

class SeasonBadge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String color;
  final int points;
  final Map<String, dynamic> criteria;

  const SeasonBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.points,
    required this.criteria,
  });

  factory SeasonBadge.fromMap(Map<String, dynamic> map) {
    return SeasonBadge(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      icon: map['icon'] ?? '🏆',
      color: map['color'] ?? '#FFD700',
      points: map['points'] ?? 0,
      criteria: Map<String, dynamic>.from(map['criteria'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'points': points,
      'criteria': criteria,
    };
  }
}
