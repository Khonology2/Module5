import 'package:flutter/material.dart';
// Drawers removed in favor of persistent sidebar
// Role-aware features handled inside MainLayout
// Profile handled by MainLayout

class BadgesPointsScreen extends StatelessWidget {
  const BadgesPointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0), // Adjusted padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Badges & Points', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildPointsAndLevelCard(),
          const SizedBox(height: 25),
          _buildSectionHeader('Achievements'),
          _buildAchievementsGrid(context),
          const SizedBox(height: 25),
          _buildLevelProgress(),
          const SizedBox(height: 25),
          _buildSectionHeader('Leaderboard'),
          _buildLeaderboard(),
          const SizedBox(height: 25),
          _buildSectionHeader('Team Challenges'),
          _buildTeamChallengeCard(
            context: context,
            title: 'Innovation Sprint',
            description: 'Submit creative solutions for workplace efficiency',
            progress: '7/15 participants',
            endsIn: '5 days',
            status: 'Join',
          ),
          const SizedBox(height: 15),
          _buildTeamChallengeCard(
            context: context,
            title: 'Wellness Week',
            description: 'Complete daily wellness activities with your team',
            progress: '12/20 participants',
            endsIn: '2 days',
            status: 'Joined',
          ),
          const SizedBox(height: 25),
          _buildSectionHeader('Recent Celebrations'),
          _buildCelebrationCard(
            icon: Icons.emoji_events,
            iconColor: const Color(0xFFC10D00),
            message: 'Alex completed the \'Code Review Champion\' badge!',
            time: '2 hours ago',
          ),
          const SizedBox(height: 10),
          _buildCelebrationCard(
            icon: Icons.thumb_up,
            iconColor: const Color(0xFFC10D00),
            message: 'Development Team reached Level 8!',
            time: 'Yesterday',
          ),
          const SizedBox(height: 10),
          _buildCelebrationCard(
            icon: Icons.workspace_premium,
            iconColor: const Color(0xFFC10D00),
            message: 'Lisa earned \'Collaboration Expert\' achievement!',
            time: '3 days ago',
          ),
          const SizedBox(height: 20),
          _buildAISuggestionsCard(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPointsAndLevelCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFC10D00),
            Color(0xFF0A1931),
          ], // App's red to dark blue gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '2,847',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Total Points',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Level 12',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Champion',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 0.9,
      children: [
        _buildAchievementCard(
          icon: Icons.emoji_events,
          iconColor: const Color(0xFFC10D00), // App's red color
          title: 'Team Player',
          description: 'Completed 10\nteam challenges',
          status: 'Earned Dec 15',
        ),
        _buildAchievementCard(
          icon: Icons.trending_up,
          iconColor: Colors.white,
          title: 'Streak Master',
          description: '30-day activity streak',
          status: 'In Progress',
        ),
        _buildAchievementCard(
          icon: Icons.star,
          iconColor: const Color(0xFFC10D00), // App's red color
          title: 'Innovation Star',
          description: 'Submitted 5\ncreative ideas',
          status: 'Earned Nov 28',
        ),
        _buildAchievementCard(
          icon: Icons.group,
          iconColor: Colors.white,
          title: 'Mentor',
          description: 'Help 20 team\nmembers',
          status: '12/20 Complete',
        ),
      ],
    );
  }

  Widget _buildAchievementCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840), // App's card background color
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 30),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const Spacer(),
          Text(
            status,
            style: TextStyle(
              color: status == 'In Progress'
                  ? Colors.orange
                  : const Color(0xFFC10D00), // App's red color
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Level Progress',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '847/1000 XP',
              style: TextStyle(
                color: Color(0xFFC10D00), // App's red color
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: 0.847,
          backgroundColor: Colors.grey.withValues(alpha: 0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(
            Color(0xFFC10D00),
          ), // App's red color
          minHeight: 8,
          borderRadius: BorderRadius.circular(5),
        ),
        const SizedBox(height: 5),
        const Text(
          '153 XP to Level 13',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLeaderboard() {
    return Column(
      children: [
        _buildLeaderboardEntry(
          rank: 1,
          name: 'Sarah Chen',
          team: 'Marketing Team',
          points: 3245,
          isYou: false,
        ),
        const SizedBox(height: 10),
        _buildLeaderboardEntry(
          rank: 2,
          name: 'You',
          team: 'Development Team',
          points: 2847,
          isYou: true,
        ),
        const SizedBox(height: 10),
        _buildLeaderboardEntry(
          rank: 3,
          name: 'Mike Rodriguez',
          team: 'Sales Team',
          points: 2634,
          isYou: false,
        ),
      ],
    );
  }

  Widget _buildLeaderboardEntry({
    required int rank,
    required String name,
    required String team,
    required int points,
    required bool isYou,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isYou
            ? const Color(0xFFC10D00).withValues(alpha: 0.4)
            : const Color(0xFF1F2840), // App's red and card colors
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isYou
                ? Colors.white
                : const Color(0xFFC10D00), // App's red color
            child: Text(
              '$rank',
              style: TextStyle(
                color: isYou ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  team,
                  style: TextStyle(
                    color: Colors.white70.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$points pts',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamChallengeCard({
    required BuildContext context,
    required String title,
    required String description,
    required String progress,
    required String endsIn,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840), // App's card background color
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$status challenge: $title')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: status == 'Joined'
                      ? Colors.grey
                      : const Color(0xFFC10D00), // App's red color
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                ),
                child: Text(status),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(
              color: Colors.white70.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress: $progress',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Ends in $endsIn',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCelebrationCard({
    required IconData icon,
    required Color iconColor,
    required String message,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840), // App's card background color
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.white70.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAISuggestionsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFC10D00),
            Color(0xFF0A1931),
          ], // App's green to dark blue gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'AI Smart Alerts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.psychology, color: Color(0xFFC10D00), size: 22),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Based on your activity, try joining the \'Knowledge Sharing\' challenge to earn the \'Mentor\' badge faster!',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 15),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Viewing AI Suggestions...')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('View Suggestions'),
            ),
          ),
        ],
      ),
    );
  }
}

// Drawer removed; persistent sidebar via MainLayout
