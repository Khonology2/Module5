import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/widgets/sidebar.dart';

class EmployeePortalScreen extends StatelessWidget {
  const EmployeePortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routeName = ModalRoute.of(context)?.settings.name;
    return AppScaffold(
      title: 'Employee Portal.',
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
        if (current != r) Navigator.pushNamed(context, r);
      },
      onLogout: () => Navigator.pushReplacementNamed(context, '/sign_in'),
      content: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/20250919_1033_Futuristic Red Patterns_remix_01k5ghm3a8e39bxbzcpw8sgg6v.png',
              fit: BoxFit.cover,
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
        child: const Center(
          child: Text(
            'Open menu to navigate',
            style: TextStyle(
              fontSize: 16.0,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // No main content actions; navigation happens via drawer
}
