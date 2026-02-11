import 'dart:developer' as developer;

/// Service to handle onboarding collection users and extract persona from moduleAccessRole
class OnboardingService {
  /// App name constant - used to identify this app in moduleAccessRole
  static const String appName = 'PDH';

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
      // Split by comma to get individual app-persona pairs
      final pairs = moduleAccessRole.split(',');

      for (final pair in pairs) {
        final trimmed = pair.trim();
        // Split by " - " to separate app name and persona
        if (trimmed.contains(' - ')) {
          final parts = trimmed.split(' - ');
          if (parts.length == 2) {
            final appNamePart = parts[0].trim();
            final personaPart = parts[1].trim();

            // Check if this entry matches our app
            if (appNamePart == app) {
              // Map persona to role format
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

  /// Check if a user from onboarding collection should be included based on their persona
  /// Returns true if persona matches the required role
  static bool shouldIncludeUser(
    String? moduleAccessRole,
    String requiredRole, {
    String app = appName,
  }) {
    final persona = extractPersonaForApp(moduleAccessRole, app: app);
    if (persona == null) return false;

    return persona == requiredRole.toLowerCase();
  }

  /// Convert onboarding user data to a format compatible with users collection
  /// This allows onboarding users to be displayed alongside regular users
  static Map<String, dynamic> convertOnboardingUserToUserFormat(
    Map<String, dynamic> onboardingData,
    String userId,
  ) {
    final moduleAccessRole = onboardingData['moduleAccessRole'] as String?;
    final persona = extractPersonaForApp(moduleAccessRole) ?? 'employee';

    // Extract common fields from onboarding data
    final displayName =
        onboardingData['displayName'] ??
        onboardingData['name'] ??
        onboardingData['fullName'] ??
        'Unknown User';

    // Extract individual name and surname fields if available
    final name = onboardingData['name'] as String? ?? '';
    final surname = onboardingData['surname'] as String? ?? '';

    // If we have separate name and surname, combine them for displayName
    String finalDisplayName = displayName;
    if (name.isNotEmpty && surname.isNotEmpty) {
      finalDisplayName = '$name $surname';
    } else if (name.isNotEmpty && displayName == 'Unknown User') {
      finalDisplayName = name;
    }

    final email = onboardingData['email'] ?? '';

    // Create a user-like document
    return {
      'displayName': finalDisplayName,
      'name': name.isNotEmpty ? name : null,
      'surname': surname.isNotEmpty ? surname : null,
      'email': email,
      'role': persona,
      'fromOnboarding': true, // Flag to identify onboarding users
      // Copy other relevant fields if they exist
      ...onboardingData,
    };
  }
}
