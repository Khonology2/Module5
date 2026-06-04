import 'dart:developer' as developer;

import 'package:pdh/auth_service.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/services/performance_cache_service.dart';

/// Service to check and manage profile completion status via PostgreSQL.
/// Ensures users complete essential profile fields before adding goals.
class ProfileCompletionService {
  static final BackendAuthService _backend = BackendAuthService.instance;

  /// Required fields for a complete profile
  static const List<String> requiredFields = [
    'displayName',
    'email',
    'jobTitle',
    'department',
  ];

  /// Check if a user's profile is complete
  static Future<bool> isProfileComplete(
    String userId, {
    bool bypassCache = false,
  }) async {
    try {
      if (bypassCache) {
        PerformanceCacheService().clearAll();
      }
      final profile = await _loadUserProfile(userId);
      return _checkProfileCompleteness(profile);
    } catch (e) {
      developer.log('Error checking profile completion: $e');
      return false;
    }
  }

  static Future<UserProfile> _loadUserProfile(String userId) async {
    final cache = PerformanceCacheService();
    final cached = cache.getCachedUserProfile();
    if (cached != null && cached.uid == userId) {
      return cached;
    }

    final data = await _backend.getUser(userId);
    final profile = UserProfile.fromMap(data, id: userId);
    cache.cacheUserProfile(profile);
    return profile;
  }

  static bool _checkProfileCompleteness(UserProfile profile) {
    if (profile.displayName.trim().isEmpty) return false;
    if (profile.email.trim().isEmpty) return false;
    if (profile.jobTitle.trim().isEmpty) return false;
    if (profile.department.trim().isEmpty) return false;
    return true;
  }

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

  static Future<ProfileCompletionStatus> getCurrentUserCompletionStatus() async {
    final user = AuthService().currentUser;
    if (user == null) {
      return ProfileCompletionStatus(
        isComplete: false,
        missingFields: ['Full Name', 'Email', 'Job Title', 'Department'],
        completionPercentage: 0,
      );
    }

    try {
      final profile = await _loadUserProfile(user.uid);
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

  static int _calculateCompletionPercentage(UserProfile profile) {
    int completed = 0;
    const total = 4;

    if (profile.displayName.trim().isNotEmpty) completed++;
    if (profile.email.trim().isNotEmpty) completed++;
    if (profile.jobTitle.trim().isNotEmpty) completed++;
    if (profile.department.trim().isNotEmpty) completed++;

    return ((completed / total) * 100).round();
  }

  static Future<bool> isCurrentUserProfileComplete({
    bool bypassCache = false,
  }) async {
    final user = AuthService().currentUser;
    if (user == null) return false;
    return isProfileComplete(user.uid, bypassCache: bypassCache);
  }
}

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
