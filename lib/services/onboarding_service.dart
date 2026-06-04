import 'dart:developer' as developer;

import 'package:pdh/services/backend_auth_service.dart';

/// Parses onboarding records from PostgreSQL and extracts persona from moduleAccessRole.
class OnboardingService {
  OnboardingService._();

  static final BackendAuthService _backend = BackendAuthService.instance;

  /// App name constant - used to identify this app in moduleAccessRole
  static const String appName = 'PDH';

  /// Fetch a single onboarding record from PostgreSQL by user id.
  static Future<Map<String, dynamic>> fetchOnboardingRecord(
    String userId,
  ) async {
    if (userId.trim().isEmpty) return {};
    return _backend.tryGetOnboarding(userId.trim());
  }

  /// Fetch onboarding records from PostgreSQL, optionally filtered by email.
  static Future<List<Map<String, dynamic>>> listOnboardingRecords({
    String? email,
    int limit = 500,
  }) {
    return _backend.listOnboarding(email: email, limit: limit);
  }

  /// Resolve a display name from a PostgreSQL onboarding record.
  static String? displayNameFromOnboarding(Map<String, dynamic> onboardingData) {
    final name =
        onboardingData['displayName'] ??
        onboardingData['fullName'] ??
        onboardingData['name'] ??
        onboardingData['firstName'] ??
        (onboardingData['firstName'] != null &&
                onboardingData['lastName'] != null
            ? '${onboardingData['firstName']} ${onboardingData['lastName']}'
                  .trim()
            : null);
    if (name == null) return null;
    final trimmed = name.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Parse moduleAccessRole string and extract persona for the specified app
  ///
  /// Format: "PDH - Employee, Skills Heatmap - Manager"
  /// Returns: 'employee' or 'manager' based on the persona, or null if not found
  static String? extractPersonaForApp(
    String? moduleAccessRole, {
    String app = appName,
  }) {
    if (moduleAccessRole == null || moduleAccessRole.isEmpty) {
      return null;
    }

    try {
      final pairs = moduleAccessRole.split(',');

      for (final pair in pairs) {
        final trimmed = pair.trim();
        if (trimmed.contains(' - ')) {
          final parts = trimmed.split(' - ');
          if (parts.length == 2) {
            final appNamePart = parts[0].trim();
            final personaPart = parts[1].trim();

            if (appNamePart == app) {
              final personaLower = personaPart.toLowerCase();
              if (personaLower == 'employee') {
                return 'employee';
              } else if (personaLower == 'manager') {
                return 'manager';
              }
            }
          }
        }
      }
    } catch (e) {
      developer.log('Error parsing moduleAccessRole: $e');
    }

    return null;
  }

  /// Check if a user from onboarding should be included based on their persona
  static bool shouldIncludeUser(
    String? moduleAccessRole,
    String requiredRole, {
    String app = appName,
  }) {
    final persona = extractPersonaForApp(moduleAccessRole, app: app);
    if (persona == null) return false;

    return persona == requiredRole.toLowerCase();
  }

  /// Convert a PostgreSQL onboarding record to a user-like map for UI lists.
  static Map<String, dynamic> convertOnboardingUserToUserFormat(
    Map<String, dynamic> onboardingData,
    String userId,
  ) {
    final moduleAccessRole =
        onboardingData['moduleAccessRole'] as String? ??
        onboardingData['module_access_role'] as String?;
    final persona = extractPersonaForApp(moduleAccessRole) ?? 'employee';

    final displayName =
        onboardingData['displayName'] ??
        onboardingData['name'] ??
        onboardingData['fullName'] ??
        'Unknown User';

    final email = onboardingData['email'] ?? '';

    return {
      'displayName': displayName,
      'email': email,
      'role': persona,
      'fromOnboarding': true,
      'userId': userId,
      ...onboardingData,
    };
  }
}
