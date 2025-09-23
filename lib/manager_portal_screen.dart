import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
// Removed unused imports
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/widgets/sidebar.dart';

class ManagerPortalScreen extends StatelessWidget {
  const ManagerPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routeName = ModalRoute.of(context)?.settings.name;
    return AppScaffold(
      title: 'Manager Portal',
      showAppBar: false,
      items: const [
        SidebarItem(icon: Icons.dashboard, label: 'Dashboard', route: '/dashboard'),
        SidebarItem(icon: Icons.groups, label: 'Manager Review', route: '/manager_review_team_dashboard'),
        SidebarItem(icon: Icons.bar_chart, label: 'Progress Visuals', route: '/progress_visuals'),
        SidebarItem(icon: Icons.notifications, label: 'Alerts & Nudges', route: '/alerts_nudges'),
        SidebarItem(icon: Icons.leaderboard, label: 'Leaderboard', route: '/leaderboard'),
        SidebarItem(icon: Icons.folder_open, label: 'Repository & Audit', route: '/repository_audit'),
        SidebarItem(icon: Icons.settings, label: 'Settings & Privacy', route: '/settings'),
      ],
      currentRouteName: routeName,
      onNavigate: (r) {
        final current = ModalRoute.of(context)?.settings.name;
        if (current != r) Navigator.pushNamed(context, r);
      },
      onLogout: () => Navigator.pushReplacementNamed(context, '/sign_in'),
      content: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/20250919_1033_Futuristic Red Patterns_remix_01k5ghm3a8e39bxbzcpw8sgg6v.png',
              fit: BoxFit.cover,
            ),
          ),
          // Overlay for gradient effect and content
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Color(0x880A0F1F), // More opaque semi-transparent overlay
                      Color(0x88040610), // More opaque semi-transparent overlay
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      const SizedBox(height: 40),
                            const Text(
                              'Welcome to Manager Portal',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Access all management tools and team oversight features from the sidebar menu.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                height: 1.5,
                              ),
                            ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Sidebar handled by AppScaffold
        ],
      ),
    );
  }

}

// Removed inline _ManagerDrawer in favor of reusable ManagerNavDrawer
