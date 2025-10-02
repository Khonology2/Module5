import 'package:flutter/material.dart';
import 'package:pdh/widgets/sidebar.dart'; // Import ResponsiveSidebar
import 'package:pdh/dashboard_screen.dart'; // Import DashboardScreen
import 'package:pdh/manager_review_team_dashboard_screen.dart'; // Import ManagerReviewTeamDashboardScreen
import 'package:pdh/progress_visuals_screen.dart'; // Import ProgressVisualsScreen
import 'package:pdh/alerts_nudges_screen.dart'; // Import AlertsNudgesScreen
import 'package:pdh/leaderboard_screen.dart'; // Import LeaderboardScreen
import 'package:pdh/repository_audit_screen.dart'; // Import RepositoryAuditScreen
import 'package:pdh/settings_screen.dart'; // Import SettingsScreen
import 'package:pdh/my_pdp_screen.dart'; // Import MyPdpScreen
import 'package:pdh/my_goal_workspace_screen.dart'; // Import MyGoalWorkspaceScreen
import 'package:pdh/badges_points_screen.dart'; // Import BadgesPointsScreen
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth for logout
import 'package:pdh/sign_in_screen.dart'; // Import SignInScreen for post-logout navigation


class ManagerPortalScreen extends StatefulWidget {
  const ManagerPortalScreen({super.key});

  @override
  State<ManagerPortalScreen> createState() => _ManagerPortalScreenState();
}

class _ManagerPortalScreenState extends State<ManagerPortalScreen> {
  String _currentRoute = '/dashboard'; // Default route for manager

  final List<SidebarItem> _managerSidebarItems = [
    const SidebarItem(icon: Icons.dashboard, label: 'Dashboard', route: '/dashboard'),
    const SidebarItem(icon: Icons.person, label: 'Profile & PDP', route: '/my_pdp'), // Re-using MyPdpScreen for manager profile view
    const SidebarItem(icon: Icons.work, label: 'Goal Workspace', route: '/my_goal_workspace'), // Re-using MyGoalWorkspaceScreen
    const SidebarItem(icon: Icons.bar_chart, label: 'Progress Visuals', route: '/progress_visuals'),
    const SidebarItem(icon: Icons.notifications, label: 'Alerts & Nudges', route: '/alerts_nudges'),
    const SidebarItem(icon: Icons.workspace_premium, label: 'Badges & Points', route: '/badges_points'),
    const SidebarItem(icon: Icons.leaderboard, label: 'Leaderboard', route: '/leaderboard'),
    const SidebarItem(icon: Icons.folder_open, label: 'Repository & Audit', route: '/repository_audit'),
    const SidebarItem(icon: Icons.settings, label: 'Settings & Privacy', route: '/settings'),
    const SidebarItem(icon: Icons.groups, label: 'Review Team', route: '/manager_review_team_dashboard'),
  ];

  Widget _getBodyWidget() {
    switch (_currentRoute) {
      case '/dashboard':
        return const DashboardScreen();
      case '/my_pdp':
        return const MyPdpScreen();
      case '/my_goal_workspace':
        return const MyGoalWorkspaceScreen();
      case '/progress_visuals':
        return const ProgressVisualsScreen();
      case '/alerts_nudges':
        return const AlertsNudgesScreen();
      case '/badges_points':
        return const BadgesPointsScreen();
      case '/leaderboard':
        return const LeaderboardScreen();
      case '/repository_audit':
        return const RepositoryAuditScreen();
      case '/settings':
        return const SettingsScreen();
      case '/manager_review_team_dashboard':
        return const ManagerReviewTeamDashboardScreen();
      default:
        return const DashboardScreen();
    }
  }

  void _onNavigate(String route) {
    setState(() {
      _currentRoute = route;
    });
  }

  Future<void> _onLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()), // Use LoginScreen as SignInScreen is deprecated
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style here if needed to ensure consistency across the portal
    // SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    //   statusBarColor: Colors.transparent, // Transparent status bar
    //   systemNavigationBarColor: Colors.transparent, // Transparent navigation bar
    //   statusBarIconBrightness: Brightness.light, // For dark status bar icons
    //   systemNavigationBarIconBrightness: Brightness.light, // For dark navigation bar icons
    // ));
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
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
              child: Row(
                children: [
                  ResponsiveSidebar(
                    items: _managerSidebarItems,
                    onNavigate: _onNavigate,
                    currentRouteName: _currentRoute,
                    onLogout: _onLogout,
                  ),
                  Expanded(
                    child: _getBodyWidget(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
