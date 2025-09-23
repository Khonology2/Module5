import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/widgets/sidebar.dart';
// import 'package:pdh/bottom_nav_bar.dart'; // Bottom nav removed on leaderboard
import 'package:pdh/services/role_service.dart';

class LeaderboardScreen extends StatefulWidget { // Changed to StatefulWidget
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final routeName = ModalRoute.of(context)?.settings.name;
    return AppScaffold(
      title: 'Leaderboard',
      showAppBar: false,
      currentRouteName: routeName,
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
      onNavigate: (r) {
        final current = ModalRoute.of(context)?.settings.name;
        if (current != r) {
          Navigator.pushNamed(context, r);
        }
      },
      onLogout: () {
        Navigator.pushReplacementNamed(context, '/sign_in');
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
                    colors: [Color(0x880A0F1F), Color(0x88040610)],
                    stops: [0.0, 1.0],
                  ),
                ),
                child: StreamBuilder<String?>(
                  stream: RoleService.instance.roleStream(),
                  builder: (context, snapshot) {
                    final role = snapshot.data;
                    if (role == null) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white70));
                    }
                    final isManager = role == 'manager';
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _filtersBar(isManager: isManager),
                          const SizedBox(height: 16),
                          _podium(),
                          const SizedBox(height: 20),
                          _leaderList(isManager: isManager),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Drawer removed; sidebar is handled centrally in AppScaffold

Widget _filtersBar({required bool isManager}) {
  Widget chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A3652),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      );
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFF1F2840), borderRadius: BorderRadius.circular(10)),
    child: Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip('This month'),
              chip('Points'),
              chip('Streaks'),
              if (isManager) chip('My team'),
              if (isManager) chip('Org'),
            ],
          ),
        ),
        IconButton(icon: const Icon(Icons.filter_list, color: Colors.white70), onPressed: () {}),
      ],
    ),
  );
}

Widget _podium() {
  // Removed mock data for podium
  return Row(
    children: [
      // Removed mock data for podium
    ],
  );
}

Widget _leaderList({required bool isManager}) {
  // Removed mock data

  // Removed mock data for top performers

  // Removed mock data for full leaderboard

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Top performers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 10),
      // Removed mock data for top performers
      const SizedBox(height: 16),
      const Text('Full leaderboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 10),
      // Removed mock data for full leaderboard
    ],
  );
}
