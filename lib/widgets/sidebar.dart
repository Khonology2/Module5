import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:pdh/widgets/sidebar_state.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_breakpoints.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:pdh/widgets/employee_sidebar_tutorial.dart';

class ResponsiveSidebar extends StatelessWidget {
  const ResponsiveSidebar({
    super.key,
    required this.items,
    required this.onNavigate,
    required this.currentRouteName,
    required this.onLogout,
    this.tutorialStepIndex,
    this.sidebarTutorialKeys,
    this.onTutorialNext,
    this.onTutorialSkip,
  });

  final List<SidebarItem> items;
  final void Function(String route) onNavigate;
  final String? currentRouteName;
  final VoidCallback onLogout;
  final int? tutorialStepIndex;
  final List<GlobalKey>? sidebarTutorialKeys;
  final VoidCallback? onTutorialNext;
  final VoidCallback? onTutorialSkip;

  // Use design system colors
  static const Color backgroundColor = AppColors.backgroundColor;
  static const Color hoverColor = AppColors.hoverColor;
  static const Color activeColor = AppColors.activeColor;

  @override
  Widget build(BuildContext context) {
    // Use design system breakpoints
    final isSmall = AppBreakpoints.isSmall(context);

    return ValueListenableBuilder<bool>(
      valueListenable: SidebarState.instance.isCollapsed,
      builder: (context, collapsed, _) {
        // Allow toggling on medium/large screens; always collapsed on small screens
        final effectiveCollapsed = isSmall ? true : collapsed;

        return Container(
          width: isSmall
              ? double.infinity
              : (effectiveCollapsed ? 72 : 280), // Increased from 240 to 280
          color: backgroundColor,
          child: Column(
            children: [
              _buildHeader(context, effectiveCollapsed),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: ListView(
                  padding: AppSpacing.sidebarContentPadding,
                  children: items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final it = entry.value;
                    final navTile = _NavTile(
                      icon: it.icon,
                      iconWidget: it.iconWidget,
                      assetWhite: it.assetWhite,
                      assetRed: it.assetRed,
                      label: it.label,
                      route: it.route,
                      isActive: currentRouteName == it.route,
                      collapsed: effectiveCollapsed,
                      onTap: () => onNavigate(it.route),
                      tutorialKey:
                          sidebarTutorialKeys != null &&
                              index < sidebarTutorialKeys!.length
                          ? sidebarTutorialKeys![index]
                          : null,
                      showTutorial:
                          tutorialStepIndex != null &&
                          tutorialStepIndex == index,
                      onTutorialNext: onTutorialNext,
                      onTutorialSkip: onTutorialSkip,
                      isLastTutorialStep:
                          tutorialStepIndex != null &&
                          tutorialStepIndex == items.length - 1,
                    );
                    return navTile;
                  }).toList(),
                ),
              ),
              _NavTile(
                icon: Icons.exit_to_app,
                label: 'Exit',
                route: '__logout__',
                isActive: false,
                collapsed: effectiveCollapsed,
                onTap: onLogout,
              ),
              _CollapseToggle(collapsed: effectiveCollapsed),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool collapsed) {
    return Container(
      height: 64,
      padding: AppSpacing.sidebarHeaderPadding,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          // Toggle collapse/expand when logo is tapped (medium/large screens)
          if (!MediaQuery.of(context).size.width.isNaN) {
            SidebarState.instance.isCollapsed.value =
                !SidebarState.instance.isCollapsed.value;
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;
            // Target widths for collapsed/expanded
            final double targetWidth = collapsed ? 56.0 : 160.0;
            // Keep some horizontal padding headroom to avoid overflow during animations
            final double clampedWidth = math.max(
              24.0,
              math.min(targetWidth, availableWidth - 16.0),
            );
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                SizedBox(
                  width: clampedWidth,
                  height: 64,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/Red_Khono_Discs.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.low,
                      // Scale decode near the rendered size for perf
                      cacheWidth: 300,
                      errorBuilder: (context, error, stack) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CollapseToggle extends StatelessWidget {
  const _CollapseToggle({required this.collapsed});
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => SidebarState.instance.isCollapsed.value =
          !SidebarState.instance.isCollapsed.value,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        child: Icon(
          collapsed ? Icons.chevron_right : Icons.chevron_left,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    this.icon, // Make icon optional
    this.iconWidget, // Add optional iconWidget
    this.assetWhite,
    this.assetRed,
    required this.label,
    required this.route,
    required this.isActive,
    required this.collapsed,
    required this.onTap,
    this.tutorialKey,
    this.showTutorial = false,
    this.onTutorialNext,
    this.onTutorialSkip,
    this.isLastTutorialStep = false,
  }) : assert(
         icon != null || iconWidget != null || assetWhite != null,
         'Provide icon, iconWidget, or assetWhite',
       );
  final IconData? icon;
  final Widget? iconWidget;
  final String? assetWhite;
  final String? assetRed;
  final String label;
  final String route;
  final bool isActive;
  final bool collapsed;
  final VoidCallback onTap;
  final GlobalKey? tutorialKey;
  final bool showTutorial;
  final VoidCallback? onTutorialNext;
  final VoidCallback? onTutorialSkip;
  final bool isLastTutorialStep;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool hovering = false;
  @override
  Widget build(BuildContext context) {
    final bool isHovered = hovering && !widget.isActive;
    final bool isSelected = widget.isActive;
    final bool isCollapsed = widget.collapsed;

    Widget navTileContent = Padding(
      padding: AppSpacing.sidebarItemPadding,
      child: MouseRegion(
        onEnter: (_) => setState(() => hovering = true),
        onExit: (_) => setState(() => hovering = false),
        child: Tooltip(
          message: isCollapsed ? widget.label : '',
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                // When expanded: highlight background for active
                // When collapsed: keep background transparent for a clean mini look
                color: !isCollapsed
                    ? (isSelected
                          ? ResponsiveSidebar.activeColor
                          : (isHovered
                                ? ResponsiveSidebar.hoverColor
                                : Colors.transparent))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: (!isCollapsed && (isSelected || isHovered))
                    ? [
                        BoxShadow(
                          color:
                              (isSelected
                                      ? ResponsiveSidebar.activeColor
                                      : ResponsiveSidebar.hoverColor)
                                  .withValues(alpha: 0x35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: isCollapsed
                  ? Center(child: _buildIcon(isSelected))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // If there isn't enough width to safely render icon + label,
                        // fall back to icon-only to avoid overflows during animations/resizes.
                        final bool tooNarrow = constraints.maxWidth < 80;
                        if (tooNarrow) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [_buildIcon(isSelected)],
                          );
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            _buildIcon(isSelected),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                widget.label,
                                style: isSelected
                                    ? AppTypography.navigationActive
                                    : AppTypography.navigation,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );

    // Wrap with Showcase if tutorial is active for this item
    if (widget.showTutorial &&
        widget.tutorialKey != null &&
        widget.onTutorialNext != null) {
      try {
        // Find matching step for this route
        SidebarTutorialStep step;
        try {
          step = EmployeeSidebarTutorialConfig.steps.firstWhere(
            (s) => s.route == widget.route,
          );
        } catch (_) {
          // If route doesn't match, don't show showcase for this item
          return navTileContent;
        }

        // Create custom tooltip widget with Skip button
        final customTooltip = Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.activeColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(step.title, style: AppTypography.heading4),
              const SizedBox(height: 8),
              // Description
              Text(step.description, style: AppTypography.bodyMedium),
              const SizedBox(height: 16),
              // Action buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Skip button
                  TextButton(
                    onPressed: widget.onTutorialSkip ?? widget.onTutorialNext!,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 8),
                  // Next button
                  ElevatedButton(
                    onPressed: widget.onTutorialNext!,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.activeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: Text(widget.isLastTutorialStep ? 'Finish' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        );

        return Showcase.withWidget(
          key: widget.tutorialKey!,
          width: 320,
          height: 250,
          targetShapeBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          overlayColor: Colors.black87,
          overlayOpacity: 0.8,
          container: customTooltip,
          onBarrierClick: widget.onTutorialNext!,
          onTargetClick: widget.onTutorialNext!,
          disposeOnTap: true,
          child: navTileContent,
        );
      } catch (e, stackTrace) {
        // If there's an error with showcase, just return the nav tile without showcase
        debugPrint('Error wrapping sidebar item with showcase: $e');
        debugPrint('Stack trace: $stackTrace');
        return navTileContent;
      }
    }

    return navTileContent;
  }

  Widget _buildIcon(bool isSelected) {
    // Priority: explicit asset pair -> iconWidget -> IconData
    if (widget.assetWhite != null) {
      // Requirement: White when expanded (even if selected); Red only when mini AND selected
      final bool useRed =
          isSelected && widget.collapsed && widget.assetRed != null;
      final String path = useRed ? widget.assetRed! : widget.assetWhite!;
      return SizedBox(
        width: 24,
        height: 24,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Image.asset(
            path,
            filterQuality: FilterQuality.low,
            cacheWidth: 48,
          ),
        ),
      );
    }
    if (widget.iconWidget != null) {
      return widget.iconWidget!;
    }
    return Icon(
      widget.icon,
      color: isSelected ? ResponsiveSidebar.activeColor : AppColors.textPrimary,
      size: 24.0,
    );
  }
}

class SidebarItem {
  const SidebarItem({
    this.icon, // Make icon optional
    this.iconWidget, // Add optional iconWidget
    this.assetWhite,
    this.assetRed,
    required this.label,
    required this.route,
  }) : assert(
         icon != null || iconWidget != null || assetWhite != null,
         'Provide icon, iconWidget, or assetWhite',
       );
  final IconData? icon; // Make icon nullable
  final Widget? iconWidget; // New field for custom icon widget
  final String? assetWhite; // unselected
  final String? assetRed; // selected
  final String label;
  final String route;
}
