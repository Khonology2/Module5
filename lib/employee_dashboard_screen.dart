import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:pdh/widgets/sidebar.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:pdh/auth_service.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final routeName = ModalRoute.of(context)?.settings.name;

    return AppScaffold(
      title: 'Employee Dashboard',
      showAppBar: false,
      items: const [
        SidebarItem(icon: Icons.dashboard, label: 'Dashboard', route: '/employee_dashboard'),
        SidebarItem(icon: Icons.person_outline, label: 'Profile & PDP.', route: '/my_pdp'),
        SidebarItem(icon: Icons.track_changes, label: 'Goal Workspace', route: '/my_goal_workspace'),
        SidebarItem(icon: Icons.bar_chart, label: 'Progress Visuals.', route: '/progress_visuals'),
        SidebarItem(icon: Icons.notifications_none, label: 'Alerts & Visuals.', route: '/alerts_nudges'),
        SidebarItem(icon: Icons.workspace_premium, label: 'Badges & Points.', route: '/badges_points'),
        SidebarItem(icon: Icons.leaderboard, label: 'LeaderBoard.', route: '/leaderboard'),
        SidebarItem(icon: Icons.folder_open, label: 'Repository & Audit.', route: '/repository_audit'),
        SidebarItem(icon: Icons.settings_outlined, label: 'Settings & Privacy.', route: '/settings'),
      ],
      currentRouteName: routeName,
      onNavigate: (r) {
        final current = ModalRoute.of(context)?.settings.name;
        if (current != r) {
          Navigator.pushNamed(context, r);
        }
      },
      onLogout: () async {
        if (!mounted) return; // Ensure mounted before any async operation that might use context
        final currentContext = context; // Capture context before async gap
        await AuthService().signOut();
        if (mounted) {
          // ignore: use_build_context_synchronously
          Navigator.pushNamedAndRemoveUntil(currentContext, '/sign_in', (route) => false);
        }
      },
      content: Stack(
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
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Color(0x880A0F1F),
                      Color(0x88040610),
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: 20),
                      _buildQuickStats(),
                      const SizedBox(height: 20),
                      _buildRecentActivity(),
                      const SizedBox(height: 20),
                      _buildQuickActions(),
                      const SizedBox(height: 20),
                      _buildUpcomingGoals(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Sidebar handled by AppScaffold; no duplication here
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final user = FirebaseAuth.instance.currentUser; // Get current user
    final userName = user?.displayName?.split(' ').first ?? 'User'; // Extract first name

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Color(0xFFC10D00).withValues(alpha: 76)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFC10D00),
            child: Icon(
              Icons.person,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $userName!', // Use dynamic userName
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Ready to achieve your goals today?',
                  style: TextStyle(
                    color: Colors.white70.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Active Goals',
            value: '8',
            icon: Icons.track_changes,
            color: const Color(0xFFC10D00),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Completed',
            value: '12',
            icon: Icons.check_circle,
            color: const Color(0xFFC10D00),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Points',
            value: '1,250',
            icon: Icons.stars,
            color: const Color(0xFFFF9800),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white70.withValues(alpha: 0.8),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildActivityItem(
            icon: Icons.check_circle,
            title: 'Completed "Learn React Native"',
            subtitle: '2 hours ago',
            color: const Color(0xFFC10D00),
          ),
          const SizedBox(height: 8),
          _buildActivityItem(
            icon: Icons.add_circle,
            title: 'Added new goal: "Master Flutter"',
            subtitle: '1 day ago',
            color: const Color(0xFFC10D00),
          ),
          const SizedBox(height: 8),
          _buildActivityItem(
            icon: Icons.stars,
            title: 'Earned "Code Master" badge',
            subtitle: '3 days ago',
            color: const Color(0xFFFF9800),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white70.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.add,
                  label: 'Add Goal',
                  onTap: () {
                    Navigator.pushNamed(context, '/my_goal_workspace');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.bar_chart,
                  label: 'View Progress',
                  onTap: () {
                    Navigator.pushNamed(context, '/progress_visuals');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.leaderboard,
                  label: 'Leaderboard',
                  onTap: () {
                    Navigator.pushNamed(context, '/leaderboard');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.workspace_premium,
                  label: 'Badges',
                  onTap: () {
                    Navigator.pushNamed(context, '/badges_points');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFC10D00).withValues(alpha: 25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFC10D00).withValues(alpha: 76)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFC10D00), size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingGoals() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming Goals',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildGoalItem(
            title: 'Complete Flutter Certification',
            deadline: 'Due in 5 days',
            progress: 0.7,
          ),
          const SizedBox(height: 8),
          _buildGoalItem(
            title: 'Learn Advanced React Patterns',
            deadline: 'Due in 12 days',
            progress: 0.3,
          ),
          const SizedBox(height: 8),
          _buildGoalItem(
            title: 'Build Portfolio Project',
            deadline: 'Due in 20 days',
            progress: 0.1,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalItem({
    required String title,
    required String deadline,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3652),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            deadline,
            style: TextStyle(
              color: Colors.white70.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC10D00)),
          ),
        ],
      ),
    );
  }
}
