import 'package:pdh/badges_v2/badge_v2_definition.dart';

class BadgeUserStatsV2 {
  final int goalsCreated;
  final int goalsCompleted;
  final int currentStreakDays;
  final int totalPoints;
  final int seasonsJoined;
  final int collaborationEngagements;

  const BadgeUserStatsV2({
    required this.goalsCreated,
    required this.goalsCompleted,
    required this.currentStreakDays,
    required this.totalPoints,
    required this.seasonsJoined,
    required this.collaborationEngagements,
  });
}

class BadgeEngineV2 {
  const BadgeEngineV2();

  int progressFor(BadgeRuleV2 rule, BadgeUserStatsV2 stats) {
    final target = rule.target <= 0 ? 1 : rule.target;
    int value;
    switch (rule.type) {
      case BadgeRuleTypeV2.goalsCreated:
        value = stats.goalsCreated;
        break;
      case BadgeRuleTypeV2.goalsCompleted:
        value = stats.goalsCompleted;
        break;
      case BadgeRuleTypeV2.currentStreakDays:
        value = stats.currentStreakDays;
        break;
      case BadgeRuleTypeV2.totalPoints:
        value = stats.totalPoints;
        break;
      case BadgeRuleTypeV2.seasonsJoined:
        value = stats.seasonsJoined;
        break;
      case BadgeRuleTypeV2.collaborationEngagements:
        value = stats.collaborationEngagements;
        break;
    }
    return value.clamp(0, target);
  }
}

