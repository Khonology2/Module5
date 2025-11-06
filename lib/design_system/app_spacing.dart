import 'package:flutter/material.dart';

/// Comprehensive spacing system for the Personal Development Hub app
/// Provides consistent spacing values throughout the application
class AppSpacing {
  // Private constructor to prevent instantiation
  AppSpacing._();

  // ===== BASE SPACING UNITS =====
  /// Extra small spacing (4px)
  static const double xs = 4.0;

  /// Small spacing (8px)
  static const double sm = 8.0;

  /// Medium spacing (12px)
  static const double md = 12.0;

  /// Large spacing (16px)
  static const double lg = 16.0;

  /// Extra large spacing (20px)
  static const double xl = 20.0;

  /// Double extra large spacing (24px)
  static const double xxl = 24.0;

  /// Triple extra large spacing (32px)
  static const double xxxl = 32.0;

  /// Quadruple extra large spacing (40px)
  static const double xxxxl = 40.0;

  // ===== COMPONENT-SPECIFIC SPACING =====
  /// Card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);

  /// Card padding with medium spacing
  static const EdgeInsets cardPaddingMedium = EdgeInsets.all(md);

  /// Card padding with large spacing
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(xl);

  /// Screen padding
  static const EdgeInsets screenPadding = EdgeInsets.fromLTRB(lg, 100, lg, xxl);

  /// Screen padding for mobile
  static const EdgeInsets screenPaddingMobile = EdgeInsets.fromLTRB(
    md,
    80,
    md,
    lg,
  );

  /// Section spacing
  static const EdgeInsets sectionSpacing = EdgeInsets.symmetric(vertical: xl);

  /// Row spacing
  static const EdgeInsets rowSpacing = EdgeInsets.symmetric(horizontal: sm);

  /// Column spacing
  static const EdgeInsets columnSpacing = EdgeInsets.symmetric(vertical: sm);

  // ===== BUTTON SPACING =====
  /// Button padding
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    vertical: md,
    horizontal: lg,
  );

  /// Small button padding
  static const EdgeInsets buttonPaddingSmall = EdgeInsets.symmetric(
    vertical: sm,
    horizontal: md,
  );

  /// Large button padding
  static const EdgeInsets buttonPaddingLarge = EdgeInsets.symmetric(
    vertical: lg,
    horizontal: xl,
  );

  // ===== INPUT SPACING =====
  /// Input field padding
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    vertical: md,
    horizontal: lg,
  );

  /// Input field margin
  static const EdgeInsets inputMargin = EdgeInsets.only(bottom: lg);

  // ===== LIST SPACING =====
  /// List item padding
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    vertical: sm,
    horizontal: lg,
  );

  /// List item margin
  static const EdgeInsets listItemMargin = EdgeInsets.only(bottom: sm);

  // ===== GRID SPACING =====
  /// Grid spacing
  static const double gridSpacing = lg;

  /// Grid spacing small
  static const double gridSpacingSmall = md;

  /// Grid spacing large
  static const double gridSpacingLarge = xl;

  // ===== SIDEBAR SPACING =====
  /// Sidebar item padding
  static const EdgeInsets sidebarItemPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: xs,
  );

  /// Sidebar header padding
  static const EdgeInsets sidebarHeaderPadding = EdgeInsets.symmetric(
    horizontal: md,
  );

  /// Sidebar content padding
  static const EdgeInsets sidebarContentPadding = EdgeInsets.symmetric(
    vertical: sm,
  );

  // ===== UTILITY METHODS =====
  /// Create symmetric padding
  static EdgeInsets symmetric({double? vertical, double? horizontal}) {
    return EdgeInsets.symmetric(
      vertical: vertical ?? 0,
      horizontal: horizontal ?? 0,
    );
  }

  /// Create all-around padding
  static EdgeInsets all(double value) {
    return EdgeInsets.all(value);
  }

  /// Create directional padding
  static EdgeInsets directional({
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return EdgeInsets.only(
      top: top ?? 0,
      bottom: bottom ?? 0,
      left: left ?? 0,
      right: right ?? 0,
    );
  }

  /// Create margin with all values
  static EdgeInsets marginAll(double value) {
    return EdgeInsets.all(value);
  }

  /// Create margin with symmetric values
  static EdgeInsets marginSymmetric({double? vertical, double? horizontal}) {
    return EdgeInsets.symmetric(
      vertical: vertical ?? 0,
      horizontal: horizontal ?? 0,
    );
  }

  /// Create margin with directional values
  static EdgeInsets marginDirectional({
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return EdgeInsets.only(
      top: top ?? 0,
      bottom: bottom ?? 0,
      left: left ?? 0,
      right: right ?? 0,
    );
  }
}
