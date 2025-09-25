import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:pdh/employee_drawer.dart'; // Import the EmployeeDrawer
import 'package:pdh/manager_nav_drawer.dart';
import 'package:pdh/services/role_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:pdh/employee_profile_screen.dart'; // Import EmployeeProfileScreen

class BadgesPointsScreen extends StatelessWidget {
  const BadgesPointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Set Scaffold background to transparent
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
      appBar: AppBar(
        title: const Text(
          'Badges & Points',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove AppBar shadow
        actions: [
          _buildProfileButton(context), // Use the new profile button widget
        ],
      ),
      drawer: const _RoleAwareDrawer(),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/20250919_1033_Futuristic Red Patterns_remix_01k5ghm3a8e39bxbzcpw8sgg6v.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // Apply stronger blur effect
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Color(0x880A0F1F), // More opaque semi-transparent overlay (alpha 0x88)
                      Color(0x88040610), // More opaque semi-transparent overlay (alpha 0x88)
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        icon: Icons.emoji_events, // Trophy icon
                        iconColor: const Color(0xFFC10D00), // App's red color
                        message: 'Alex completed the \'Code Review Champion\' badge!',
                        time: '2 hours ago',
                      ),
                      const SizedBox(height: 10),
                      _buildCelebrationCard(
                        icon: Icons.thumb_up, // Thumbs up icon
                        iconColor: const Color(0xFFC10D00), // App's red color
                        message: 'Development Team reached Level 8!',
                        time: 'Yesterday',
                      ),
                      const SizedBox(height: 10),
                      _buildCelebrationCard(
                        icon: Icons.workspace_premium, // Badge icon
                        iconColor: const Color(0xFFC10D00), // App's red color
                        message: 'Lisa earned \'Collaboration Expert\' achievement!',
                        time: '3 days ago',
                      ),
                      const SizedBox(height: 20),
                      _buildAISuggestionsCard(context),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? 'Profile';
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeProfileScreen()));
        },
        child: Row(
          children: [
            const Icon(Icons.person, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              userName,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
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
          colors: [Color(0xFFC10D00), Color(0xFF0A1931)], // App's red to dark blue gradient
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
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
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
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
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
              color: status == 'In Progress' ? Colors.orange : const Color(0xFFC10D00), // App's red color
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
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC10D00)), // App's red color
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
        color: isYou ? const Color(0xFFC10D00).withValues(alpha: 0.4) : const Color(0xFF1F2840), // App's red and card colors
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isYou ? Colors.white : const Color(0xFFC10D00), // App's red color
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
                  backgroundColor: status == 'Joined' ? Colors.grey : const Color(0xFFC10D00), // App's red color
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
            style: TextStyle(color: Colors.white70.withValues(alpha: 0.7), fontSize: 14),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress: $progress',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                  style: TextStyle(color: Colors.white70.withValues(alpha: 0.7), fontSize: 12),
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
          colors: [Color(0xFFC10D00), Color(0xFF0A1931)], // App's green to dark blue gradient
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
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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

class _RoleAwareDrawer extends StatelessWidget {
  const _RoleAwareDrawer();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: RoleService.instance.roleStream(),
      builder: (context, snapshot) {
        final isManager = snapshot.data == 'manager';
        return isManager ? const ManagerNavDrawer() : const EmployeeDrawer();
      },
    );
  }
}
