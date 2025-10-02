import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:pdh/widgets/sidebar_state.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_breakpoints.dart';

class ResponsiveSidebar extends StatelessWidget {
  const ResponsiveSidebar({
    super.key,
    required this.items,
    required this.onNavigate,
    required this.currentRouteName,
    required this.onLogout,
  });

  final List<SidebarItem> items;
  final void Function(String route) onNavigate;
  final String? currentRouteName;
  final VoidCallback onLogout;

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
          width: isSmall ? double.infinity : (effectiveCollapsed ? 72 : 240),
          color: backgroundColor,
          child: Column(
            children: [
              _buildHeader(context, effectiveCollapsed),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView(
                  padding: AppSpacing.sidebarContentPadding,
                  children: items
                      .map(
                        (it) => _NavTile(
                          icon: it.icon,
                          label: it.label,
                          route: it.route,
                          isActive: currentRouteName == it.route,
                          collapsed: effectiveCollapsed,
                          onTap: () => onNavigate(it.route),
                        ),
                      )
                      .toList(),
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
            final double targetWidth = collapsed ? 48.0 : 150.0;
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
                  height: 60,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/khonodemy-sidebar-logo-red.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
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
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
    required this.collapsed,
    required this.onTap,
  });
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
    final bool isCollapsed = widget.collapsed;
    return Padding(
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
              child: Row(
                mainAxisAlignment: isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start, // Center when collapsed, start when expanded
                children: [
                  Icon(
                    widget.icon,
                    // Collapsed: make active icon stand out (bolder look via size/color)
                    color: isCollapsed
                        ? (isSelected
                              ? ResponsiveSidebar.activeColor
                              : AppColors.textPrimary)
                        : AppColors.textPrimary,
                    size: isCollapsed ? (isSelected ? 24 : 20) : 20,
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: isSelected
                            ? AppTypography.navigationActive
                            : AppTypography.navigation,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SidebarItem {
  const SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final String label;
  final String route;
}
