import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:http/http.dart' as http;
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

// #region agent log
void postSidebarDebugLog({
  required String runId,
  required String hypothesisId,
  required String location,
  required String message,
  required Map<String, dynamic> data,
}) {
  final payload = <String, dynamic>{
    'sessionId': '182693',
    'runId': runId,
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
  unawaited(
    Future<void>(() async {
      try {
        await http.post(
          Uri.parse('http://127.0.0.1:7413/ingest/4c092313-279a-400c-82c7-76b9943fcc16'),
          headers: const {
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': '182693',
          },
          body: jsonEncode(payload),
        );
      } catch (_) {}
    }),
  );
}
// #endregion

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
  // Temporary UX override: keep non-mobile sidebar expanded.
  static const bool _disableSidebarCollapseTemporarily = true;
  static const double _sidebarZoomFactor = 0.8;
  final ScrollController _scrollController = ScrollController();
  int? _previousTutorialStep;
  bool _isProfileIncomplete = false;
  bool _didLogZoomMetrics = false;
  final WorkspaceContextService _workspaceService = WorkspaceContextService();
  List<SidebarItem> _currentItems = [];

  // Dark-mode sidebar surface shared across employee/manager/admin.
  static const Color backgroundColor = Color(0xFF3D3F40);

  @override
  void initState() {
    super.initState();
    _previousTutorialStep = widget.tutorialStepIndex;
    _checkProfileCompletion();
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
        _updateItems();
      });
    }
  }

  void _updateItems() {
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
            final effectiveCollapsed = isSmall
                ? true
                : (_disableSidebarCollapseTemporarily ? false : collapsed);

            final Widget column = _SidebarLightMode(
              light: sidebarLight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxHeight < 760;
                  final isVeryCompact = constraints.maxHeight < 660;
                  final isUltraCompact = constraints.maxHeight < 580;

                  final double sidebarIconSize = isUltraCompact
                      ? 20
                      : (isVeryCompact ? 22 : (isCompact ? 24 : 26));
                  final double navTileHeight = isUltraCompact
                      ? 32
                      : (isVeryCompact ? 36 : (isCompact ? 40 : 44));
                  final double navVerticalPadding = isUltraCompact
                      ? 1.5
                      : (isVeryCompact ? 2 : 3);
                  final double navFontSize = isUltraCompact
                      ? 11.2
                      : (isVeryCompact ? 12.0 : 12.8);
                  final double sectionGap = isUltraCompact
                      ? 2
                      : (isVeryCompact ? 4 : 6);
                  final double bottomGap = isUltraCompact
                      ? 6
                      : (isVeryCompact ? 8 : 10);

                  final entries = _currentItems.asMap().entries.toList();
                  final mainEntries = entries
                      .where((e) => !_isBottomPinnedItem(e.value.route))
                      .toList();
                  final bottomEntries = entries
                      .where((e) => _isBottomPinnedItem(e.value.route))
                      .toList();

                  // #region agent log
                  if (!_didLogZoomMetrics) {
                    final bottomRoutes = bottomEntries
                        .map((e) => e.value.route)
                        .toList(growable: false);
                    debugPrint(
                      '[sidebar-debug] sizing zoom=$_sidebarZoomFactor '
                      'iconSize=$sidebarIconSize navFontSize=$navFontSize '
                      'mainCount=${mainEntries.length} bottomCount=${bottomEntries.length} '
                      'bottomRoutes=$bottomRoutes',
                    );
                    postSidebarDebugLog(
                      runId: 'pre-fix-4',
                      hypothesisId: 'H1_H2_H3',
                      location: 'lib/widgets/sidebar.dart:LayoutBuilder',
                      message: 'Sidebar sizing and pinned-bottom composition',
                      data: <String, dynamic>{
                        'zoomFactor': _sidebarZoomFactor,
                        'iconSize': sidebarIconSize,
                        'navFontSize': navFontSize,
                        'mainCount': mainEntries.length,
                        'bottomCount': bottomEntries.length,
                        'bottomRoutes': bottomRoutes,
                        'logoutRoute': '__logout__',
                        'collapseTogglePresent': true,
                      },
                    );
                    _didLogZoomMetrics = true;
                  }
                  postSidebarDebugLog(
                    runId: 'pre-fix-6',
                    hypothesisId: 'Hspacing',
                    location: 'lib/widgets/sidebar.dart:LayoutBuilder',
                    message: 'Sidebar vertical spacing metrics',
                    data: <String, dynamic>{
                      'maxHeight': constraints.maxHeight,
                      'isCompact': isCompact,
                      'isVeryCompact': isVeryCompact,
                      'isUltraCompact': isUltraCompact,
                      'sectionGap': sectionGap,
                      'bottomGap': bottomGap,
                      'navVerticalPadding': navVerticalPadding,
                      'mainEntriesCount': mainEntries.length,
                      'bottomEntriesCount': bottomEntries.length,
                      'hasWorkspaceSwitcher':
                          _workspaceService.canAccessManagerWorkspace,
                    },
                  );
                  // #endregion

                  Widget buildEntry(MapEntry<int, SidebarItem> entry) {
                    final index = entry.key;
                    final it = entry.value;
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
                        navVerticalPadding: navVerticalPadding,
                        navFontSize: navFontSize,
                        iconSize: sidebarIconSize,
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
                      navVerticalPadding: navVerticalPadding,
                      navFontSize: navFontSize,
                      iconSize: sidebarIconSize,
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
                  }

                  return Column(
                    children: [
                      _buildHeader(
                        context,
                        effectiveCollapsed,
                        sidebarLight,
                        isUltraCompact: isUltraCompact,
                        isVeryCompact: isVeryCompact,
                      ),
                      SizedBox(height: sectionGap),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: WorkspaceContextSwitcher(),
                      ),
                      SizedBox(height: sectionGap),
                      Expanded(
                        child: ListView(
                          controller: _scrollController,
                          padding: EdgeInsets.symmetric(
                            vertical: navVerticalPadding,
                          ),
                          children: mainEntries.map(buildEntry).toList(),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: bottomGap),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...bottomEntries.map(buildEntry),
                            _NavTile(
                              key: const ValueKey('nav_logout'),
                              icon: Icons.exit_to_app,
                              assetWhite: 'assets/manager_sidebar/12.png',
                              assetRed: 'assets/manager_sidebar/12.png',
                              label:
                                  AppLocalizations.of(context).employee_drawer_exit,
                              route: '__logout__',
                              isActive: false,
                              collapsed: effectiveCollapsed,
                              onTap: widget.onLogout,
                              navVerticalPadding: navVerticalPadding,
                              navFontSize: navFontSize,
                              iconSize: sidebarIconSize,
                            ),
                            _CollapseToggle(
                              collapsed: effectiveCollapsed,
                              tileHeight: navTileHeight,
                              tutorialKey:
                                  widget.sidebarTutorialKeys != null &&
                                      widget.tutorialStepIndex != null &&
                                      widget.tutorialStepIndex ==
                                          widget.items.length &&
                                      widget.tutorialStepIndex! <
                                          widget.sidebarTutorialKeys!.length
                                  ? widget.sidebarTutorialKeys![
                                      widget.tutorialStepIndex!]
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
                  );
                },
              ),
            );

            final Widget shell = Container(
              width: isSmall
                  ? double.infinity
                  : ((effectiveCollapsed ? 72 : 280) * _sidebarZoomFactor),
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

            // #region agent log
            if (!_didLogZoomMetrics) {
              _didLogZoomMetrics = true;
              debugPrint(
                '[sidebar-debug] zoom factor=$_sidebarZoomFactor '
                'isSmall=$isSmall collapsed=$effectiveCollapsed '
                'baseWidth=${effectiveCollapsed ? 72 : 280} '
                'renderedWidth=${isSmall ? -1 : ((effectiveCollapsed ? 72 : 280) * _sidebarZoomFactor)}',
              );
              postSidebarDebugLog(
                runId: 'pre-fix-3',
                hypothesisId: 'H5',
                location: 'lib/widgets/sidebar.dart:_ResponsiveSidebarState.build',
                message: 'Sidebar zoom and width metrics',
                data: <String, dynamic>{
                  'zoomFactor': _sidebarZoomFactor,
                  'isSmall': isSmall,
                  'effectiveCollapsed': effectiveCollapsed,
                  'baseWidth': effectiveCollapsed ? 72 : 280,
                        'renderedWidth': isSmall
                            ? -1
                            : ((effectiveCollapsed ? 72 : 280) *
                                  _sidebarZoomFactor),
                },
              );
            }
            // #endregion

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

  bool _isBottomPinnedItem(String route) {
    return route == '/my_profile' ||
        route == '/manager_profile' ||
        route == '/admin_profile' ||
        route == '/settings' ||
        route == '/admin_settings';
  }

  Widget _buildHeader(
    BuildContext context,
    bool collapsed,
    bool sidebarLight, {
    required bool isUltraCompact,
    required bool isVeryCompact,
  }) {
    final isDark = !sidebarLight;
    final Color welcomeTextColor = isDark
        ? Colors.white
        : const Color(0xFF000000);

    // Expanded header needs room for logo + welcome text (fixed height was causing
    // RenderFlex overflow on web when text wrapped to two lines).
    final double headerHeight = collapsed
        ? (isUltraCompact ? 52.0 : 64.0)
        : (isVeryCompact ? 102.0 : 118.0);
    final double logoBoxHeight = collapsed
        ? (isUltraCompact ? 52.0 : 64.0)
        : (isVeryCompact ? 48.0 : 56.0);

    // #region agent log
    postSidebarDebugLog(
      runId: 'pre-fix-4',
      hypothesisId: 'H4',
      location: 'lib/widgets/sidebar.dart:_buildHeader',
      message: 'Header layout metrics',
      data: <String, dynamic>{
        'collapsed': collapsed,
        'isUltraCompact': isUltraCompact,
        'isVeryCompact': isVeryCompact,
        'headerHeight': headerHeight,
        'logoBoxHeight': logoBoxHeight,
        'welcomeTextColor': welcomeTextColor.toARGB32().toRadixString(16),
      },
    );
    // #endregion

    return Container(
      height: headerHeight,
      padding: AppSpacing.sidebarHeaderPadding,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () {
          // Toggle collapse/expand when logo is tapped (medium/large screens)
          if (!_disableSidebarCollapseTemporarily &&
              !MediaQuery.of(context).size.width.isNaN) {
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                      'Welcome',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: welcomeTextColor,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Personal Development Hub',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: welcomeTextColor,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
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
    this.tileHeight = 40,
  });
  final bool collapsed;
  final GlobalKey? tutorialKey;
  final bool showTutorial;
  final VoidCallback? onTutorialNext;
  final VoidCallback? onTutorialSkip;
  final bool isLastTutorialStep;
  final double tileHeight;

  @override
  Widget build(BuildContext context) {
    final light = _SidebarLightMode.of(context);
    Widget collapseWidget = InkWell(
      onTap: () => SidebarState.instance.isCollapsed.value =
          !SidebarState.instance.isCollapsed.value,
      child: Container(
        height: tileHeight,
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
    this.navVerticalPadding = 3,
    this.navFontSize = 11.2,
    this.iconSize = 20,
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
  final double navVerticalPadding;
  final double navFontSize;
  final double iconSize;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool hovering = false;
  bool _didLogRender = false;

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
    final isDark = !sidebarLight;
    final Color unselectedColor = isDark ? Colors.white : const Color(0xFF000000);
    final Color subItemUnselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.9)
        : const Color(0xFF000000);
    final Color labelColor = isDark
        ? (isSelected ? Colors.white : (widget.isChild
              ? subItemUnselectedColor
              : unselectedColor))
        : const Color(0xFF000000);
    final Color hoverFill = sidebarLight
        ? const Color(0xFFE8E8E8)
        : AppColors.hoverColor;

    // #region agent log
    if (!_didLogRender && (isSelected || widget.route == '/employee_dashboard')) {
      _didLogRender = true;
      debugPrint(
        '[sidebar-debug] route=${widget.route} selected=$isSelected '
        'sidebarLight=$sidebarLight isDark=$isDark '
        'labelColor=${labelColor.toARGB32().toRadixString(16)}',
      );
      postSidebarDebugLog(
        runId: 'pre-fix-1',
        hypothesisId: 'H1_H2',
        location: 'lib/widgets/sidebar.dart:_NavTileState.build',
        message: 'Computed nav label color inputs',
        data: <String, dynamic>{
          'route': widget.route,
          'label': label,
          'isSelected': isSelected,
          'sidebarLight': sidebarLight,
          'isDark': isDark,
          'labelColor': labelColor.toARGB32().toRadixString(16),
        },
      );
    }
    // #endregion

    Widget navTileContent = Padding(
      padding: widget.isChild
          ? EdgeInsets.only(
              left: 36,
              right: 12,
              top: widget.navVerticalPadding,
              bottom: widget.navVerticalPadding,
            )
          : EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: widget.navVerticalPadding,
            ),
      child: MouseRegion(
        onEnter: (_) => setState(() => hovering = true),
        onExit: (_) => setState(() => hovering = false),
        child: Tooltip(
          message: isCollapsed ? label : '',
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: math.max(32, widget.iconSize + 14),
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
                                style: AppTypography.navigation.copyWith(
                                  color: isDark
                                      ? (isSelected
                                          ? Colors.white
                                          : labelColor)
                                      : const Color(0xFF000000),
                                  fontSize: widget.navFontSize,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.bold,
                                ),
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
        width: widget.iconSize,
        height: widget.iconSize,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Image.asset(
            path,
            filterQuality: FilterQuality.low,
            cacheWidth: 48,
          ),
        ),
      );
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
      size: widget.iconSize,
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
    this.navVerticalPadding = 3,
    this.navFontSize = 11.2,
    this.iconSize = 20,
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
  final double navVerticalPadding;
  final double navFontSize;
  final double iconSize;

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
        navVerticalPadding: widget.navVerticalPadding,
        navFontSize: widget.navFontSize,
        iconSize: widget.iconSize,
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
          navVerticalPadding: widget.navVerticalPadding,
          navFontSize: widget.navFontSize,
          iconSize: widget.iconSize,
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
              navVerticalPadding: widget.navVerticalPadding,
              navFontSize: widget.navFontSize,
              iconSize: widget.iconSize,
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
