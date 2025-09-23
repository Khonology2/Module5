import 'package:flutter/material.dart';
import 'package:pdh/widgets/sidebar_state.dart';

class ResponsiveSidebar extends StatelessWidget {
  const ResponsiveSidebar({super.key, required this.items, required this.onNavigate, required this.currentRouteName, required this.onLogout});

  final List<SidebarItem> items;
  final void Function(String route) onNavigate;
  final String? currentRouteName;
  final VoidCallback onLogout;

  static const Color backgroundColor = Color(0xFF1F2840);
  // Lighter shade shown on hover only
  static const Color hoverColor = Color(0xFF2A3652);
  // Distinct active/selected color
  static const Color activeColor = Color(0xFFC10D00);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // Small screens: show as drawer content only, caller should use Drawer
    final isSmall = width < 600;
    final isMedium = width >= 600 && width < 1000;

    return ValueListenableBuilder<bool>(
      valueListenable: SidebarState.instance.isCollapsed,
      builder: (context, collapsed, _) {
        final effectiveCollapsed = isSmall ? true : (isMedium ? true : collapsed);

        return Container(
          width: isSmall
              ? double.infinity
              : (effectiveCollapsed ? 72 : 240),
          color: backgroundColor,
          child: Column(
            children: [
              _buildHeader(context, effectiveCollapsed),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: items.map((it) => _NavTile(
                    icon: it.icon,
                    label: it.label,
                    route: it.route,
                    isActive: currentRouteName == it.route,
                    collapsed: effectiveCollapsed,
                    onTap: () => onNavigate(it.route),
                  )).toList(),
                ),
              ),
              _NavTile(
                icon: Icons.exit_to_app,
                label: 'Exit.',
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          if (collapsed) {
            SidebarState.instance.isCollapsed.value = false;
          } else {
            // Navigate to employee dashboard landing after login
            onNavigate('/employee_dashboard');
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Image.asset('assets/khonodemy.png', width: 28, height: 28),
            if (!collapsed) ...[
              const SizedBox(width: 10),
              const Text(
                'PDH',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ]
          ],
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
      onTap: () => SidebarState.instance.isCollapsed.value = !SidebarState.instance.isCollapsed.value,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        child: Icon(
          collapsed ? Icons.chevron_right : Icons.chevron_left,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({required this.icon, required this.label, required this.route, required this.isActive, required this.collapsed, required this.onTap});
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool hovering = false;
  @override
  Widget build(BuildContext context) {
    final bool isHovered = hovering && !widget.isActive;
    final bool isSelected = widget.isActive;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => hovering = true),
        onExit: (_) => setState(() => hovering = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? ResponsiveSidebar.activeColor
                  : (isHovered ? ResponsiveSidebar.hoverColor : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              boxShadow: (isSelected || isHovered)
                  ? [
                      BoxShadow(
                        color: (isSelected
                                ? ResponsiveSidebar.activeColor
                                : ResponsiveSidebar.hoverColor)
                            .withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(widget.icon, color: Colors.white),
                if (!widget.collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SidebarItem {
  const SidebarItem({required this.icon, required this.label, required this.route});
  final IconData icon;
  final String label;
  final String route;
}


