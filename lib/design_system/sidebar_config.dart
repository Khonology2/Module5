import 'package:flutter/material.dart';
import 'package:pdh/widgets/sidebar.dart';

/// Standard sidebar configuration for the Personal Development Hub app
/// Provides consistent navigation items for different user roles
class SidebarConfig {
  // Private constructor to prevent instantiation
  SidebarConfig._();

  // ===== EMPLOYEE SIDEBAR ITEMS =====
  static List<SidebarItem> employeeItems = [
    SidebarItem(
      iconWidget: Image.asset('assets/rokects.png', width: 24.0, height: 24.0),
      label: 'Dashboard',
      route: '/employee_dashboard',
    ),
    SidebarItem(
      iconWidget: Image.asset(
        'assets/Account_User_Profile/Profile.png',
        width: 24.0,
        height: 24.0,
      ),
      label: 'Profile & PDP.',
      route: '/my_pdp',
    ),
    SidebarItem(
      icon: Icons.track_changes,
      label: 'Goal Workspace',
      route: '/my_goal_workspace',
    ),
    SidebarItem(
      icon: Icons.bar_chart,
      label: 'Progress Visuals.',
      route: '/progress_visuals',
    ),
    SidebarItem(
      icon: Icons.notifications_none,
      label: 'Alerts & Visuals.',
      route: '/alerts_nudges',
    ),
    SidebarItem(
      icon: Icons.workspace_premium,
      label: 'Badges & Points.',
      route: '/badges_points',
    ),
    SidebarItem(
      icon: Icons.leaderboard,
      label: 'LeaderBoard.',
      route: '/leaderboard',
    ),
    SidebarItem(
      icon: Icons.folder_open,
      label: 'Repository & Audit.',
      route: '/repository_audit',
    ),
    SidebarItem(
      icon: Icons.upload_file,
      label: 'Goal Proof',
      route: '/goal_evidence_submission',
    ),
    SidebarItem(
      icon: Icons.settings_outlined,
      label: 'Settings & Privacy.',
      route: '/settings',
    ),
  ];

  // ===== MANAGER SIDEBAR ITEMS =====
  static List<SidebarItem> managerItems = [
    SidebarItem(
      iconWidget: Image.asset('assets/rokects.png', width: 24.0, height: 24.0),
      label: 'Dashboard',
      route: '/dashboard',
    ),
    SidebarItem(
      icon: Icons.people_outline,
      label: 'Team Management',
      route: '/manager_portal',
    ),
    SidebarItem(
      icon: Icons.rate_review,
      label: 'Team Reviews',
      route: '/manager_review_team_dashboard',
    ),
    SidebarItem(
      icon: Icons.bar_chart,
      label: 'Progress Visuals.',
      route: '/progress_visuals',
    ),
    SidebarItem(
      icon: Icons.message_outlined,
      label: 'Team Alerts & Nudges',
      route: '/manager_alerts_nudges',
    ),
    SidebarItem(
      icon: Icons.notifications_none,
      label: 'Personal Alerts',
      route: '/alerts_nudges',
    ),
    SidebarItem(
      icon: Icons.leaderboard,
      label: 'LeaderBoard.',
      route: '/leaderboard',
    ),
    SidebarItem(
      icon: Icons.folder_open,
      label: 'Repository & Audit.',
      route: '/repository_audit',
    ),
    SidebarItem(
      icon: Icons.settings_outlined,
      label: 'Settings & Privacy.',
      route: '/settings',
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
  /// Get sidebar items based on user role
  static List<SidebarItem> getItemsForRole(String role) {
    switch (role.toLowerCase()) {
      case 'employee':
        return employeeItems;
      case 'manager':
        return managerItems;
      case 'admin':
        return adminItems;
      default:
        return employeeItems; // Default to employee items
    }
  }

  /// Get sidebar items for a specific route
  static List<SidebarItem> getItemsForRoute(String route) {
    // Determine role based on route
    if (route.startsWith('/manager') || route.startsWith('/dashboard')) {
      return managerItems;
    } else if (route.startsWith('/admin')) {
      return adminItems;
    } else {
      return employeeItems;
    }
  }

  /// Check if a route is valid for a specific role
  static bool isRouteValidForRole(String route, String role) {
    final items = getItemsForRole(role);
    return items.any((item) => item.route == route);
  }

  /// Get the default route for a specific role
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

  /// Get the icon for a specific route
  static Widget? getIconForRoute(String route) {
    // Check all sidebar configurations
    final allItems = [...employeeItems, ...managerItems, ...adminItems];
    final item = allItems.firstWhere(
      (item) => item.route == route,
      orElse: () => const SidebarItem(
        icon: Icons.help_outline,
        label: 'Unknown',
        route: '/unknown',
      ),
    );
    return item.iconWidget ??
        Icon(item.icon!); // Return iconWidget if available, else Icon(icon)
  }

  /// Get the label for a specific route
  static String getLabelForRoute(String route) {
    // Check all sidebar configurations
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
