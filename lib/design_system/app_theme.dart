import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Comprehensive theme configuration for the Personal Development Hub app
/// Provides consistent theming across the entire application
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // ===== LIGHT THEME =====
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTypography.fontFamily,
      primarySwatch: Colors.red,
      primaryColor: AppColors.activeColor,
      scaffoldBackgroundColor: Colors.grey[50],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.activeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.heading3,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.activeColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.activeColor,
          side: const BorderSide(color: AppColors.activeColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: AppTypography.heading1,
        displayMedium: AppTypography.heading2,
        displaySmall: AppTypography.heading3,
        headlineLarge: AppTypography.heading4,
        headlineMedium: AppTypography.bodyLarge,
        headlineSmall: AppTypography.bodyMedium,
        titleLarge: AppTypography.labelLarge,
        titleMedium: AppTypography.labelMedium,
        titleSmall: AppTypography.labelSmall,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.buttonLarge,
        labelMedium: AppTypography.buttonMedium,
        labelSmall: AppTypography.buttonSmall,
      ),
    );
  }

  // ===== DARK THEME =====
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTypography.fontFamily,
      primarySwatch: Colors.red,
      primaryColor: AppColors.activeColor,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.heading3,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.cardBackground,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        shadowColor: AppColors.shadowColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.activeColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.activeShadowColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.activeColor,
          side: const BorderSide(color: AppColors.activeColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.activeColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.elevatedBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.activeColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.dangerColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.dangerColor, width: 2),
        ),
        labelStyle: AppTypography.labelMedium,
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textMuted,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: AppTypography.heading1,
        displayMedium: AppTypography.heading2,
        displaySmall: AppTypography.heading3,
        headlineLarge: AppTypography.heading4,
        headlineMedium: AppTypography.bodyLarge,
        headlineSmall: AppTypography.bodyMedium,
        titleLarge: AppTypography.labelLarge,
        titleMedium: AppTypography.labelMedium,
        titleSmall: AppTypography.labelSmall,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.buttonLarge,
        labelMedium: AppTypography.buttonMedium,
        labelSmall: AppTypography.buttonSmall,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.backgroundColor,
        elevation: 8,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimary,
        iconColor: AppColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderColor,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.elevatedBackground,
        selectedColor: AppColors.activeColor,
        labelStyle: AppTypography.labelSmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.activeColor,
        linearTrackColor: AppColors.elevatedBackground,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.activeColor;
          }
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.activeColor.withValues(alpha: 0.5);
          }
          return AppColors.elevatedBackground;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.activeColor;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AppColors.borderColor, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.activeColor;
          }
          return AppColors.textMuted;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.activeColor,
        inactiveTrackColor: AppColors.elevatedBackground,
        thumbColor: AppColors.activeColor,
        overlayColor: AppColors.activeColor.withValues(alpha: 0.2),
      ),
    );
  }

  // ===== CUSTOM THEME EXTENSIONS =====
  /// Get custom color scheme
  static ColorScheme get colorScheme {
    return const ColorScheme.dark(
      primary: AppColors.activeColor,
      secondary: AppColors.infoColor,
      surface: AppColors.cardBackground,
      // background: AppColors.backgroundColor,
      error: AppColors.dangerColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimary,
      onError: Colors.white,
    );
  }

  // ===== THEME UTILITIES =====
  /// Get theme data based on brightness
  static ThemeData getThemeData(Brightness brightness) {
    return brightness == Brightness.dark ? darkTheme : lightTheme;
  }

  /// Get text theme based on brightness
  static TextTheme getTextTheme(Brightness brightness) {
    return brightness == Brightness.dark
        ? darkTheme.textTheme
        : lightTheme.textTheme;
  }

  /// Get color scheme based on brightness
  static ColorScheme getColorScheme(Brightness brightness) {
    return brightness == Brightness.dark ? colorScheme : lightTheme.colorScheme;
  }
}
