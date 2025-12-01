import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:pdh/widgets/sidebar_state.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_breakpoints.dart';
import 'package:pdh/services/profile_completion_service.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:pdh/widgets/employee_sidebar_tutorial.dart';

class ResponsiveSidebar extends StatefulWidget {
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

  @override
  State<ResponsiveSidebar> createState() => _ResponsiveSidebarState();
}

class _ResponsiveSidebarState extends State<ResponsiveSidebar> {
  final ScrollController _scrollController = ScrollController();
  int? _previousTutorialStep;
  bool _isProfileIncomplete = false;

  // Use design system colors
  static const Color backgroundColor = AppColors.backgroundColor;

  @override
  void initState() {
    super.initState();
    _previousTutorialStep = widget.tutorialStepIndex;
    _checkProfileCompletion();
  }

  Future<void> _checkProfileCompletion() async {
    try {
      final isComplete =
          await ProfileCompletionService.isCurrentUserProfileComplete();
      if (mounted) {
        setState(() {
          _isProfileIncomplete = !isComplete;
        });
      }
    } catch (e) {
      // Silently fail - don't show indicator if check fails
      if (mounted) {
        setState(() {
          _isProfileIncomplete = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ResponsiveSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll to tutorial item when step changes
    if (widget.tutorialStepIndex != null &&
        widget.tutorialStepIndex != _previousTutorialStep &&
        widget.sidebarTutorialKeys != null &&
        widget.tutorialStepIndex! < widget.sidebarTutorialKeys!.length) {
      _previousTutorialStep = widget.tutorialStepIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTutorialItem(widget.tutorialStepIndex!);
      });
    }
    // Refresh profile completion check when widget updates (e.g., after profile save)
    if (widget.currentRouteName == '/my_profile' ||
        oldWidget.currentRouteName == '/my_profile') {
      _checkProfileCompletion();
    }
  }

  void _scrollToTutorialItem(int stepIndex) {
    if (widget.sidebarTutorialKeys == null ||
        stepIndex >= widget.sidebarTutorialKeys!.length) {
      return;
    }

    final key = widget.sidebarTutorialKeys![stepIndex];
    final context = key.currentContext;
    if (context != null && _scrollController.hasClients) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
  }

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
                  controller: _scrollController,
                  padding: AppSpacing.sidebarContentPadding,
                  children: widget.items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final it = entry.value;
                    // Check if this is the My Profile route and profile is incomplete
                    final bool showProfileIndicator =
                        (it.route == '/my_profile' ||
                            it.route == '/manager_profile') &&
                        (_isProfileIncomplete == true);

                    final navTile = _NavTile(
                      icon: it.icon,
                      iconWidget: it.iconWidget,
                      assetWhite: it.assetWhite,
                      assetRed: it.assetRed,
                      label: it.label,
                      route: it.route,
                      isActive: widget.currentRouteName == it.route,
                      collapsed: effectiveCollapsed,
                      onTap: () => widget.onNavigate(it.route),
                      showProfileIndicator: showProfileIndicator,
                      tutorialKey:
                          widget.sidebarTutorialKeys != null &&
                              index < widget.sidebarTutorialKeys!.length
                          ? widget.sidebarTutorialKeys![index]
                          : null,
                      showTutorial:
                          widget.tutorialStepIndex != null &&
                          widget.tutorialStepIndex == index,
                      onTutorialNext: widget.onTutorialNext,
                      onTutorialSkip: widget.onTutorialSkip,
                      isLastTutorialStep:
                          widget.tutorialStepIndex != null &&
                          widget.tutorialStepIndex == widget.items.length - 1,
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
                onTap: widget.onLogout,
              ),
              _CollapseToggle(
                collapsed: effectiveCollapsed,
                tutorialKey:
                    widget.sidebarTutorialKeys != null &&
                        widget.tutorialStepIndex != null &&
                        widget.tutorialStepIndex == widget.items.length &&
                        widget.tutorialStepIndex! <
                            widget.sidebarTutorialKeys!.length
                    ? widget.sidebarTutorialKeys![widget.tutorialStepIndex!]
                    : null,
                showTutorial:
                    widget.tutorialStepIndex != null &&
                    widget.tutorialStepIndex == widget.items.length,
                onTutorialNext: widget.onTutorialNext,
                onTutorialSkip: widget.onTutorialSkip,
                isLastTutorialStep:
                    widget.tutorialStepIndex != null &&
                    widget.tutorialStepIndex == widget.items.length,
              ),
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
  const _CollapseToggle({
    required this.collapsed,
    this.tutorialKey,
    this.showTutorial = false,
    this.onTutorialNext,
    this.onTutorialSkip,
    this.isLastTutorialStep = false,
  });
  final bool collapsed;
  final GlobalKey? tutorialKey;
  final bool showTutorial;
  final VoidCallback? onTutorialNext;
  final VoidCallback? onTutorialSkip;
  final bool isLastTutorialStep;

  @override
  Widget build(BuildContext context) {
    Widget collapseWidget = InkWell(
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

    // Wrap with showcase if tutorial is active
    if (showTutorial && tutorialKey != null && onTutorialNext != null) {
      try {
        final step = EmployeeSidebarTutorialConfig.steps.firstWhere(
          (s) => s.route == '__collapse_toggle__',
        );

        final customTooltip = Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.backgroundColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.activeColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI Avatar GIF at the top - centered and circular
              Center(
                child: ClipOval(
                  child: Image.asset(
                    'assets/videos/Ai_Avatar.gif',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Title - compact
              Text(
                step.title,
                style: AppTypography.heading4.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              // Description - compact
              Text(
                step.description,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 12,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              // Action buttons row - compact
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Skip button
                  TextButton(
                    onPressed: onTutorialSkip ?? onTutorialNext!,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Skip', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                  // Next button
                  ElevatedButton(
                    onPressed: onTutorialNext!,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.activeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      isLastTutorialStep ? 'Finish' : 'Next',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        return Showcase.withWidget(
          key: tutorialKey!,
          width: 260,
          height: 200,
          targetShapeBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          overlayColor: Colors.transparent,
          overlayOpacity: 0.0,
          container: customTooltip,
          onBarrierClick: onTutorialNext!,
          onTargetClick: onTutorialNext!,
          disposeOnTap: true,
          child: collapseWidget,
        );
      } catch (e) {
        return collapseWidget;
      }
    }

    return collapseWidget;
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
    bool? showProfileIndicator,
    this.tutorialKey,
    this.showTutorial = false,
    this.onTutorialNext,
    this.onTutorialSkip,
    this.isLastTutorialStep = false,
  }) : showProfileIndicator = showProfileIndicator ?? false,
       assert(
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
  final bool showProfileIndicator;
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
                          ? AppColors.activeColor
                          : (isHovered
                                ? AppColors.hoverColor
                                : Colors.transparent))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: (!isCollapsed && (isSelected || isHovered))
                    ? [
                        BoxShadow(
                          color:
                              (isSelected
                                      ? AppColors.activeColor
                                      : AppColors.hoverColor)
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
                              child: Row(
                                children: [
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
                                  if (widget.showProfileIndicator &&
                                      !widget.collapsed)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.error_outline,
                                        size: 16,
                                        color: AppColors.dangerColor,
                                      ),
                                    ),
                                ],
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

        // Create custom tooltip widget with Skip button - compact translucent design
        final customTooltip = Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.backgroundColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.activeColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI Avatar GIF at the top - centered and circular
              Center(
                child: ClipOval(
                  child: Image.asset(
                    'assets/videos/Ai_Avatar.gif',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Title - compact
              Text(
                step.title,
                style: AppTypography.heading4.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              // Description - compact
              Text(
                step.description,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 12,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              // Action buttons row - compact
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Skip button
                  TextButton(
                    onPressed: widget.onTutorialSkip ?? widget.onTutorialNext!,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Skip', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                  // Next button
                  ElevatedButton(
                    onPressed: widget.onTutorialNext!,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.activeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      widget.isLastTutorialStep ? 'Finish' : 'Next',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        return Showcase.withWidget(
          key: widget.tutorialKey!,
          width: 260,
          height: 200,
          targetShapeBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          overlayColor: Colors.transparent,
          overlayOpacity: 0.0,
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
      color: isSelected ? AppColors.activeColor : AppColors.textPrimary,
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
