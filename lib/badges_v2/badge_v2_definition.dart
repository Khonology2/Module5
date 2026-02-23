import 'package:pdh/models/badge.dart';

enum BadgeRuleTypeV2 {
  goalsCreated,
  goalsCompleted,
  currentStreakDays,
  totalPoints,
  seasonsJoined,
  // Reserved for future data sources
  collaborationEngagements,
}

class BadgeRuleV2 {
  final BadgeRuleTypeV2 type;
  final int target;

  const BadgeRuleV2({required this.type, required this.target});

  Map<String, dynamic> toCriteriaMap() => {
    'designVersion': 2,
    'ruleType': type.name,
    'target': target,
  };
}

class BadgeDefinitionV2 {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final BadgeCategory category;
  final BadgeRarity rarity;
  final BadgeRuleV2 rule;
  final int sortOrder;

  const BadgeDefinitionV2({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.category,
    required this.rarity,
    required this.rule,
    required this.sortOrder,
  });

  Badge seedBadge() {
    final target = rule.target <= 0 ? 1 : rule.target;
    final maxProgress = rule.type == BadgeRuleTypeV2.currentStreakDays ||
            rule.type == BadgeRuleTypeV2.totalPoints ||
            rule.type == BadgeRuleTypeV2.seasonsJoined ||
            rule.type == BadgeRuleTypeV2.goalsCreated ||
            rule.type == BadgeRuleTypeV2.goalsCompleted ||
            rule.type == BadgeRuleTypeV2.collaborationEngagements
        ? target
        : 1;

    return Badge(
      id: id,
      name: name,
      description: description,
      iconName: iconName,
      category: category,
      rarity: rarity,
      pointsRequired: 0,
      criteria: rule.toCriteriaMap(),
      maxProgress: maxProgress,
      isEarned: false,
      progress: 0,
      earnedAt: null,
    );
  }
}

