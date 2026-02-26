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
  // Use getters to avoid mutable static list ordering issues during hot reload,
  // and to prevent accidental runtime mutations.
  static List<SidebarItem> get employeeItems => List.unmodifiable([
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Dashboard_White.png',
      red: 'assets/Khonodemy Icons/Dashboard_Red.png',
      label: 'Dashboard',
      route: '/employee_dashboard',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Profile_White.png',
      red: 'assets/Khonodemy Icons/Profile_Red.png',
      label: 'Goal Workspace',
      route: '/my_pdp',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Alerts&Visuals_White.png',
      red: 'assets/Khonodemy Icons/Alerts&Visuals_Red.png',
      label: 'Alerts & Nudges',
      route: '/alerts_nudges',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/GoalWorkspace_White.png',
      red: 'assets/Khonodemy Icons/GoalWorkspace_Red.png',
      label: 'My PDP',
      route: '/my_goal_workspace',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/ProgressVisuals_Whie.png',
      red: 'assets/Khonodemy Icons/ProgressVisuals_Red.png',
      label: 'Progress Visuals',
      route: '/progress_visuals',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/LeaderBoard_White.png',
      red: 'assets/Khonodemy Icons/Leaderboard_Red.png',
      label: 'Leaderboard',
      route: '/leaderboard',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Badges&Points_White.png',
      red: 'assets/Khonodemy Icons/Badges&Points_Red.png',
      label: 'Badges & Points',
      route: '/badges_points',
    ),
    SidebarItem(
      icon: Icons.emoji_events_outlined,
      label: 'Season Challenges',
      route: '/season_challenges',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Repository&Audit_White.png',
      red: 'assets/Khonodemy Icons/Repository&Audit_Red.png',
      label: 'Repository & Audit',
      route: '/repository_audit',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Profile_White.png',
      red: 'assets/Khonodemy Icons/Profile_Red.png',
      label: 'My Profile',
      route: '/my_profile',
    ),
    // Goal Proof removed
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Settings_White.png',
      red: 'assets/Khonodemy Icons/Settings_Red.png',
      label: 'Settings & Privacy',
      route: '/settings',
    ),
  ]);

  // ===== MANAGER SIDEBAR ITEMS =====
  static List<SidebarItem> get managerItems => List.unmodifiable([
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Dashboard_White.png',
      red: 'assets/Khonodemy Icons/Dashboard_Red.png',
      label: 'Dashboard',
      route: '/dashboard',
    ),
    SidebarItem(icon: Icons.person, label: 'Goal Workspace', route: '/my_pdp'),
    SidebarItem(
      icon: Icons.inbox_outlined,
      label: 'Manager IBox',
      route: '/manager_inbox',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Alerts&Visuals_White.png',
      red: 'assets/Khonodemy Icons/Alerts&Visuals_Red.png',
      label: 'Team Alerts & Nudges',
      route: '/manager_alerts_nudges',
    ),
    SidebarItem(
      icon: Icons.emoji_events,
      label: 'Team Challenges',
      route: '/team_challenges_seasons',
    ),
    SidebarItem(
      icon: Icons.groups,
      label: 'Team Review',
      route: '/manager_review_team_dashboard',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/ProgressVisuals_Whie.png',
      red: 'assets/Khonodemy Icons/ProgressVisuals_Red.png',
      label: 'Progress Visuals',
      route: '/progress_visuals',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/LeaderBoard_White.png',
      red: 'assets/Khonodemy Icons/Leaderboard_Red.png',
      label: 'Leaderboard',
      route: '/manager_leaderboard',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Badges&Points_White.png',
      red: 'assets/Khonodemy Icons/Badges&Points_Red.png',
      label: 'Badges & Points',
      route: '/manager_badges_points',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Repository&Audit_White.png',
      red: 'assets/Khonodemy Icons/Repository&Audit_Red.png',
      label: 'Repository & Audit',
      route: '/repository_audit',
    ),
    SidebarItem(
      icon: Icons.manage_accounts,
      label: 'My Profile',
      route: '/manager_profile',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Settings_White.png',
      red: 'assets/Khonodemy Icons/Settings_Red.png',
      label: 'Settings & Privacy',
      route: '/settings',
    ),
  ]);

  // ===== ADMIN SIDEBAR ITEMS =====
  static List<SidebarItem> get adminItems => List.unmodifiable([
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
  ]);

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
