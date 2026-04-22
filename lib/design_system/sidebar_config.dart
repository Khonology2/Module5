import 'package:flutter/material.dart';
import 'package:pdh/widgets/sidebar.dart';
import 'package:pdh/services/workspace_context_service.dart';
import 'package:pdh/services/role_service.dart';

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

  // ===== WORKSPACE-SPECIFIC ITEMS =====

  /// My Workspace items (for employees and managers when in my workspace context)
  static List<SidebarItem> get myWorkspaceItems => List.unmodifiable([
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
  ]);

  /// Manager "My Workspace" uses manager_gw_menu routes so navigation stays
  /// inside ManagerPortalScreen while showing employee-style screens.
  static List<SidebarItem> get managerMyWorkspaceItems => List.unmodifiable([
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Dashboard_White.png',
      red: 'assets/Khonodemy Icons/Dashboard_Red.png',
      label: 'Dashboard',
      route: '/manager_gw_menu_dashboard',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Profile_White.png',
      red: 'assets/Khonodemy Icons/Profile_Red.png',
      label: 'Goal Workspace',
      route: '/manager_gw_menu_goal_workspace',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Alerts&Visuals_White.png',
      red: 'assets/Khonodemy Icons/Alerts&Visuals_Red.png',
      label: 'Alerts & Nudges',
      route: '/manager_gw_menu_alerts',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/GoalWorkspace_White.png',
      red: 'assets/Khonodemy Icons/GoalWorkspace_Red.png',
      label: 'My PDP',
      route: '/manager_gw_menu_my_pdp',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/ProgressVisuals_Whie.png',
      red: 'assets/Khonodemy Icons/ProgressVisuals_Red.png',
      label: 'Progress Visuals',
      route: '/manager_gw_menu_progress',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/LeaderBoard_White.png',
      red: 'assets/Khonodemy Icons/Leaderboard_Red.png',
      label: 'Leaderboard',
      route: '/manager_gw_menu_leaderboard',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Badges&Points_White.png',
      red: 'assets/Khonodemy Icons/Badges&Points_Red.png',
      label: 'Badges & Points',
      route: '/manager_gw_menu_badges',
    ),
    SidebarItem(
      icon: Icons.emoji_events_outlined,
      label: 'Season Challenges',
      route: '/manager_gw_menu_season_challenges',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Repository&Audit_White.png',
      red: 'assets/Khonodemy Icons/Repository&Audit_Red.png',
      label: 'Repository & Audit',
      route: '/manager_gw_menu_repository',
    ),
  ]);

  /// Manager Workspace items (for managers when in manager workspace context)
  static List<SidebarItem> get managerWorkspaceItems => List.unmodifiable([
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Dashboard_White.png',
      red: 'assets/Khonodemy Icons/Dashboard_Red.png',
      label: 'Dashboard',
      route: '/dashboard',
    ),
    const SidebarItem(
      icon: Icons.inbox_outlined,
      label: 'Inbox',
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
  ]);

  /// Global navigation items (always visible at bottom)
  static List<SidebarItem> get globalItems => List.unmodifiable([
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Profile_White.png',
      red: 'assets/Khonodemy Icons/Profile_Red.png',
      label: 'My Profile',
      route: '/my_profile',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Settings_White.png',
      red: 'assets/Khonodemy Icons/Settings_Red.png',
      label: 'Settings & Privacy',
      route: '/settings',
    ),
  ]);

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
    const SidebarItem(
      icon: Icons.inbox_outlined,
      label: 'Inbox',
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
  // Labels and order mirror manager sidebar (excluding Manager Workspace). Admin oversees managers.
  static List<SidebarItem> get adminItems => List.unmodifiable([
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Dashboard_White.png',
      red: 'assets/Khonodemy Icons/Dashboard_Red.png',
      label: 'Dashboard',
      route: '/admin_dashboard',
    ),
    SidebarItem(
      icon: Icons.inbox_outlined,
      label: 'Inbox',
      route: '/admin_inbox',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Alerts&Visuals_White.png',
      red: 'assets/Khonodemy Icons/Alerts&Visuals_Red.png',
      label: 'Team Alerts & Nudges',
      route: '/admin_team_alerts_nudges',
    ),
    SidebarItem(
      icon: Icons.emoji_events,
      label: 'Team Challenges',
      route: '/admin_team_challenges',
    ),
    SidebarItem(
      icon: Icons.groups,
      label: 'Team Review',
      route: '/admin_team_review',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/ProgressVisuals_Whie.png',
      red: 'assets/Khonodemy Icons/ProgressVisuals_Red.png',
      label: 'Progress Visuals',
      route: '/admin_progress_visuals',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/LeaderBoard_White.png',
      red: 'assets/Khonodemy Icons/Leaderboard_Red.png',
      label: 'Leaderboard',
      route: '/org_leaderboard',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Badges&Points_White.png',
      red: 'assets/Khonodemy Icons/Badges&Points_Red.png',
      label: 'Badges & Points',
      route: '/admin_badges_points',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Repository&Audit_White.png',
      red: 'assets/Khonodemy Icons/Repository&Audit_Red.png',
      label: 'Repository & Audit',
      route: '/admin_repository_audit',
    ),
    SidebarItem(
      icon: Icons.manage_accounts,
      label: 'My Profile',
      route: '/admin_profile',
    ),
    itemWithAssets(
      white: 'assets/Khonodemy Icons/Settings_White.png',
      red: 'assets/Khonodemy Icons/Settings_Red.png',
      label: 'Settings & Privacy',
      route: '/admin_settings',
    ),
  ]);

  // ===== UTILITY METHODS =====

  /// Get sidebar items based on workspace context and user role
  static List<SidebarItem> getItemsForWorkspaceAndRole(
    String role,
    WorkspaceContext workspace,
  ) {
    final roleLower = role.toLowerCase();

    // Employees only have access to My Workspace (personal goals)
    if (roleLower == 'employee') {
      return [...myWorkspaceItems, ...globalItems];
    }

    // Admins use admin items (no workspace switching)
    if (roleLower == 'admin') {
      return adminItems;
    }

    // Managers can switch between workspaces
    if (workspace == WorkspaceContext.managerWorkspace) {
      return [...managerWorkspaceItems, ...globalItems];
    } else {
      return [...managerMyWorkspaceItems, ...globalItems];
    }
  }

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

  /// Admin route paths (used for getItemsForRoute; excludes /manager* used by manager).
  static const Set<String> _adminRoutes = {
    '/admin_dashboard',
    '/admin_inbox',
    '/admin_team_alerts_nudges',
    '/admin_team_challenges',
    '/admin_team_review',
    '/admin_progress_visuals',
    '/org_leaderboard',
    '/admin_badges_points',
    '/admin_repository_audit',
    '/admin_profile',
    '/admin_settings',
  };

  static List<SidebarItem> getItemsForRoute(String route) {
    if (_adminRoutes.contains(route)) {
      return adminItems;
    }
    if (route.startsWith('/manager') || route.startsWith('/dashboard')) {
      return managerItems;
    }
    return employeeItems;
  }

  /// Get sidebar items based on current workspace context
  static List<SidebarItem> getItemsForCurrentWorkspace() {
    final workspaceService = WorkspaceContextService();
    final role = RoleService.instance.cachedRole ?? 'employee';
    return getItemsForWorkspaceAndRole(role, workspaceService.currentContext);
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
