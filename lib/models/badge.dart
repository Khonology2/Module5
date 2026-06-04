import 'package:pdh/utils/date_parse.dart';

enum BadgeCategory {
  achievement,
  streak,
  goals,
  collaboration,
  innovation,
  leadership,
  learning,
  community,
  // ===== v2 category groups (employee-focused) =====
  goalMastery,
  consistency,
  growth,
  milestones,
}

enum BadgeRarity {
  common,
  rare,
  epic,
  legendary,
}

class Badge {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final BadgeCategory category;
  final BadgeRarity rarity;
  final int pointsRequired;
  final Map<String, dynamic> criteria;
  final DateTime? earnedAt;
  final bool isEarned;
  final int progress;
  final int maxProgress;

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.category,
    required this.rarity,
    required this.pointsRequired,
    required this.criteria,
    this.earnedAt,
    this.isEarned = false,
    this.progress = 0,
    required this.maxProgress,
  });

  factory Badge.fromMap(Map<String, dynamic> data, {String? fallbackId}) {
    return Badge(
      id: (data['id'] ?? fallbackId ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      iconName: (data['iconName'] ?? 'emoji_events').toString(),
      category: BadgeCategory.values.firstWhere(
        (e) => e.name == (data['category'] ?? 'achievement').toString(),
        orElse: () => BadgeCategory.achievement,
      ),
      rarity: BadgeRarity.values.firstWhere(
        (e) => e.name == (data['rarity'] ?? 'common').toString(),
        orElse: () => BadgeRarity.common,
      ),
      pointsRequired: (data['pointsRequired'] ?? 0) is num
          ? (data['pointsRequired'] as num).toInt()
          : int.tryParse(data['pointsRequired']?.toString() ?? '0') ?? 0,
      criteria: Map<String, dynamic>.from(
        (data['criteria'] as Map?) ?? const {},
      ),
      earnedAt: parseNullableDate(data['earnedAt'] ?? data['createdAt']),
      isEarned: data['isEarned'] == true,
      progress: (data['progress'] ?? 0) is num
          ? (data['progress'] as num).toInt()
          : int.tryParse(data['progress']?.toString() ?? '0') ?? 0,
      maxProgress: (data['maxProgress'] ?? 1) is num
          ? (data['maxProgress'] as num).toInt()
          : int.tryParse(data['maxProgress']?.toString() ?? '1') ?? 1,
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'name': name,
      'description': description,
      'iconName': iconName,
      'category': category.name,
      'rarity': rarity.name,
      'pointsRequired': pointsRequired,
      'criteria': criteria,
      'earnedAt': earnedAt?.toIso8601String(),
      'isEarned': isEarned,
      'progress': progress,
      'maxProgress': maxProgress,
    };
  }

  Badge copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    BadgeCategory? category,
    BadgeRarity? rarity,
    int? pointsRequired,
    Map<String, dynamic>? criteria,
    DateTime? earnedAt,
    bool? isEarned,
    int? progress,
    int? maxProgress,
  }) {
    return Badge(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      category: category ?? this.category,
      rarity: rarity ?? this.rarity,
      pointsRequired: pointsRequired ?? this.pointsRequired,
      criteria: criteria ?? this.criteria,
      earnedAt: earnedAt ?? this.earnedAt,
      isEarned: isEarned ?? this.isEarned,
      progress: progress ?? this.progress,
      maxProgress: maxProgress ?? this.maxProgress,
    );
  }

  double get progressPercentage => maxProgress > 0 ? (progress / maxProgress).clamp(0.0, 1.0) : 0.0;
  
  bool get isCompleted => progress >= maxProgress;
}
