import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Comprehensive typography system for the Personal Development Hub app
/// Uses Poppins font family with consistent sizing and color hierarchy
class AppTypography {
  // Private constructor to prevent instantiation
  AppTypography._();

  // ===== FONT FAMILY =====
  static const String fontFamily = 'Poppins';

  // ===== FONT SIZES =====
  static const double fontSizeXS = 10.0;
  static const double fontSizeSM = 12.0;
  static const double fontSizeBase = 14.0;
  static const double fontSizeLG = 16.0;
  static const double fontSizeXL = 18.0;
  static const double fontSize2XL = 20.0;
  static const double fontSize3XL = 24.0;
  static const double fontSize4XL = 28.0;
  static const double fontSize5XL = 32.0;

  // ===== FONT WEIGHTS =====
  static const FontWeight fontWeightLight = FontWeight.w300;
  static const FontWeight fontWeightNormal = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;
  static const FontWeight fontWeightExtraBold = FontWeight.w800;

  // ===== HEADING STYLES =====
  /// Large heading for page titles
  static const TextStyle heading1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize4XL,
    fontWeight: fontWeightBold,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  /// Medium heading for section titles
  static const TextStyle heading2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize3XL,
    fontWeight: fontWeightBold,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Small heading for subsection titles
  static const TextStyle heading3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize2XL,
    fontWeight: fontWeightSemiBold,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Extra small heading for card titles
  static const TextStyle heading4 = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeXL,
    fontWeight: fontWeightSemiBold,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // ===== BODY TEXT STYLES =====
  /// Primary body text
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeLG,
    fontWeight: fontWeightNormal,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// Standard body text
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeBase,
    fontWeight: fontWeightNormal,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// Small body text
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeSM,
    fontWeight: fontWeightNormal,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  /// Extra small body text
  static const TextStyle bodyXSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeXS,
    fontWeight: fontWeightNormal,
    color: AppColors.textMuted,
    height: 1.3,
  );

  // ===== SECONDARY TEXT STYLES =====
  /// Secondary text with medium weight
  static const TextStyle secondaryMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeBase,
    fontWeight: fontWeightMedium,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  /// Secondary text with small size
  static const TextStyle secondarySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeSM,
    fontWeight: fontWeightNormal,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  /// Muted text for less important information
  static const TextStyle muted = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeSM,
    fontWeight: fontWeightNormal,
    color: AppColors.textMuted,
    height: 1.4,
  );

  // ===== BUTTON TEXT STYLES =====
  /// Primary button text
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeLG,
    fontWeight: fontWeightSemiBold,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  /// Medium button text
  static const TextStyle buttonMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeBase,
    fontWeight: fontWeightSemiBold,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  /// Small button text
  static const TextStyle buttonSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeSM,
    fontWeight: fontWeightMedium,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  // ===== LABEL STYLES =====
  /// Large label text
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeLG,
    fontWeight: fontWeightMedium,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Medium label text
  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeBase,
    fontWeight: fontWeightMedium,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Small label text
  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeSM,
    fontWeight: fontWeightMedium,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  // ===== CAPTION STYLES =====
  /// Caption text for small descriptions
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeXS,
    fontWeight: fontWeightNormal,
    color: AppColors.textMuted,
    height: 1.3,
  );

  // ===== SPECIAL STYLES =====
  /// Text for KPI values and metrics
  static const TextStyle kpiValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize2XL,
    fontWeight: fontWeightBold,
    color: AppColors.activeColor,
    height: 1.2,
  );

  /// Text for KPI labels
  static const TextStyle kpiLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeSM,
    fontWeight: fontWeightNormal,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  /// Text for navigation items
  static const TextStyle navigation = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeBase,
    fontWeight: fontWeightSemiBold,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  /// Text for active navigation items
  static const TextStyle navigationActive = TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeBase,
    fontWeight: fontWeightExtraBold,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static TextStyle? get bodyText => null;

  static TextStyle? get body => null;

  // ===== UTILITY METHODS =====
  /// Create a text style with custom color
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Create a text style with custom size
  static TextStyle withSize(TextStyle style, double size) {
    return style.copyWith(fontSize: size);
  }

  /// Create a text style with custom weight
  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }
}
