import 'package:pdh/auth_service.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/services/onboarding_service.dart';

/// Resolves a human-readable name for the signed-in user (PostgreSQL profile, onboarding, auth, email).
class UserDisplayNameService {
  UserDisplayNameService._();

  static final BackendAuthService _backend = BackendAuthService.instance;

  static String formatNameFromEmail(String email) {
    final local = email.split('@').first.trim();
    if (local.isEmpty) return '';
    return local
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
        })
        .join(' ')
        .trim();
  }

  static Future<String> resolveForCurrentUser() async {
    final user = AuthService().currentUser;
    if (user == null) return '';

    final uid = user.uid;
    final email = (user.email ?? '').trim();

    try {
      final profile = await _backend.getUser(uid);
      final fromProfile =
          (profile['displayName'] ?? profile['fullName'] ?? '').toString().trim();
      if (fromProfile.isNotEmpty) return fromProfile;
    } catch (_) {}

    try {
      final onboarding = await OnboardingService.fetchOnboardingRecord(uid);
      final fromOnboarding = OnboardingService.displayNameFromOnboarding(
        onboarding,
      );
      if (fromOnboarding != null && fromOnboarding.isNotEmpty) {
        return fromOnboarding;
      }

      if (email.isNotEmpty) {
        final byEmail = await OnboardingService.listOnboardingRecords(
          email: email,
          limit: 1,
        );
        if (byEmail.isNotEmpty) {
          final name = OnboardingService.displayNameFromOnboarding(byEmail.first);
          if (name != null && name.isNotEmpty) return name;
        }
      }
    } catch (_) {}

    final authName = (user.displayName ?? '').trim();
    if (authName.isNotEmpty) return authName;

    if (email.isNotEmpty) {
      final fromEmail = formatNameFromEmail(email);
      if (fromEmail.isNotEmpty) return fromEmail;
    }

    return '';
  }
}
