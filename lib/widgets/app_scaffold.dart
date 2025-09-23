import 'package:flutter/material.dart';
import 'package:pdh/widgets/sidebar.dart';
import 'package:pdh/widgets/sidebar_state.dart';

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
  });

  final String title;
  final Widget content;
  final List<SidebarItem> items;
  final String? currentRouteName;
  final void Function(String route) onNavigate;
  final VoidCallback onLogout;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 600;
    final isMedium = width >= 600 && width < 1000;

    if (isSmall) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: false,
        appBar: showAppBar
            ? AppBar(
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.transparent,
                elevation: 0,
              )
            : null,
        drawer: Drawer(
          elevation: 12,
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
        body: SafeArea(child: content),
      );
    }

    // Medium and large screens: permanent sidebar + content in a Row
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: false,
      appBar: showAppBar
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => SidebarState.instance.isCollapsed.value = !SidebarState.instance.isCollapsed.value,
              ),
              title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: SafeArea(child: ValueListenableBuilder<bool>(
        valueListenable: SidebarState.instance.isCollapsed,
        builder: (context, collapsed, _) {
          final effectiveCollapsed = isMedium ? true : collapsed;
          final sidebarWidth = effectiveCollapsed ? 72.0 : 240.0;

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
              Expanded(child: ClipRect(child: content)),
            ],
          );
        },
      )),
    );
  }
}


