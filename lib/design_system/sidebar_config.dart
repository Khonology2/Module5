import 'package:flutter/material.dart';
import 'package:pdh/widgets/sidebar.dart';

/// Standard sidebar configuration for the Personal Development Hub app
/// Provides consistent navigation items for different user roles
class SidebarConfig {
  // Private constructor
  SidebarConfig._();

  /// Ensures all icons (image or icon) have consistent size and alignment
  static Widget sidebarIcon(String assetPath) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: Image.asset(
          assetPath,
          width: 24,
          height: 24,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  static SidebarItem itemWithAssets({
    required String white,
    String? red,
    required String label,
    required String route,
  }) {
    return SidebarItem(
      assetWhite: white,
      assetRed: red,
      label: label,
      route: route,
    );
  }

  // ===== EMPLOYEE SIDEBAR ITEMS =====
  static List<SidebarItem> employeeItems = [
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Dashboard_White.png',
      red:   'assets/Khonodemy Icons/Dashboard_Red.png',
      label: 'Dashboard',
      route: '/employee_dashboard',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Profile_White.png',
      red:   'assets/Khonodemy Icons/Profile_Red.png',
      label: 'Profile',
      route: '/my_pdp',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/GoalWorkspace_White.png',
      red:   'assets/Khonodemy Icons/GoalWorkspace_Red.png',
      label: 'Goal Workspace',
      route: '/my_goal_workspace',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/ProgressVisuals_Whie.png',
      red:   'assets/Khonodemy Icons/ProgressVisuals_Red.png',
      label: 'Progress Visuals',
      route: '/progress_visuals',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Alerts&Visuals_White.png',
      red:   'assets/Khonodemy Icons/Alerts&Visuals_Red.png',
      label: 'Alerts & Visuals',
      route: '/alerts_nudges',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Badges&Points_White.png',
      red:   'assets/Khonodemy Icons/Badges&Points_Red.png',
      label: 'Badges & Points',
      route: '/badges_points',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/LeaderBoard_White.png',
      red:   'assets/Khonodemy Icons/Leaderboard_Red.png',
      label: 'Leaderboard',
      route: '/leaderboard',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Repository&Audit_White.png',
      red:   'assets/Khonodemy Icons/Repository&Audit_Red.png',
      label: 'Repository & Audit',
      route: '/repository_audit',
    ),
    // Goal Proof removed
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Settings_White.png',
      red:   'assets/Khonodemy Icons/Settings_Red.png',
      label: 'Settings & Privacy',
      route: '/settings',
    ),
  ];

  // ===== MANAGER SIDEBAR ITEMS =====
  static List<SidebarItem> managerItems = [
    // Dashboard → /dashboard
    SidebarItem(
      icon: Icons.dashboard,
      label: 'Dashboard',
      route: '/dashboard',
    ),
    // Profile → /my_pdp
    SidebarItem(
      icon: Icons.person,
      label: 'Profile',
      route: '/my_pdp',
    ),
    // Team Challenges & Seasons → /team_challenges_seasons
    SidebarItem(
      icon: Icons.emoji_events,
      label: 'Team Challenges & Seasons',
      route: '/team_challenges_seasons',
    ),
    // Progress Visuals → /progress_visuals
    SidebarItem(
      iconWidget: SidebarConfig.sidebarIcon('assets/Khonodemy Icons/ProgressVisuals_Whie.png'),
      label: 'Progress Visuals',
      route: '/progress_visuals',
    ),
    // Team Alerts & Nudges → /manager_alerts_nudges
    SidebarItem(
      iconWidget: SidebarConfig.sidebarIcon('assets/Khonodemy Icons/Alerts&Visuals_White.png'),
      label: 'Team Alerts & Nudges',
      route: '/manager_alerts_nudges',
    ),
    // Badges & Points → /badges_points
    SidebarItem(
      icon: Icons.workspace_premium,
      label: 'Badges & Points',
      route: '/badges_points',
    ),
    // Leaderboard → /manager_leaderboard
    SidebarItem(
      iconWidget: SidebarConfig.sidebarIcon('assets/Khonodemy Icons/LeaderBoard_White.png'),
      label: 'Leaderboard',
      route: '/manager_leaderboard',
    ),
    // Repository & Audit → /repository_audit
    SidebarItem(
      iconWidget: SidebarConfig.sidebarIcon('assets/Khonodemy Icons/Repository&Audit_White.png'),
      label: 'Repository & Audit',
      route: '/repository_audit',
    ),
    // Settings & Privacy → /settings
    SidebarItem(
      iconWidget: SidebarConfig.sidebarIcon('assets/Khonodemy Icons/Settings_White.png'),
      label: 'Settings & Privacy',
      route: '/settings',
    ),
    // Review Team → /manager_review_team_dashboard
    SidebarItem(
      icon: Icons.groups,
      label: 'Review Team',
      route: '/manager_review_team_dashboard',
    ),
  ];

  // ===== ADMIN SIDEBAR ITEMS =====
  static List<SidebarItem> adminItems = [
    SidebarItem(
      icon: Icons.admin_panel_settings,
      label: 'Admin Dashboard',
      route: '/admin_dashboard',
    ),
    SidebarItem(
      icon: Icons.people,
      label: 'User Management',
      route: '/user_management',
    ),
    SidebarItem(icon: Icons.analytics, label: 'Analytics', route: '/analytics'),
    SidebarItem(
      icon: Icons.settings,
      label: 'System Settings',
      route: '/system_settings',
    ),
    SidebarItem(icon: Icons.security, label: 'Security', route: '/security'),
    SidebarItem(
      icon: Icons.backup,
      label: 'Backup & Restore',
      route: '/backup',
    ),
  ];

  // ===== UTILITY METHODS =====
  static List<SidebarItem> getItemsForRole(String role) {
    switch (role.toLowerCase()) {
      case 'employee':
        return employeeItems;
      case 'manager':
        return managerItems;
      case 'admin':
        return adminItems;
      default:
        return employeeItems;
    }
  }

  static List<SidebarItem> getItemsForRoute(String route) {
    if (route.startsWith('/manager') || route.startsWith('/dashboard')) {
      return managerItems;
    } else if (route.startsWith('/admin')) {
      return adminItems;
    } else {
      return employeeItems;
    }
  }

  static bool isRouteValidForRole(String route, String role) {
    final items = getItemsForRole(role);
    return items.any((item) => item.route == route);
  }

  static String getDefaultRouteForRole(String role) {
    switch (role.toLowerCase()) {
      case 'employee':
        return '/employee_dashboard';
      case 'manager':
        return '/dashboard';
      case 'admin':
        return '/admin_dashboard';
      default:
        return '/employee_dashboard';
    }
  }

  static Widget? getIconForRoute(String route) {
    final allItems = [...employeeItems, ...managerItems, ...adminItems];
    final item = allItems.firstWhere(
      (item) => item.route == route,
      orElse: () => const SidebarItem(
        icon: Icons.help_outline,
        label: 'Unknown',
        route: '/unknown',
      ),
    );
    return item.iconWidget ?? Icon(item.icon!);
  }

  static String getLabelForRoute(String route) {
    final allItems = [...employeeItems, ...managerItems, ...adminItems];
    final item = allItems.firstWhere(
      (item) => item.route == route,
      orElse: () => const SidebarItem(
        icon: Icons.help_outline,
        label: 'Unknown',
        route: '/unknown',
      ),
    );
    return item.label;
  }
}
