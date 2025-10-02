import 'package:cloud_firestore/cloud_firestore.dart';

enum BadgeCategory {
  achievement,
  streak,
  goals,
  collaboration,
  innovation,
  leadership,
  learning,
  community,
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

  factory Badge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return Badge(
      id: doc.id,
      name: data?['name'] ?? '',
      description: data?['description'] ?? '',
      iconName: data?['iconName'] ?? 'emoji_events',
      category: BadgeCategory.values.firstWhere(
        (e) => e.name == (data?['category'] ?? 'achievement'),
        orElse: () => BadgeCategory.achievement,
      ),
      rarity: BadgeRarity.values.firstWhere(
        (e) => e.name == (data?['rarity'] ?? 'common'),
        orElse: () => BadgeRarity.common,
      ),
      pointsRequired: (data?['pointsRequired'] ?? 0) as int,
      criteria: Map<String, dynamic>.from(data?['criteria'] ?? {}),
      earnedAt: (data?['earnedAt'] as Timestamp?)?.toDate(),
      isEarned: data?['isEarned'] ?? false,
      progress: (data?['progress'] ?? 0) as int,
      maxProgress: (data?['maxProgress'] ?? 1) as int,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'iconName': iconName,
      'category': category.name,
      'rarity': rarity.name,
      'pointsRequired': pointsRequired,
      'criteria': criteria,
      'earnedAt': earnedAt != null ? Timestamp.fromDate(earnedAt!) : null,
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
