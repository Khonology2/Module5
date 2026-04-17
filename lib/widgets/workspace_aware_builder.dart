import 'package:flutter/material.dart';
import 'package:pdh/services/workspace_context_service.dart';
import 'package:pdh/services/role_service.dart';

/// A widget that provides workspace context to its descendants
class WorkspaceAwareBuilder extends StatelessWidget {
  const WorkspaceAwareBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(
    BuildContext context,
    WorkspaceContext workspaceContext,
    bool isManager,
    bool isMyWorkspace,
    bool isManagerWorkspace,
  ) builder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WorkspaceContextService(),
      builder: (context, _) {
        final workspaceService = WorkspaceContextService();
        final role = RoleService.instance.cachedRole?.toLowerCase() ?? 'employee';
        final isManager = role == 'manager' || role == 'admin';
        
        return builder(
          context,
          workspaceService.currentContext,
          isManager,
          workspaceService.isMyWorkspace,
          workspaceService.isManagerWorkspace,
        );
      },
    );
  }
}

/// Extension methods to make workspace context checking easier
extension WorkspaceContextExtensions on BuildContext {
  /// Get current workspace context
  WorkspaceContext get workspaceContext => WorkspaceContextService().currentContext;
  
  /// Check if user is in My Workspace
  bool get isMyWorkspace => WorkspaceContextService().isMyWorkspace;
  
  /// Check if user is in Manager Workspace
  bool get isManagerWorkspace => WorkspaceContextService().isManagerWorkspace;
  
  /// Check if current user is a manager or admin
  bool get isManagerUser {
    final role = RoleService.instance.cachedRole?.toLowerCase() ?? 'employee';
    return role == 'manager' || role == 'admin';
  }
  
  /// Check if should load personal data (My Workspace context)
  bool get shouldLoadPersonalData => isMyWorkspace;
  
  /// Check if should load team/manager data (Manager Workspace context)
  bool get shouldLoadManagerData => isManagerWorkspace && isManagerUser;
}
