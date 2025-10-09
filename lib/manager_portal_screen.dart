import 'package:flutter/material.dart';
import 'package:pdh/widgets/sidebar.dart'; // Import ResponsiveSidebar
import 'package:pdh/manager_review_team_dashboard_screen.dart'; // Import ManagerReviewTeamDashboardScreen
import 'package:pdh/manager_dashboard_screen.dart'; // New Manager Dashboard
import 'package:pdh/progress_visuals_screen.dart'; // Import ProgressVisualsScreen
import 'package:pdh/manager_alerts_nudges_screen.dart'; // Import ManagerAlertsNudgesScreen
import 'package:pdh/manager_team_workspace_screen.dart'; // Import ManagerTeamWorkspaceScreen
// Removed: employee leaderboard import; manager uses ManagerLeaderboardScreen
// Removed in favor of employee leaderboard UI for uniformity
import 'package:pdh/leaderboard_screen.dart'; // Use employee leaderboard UI
import 'package:pdh/repository_audit_screen.dart'; // Import RepositoryAuditScreen
import 'package:pdh/settings_screen.dart'; // Import SettingsScreen
import 'package:pdh/my_pdp_screen.dart'; // Import MyPdpScreen
// Import MyGoalWorkspaceScreen
import 'package:pdh/badges_points_screen.dart'; // Import BadgesPointsScreen
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth for logout
import 'package:pdh/sign_in_screen.dart'; // Import SignInScreen for post-logout navigation
import 'package:pdh/manager_profile_screen.dart'; // Import ManagerProfileScreen
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';

class ManagerPortalScreen extends StatefulWidget {
  const ManagerPortalScreen({super.key});

  @override
  State<ManagerPortalScreen> createState() => _ManagerPortalScreenState();
}

class _ManagerPortalScreenState extends State<ManagerPortalScreen> {
  String _currentRoute = '/dashboard'; // Default to Dashboard

  final List<SidebarItem> _managerSidebarItems = [
    const SidebarItem(
      icon: Icons.dashboard,
      label: 'Dashboard',
      route: '/dashboard',
    ),
    const SidebarItem(
      icon: Icons.person,
      label: 'Profile & PDP',
      route: '/my_pdp',
    ), // Re-using MyPdpScreen for manager profile view
    const SidebarItem(
      icon: Icons.work,
      label: 'Team Workspace',
      route: '/manager_team_workspace',
    ), // Manager-specific team workspace
    const SidebarItem(
      icon: Icons.bar_chart,
      label: 'Progress Visuals',
      route: '/progress_visuals',
    ),
    const SidebarItem(
      icon: Icons.message_outlined,
      label: 'Team Alerts & Nudges',
      route: '/manager_alerts_nudges',
    ),
    const SidebarItem(
      icon: Icons.workspace_premium,
      label: 'Badges & Points',
      route: '/badges_points',
    ),
    const SidebarItem(
      icon: Icons.leaderboard,
      label: 'Leaderboard',
      route: '/manager_leaderboard',
    ),
    const SidebarItem(
      icon: Icons.folder_open,
      label: 'Repository & Audit',
      route: '/repository_audit',
    ),
    const SidebarItem(
      icon: Icons.settings,
      label: 'Settings & Privacy',
      route: '/settings',
    ),
    const SidebarItem(
      icon: Icons.groups,
      label: 'Review Team',
      route: '/manager_review_team_dashboard',
    ),
  ];

  Widget _getBodyWidget() {
    switch (_currentRoute) {
      case '/dashboard':
        return const ManagerDashboardScreen();
      case '/my_pdp':
        return const MyPdpScreen();
      case '/manager_team_workspace':
        return const ManagerTeamWorkspaceScreen(embedded: true);
      case '/progress_visuals':
        return const ProgressVisualsScreen(embedded: true);
      case '/manager_alerts_nudges':
        return const ManagerAlertsNudgesScreen(embedded: true);
      case '/badges_points':
        return const BadgesPointsScreen(embedded: true);
      case '/manager_leaderboard':
        return const LeaderboardScreen();
      case '/repository_audit':
        return const RepositoryAuditScreen();
      case '/settings':
        return const SettingsScreen();
      case '/manager_review_team_dashboard':
        return const ManagerReviewTeamDashboardScreen();
      default:
        return const ManagerDashboardScreen();
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
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ), // Use LoginScreen as SignInScreen is deprecated
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
                  Expanded(child: _getBodyWidget()),
                ],
              ),
            ),
          ),
          // Profile button positioned in top-right corner
          Positioned(top: 16, right: 16, child: _buildProfileButton(context)),
        ],
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String userName = 'User';
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      userName = user.displayName!.split(' ').first;
    } else if (user?.email != null && user!.email!.isNotEmpty) {
      userName = user.email!.split('@').first;
    }
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ManagerProfileScreen()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.elevatedBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              userName,
              style: AppTypography.bodySmall.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
