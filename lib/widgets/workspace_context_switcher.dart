import 'package:flutter/material.dart';
import 'package:pdh/services/workspace_context_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';
import 'package:showcaseview/showcaseview.dart';

/// Workspace context switcher widget for the sidebar
class WorkspaceContextSwitcher extends StatefulWidget {
  const WorkspaceContextSwitcher({super.key});

  @override
  State<WorkspaceContextSwitcher> createState() =>
      _WorkspaceContextSwitcherState();
}

class _WorkspaceContextSwitcherState extends State<WorkspaceContextSwitcher> {
  final WorkspaceContextService _workspaceService = WorkspaceContextService();

  @override
  void initState() {
    super.initState();
    _workspaceService.addListener(_onWorkspaceChanged);
  }

  @override
  void dispose() {
    _workspaceService.removeListener(_onWorkspaceChanged);
    super.dispose();
  }

  void _onWorkspaceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _navigateToWorkspace(
    BuildContext buildContext,
    WorkspaceContext workspaceContext,
  ) {
    final role = RoleService.instance.cachedRole?.toLowerCase();

    if (role == 'manager') {
      try {
        ShowCaseWidget.of(buildContext).dismiss();
      } catch (_) {}
      final initialRoute = workspaceContext == WorkspaceContext.myWorkspace
          ? '/manager_gw_menu_dashboard'
          : '/dashboard';
      Navigator.pushReplacementNamed(
        buildContext,
        '/manager_portal',
        arguments: {'initialRoute': initialRoute},
      );
    }
  }

  TextStyle _labelStyle({
    required Color color,
    required FontWeight weight,
    required double fontSize,
  }) {
    return AppTypography.bodySmall.copyWith(
      color: color,
      fontWeight: weight,
      fontSize: fontSize,
      height: 1.15,
    );
  }

  /// Red pill — width follows the label only (intrinsic), not the full sidebar.
  Widget _pillSegment({
    required String label,
    required Color textColor,
    required bool isActive,
    required double fontSize,
    required double padH,
    required double padV,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.activeColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            style: _labelStyle(
              color: textColor,
              weight: isActive ? FontWeight.w600 : FontWeight.w400,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }

  /// Inactive label — intrinsic width; row + [FittedBox] handles fitting.
  Widget _plainLabel({
    required String label,
    required Color textColor,
    required bool isActive,
    required double fontSize,
    required double padH,
    required double padV,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: _labelStyle(
            color: textColor,
            weight: isActive ? FontWeight.w600 : FontWeight.w400,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = !employeeDashboardLightModeNotifier.value;
    final switcherTextColor = isDark ? Colors.white : const Color(0xFF000000);
    final switcherBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : const Color(0xFF000000);
    final myWorkspaceTextColor = _workspaceService.isMyWorkspace
        ? Colors.white
        : switcherTextColor;
    final managerWorkspaceTextColor = _workspaceService.isManagerWorkspace
        ? Colors.white
        : switcherTextColor;

    if (!_workspaceService.canAccessManagerWorkspace) {
      return const SizedBox.shrink();
    }

    final isMy = _workspaceService.isMyWorkspace;

    void onMy() {
      _workspaceService.switchToContext(WorkspaceContext.myWorkspace);
      _navigateToWorkspace(context, WorkspaceContext.myWorkspace);
    }

    void onManager() {
      _workspaceService.switchToContext(WorkspaceContext.managerWorkspace);
      _navigateToWorkspace(context, WorkspaceContext.managerWorkspace);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double band = constraints.maxWidth;
        // Room for ~240px sidebar band: comfortable caps; narrow bands scale down via FittedBox.
        final double marginH = band < 200 ? 4.0 : (band < 232 ? 8.0 : 12.0);
        final double trackPad = band < 200 ? 3.0 : 4.0;
        final double gap = band < 200 ? 5.0 : 8.0;
        final double padH = band < 200 ? 8.0 : 10.0;
        final double padV = band < 200 ? 6.0 : 8.0;
        final double fontSize = (10.0 + (band / 260) * 2.2).clamp(9.5, 11.5);

        final double innerTrackWidth =
            (band - 2 * marginH).clamp(0.0, double.infinity);

        return Padding(
          padding: EdgeInsets.fromLTRB(marginH, 12, marginH, 12),
          child: Container(
            width: innerTrackWidth,
            padding: EdgeInsets.all(trackPad),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: switcherBorderColor, width: 1),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMy) ...[
                    _pillSegment(
                      label: 'My Workspace',
                      textColor: myWorkspaceTextColor,
                      isActive: true,
                      fontSize: fontSize,
                      padH: padH,
                      padV: padV,
                      onTap: onMy,
                    ),
                    SizedBox(width: gap),
                    _plainLabel(
                      label: 'Manager Workspace',
                      textColor: managerWorkspaceTextColor,
                      isActive: false,
                      fontSize: fontSize,
                      padH: padH,
                      padV: padV,
                      onTap: onManager,
                    ),
                  ] else ...[
                    _plainLabel(
                      label: 'My Workspace',
                      textColor: myWorkspaceTextColor,
                      isActive: false,
                      fontSize: fontSize,
                      padH: padH,
                      padV: padV,
                      onTap: onMy,
                    ),
                    SizedBox(width: gap),
                    _pillSegment(
                      label: 'Manager Workspace',
                      textColor: managerWorkspaceTextColor,
                      isActive: true,
                      fontSize: fontSize,
                      padH: padH,
                      padV: padV,
                      onTap: onManager,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
