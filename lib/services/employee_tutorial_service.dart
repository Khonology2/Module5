// ignore_for_file: use_build_context_synchronously

import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/settings_service.dart';
import 'package:pdh/widgets/employee_sidebar_tutorial.dart';
import 'package:pdh/design_system/sidebar_config.dart';

/// Service to manage employee sidebar tutorial state
class EmployeeTutorialService {
  EmployeeTutorialService._internal();
  static final EmployeeTutorialService instance =
      EmployeeTutorialService._internal();

  // Global tutorial state that persists across navigation
  bool _isTutorialActive = false;
  int _currentTutorialStep = 0;
  List<GlobalKey>? _tutorialKeys;

  bool get isTutorialActive => _isTutorialActive;
  int get currentTutorialStep => _currentTutorialStep;
  List<GlobalKey>? get tutorialKeys => _tutorialKeys;
  BuildContext? get currentContext => _currentContext;

  // Callbacks that work from any screen
  VoidCallback? get onTutorialNext => _isTutorialActive
      ? () => moveToNextTutorialStep(_getCurrentContext())
      : null;
  VoidCallback? get onTutorialSkip =>
      _isTutorialActive ? () => skipTutorial(_getCurrentContext()) : null;

  BuildContext? _currentContext;
  void setCurrentContext(BuildContext context) {
    _currentContext = context;
  }

  BuildContext _getCurrentContext() {
    if (_currentContext == null) {
      throw StateError(
        'Tutorial context not set. Call setCurrentContext first.',
      );
    }
    return _currentContext!;
  }

  void setTutorialState({
    required bool isActive,
    required int currentStep,
    required List<GlobalKey> keys,
    required BuildContext context,
  }) {
    _isTutorialActive = isActive;
    _currentTutorialStep = currentStep;
    _tutorialKeys = keys;
    _currentContext = context;
  }

  void updateTutorialStep(int step) {
    _currentTutorialStep = step;
  }

  void clearTutorialState() {
    _isTutorialActive = false;
    _currentTutorialStep = 0;
    _tutorialKeys = null;
    _currentContext = null;
  }

  /// Show tutorial popup for current step (can be called from any screen)
  void showTutorialPopup(BuildContext context) {
    if (!_isTutorialActive || _tutorialKeys == null) {
      return;
    }
    // Update context
    _currentContext = context;
    _tryShowTutorialPopup(0);
  }

  /// Try to show tutorial popup with retries
  void _tryShowTutorialPopup(int attempt) {
    if (!_isTutorialActive || _tutorialKeys == null) {
      if (attempt < 5) {
        // Retry up to 5 times
        Future.delayed(Duration(milliseconds: 500 + (attempt * 200)), () {
          _tryShowTutorialPopup(attempt + 1);
        });
      }
      return;
    }

    // If context is not ready, retry (it will be set by the new screen's build method)
    if (_currentContext == null) {
      developer.log(
        'Tutorial context not ready yet, attempt $attempt',
        name: 'EmployeeTutorialService',
      );
      if (attempt < 5) {
        Future.delayed(Duration(milliseconds: 500 + (attempt * 200)), () {
          _tryShowTutorialPopup(attempt + 1);
        });
      }
      return;
    }

    if (_currentTutorialStep >= _tutorialKeys!.length) {
      return;
    }

    try {
      final key = _tutorialKeys![_currentTutorialStep];
      final keyContext = key.currentContext;

      if (keyContext != null) {
        Future.delayed(const Duration(milliseconds: 300), () {
          try {
            // Use the stored context which should be from the current screen
            ShowcaseView.get().startShowCase([key]);
            developer.log(
              'Tutorial popup shown for step $_currentTutorialStep',
              name: 'EmployeeTutorialService',
            );
          } catch (e) {
            developer.log(
              'Error showing tutorial popup: $e',
              name: 'EmployeeTutorialService',
            );
            // Retry once with longer delay
            if (attempt < 3) {
              Future.delayed(const Duration(milliseconds: 1000), () {
                _tryShowTutorialPopup(attempt + 1);
              });
            }
          }
        });
      } else {
        developer.log(
          'Tutorial key context not found for step $_currentTutorialStep, attempt $attempt',
          name: 'EmployeeTutorialService',
        );
        // Retry after delay
        if (attempt < 5) {
          Future.delayed(Duration(milliseconds: 500 + (attempt * 200)), () {
            _tryShowTutorialPopup(attempt + 1);
          });
        }
      }
    } catch (e) {
      developer.log(
        'Error in _tryShowTutorialPopup: $e',
        name: 'EmployeeTutorialService',
      );
      if (attempt < 3) {
        Future.delayed(Duration(milliseconds: 500 + (attempt * 200)), () {
          _tryShowTutorialPopup(attempt + 1);
        });
      }
    }
  }

  // Helper to get tutorial parameters for AppScaffold
  Map<String, dynamic> getTutorialParams() {
    if (!_isTutorialActive) {
      return {
        'tutorialStepIndex': null,
        'sidebarTutorialKeys': null,
        'onTutorialNext': null,
        'onTutorialSkip': null,
      };
    }
    return {
      'tutorialStepIndex': _currentTutorialStep,
      'sidebarTutorialKeys': _tutorialKeys,
      'onTutorialNext': onTutorialNext,
      'onTutorialSkip': onTutorialSkip,
    };
  }

  /// Move to next tutorial step (can be called from any screen)
  void moveToNextTutorialStep(BuildContext context) {
    if (!_isTutorialActive || _tutorialKeys == null) {
      developer.log(
        'Tutorial not active or keys null. Active: $_isTutorialActive, Keys: ${_tutorialKeys != null}',
        name: 'EmployeeTutorialService',
      );
      return;
    }
    // Update context
    _currentContext = context;

    // Total steps = sidebar items + collapse toggle
    final totalSteps = SidebarConfig.employeeItems.length + 1;
    if (_currentTutorialStep < totalSteps - 1) {
      final nextStep = _currentTutorialStep + 1;

      developer.log(
        'Moving to next tutorial step: $_currentTutorialStep -> $nextStep',
        name: 'EmployeeTutorialService',
      );

      // Update global tutorial state
      updateTutorialStep(nextStep);

      // Navigate to the screen for this tutorial step
      if (nextStep < EmployeeSidebarTutorialConfig.steps.length) {
        final step = EmployeeSidebarTutorialConfig.steps[nextStep];
        final currentRoute = ModalRoute.of(context)?.settings.name;

        developer.log(
          'Current route: $currentRoute, Next step route: ${step.route}',
          name: 'EmployeeTutorialService',
        );

        // Only navigate if it's not the collapse toggle
        if (step.route != '__collapse_toggle__') {
          // Always navigate to ensure we're on the correct screen
          // This fixes the issue where the tutorial gets stuck
          if (currentRoute != step.route) {
            developer.log(
              'Navigating to ${step.route} for tutorial step $nextStep',
              name: 'EmployeeTutorialService',
            );
            // Use pushReplacementNamed to replace current screen and avoid GlobalKey conflicts
            // This ensures only one sidebar with tutorial keys exists at a time
            Navigator.pushReplacementNamed(context, step.route)
                .then((_) {
                  developer.log(
                    'Navigation to ${step.route} completed',
                    name: 'EmployeeTutorialService',
                  );
                  // After navigation completes, wait for the new screen to fully build
                  // Use post-frame callback to ensure widget tree is ready
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // Wait a bit more for the new screen to update context
                    Future.delayed(const Duration(milliseconds: 800), () {
                      // Try to show popup - the new screen should have updated context by now
                      if (_isTutorialActive && _currentContext != null) {
                        developer.log(
                          'Attempting to show tutorial popup after navigation',
                          name: 'EmployeeTutorialService',
                        );
                        _tryShowTutorialPopup(0);
                      } else {
                        developer.log(
                          'Context not ready, retrying...',
                          name: 'EmployeeTutorialService',
                        );
                        // If context not ready, retry with longer delay
                        Future.delayed(const Duration(milliseconds: 1000), () {
                          if (_isTutorialActive && _currentContext != null) {
                            _tryShowTutorialPopup(0);
                          } else {
                            developer.log(
                              'Tutorial context still not available after navigation to ${step.route}',
                              name: 'EmployeeTutorialService',
                            );
                            // Final retry
                            Future.delayed(
                              const Duration(milliseconds: 1500),
                              () {
                                _tryShowTutorialPopup(0);
                              },
                            );
                          }
                        });
                      }
                    });
                  });
                })
                .catchError((error) {
                  developer.log(
                    'Error navigating to ${step.route}: $error',
                    name: 'EmployeeTutorialService',
                    error: error,
                  );
                });
            return; // Exit early, popup will be shown after navigation
          } else {
            // Already on the correct route, just show the popup
            developer.log(
              'Already on correct route, showing popup directly',
              name: 'EmployeeTutorialService',
            );
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_isTutorialActive) {
                _tryShowTutorialPopup(0);
              }
            });
            return;
          }
        } else {
          // This is the collapse toggle step, no navigation needed
          developer.log(
            'Collapse toggle step, showing popup directly',
            name: 'EmployeeTutorialService',
          );
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_isTutorialActive) {
              _tryShowTutorialPopup(0);
            }
          });
          return;
        }
      }

      // Fallback: Trigger showcase for next step (if no navigation needed)
      developer.log(
        'Fallback: showing popup without navigation',
        name: 'EmployeeTutorialService',
      );
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_isTutorialActive) {
          _tryShowTutorialPopup(0);
        }
      });
    } else {
      // Tutorial complete
      developer.log('Tutorial complete!', name: 'EmployeeTutorialService');
      completeTutorial();
    }
  }

  /// Complete the tutorial
  Future<void> completeTutorial() async {
    developer.log(
      'Completing employee sidebar tutorial',
      name: 'EmployeeTutorialService',
    );
    await markTutorialCompleted();
    clearTutorialState();
  }

  /// Skip the tutorial
  Future<void> skipTutorial(BuildContext context) async {
    developer.log(
      'Skipping employee sidebar tutorial',
      name: 'EmployeeTutorialService',
    );

    // Dismiss the current showcase overlay
    try {
      ShowcaseView.get().dismiss();
    } catch (e) {
      developer.log(
        'Error dismissing showcase: $e',
        name: 'EmployeeTutorialService',
      );
    }

    // Mark tutorial as completed and disable it in settings
    await markTutorialCompleted();
    await SettingsService.updateSetting('tutorialEnabled', false);

    // Clear global tutorial state
    clearTutorialState();
  }

  /// Check if tutorial has been completed for the current user
  Future<bool> checkIfTutorialCompleted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      developer.log(
        'No user found in checkIfTutorialCompleted',
        name: 'EmployeeTutorialService',
      );
      return false;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // If document doesn't exist, user is new - tutorial not completed
      if (!doc.exists) {
        developer.log(
          'User document does not exist - tutorial not completed',
          name: 'EmployeeTutorialService',
        );
        return false;
      }

      final data = doc.data();
      // Tutorial is completed only if explicitly set to true
      // null or false means tutorial hasn't been completed yet
      final isCompleted = data?['employeeSidebarTutorialCompleted'] == true;
      developer.log(
        'Employee sidebar tutorial completed check: $isCompleted (raw value: ${data?['employeeSidebarTutorialCompleted']})',
        name: 'EmployeeTutorialService',
      );
      return isCompleted;
    } catch (e) {
      developer.log(
        'Error checking tutorial completion: $e',
        name: 'EmployeeTutorialService',
      );
      // If there's an error, assume tutorial not completed (safer for new users)
      return false;
    }
  }

  /// Mark tutorial as completed for the current user
  Future<void> markTutorialCompleted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      developer.log(
        'Cannot mark tutorial completed - no user',
        name: 'EmployeeTutorialService',
      );
      return;
    }

    try {
      developer.log(
        'Marking employee sidebar tutorial as completed for user: ${user.uid}',
        name: 'EmployeeTutorialService',
      );

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'employeeSidebarTutorialCompleted': true,
        'employeeSidebarTutorialCompletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      developer.log(
        'Employee sidebar tutorial marked as completed successfully',
        name: 'EmployeeTutorialService',
      );
    } catch (e) {
      developer.log(
        'Error marking tutorial as completed: $e',
        name: 'EmployeeTutorialService',
        error: e,
      );
    }
  }

  /// Reset tutorial completion status (for restarting tutorial)
  Future<void> resetTutorialCompletion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'employeeSidebarTutorialCompleted': false,
      }, SetOptions(merge: true));
      developer.log(
        'Employee sidebar tutorial completion reset',
        name: 'EmployeeTutorialService',
      );
    } catch (e) {
      developer.log(
        'Error resetting tutorial completion: $e',
        name: 'EmployeeTutorialService',
      );
    }
  }

  /// Check if tutorial is enabled in user settings
  Future<bool> isTutorialEnabled() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final settings = await SettingsService.getUserSettings();
      return settings?.tutorialEnabled ?? false;
    } catch (e) {
      developer.log(
        'Error checking tutorial enabled: $e',
        name: 'EmployeeTutorialService',
      );
      return false;
    }
  }

  /// Determine if tutorial should be shown automatically
  /// Returns true if user is an employee, tutorial is enabled, and hasn't completed tutorial
  Future<bool> shouldShowTutorial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      developer.log(
        'No user found, tutorial will not show',
        name: 'EmployeeTutorialService',
      );
      return false;
    }

    try {
      // Check if user is an employee
      final role = await RoleService.instance.getRole();
      developer.log('User role: $role', name: 'EmployeeTutorialService');

      if (role != 'employee') {
        developer.log(
          'User is not an employee, tutorial will not show',
          name: 'EmployeeTutorialService',
        );
        return false;
      }

      // Check if tutorial is enabled in settings
      final enabled = await isTutorialEnabled();
      developer.log(
        'Tutorial enabled in settings: $enabled',
        name: 'EmployeeTutorialService',
      );

      if (!enabled) {
        developer.log(
          'Tutorial is disabled in settings',
          name: 'EmployeeTutorialService',
        );
        return false;
      }

      // Check if tutorial has been completed
      final isCompleted = await checkIfTutorialCompleted();
      developer.log(
        'Tutorial completed status: $isCompleted',
        name: 'EmployeeTutorialService',
      );

      // Show tutorial if NOT completed
      final shouldShow = !isCompleted;
      developer.log(
        'Should show employee sidebar tutorial: $shouldShow',
        name: 'EmployeeTutorialService',
      );
      return shouldShow;
    } catch (e) {
      developer.log(
        'Error checking if tutorial should show: $e',
        name: 'EmployeeTutorialService',
      );
      // On error, default to not showing tutorial
      return false;
    }
  }
}
