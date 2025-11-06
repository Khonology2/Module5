class ManagerLevelInfo {
  final int level;
  final String title;
  final String theme; // emoji or icon hint
  final String description;
  const ManagerLevelInfo({
    required this.level,
    required this.title,
    required this.theme,
    required this.description,
  });
}

class ManagerLevelService {
  static ManagerLevelInfo getInfoForPoints(int points) {
    if (points >= 3500) {
      return const ManagerLevelInfo(
        level: 5,
        title: 'Master Coach',
        theme: '🏆',
        description: 'Excellence Leader — demonstrates outstanding leadership with consistently strong team development results.',
      );
    }
    if (points >= 2000) {
      return const ManagerLevelInfo(
        level: 4,
        title: 'Strategic Mentor',
        theme: '🧭',
        description: 'Growth Driver — leads teams through Growth Seasons with high completion and engagement.',
      );
    }
    if (points >= 1000) {
      return const ManagerLevelInfo(
        level: 3,
        title: 'Growth Enabler',
        theme: '🌱',
        description: 'Team Motivator — maintains active PDPs and helps replan goals when needed.',
      );
    }
    if (points >= 500) {
      return const ManagerLevelInfo(
        level: 2,
        title: 'Active Coach',
        theme: '💬',
        description: 'Consistent Leader — regularly engages in reviews, feedback, and check-ins to guide progress.',
      );
    }
    return const ManagerLevelInfo(
      level: 1,
      title: 'Starter Coach',
      theme: '🎯',
      description: 'New Manager — has begun supporting team development through initial acknowledgements and feedback.',
    );
  }
}
