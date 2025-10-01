import 'package:flutter/material.dart';

/// Responsive breakpoint system for the Personal Development Hub app
/// Defines screen size categories and responsive behavior
class AppBreakpoints {
  // Private constructor to prevent instantiation
  AppBreakpoints._();

  // ===== BREAKPOINT VALUES =====
  /// Small screens (mobile) - less than 600px
  static const double small = 600.0;

  /// Medium screens (tablet) - 600px to 1000px
  static const double medium = 1000.0;

  /// Large screens (desktop) - greater than 1000px
  static const double large = 1000.0;

  // ===== SCREEN SIZE DETECTION =====
  /// Check if screen is small (mobile)
  static bool isSmall(BuildContext context) {
    return MediaQuery.of(context).size.width < small;
  }

  /// Check if screen is medium (tablet)
  static bool isMedium(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= small && width < medium;
  }

  /// Check if screen is large (desktop)
  static bool isLarge(BuildContext context) {
    return MediaQuery.of(context).size.width >= large;
  }

  /// Check if screen is medium or larger
  static bool isMediumOrLarger(BuildContext context) {
    return MediaQuery.of(context).size.width >= small;
  }

  /// Check if screen is large or larger
  static bool isLargeOrLarger(BuildContext context) {
    return MediaQuery.of(context).size.width >= large;
  }

  // ===== RESPONSIVE VALUES =====
  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isSmall(context)) {
      return const EdgeInsets.all(12.0); // Mobile padding
    } else if (isMedium(context)) {
      return const EdgeInsets.all(16.0); // Tablet padding
    } else {
      return const EdgeInsets.all(20.0); // Desktop padding
    }
  }

  /// Get responsive margin based on screen size
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    if (isSmall(context)) {
      return const EdgeInsets.all(8.0); // Mobile margin
    } else if (isMedium(context)) {
      return const EdgeInsets.all(12.0); // Tablet margin
    } else {
      return const EdgeInsets.all(16.0); // Desktop margin
    }
  }

  /// Get responsive font size based on screen size
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    if (isSmall(context)) {
      return baseSize * 0.9; // Slightly smaller on mobile
    } else if (isMedium(context)) {
      return baseSize; // Normal size on tablet
    } else {
      return baseSize * 1.1; // Slightly larger on desktop
    }
  }

  /// Get responsive grid columns based on screen size
  static int getResponsiveColumns(BuildContext context) {
    if (isSmall(context)) {
      return 1; // Single column on mobile
    } else if (isMedium(context)) {
      return 2; // Two columns on tablet
    } else {
      return 3; // Three columns on desktop
    }
  }

  /// Get responsive sidebar width based on screen size
  static double getResponsiveSidebarWidth(
    BuildContext context,
    bool isCollapsed,
  ) {
    if (isSmall(context)) {
      return 0; // No sidebar on mobile (uses drawer)
    } else if (isMedium(context)) {
      return isCollapsed ? 72.0 : 72.0; // Always collapsed on tablet
    } else {
      return isCollapsed ? 72.0 : 240.0; // Collapsible on desktop
    }
  }

  /// Get responsive card width based on screen size
  static double getResponsiveCardWidth(BuildContext context) {
    if (isSmall(context)) {
      return double.infinity; // Full width on mobile
    } else if (isMedium(context)) {
      return 300.0; // Fixed width on tablet
    } else {
      return 350.0; // Larger width on desktop
    }
  }

  // ===== SIDEBAR BEHAVIOR =====
  /// Determine if sidebar should be collapsed by default
  static bool shouldCollapseSidebarByDefault(BuildContext context) {
    return isMedium(context); // Collapsed on tablet, expandable on desktop
  }

  /// Determine if sidebar should use drawer on mobile
  static bool shouldUseDrawer(BuildContext context) {
    return isSmall(context); // Drawer on mobile, sidebar on larger screens
  }

  // ===== LAYOUT BEHAVIOR =====
  /// Get responsive layout type
  static ResponsiveLayoutType getLayoutType(BuildContext context) {
    if (isSmall(context)) {
      return ResponsiveLayoutType.mobile;
    } else if (isMedium(context)) {
      return ResponsiveLayoutType.tablet;
    } else {
      return ResponsiveLayoutType.desktop;
    }
  }

  /// Get responsive content constraints
  static BoxConstraints getResponsiveConstraints(BuildContext context) {
    if (isSmall(context)) {
      return const BoxConstraints(maxWidth: 600);
    } else if (isMedium(context)) {
      return const BoxConstraints(maxWidth: 800);
    } else {
      return const BoxConstraints(maxWidth: 1200);
    }
  }
}

/// Enum for responsive layout types
enum ResponsiveLayoutType { mobile, tablet, desktop }

/// Extension for responsive layout type
extension ResponsiveLayoutTypeExtension on ResponsiveLayoutType {
  /// Check if layout is mobile
  bool get isMobile => this == ResponsiveLayoutType.mobile;

  /// Check if layout is tablet
  bool get isTablet => this == ResponsiveLayoutType.tablet;

  /// Check if layout is desktop
  bool get isDesktop => this == ResponsiveLayoutType.desktop;
}
