import 'package:pdh/models/goal.dart';
import 'package:pdh/services/database_service.dart';

class SampleDataSeeder {
  static Future<void> createSampleGoals(String uid) async {
    final now = DateTime.now();
    final samples = <Goal>[
      Goal(
        id: '',
        userId: uid,
        title: 'Read a book',
        description: 'Finish reading a self-improvement book',
        category: GoalCategory.learning,
        priority: GoalPriority.medium,
        createdAt: now,
        targetDate: now.add(const Duration(days: 14)),
        points: 30,
      ),
      Goal(
        id: '',
        userId: uid,
        title: 'Morning run 5km',
        description: 'Run 5km three times this week',
        category: GoalCategory.health,
        priority: GoalPriority.high,
        createdAt: now,
        targetDate: now.add(const Duration(days: 7)),
        points: 50,
      ),
    ];

    for (final goal in samples) {
      await DatabaseService.createGoal(goal);
    }
  }
}


