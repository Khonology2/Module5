import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/services/database_service.dart';

/// Service to check and manage profile completion status
/// Ensures users complete essential profile fields before adding goals
class ProfileCompletionService {
  /// Required fields for a complete profile
  /// These are essential fields that users must fill before they can add goals
  static const List<String> requiredFields = [
    'displayName',
    'email',
    'jobTitle',
    'department',
  ];

  /// Check if a user's profile is complete
  /// Returns true if all required fields are filled
  static Future<bool> isProfileComplete(String userId) async {
    try {
      final profile = await DatabaseService.getUserProfile(userId);
      return _checkProfileCompleteness(profile);
    } catch (e) {
      developer.log('Error checking profile completion: $e');
      return false;
    }
  }

  /// Check profile completeness from a UserProfile object
  static bool _checkProfileCompleteness(UserProfile profile) {
    // Check required fields - all must be non-empty
    if (profile.displayName.trim().isEmpty) return false;
    if (profile.email.trim().isEmpty) return false;
    if (profile.jobTitle.trim().isEmpty) return false;
    if (profile.department.trim().isEmpty) return false;

    return true;
  }

  /// Get list of missing required fields with user-friendly names
  static List<String> getMissingFields(UserProfile profile) {
    final missing = <String>[];

    if (profile.displayName.trim().isEmpty) {
      missing.add('Full Name');
    }
    if (profile.email.trim().isEmpty) {
      missing.add('Email');
    }
    if (profile.jobTitle.trim().isEmpty) {
      missing.add('Job Title');
    }
    if (profile.department.trim().isEmpty) {
      missing.add('Department');
    }

    return missing;
  }

  /// Get profile completion status for current user
  static Future<ProfileCompletionStatus>
  getCurrentUserCompletionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return ProfileCompletionStatus(
        isComplete: false,
        missingFields: ['Full Name', 'Email', 'Job Title', 'Department'],
        completionPercentage: 0,
      );
    }

    try {
      final profile = await DatabaseService.getUserProfile(user.uid);
      final isComplete = _checkProfileCompleteness(profile);
      final missing = getMissingFields(profile);
      final percentage = _calculateCompletionPercentage(profile);

      return ProfileCompletionStatus(
        isComplete: isComplete,
        missingFields: missing,
        completionPercentage: percentage,
      );
    } catch (e) {
      developer.log('Error getting completion status: $e');
      return ProfileCompletionStatus(
        isComplete: false,
        missingFields: ['Full Name', 'Email', 'Job Title', 'Department'],
        completionPercentage: 0,
      );
    }
  }

  /// Calculate completion percentage (0-100)
  static int _calculateCompletionPercentage(UserProfile profile) {
    int completed = 0;
    const total = 4; // displayName, email, jobTitle, department

    if (profile.displayName.trim().isNotEmpty) completed++;
    if (profile.email.trim().isNotEmpty) completed++;
    if (profile.jobTitle.trim().isNotEmpty) completed++;
    if (profile.department.trim().isNotEmpty) completed++;

    return ((completed / total) * 100).round();
  }

  /// Check profile completion for current user (convenience method)
  static Future<bool> isCurrentUserProfileComplete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return await isProfileComplete(user.uid);
  }
}

/// Status object containing profile completion information
class ProfileCompletionStatus {
  final bool isComplete;
  final List<String> missingFields;
  final int completionPercentage;

  ProfileCompletionStatus({
    required this.isComplete,
    required this.missingFields,
    required this.completionPercentage,
  });
}
