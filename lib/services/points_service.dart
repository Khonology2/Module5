import 'package:pdh/models/goal.dart';

class PointsService {
  // Base used for allocated points before weighting
  static const int base = 100;

  static double _categoryWeight(GoalCategory category) {
    switch (category) {
      case GoalCategory.work:
        return 1.0; // operational
      case GoalCategory.learning:
        return 0.8;
      case GoalCategory.health:
        return 0.9;
      case GoalCategory.personal:
        return 0.9;
    }
  }

  static double _priorityMult(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.low:
        return 0.8;
      case GoalPriority.medium:
        return 1.0;
      case GoalPriority.high:
        return 1.2;
    }
  }

  // Compute allocated points for a goal (can be cached on the goal doc as 'allocatedPoints')
  static int allocatedPointsForGoal(GoalCategory category, GoalPriority priority) {
    final allocated = base * _categoryWeight(category) * _priorityMult(priority);
    return allocated.round();
  }

  // Kickoff bonus (once) when moving from notStarted to inProgress or first progress > 0
  static int kickoffBonus(int allocatedPoints) {
    return (allocatedPoints * 0.10).round();
  }

  // Points to grant for a progress delta (0..100)
  static int progressDeltaPoints(int allocatedPoints, int deltaPercent) {
    if (deltaPercent <= 0) return 0;
    final pts = allocatedPoints * (deltaPercent / 100.0);
    return pts.round();
  }

  // Completion bonus (once) when completed
  static int completionBonus(int allocatedPoints) {
    return (allocatedPoints * 0.20).round();
  }

  // On-time modifier (applied in addition to completion bonus)
  static int onTimeModifier(int allocatedPoints) {
    return (allocatedPoints * 0.10).round();
  }

  // Late modifier (negative)
  static int lateModifier(int allocatedPoints) {
    return -(allocatedPoints * 0.10).round();
  }
}
