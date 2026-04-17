import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:pdh/widgets/sidebar_state.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_breakpoints.dart';
import 'package:pdh/services/profile_completion_service.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:pdh/widgets/employee_sidebar_tutorial.dart';
import 'package:pdh/l10n/generated/app_localizations.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';
import 'package:pdh/widgets/workspace_context_switcher.dart';
import 'package:pdh/services/workspace_context_service.dart';
import 'package:pdh/design_system/sidebar_config.dart';

/// Light palette for the nav rail (white panel, black labels), driven by
/// [employeeDashboardLightModeNotifier] with the employee dashboard light toggle.
class _SidebarLightMode extends InheritedWidget {
  const _SidebarLightMode({required this.light, required super.child});

  final bool light;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_SidebarLightMode>()
            ?.light ??
        false;
  }

  @override
  bool updateShouldNotify(_SidebarLightMode oldWidget) =>
      light != oldWidget.light;
}

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
  final WorkspaceContextService _workspaceService = WorkspaceContextService();
  List<SidebarItem> _currentItems = [];

  // Dark-mode sidebar surface shared across employee/manager/admin.
  static const Color backgroundColor = Color(0xFF3D3F40);

  @override
  void initState() {
    super.initState();
    // Keep tutorial navigation and profile warning state in sync from first paint.
    _previousTutorialStep = widget.tutorialStepIndex;
    _checkProfileCompletion();
    // Sidebar items can change when workspace context switches (My/Manager).
    _workspaceService.addListener(_onWorkspaceChanged);
    _updateItems();
  }

  Future<void> _checkProfileCompletion({bool bypassCache = false}) async {
    try {
      final isComplete =
          await ProfileCompletionService.isCurrentUserProfileComplete(
            bypassCache: bypassCache,
          );
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
    _previousTutorialStep = null; // Clear the tutorial step reference
    _workspaceService.removeListener(_onWorkspaceChanged);
    super.dispose();
  }

  void _onWorkspaceChanged() {
    if (mounted) {
      setState(() {
        // Rebuild the nav list from the active workspace/role context.
        _updateItems();
      });
    }
  }

  void _updateItems() {
    // Centralized source of sidebar items so all entry points stay consistent.
    _currentItems = SidebarConfig.getItemsForCurrentWorkspace();
  }

  @override
  void didUpdateWidget(ResponsiveSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only proceed if the widget is still in the tree
    if (!mounted) return;

    // Scroll to tutorial item when step changes
    if (widget.tutorialStepIndex != null &&
        widget.tutorialStepIndex != _previousTutorialStep &&
        widget.sidebarTutorialKeys != null &&
        widget.tutorialStepIndex! < widget.sidebarTutorialKeys!.length) {
      _previousTutorialStep = widget.tutorialStepIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Check mounted before proceeding
          _scrollToTutorialItem(widget.tutorialStepIndex!);
        }
      });
    }
    // Refresh profile completion check when widget updates (e.g., after profile save)
    // Check both employee and manager profile routes
    // Use bypassCache=true to get fresh data after profile save
    if (widget.currentRouteName == '/my_profile' ||
        oldWidget.currentRouteName == '/my_profile' ||
        widget.currentRouteName == '/manager_profile' ||
        oldWidget.currentRouteName == '/manager_profile') {
      // Bypass cache when coming from profile page to ensure we get fresh data
      final bypassCache =
          oldWidget.currentRouteName == '/manager_profile' ||
          oldWidget.currentRouteName == '/my_profile';
      _checkProfileCompletion(bypassCache: bypassCache);
    }
  }

  void _scrollToTutorialItem(int stepIndex) {
    // Add mounted check to prevent accessing keys after dispose
    if (!mounted ||
        widget.sidebarTutorialKeys == null ||
        stepIndex >= widget.sidebarTutorialKeys!.length) {
      return;
    }

    final key = widget.sidebarTutorialKeys![stepIndex];
    final context = key.currentContext;

    // Add additional null and mounted checks
    if (context != null && _scrollController.hasClients && mounted) {
      // Check mounted again after async gap
      try {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      } catch (e) {
        // Silently fail if we can't scroll to the item
        debugPrint('Failed to scroll to tutorial item: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use design system breakpoints
    final isSmall = AppBreakpoints.isSmall(context);

    return ValueListenableBuilder<bool>(
      valueListenable: employeeDashboardLightModeNotifier,
      builder: (context, sidebarLight, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: SidebarState.instance.isCollapsed,
          builder: (context, collapsed, _) {
            // Allow toggling on medium/large screens; always collapsed on small screens
            final effectiveCollapsed = isSmall ? true : collapsed;

            final Widget column = _SidebarLightMode(
              light: sidebarLight,
              child: Column(
                children: [
                  // Pass sidebarLight explicitly: builder `context` is above
                  // [_SidebarLightMode], so inherited lookup would always be false.
                  _buildHeader(context, effectiveCollapsed, sidebarLight),
                  const SizedBox(height: AppSpacing.xs),
                  // Workspace Context Switcher
                  const WorkspaceContextSwitcher(),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      padding: AppSpacing.sidebarContentPadding,
                      children: [
                        ..._currentItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final it = entry.value;
                          // Show the profile warning indicator for incomplete profile routes.
                          final bool showProfileIndicator =
                              (it.route == '/my_profile' ||
                                  it.route == '/manager_profile') &&
                              _isProfileIncomplete;

                          if (it.children != null && it.children!.isNotEmpty) {
                            return _ExpandableNavGroup(
                              key: ValueKey('expand_${it.route}_$index'),
                              parent: it,
                              currentRouteName: widget.currentRouteName,
                              collapsed: effectiveCollapsed,
                              onNavigate: widget.onNavigate,
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
                                  widget.tutorialStepIndex ==
                                      widget.items.length - 1,
                            );
                          }

                          return _NavTile(
                            key: ValueKey('nav_${it.route}_$index'),
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
                                widget.tutorialStepIndex ==
                                    widget.items.length - 1,
                          );
                        }),
                        // Keep footer actions in the scrollable region to prevent
                        // bottom RenderFlex overflows on shorter web viewports.
                        _NavTile(
                          key: const ValueKey('nav_logout'),
                          icon: Icons.exit_to_app,
                          label: AppLocalizations.of(context).employee_drawer_exit,
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
                  ),
                ],
              ),
            );

            final Widget shell = Container(
              // Keep compact and expanded rail widths explicit for predictable layout.
              width: isSmall
                  ? double.infinity
                  : (effectiveCollapsed ? 72 : 280),
              decoration: BoxDecoration(
                color: sidebarLight
                    ? Colors.white
                    : backgroundColor.withValues(alpha: 0.95),
                border: Border(
                  right: BorderSide(
                    color: sidebarLight
                        ? const Color(0x1F000000)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: column,
            );

            return ClipRRect(
              child: sidebarLight
                  ? shell
                  : BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: shell,
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool collapsed, bool sidebarLight) {
    final Color textColor = sidebarLight
        ? const Color(0xFF000000)
        : AppColors.textPrimary;

    // Expanded header needs room for logo + welcome text (fixed height was causing
    // RenderFlex overflow on web when text wrapped to two lines).
    final double headerHeight = collapsed ? 64.0 : 118.0;
    final double logoBoxHeight = collapsed ? 64.0 : 56.0;

    return Container(
      height: headerHeight,
      padding: AppSpacing.sidebarHeaderPadding,
      alignment: Alignment.topCenter,
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

            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: clampedWidth,
                  height: logoBoxHeight,
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
                if (!collapsed) ...[
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'Welcome to Personal Development Hub',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
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
    final light = _SidebarLightMode.of(context);
    Widget collapseWidget = InkWell(
      onTap: () => SidebarState.instance.isCollapsed.value =
          !SidebarState.instance.isCollapsed.value,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        child: Icon(
          collapsed ? Icons.chevron_right : Icons.chevron_left,
          color: light ? Colors.black : AppColors.textPrimary,
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
            color: _ResponsiveSidebarState.backgroundColor.withValues(alpha: 0.9),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Skip button
                  Flexible(
                    child: TextButton(
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
                  ),
                  const SizedBox(width: 4),
                  // Next button
                  Flexible(
                    child: ElevatedButton(
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
    super.key,
    this.icon, // Make icon optional
    this.iconWidget, // Add optional iconWidget
    this.assetWhite,
    this.assetRed,
    required this.label,
    required this.route,
    required this.isActive,
    required this.collapsed,
    required this.onTap,
    this.isChild = false,
    this.trailing,
    bool? showProfileIndicator,
    this.tutorialKey,
    this.showTutorial = false,
    this.onTutorialNext,
    this.onTutorialSkip,
    this.isLastTutorialStep = false,
  }) : showProfileIndicator = showProfileIndicator ?? false;
  final IconData? icon;
  final Widget? iconWidget;
  final String? assetWhite;
  final String? assetRed;
  final String label;
  final String route;
  final bool isActive;
  final bool collapsed;
  final VoidCallback onTap;
  final bool isChild;
  final Widget? trailing;
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

  bool get _hasIcon =>
      widget.icon != null ||
      widget.iconWidget != null ||
      widget.assetWhite != null;

  @override
  Widget build(BuildContext context) {
    final bool isHovered = hovering && !widget.isActive;
    final bool isSelected = widget.isActive;
    final bool isCollapsed = widget.collapsed;

    final localizations = AppLocalizations.of(context);
    String label = widget.label;
    switch (widget.route) {
      case '/employee_dashboard':
      case '/dashboard':
        label = localizations.nav_dashboard;
        break;
      case '/my_pdp':
        // Manager sidebar dropdown parent uses "Manager Workspace"; employee uses Goal Workspace.
        if (widget.label != 'Manager Workspace') {
          label = localizations.nav_goal_workspace;
        }
        break;
      case '/my_profile':
        label = localizations.nav_my_profile;
        break;
      case '/my_goal_workspace':
        label = localizations.nav_my_pdp;
        break;
      case '/progress_visuals':
        label = localizations.nav_progress_visuals;
        break;
      case '/alerts_nudges':
        label = localizations.nav_alerts_nudges;
        break;
      case '/badges_points':
      case '/manager_badges_points':
        label = localizations.nav_badges_points;
        break;
      case '/season_challenges':
        label = localizations.nav_season_challenges;
        break;
      case '/leaderboard':
      case '/manager_leaderboard':
        label = localizations.nav_leaderboard;
        break;
      case '/repository_audit':
        label = localizations.nav_repository_audit;
        break;
      case '/settings':
        label = localizations.nav_settings_privacy;
        break;
      case '/team_challenges_seasons':
        label = localizations.nav_team_challenges;
        break;
      case '/manager_alerts_nudges':
        label = localizations.nav_team_alerts_nudges;
        break;
      case '/manager_inbox':
        label = localizations.nav_manager_inbox;
        break;
      case '/manager_review_team_dashboard':
        // Use the updated manager label without requiring l10n regeneration.
        label = 'Team Review';
        break;
      case '/admin_dashboard':
        label = localizations.nav_dashboard;
        break;
      case '/user_management':
        label = localizations.nav_user_management;
        break;
      case '/analytics':
      case '/admin_analytics':
        label = localizations.nav_analytics;
        break;
      case '/system_settings':
        label = localizations.nav_system_settings;
        break;
      case '/security':
        label = localizations.nav_security;
        break;
      case '/backup':
        label = localizations.nav_backup_restore;
        break;
      default:
        break;
    }

    final bool sidebarLight = _SidebarLightMode.of(context);
    final Color labelColor = isSelected
        ? Colors.white
        : (sidebarLight ? const Color(0xFF000000) : AppColors.textPrimary);
    final Color hoverFill = sidebarLight
        ? const Color(0xFFE8E8E8)
        : AppColors.hoverColor;

    Widget navTileContent = Padding(
      padding: widget.isChild
          ? const EdgeInsets.only(left: 36, right: 12, top: 4, bottom: 4)
          : AppSpacing.sidebarItemPadding,
      child: MouseRegion(
        onEnter: (_) => setState(() => hovering = true),
        onExit: (_) => setState(() => hovering = false),
        child: Tooltip(
          message: isCollapsed ? label : '',
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
                          : (isHovered ? hoverFill : Colors.transparent))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: (!isCollapsed && (isSelected || isHovered))
                    ? [
                        BoxShadow(
                          color:
                              (isSelected
                                      ? AppColors.activeColor
                                      : (sidebarLight
                                            ? hoverFill
                                            : AppColors.hoverColor))
                                  .withValues(alpha: 0x35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: isCollapsed
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_hasIcon) _buildIcon(isSelected, sidebarLight),
                        if (widget.showProfileIndicator)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.activeColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: sidebarLight
                                      ? Colors.white
                                      : _ResponsiveSidebarState.backgroundColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // If there isn't enough width to safely render icon + label,
                        // fall back to icon-only to avoid overflows during animations/resizes.
                        final bool tooNarrow = constraints.maxWidth < 80;
                        if (tooNarrow && _hasIcon) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [_buildIcon(isSelected, sidebarLight)],
                          );
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            if (_hasIcon) ...[
                              _buildIcon(isSelected, sidebarLight),
                              const SizedBox(width: AppSpacing.xs),
                            ],
                            Flexible(
                              child: Text(
                                label,
                                style:
                                    (isSelected
                                            ? AppTypography.navigationActive
                                            : AppTypography.navigation)
                                        .copyWith(color: labelColor),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                            if (widget.showProfileIndicator) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.error,
                                size: 16,
                                color: AppColors.activeColor,
                              ),
                            ],
                            if (widget.trailing != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              widget.trailing!,
                            ],
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
            color: _ResponsiveSidebarState.backgroundColor.withValues(alpha: 0.9),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Skip button
                  Flexible(
                    child: TextButton(
                      onPressed:
                          widget.onTutorialSkip ?? widget.onTutorialNext!,
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
                  ),
                  const SizedBox(width: 4),
                  // Next button
                  Flexible(
                    child: ElevatedButton(
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

  Widget _buildIcon(bool isSelected, bool sidebarLight) {
    if (!_hasIcon) return const SizedBox.shrink();
    // Priority: explicit asset pair -> iconWidget -> IconData
    if (widget.assetWhite != null) {
      // Requirement: White when expanded (even if selected); Red only when mini AND selected
      final bool useRed =
          isSelected && widget.collapsed && widget.assetRed != null;
      final String path = useRed ? widget.assetRed! : widget.assetWhite!;
      Widget img = SizedBox(
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
      if (sidebarLight) {
        final bool whiteOnRed = isSelected && !widget.collapsed;
        if (!useRed && !whiteOnRed) {
          img = ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Color(0xFF000000),
              BlendMode.srcIn,
            ),
            child: img,
          );
        }
      }
      return img;
    }
    if (widget.iconWidget != null) {
      return widget.iconWidget!;
    }
    return Icon(
      widget.icon,
      color: (isSelected && widget.collapsed)
          ? AppColors.activeColor
          : (sidebarLight ? const Color(0xFF000000) : AppColors.textPrimary),
      size: 24.0,
    );
  }
}

class _ExpandableNavGroup extends StatefulWidget {
  const _ExpandableNavGroup({
    super.key,
    required this.parent,
    required this.currentRouteName,
    required this.collapsed,
    required this.onNavigate,
    required this.showProfileIndicator,
    this.tutorialKey,
    this.showTutorial = false,
    this.onTutorialNext,
    this.onTutorialSkip,
    this.isLastTutorialStep = false,
  });

  final SidebarItem parent;
  final String? currentRouteName;
  final bool collapsed;
  final void Function(String route) onNavigate;
  final bool showProfileIndicator;
  final GlobalKey? tutorialKey;
  final bool showTutorial;
  final VoidCallback? onTutorialNext;
  final VoidCallback? onTutorialSkip;
  final bool isLastTutorialStep;

  @override
  State<_ExpandableNavGroup> createState() => _ExpandableNavGroupState();
}

class _ExpandableNavGroupState extends State<_ExpandableNavGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final parent = widget.parent;
    final children = parent.children ?? const <SidebarItem>[];

    if (widget.collapsed) {
      return _NavTile(
        key: ValueKey('group_collapsed_${parent.route}'),
        icon: parent.icon,
        iconWidget: parent.iconWidget,
        assetWhite: parent.assetWhite,
        assetRed: parent.assetRed,
        label: parent.label,
        route: parent.route,
        isActive: widget.currentRouteName == parent.route,
        collapsed: widget.collapsed,
        onTap: () => widget.onNavigate(parent.route),
        showProfileIndicator: widget.showProfileIndicator,
        tutorialKey: widget.tutorialKey,
        showTutorial: widget.showTutorial,
        onTutorialNext: widget.onTutorialNext,
        onTutorialSkip: widget.onTutorialSkip,
        isLastTutorialStep: widget.isLastTutorialStep,
      );
    }

    final isActive = widget.currentRouteName == parent.route;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavTile(
          key: ValueKey('group_${parent.route}'),
          icon: parent.icon,
          iconWidget: parent.iconWidget,
          assetWhite: parent.assetWhite,
          assetRed: parent.assetRed,
          label: parent.label,
          route: parent.route,
          isActive: isActive,
          collapsed: widget.collapsed,
          onTap: () {
            setState(() {
              _expanded = !_expanded;
            });
          },
          trailing: Builder(
            builder: (context) {
              final light = _SidebarLightMode.of(context);
              return Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: light ? Colors.black : AppColors.textPrimary,
                size: 24,
              );
            },
          ),
          showProfileIndicator: widget.showProfileIndicator,
          tutorialKey: widget.tutorialKey,
          showTutorial: widget.showTutorial,
          onTutorialNext: widget.onTutorialNext,
          onTutorialSkip: widget.onTutorialSkip,
          isLastTutorialStep: widget.isLastTutorialStep,
        ),
        if (_expanded)
          ...children.map(
            (child) => _NavTile(
              key: ValueKey('nav_child_${child.route}'),
              icon: child.icon,
              iconWidget: child.iconWidget,
              assetWhite: child.assetWhite,
              assetRed: child.assetRed,
              label: child.label,
              route: child.route,
              isActive: widget.currentRouteName == child.route,
              collapsed: widget.collapsed,
              onTap: () => widget.onNavigate(child.route),
              isChild: true,
              showProfileIndicator: false,
            ),
          ),
      ],
    );
  }
}

class SidebarItem {
  const SidebarItem({
    this.icon,
    this.iconWidget,
    this.assetWhite,
    this.assetRed,
    required this.label,
    required this.route,
    this.children,
  });
  final IconData? icon;
  final Widget? iconWidget;
  final String? assetWhite;
  final String? assetRed;
  final String label;
  final String route;
  final List<SidebarItem>? children;
}
