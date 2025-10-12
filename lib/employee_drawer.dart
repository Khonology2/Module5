import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/sign_in_screen.dart';

class EmployeeDrawer extends StatelessWidget {
  const EmployeeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      backgroundColor: const Color(0xFF1F2840),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFC10D00), Color(0xFFC10D00)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Employee Portal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.dashboard,
            text: 'Dashboard',
            route: '/employee_dashboard',
            isSelected: currentRoute == '/employee_dashboard',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.person_outline,
            text: 'Profile & PDP.',
            route: '/my_pdp',
            isSelected: currentRoute == '/my_pdp',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.track_changes,
            text: 'Goal Workspace',
            route: '/my_goal_workspace',
            isSelected: currentRoute == '/my_goal_workspace',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.bar_chart,
            text: 'Progress Visuals.',
            route: '/progress_visuals',
            isSelected: currentRoute == '/progress_visuals',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.notifications_none,
            text: 'Alerts & Visuals.',
            route: '/alerts_nudges',
            isSelected: currentRoute == '/alerts_nudges',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.workspace_premium,
            text: 'Badges & Points.',
            route: '/badges_points',
            isSelected: currentRoute == '/badges_points',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.leaderboard,
            text: 'LeaderBoard.',
            route: '/leaderboard',
            isSelected: currentRoute == '/leaderboard',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.folder_open,
            text: 'Repository & Audit.',
            route: '/repository_audit',
            isSelected: currentRoute == '/repository_audit',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.cloud_done_outlined,
            text: 'Evidence Repository',
            route: '/evidence_repository',
            isSelected: currentRoute == '/evidence_repository',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.upload_file,
            text: 'Goal Evidence Submission',
            route: '/goal_evidence_submission',
            isSelected: currentRoute == '/goal_evidence_submission',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.settings_outlined,
            text: 'Settings & Privacy.',
            route: '/settings',
            isSelected: currentRoute == '/settings',
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Exit.', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String text,
    required String route,
    bool isSelected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Container(
        height: 60,
        decoration: ShapeDecoration(
          shape: const StadiumBorder(), // Changed to StadiumBorder
          gradient: const LinearGradient(
            colors: [Color(0xFFC10D00), Color(0xFFC10D00)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          shadows: isSelected
              ? [
                  BoxShadow(
                    color: Color(0xFFC10D00).withValues(alpha: 89),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
            final currentRouteName = ModalRoute.of(context)?.settings.name;
            if (currentRouteName != route) {
              // Guard: prevent navigating to manager-only screens
              final blocked = {
                '/manager_portal',
                '/dashboard',
                '/manager_review_team_dashboard',
              };
              if (blocked.contains(route)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Access restricted to managers'),
                  ),
                );
                return;
              }
              Navigator.pushNamed(context, route);
            }
          },
          icon: Icon(icon, color: Colors.white, size: 24),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
