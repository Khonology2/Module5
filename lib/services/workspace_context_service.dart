import 'package:flutter/material.dart';
import 'package:pdh/services/role_service.dart';

/// Workspace context types
enum WorkspaceContext { myWorkspace, managerWorkspace }

/// Service to manage workspace context state
class WorkspaceContextService extends ChangeNotifier {
  static final WorkspaceContextService _instance =
      WorkspaceContextService._internal();
  factory WorkspaceContextService() => _instance;
  WorkspaceContextService._internal();

  WorkspaceContext _currentContext = WorkspaceContext.myWorkspace;

  WorkspaceContext get currentContext => _currentContext;

  bool get isMyWorkspace => _currentContext == WorkspaceContext.myWorkspace;
  bool get isManagerWorkspace =>
      _currentContext == WorkspaceContext.managerWorkspace;

  /// Switch to a different workspace context
  void switchToContext(WorkspaceContext context) {
    if (_currentContext != context) {
      _currentContext = context;
      notifyListeners();
    }
  }

  /// Toggle between workspaces
  void toggleWorkspace() {
    switchToContext(
      isMyWorkspace
          ? WorkspaceContext.managerWorkspace
          : WorkspaceContext.myWorkspace,
    );
  }

  /// Initialize workspace context based on user role
  void initializeFromRole() {
    final role = RoleService.instance.cachedRole?.toLowerCase();
    if (role == 'manager' || role == 'admin') {
      _currentContext = WorkspaceContext.myWorkspace; // Default to my workspace
    } else {
      _currentContext =
          WorkspaceContext.myWorkspace; // Employee only has my workspace
    }
  }

  /// Get display name for current context
  String get currentContextDisplayName {
    switch (_currentContext) {
      case WorkspaceContext.myWorkspace:
        return 'My Workspace';
      case WorkspaceContext.managerWorkspace:
        return 'Manager Workspace';
    }
  }

  /// Check if user can access manager workspace
  bool get canAccessManagerWorkspace {
    final role = RoleService.instance.cachedRole?.toLowerCase();
    return role == 'manager'; // Only managers can switch workspaces
  }
}
