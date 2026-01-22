import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/settings_service.dart';

/// Service to manage manager sidebar tutorial state
class ManagerTutorialService {
  ManagerTutorialService._internal();
  static final ManagerTutorialService instance =
      ManagerTutorialService._internal();

  /// Check if tutorial has been completed for the current user
  Future<bool> checkIfTutorialCompleted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      developer.log(
        'No user found in checkIfTutorialCompleted',
        name: 'ManagerTutorialService',
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
          name: 'ManagerTutorialService',
        );
        return false;
      }

      final data = doc.data();
      final isCompleted = data?['managerSidebarTutorialCompleted'] == true;
      developer.log(
        'Manager sidebar tutorial completed check: $isCompleted',
        name: 'ManagerTutorialService',
      );
      return isCompleted;
    } catch (e) {
      developer.log(
        'Error checking tutorial completion: $e',
        name: 'ManagerTutorialService',
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
        name: 'ManagerTutorialService',
      );
      return;
    }

    try {
      developer.log(
        'Marking manager sidebar tutorial as completed for user: ${user.uid}',
        name: 'ManagerTutorialService',
      );

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'managerSidebarTutorialCompleted': true,
        'managerSidebarTutorialCompletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      developer.log(
        'Manager sidebar tutorial marked as completed successfully',
        name: 'ManagerTutorialService',
      );
    } catch (e) {
      developer.log(
        'Error marking tutorial as completed: $e',
        name: 'ManagerTutorialService',
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
        'managerSidebarTutorialCompleted': false,
      }, SetOptions(merge: true));
      developer.log(
        'Manager sidebar tutorial completion reset',
        name: 'ManagerTutorialService',
      );
    } catch (e) {
      developer.log(
        'Error resetting tutorial completion: $e',
        name: 'ManagerTutorialService',
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
        name: 'ManagerTutorialService',
      );
      return false;
    }
  }

  /// Determine if tutorial should be shown automatically
  /// Returns true if user is a manager, tutorial is enabled, and hasn't completed tutorial
  Future<bool> shouldShowTutorial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      developer.log(
        'No user found, tutorial will not show',
        name: 'ManagerTutorialService',
      );
      return false;
    }

    try {
      // Check if user is a manager
      final role = await RoleService.instance.getRole();
      developer.log('User role: $role', name: 'ManagerTutorialService');

      if (role != 'manager') {
        developer.log(
          'User is not a manager, tutorial will not show',
          name: 'ManagerTutorialService',
        );
        return false;
      }

      // Check if tutorial is enabled in settings
      final enabled = await isTutorialEnabled();
      developer.log(
        'Tutorial enabled in settings: $enabled',
        name: 'ManagerTutorialService',
      );

      if (!enabled) {
        developer.log(
          'Tutorial is disabled in settings',
          name: 'ManagerTutorialService',
        );
        return false;
      }

      // Check if tutorial has been completed
      final isCompleted = await checkIfTutorialCompleted();
      developer.log(
        'Tutorial completed status: $isCompleted',
        name: 'ManagerTutorialService',
      );

      // Show tutorial if NOT completed
      final shouldShow = !isCompleted;
      developer.log(
        'Should show manager sidebar tutorial: $shouldShow',
        name: 'ManagerTutorialService',
      );
      return shouldShow;
    } catch (e) {
      developer.log(
        'Error checking if tutorial should show: $e',
        name: 'ManagerTutorialService',
      );
      // On error, default to not showing tutorial
      return false;
    }
  }
}

