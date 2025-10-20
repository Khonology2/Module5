import 'package:flutter/material.dart';
import 'package:pdh/widgets/sidebar.dart';
import 'package:pdh/widgets/sidebar_state.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_breakpoints.dart';

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

  @override
  Widget build(BuildContext context) {
    // If embedded, return just the content without scaffold elements
    if (embedded) {
      return content;
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
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                title: Text(title, style: AppTypography.heading3),
                backgroundColor: Colors.transparent,
                elevation: 0,
              )
            : null,
        drawer: Drawer(
          elevation: 12,
          backgroundColor: AppColors.backgroundColor,
          child: SafeArea(
            child: ResponsiveSidebar(
              items: items,
              currentRouteName: currentRouteName,
              onNavigate: (r) {
                Navigator.pop(context);
                onNavigate(r);
              },
              onLogout: onLogout,
            ),
          ),
        ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: FocusTraversalGroup(
                policy: WidgetOrderTraversalPolicy(),
                child: content,
              ),
            ),
            if (topRightAction != null)
              Positioned(top: 8, right: 8, child: topRightAction!),
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
              leading: IconButton(
                icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                onPressed: () => SidebarState.instance.isCollapsed.value =
                    !SidebarState.instance.isCollapsed.value,
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
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FocusTraversalGroup(
                            policy: WidgetOrderTraversalPolicy(),
                            child: content,
                          ),
                        ),
                        if (topRightAction != null)
                          Positioned(
                            top: 16,
                            right: 16,
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
