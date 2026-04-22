import 'package:flutter/material.dart';
import 'package:pdh/services/workspace_context_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';

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
    final contextPaddingH = 12.0;
    final contextPaddingV = 8.0;

    // Only show switcher if user can access manager workspace
    if (!_workspaceService.canAccessManagerWorkspace) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: switcherBorderColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // My Workspace option
          Expanded(
            child: GestureDetector(
              onTap: () {
                _workspaceService.switchToContext(WorkspaceContext.myWorkspace);
                _navigateToWorkspace(context, WorkspaceContext.myWorkspace);
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: contextPaddingH,
                  vertical: contextPaddingV,
                ),
                decoration: BoxDecoration(
                  color: _workspaceService.isMyWorkspace
                      ? AppColors.activeColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'My Workspace',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: myWorkspaceTextColor,
                    fontWeight: _workspaceService.isMyWorkspace
                        ? FontWeight.w600
                        : FontWeight.w400,
                    fontSize: 9.5, // Update font size to 9.5
                  ),
                ),
              ),
            ),
          ),
          // Manager Workspace option
          Expanded(
            child: GestureDetector(
              onTap: () {
                _workspaceService.switchToContext(
                  WorkspaceContext.managerWorkspace,
                );
                _navigateToWorkspace(
                  context,
                  WorkspaceContext.managerWorkspace,
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: contextPaddingH,
                  vertical: contextPaddingV,
                ),
                decoration: BoxDecoration(
                  color: _workspaceService.isManagerWorkspace
                      ? AppColors.activeColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Manager Workspace',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: managerWorkspaceTextColor,
                    fontWeight: _workspaceService.isManagerWorkspace
                        ? FontWeight.w600
                        : FontWeight.w400,
                    fontSize: 9.5, // Update font size to 9.5
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
