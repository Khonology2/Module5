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
    // Rebuild when role stream emits so switcher appears as soon as role loads.
    return StreamBuilder<String?>(
      stream: RoleService.instance.roleStream(),
      initialData: RoleService.instance.cachedRole,
      builder: (context, snapshot) {
        // Only managers can access manager workspace.
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
              color: Colors.white.withValues(alpha: 0.2),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
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
                        color: _workspaceService.isMyWorkspace
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
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
                        color: _workspaceService.isManagerWorkspace
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7),
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
      },
    );
  }
}
