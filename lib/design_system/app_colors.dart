import 'package:flutter/material.dart';

/// Comprehensive color system for the Personal Development Hub app
/// Follows the dark theme with red accents design pattern
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ===== PRIMARY COLORS =====
  /// Dark blue-gray background for sidebar and cards
  static const Color backgroundColor = Color(0xFF1F2840);

  /// Lighter blue-gray for hover states
  static const Color hoverColor = Color(0xFF2A3652);

  /// Red accent color for active/selected items and primary actions
  static const Color activeColor = Color(0xFFC10D00);

  /// Card background color (same as main background)
  static const Color cardBackground = Color(0xFF1F2840);

  // ===== TEXT COLORS =====
  /// Primary white text
  static const Color textPrimary = Colors.white;

  /// Semi-transparent white for secondary text
  static const Color textSecondary = Colors.white70;

  /// More transparent white for muted text
  static const Color textMuted = Colors.white54;

  // ===== ACCENT COLORS =====
  /// Green for success actions and positive indicators
  static const Color successColor = Color(0xFF00C853);

  /// Orange for warnings and attention-grabbing elements
  static const Color warningColor = Colors.orangeAccent;

  /// Red for danger/overdue items
  static const Color dangerColor = Colors.redAccent;

  /// Teal for informational elements
  static const Color infoColor = Colors.tealAccent;

  // ===== BACKGROUND VARIATIONS =====
  /// Slightly lighter background for elevated elements
  static const Color elevatedBackground = Color(0xFF2A3652);

  /// Darker background for overlays
  static const Color overlayBackground = Color(0x880A0F1F);

  /// Even darker overlay background
  static const Color overlayBackgroundDark = Color(0x88040610);

  // ===== BORDER COLORS =====
  /// Subtle border color
  static const Color borderColor = Colors.white12;

  /// Active border color
  static const Color activeBorderColor = Color(0xFFC10D00);

  // ===== SHADOW COLORS =====
  /// Shadow color for cards and elevated elements
  static const Color shadowColor = Color(0x1A000000);

  /// Active shadow color
  static const Color activeShadowColor = Color(0x59C10D00);

  // ===== GRADIENT COLORS =====
  /// Radial gradient colors for background overlays
  static const List<Color> radialGradientColors = [
    Color(0x880A0F1F),
    Color(0x88040610),
  ];

  static const List<double> radialGradientStops = [0.0, 1.0];

  // ===== UTILITY METHODS =====
  /// Get color with opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  /// Get success color with opacity
  static Color successWithOpacity(double opacity) {
    return successColor.withValues(alpha: opacity);
  }

  /// Get warning color with opacity
  static Color warningWithOpacity(double opacity) {
    return warningColor.withValues(alpha: opacity);
  }

  /// Get danger color with opacity
  static Color dangerWithOpacity(double opacity) {
    return dangerColor.withValues(alpha: opacity);
  }

  /// Get active color with opacity
  static Color activeWithOpacity(double opacity) {
    return activeColor.withValues(alpha: opacity);
  }
}

/// Backward compatibility for code that used `Color.withValues(alpha: ...)`.
/// Flutter's `Color` does not have `withValues`; use `withOpacity` instead.
extension ColorCompatibility on Color {
  Color withValues({double? alpha}) {
    if (alpha != null) {
      return withValues(alpha: alpha);
    }
    return this;
  }
}
