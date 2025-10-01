import 'package:flutter/material.dart';
import 'dart:ui';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';
import 'app_breakpoints.dart';

/// Comprehensive component library for the Personal Development Hub app
/// Provides standardized UI components following the design system
class AppComponents {
  // Private constructor to prevent instantiation
  AppComponents._();

  // ===== CARD COMPONENTS =====
  /// Standard card container with consistent styling
  static Widget card({
    required Widget child,
    EdgeInsets? padding,
    Color? backgroundColor,
    double borderRadius = 10.0,
    Color? borderColor,
    double borderWidth = 0.0,
    List<BoxShadow>? boxShadow,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.cardBackground,
          borderRadius: BorderRadius.circular(borderRadius),
          border: borderColor != null
              ? Border.all(color: borderColor, width: borderWidth)
              : null,
          boxShadow: boxShadow,
        ),
        child: child,
      ),
    );
  }

  /// KPI/Metric card with standardized styling
  static Widget kpiCard({
    required String label,
    required String value,
    IconData? icon,
    Color? iconColor,
    Color? valueColor,
    String? subtitle,
  }) {
    return card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? AppColors.activeColor, size: 24),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            value,
            style: AppTypography.kpiValue.copyWith(
              color: valueColor ?? AppColors.activeColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.kpiLabel,
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTypography.muted,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Card with left border accent
  static Widget accentCard({
    required Widget child,
    Color? accentColor,
    double accentWidth = 3.0,
    EdgeInsets? padding,
  }) {
    return card(
      padding: padding,
      borderColor: accentColor ?? AppColors.activeColor,
      borderWidth: accentWidth,
      child: child,
    );
  }

  // ===== BUTTON COMPONENTS =====
  /// Primary action button with red accent
  static Widget primaryButton({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    bool isLoading = false,
    bool isFullWidth = false,
    EdgeInsets? padding,
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(icon, color: Colors.white, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.activeColor,
          foregroundColor: Colors.white,
          padding: padding ?? AppSpacing.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  /// Secondary button with outline style
  static Widget secondaryButton({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    bool isFullWidth = false,
    EdgeInsets? padding,
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.activeColor, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.activeColor,
          side: const BorderSide(color: AppColors.activeColor, width: 1.5),
          padding: padding ?? AppSpacing.buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  /// Filter chip component
  static Widget filterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? selectedColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (selectedColor ?? AppColors.activeColor)
              : AppColors.elevatedBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (selectedColor ?? AppColors.activeColor)
                : AppColors.borderColor,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ===== INPUT COMPONENTS =====
  /// Standard text input field
  static Widget textInput({
    required String label,
    String? hintText,
    TextEditingController? controller,
    String? Function(String?)? validator,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    Widget? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
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
              borderSide: const BorderSide(
                color: AppColors.activeColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.dangerColor),
            ),
            contentPadding: AppSpacing.inputPadding,
          ),
        ),
      ],
    );
  }

  // ===== LIST COMPONENTS =====
  /// Standard list item with consistent styling
  static Widget listItem({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets? padding,
    Color? backgroundColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: padding ?? AppSpacing.listItemPadding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }

  /// Activity item with icon and text
  static Widget activityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return listItem(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle, style: AppTypography.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== PROGRESS COMPONENTS =====
  /// Progress bar with consistent styling
  static Widget progressBar({
    required double value,
    Color? backgroundColor,
    Color? valueColor,
    double height = 8.0,
    String? label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label, style: AppTypography.labelSmall),
          const SizedBox(height: AppSpacing.xs),
        ],
        LinearProgressIndicator(
          value: value,
          backgroundColor:
              backgroundColor ?? Colors.grey.withValues(alpha: 0.3),
          valueColor: AlwaysStoppedAnimation<Color>(
            valueColor ?? AppColors.activeColor,
          ),
          minHeight: height,
        ),
      ],
    );
  }

  // ===== BACKGROUND COMPONENTS =====
  /// Background with image and blur overlay
  static Widget backgroundWithImage({
    required String imagePath,
    required Widget child,
    double blurSigma = 5.0,
    List<Color>? gradientColors,
    List<double>? gradientStops,
  }) {
    return Stack(
      children: [
        // Background image
        Positioned.fill(child: Image.asset(imagePath, fit: BoxFit.cover)),
        // Overlay with blur and gradient
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: gradientColors ?? AppColors.radialGradientColors,
                  stops: gradientStops ?? AppColors.radialGradientStops,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ],
    );
  }

  // ===== RESPONSIVE COMPONENTS =====
  /// Responsive grid layout
  static Widget responsiveGrid({
    required List<Widget> children,
    required BuildContext context,
    double spacing = 16.0,
  }) {
    final columns = AppBreakpoints.getResponsiveColumns(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: 1.2,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }

  /// Responsive card width
  static Widget responsiveCard({
    required Widget child,
    required BuildContext context,
    EdgeInsets? padding,
  }) {
    final width = AppBreakpoints.getResponsiveCardWidth(context);
    return SizedBox(
      width: width,
      child: card(padding: padding, child: child),
    );
  }
}
