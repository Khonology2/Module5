import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdh/widgets/sidebar.dart';
import 'package:pdh/widgets/sidebar_state.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_breakpoints.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.content,
    required this.items,
    required this.currentRouteName,
    required this.onNavigate,
    required this.onLogout,
    this.showAppBar = false,
    this.topRightAction,
    this.embedded = false,
    this.tutorialStepIndex,
    this.sidebarTutorialKeys,
    this.onTutorialNext,
    this.onTutorialSkip,
  });

  final String title;
  final Widget content;
  final List<SidebarItem> items;
  final String? currentRouteName;
  final void Function(String route) onNavigate;
  final VoidCallback onLogout;
  final bool showAppBar;
  final Widget? topRightAction;
  final bool embedded;
  final int? tutorialStepIndex;
  final List<GlobalKey>? sidebarTutorialKeys;
  final VoidCallback? onTutorialNext;
  final VoidCallback? onTutorialSkip;

  @override
  Widget build(BuildContext context) {
    // If embedded, return just the content without scaffold elements
    if (embedded) {
      return content;
    }

    Widget maybeFocusTraversal(Widget child) {
      // Web can hit a focus/layout assertion during view focus changes when
      // traversal policies query semantic bounds too early.
      if (kIsWeb) return child;
      return FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: child,
      );
    }

    final isSmall = AppBreakpoints.isSmall(context);
    final isMedium = AppBreakpoints.isMedium(context);

    if (isSmall) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: false,
        appBar: showAppBar
            ? AppBar(
                leading: Builder(
                  builder: (context) => ValueListenableBuilder<bool>(
                    valueListenable: employeeDashboardLightModeNotifier,
                    builder: (context, light, _) {
                      return IconButton(
                        icon: Icon(
                          Icons.menu,
                          color: light ? Colors.black : AppColors.textPrimary,
                        ),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      );
                    },
                  ),
                ),
                title: Text(title, style: AppTypography.heading3),
                backgroundColor: Colors.transparent,
                elevation: 0,
              )
            : null,
        drawer: ValueListenableBuilder<bool>(
          valueListenable: employeeDashboardLightModeNotifier,
          builder: (context, light, _) {
            return Drawer(
              elevation: 12,
              backgroundColor: light ? Colors.white : AppColors.backgroundColor,
              child: SafeArea(
                child: ResponsiveSidebar(
                  items: items,
                  currentRouteName: currentRouteName,
                  onNavigate: (r) {
                    Navigator.pop(context);
                    onNavigate(r);
                  },
                  onLogout: onLogout,
                  tutorialStepIndex: tutorialStepIndex,
                  sidebarTutorialKeys: sidebarTutorialKeys,
                  onTutorialNext: onTutorialNext,
                  onTutorialSkip: onTutorialSkip,
                ),
              ),
            );
          },
        ),
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: maybeFocusTraversal(
                  Focus(
                    canRequestFocus: true,
                    descendantsAreFocusable: true,
                    child: content,
                  ),
                ),
              ),
              if (topRightAction != null)
                Positioned(top: 24, right: 24, child: topRightAction!),
            ],
          ),
        ),
      );
    }

    // Medium and large screens: permanent sidebar + content in a Row
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: false,
      appBar: showAppBar
          ? AppBar(
              leading: ValueListenableBuilder<bool>(
                valueListenable: employeeDashboardLightModeNotifier,
                builder: (context, light, _) {
                  return IconButton(
                    icon: Icon(
                      Icons.menu,
                      color: light ? Colors.black : AppColors.textPrimary,
                    ),
                    onPressed: () => SidebarState.instance.isCollapsed.value =
                        !SidebarState.instance.isCollapsed.value,
                  );
                },
              ),
              title: Text(title, style: AppTypography.heading3),
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: SidebarState.instance.isCollapsed,
          builder: (context, collapsed, _) {
            final effectiveCollapsed = isMedium ? true : collapsed;
            final sidebarWidth = AppBreakpoints.getResponsiveSidebarWidth(
              context,
              effectiveCollapsed,
            );

            return Row(
              children: [
                SizedBox(
                  width: sidebarWidth,
                  child: Material(
                    elevation: 8,
                    color: Colors.transparent,
                    child: ClipRect(
                      child: ResponsiveSidebar(
                        items: items,
                        currentRouteName: currentRouteName,
                        onNavigate: onNavigate,
                        onLogout: onLogout,
                        tutorialStepIndex: tutorialStepIndex,
                        sidebarTutorialKeys: sidebarTutorialKeys,
                        onTutorialNext: onTutorialNext,
                        onTutorialSkip: onTutorialSkip,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                          child: maybeFocusTraversal(content),
                        ),
                        if (topRightAction != null)
                          Positioned(
                            top: 24,
                            right: 24,
                            child: topRightAction!,
                          ),
                      ],
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
