import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/settings_service.dart';

/// Service to manage employee sidebar tutorial state
class EmployeeTutorialService {
  EmployeeTutorialService._internal();
  static final EmployeeTutorialService instance =
      EmployeeTutorialService._internal();

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
      final isCompleted = data?['employeeSidebarTutorialCompleted'] == true;
      developer.log(
        'Employee sidebar tutorial completed check: $isCompleted',
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
