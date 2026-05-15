import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/database_service.dart';

/// Resolves a human-readable name for the signed-in user (profile, onboarding, auth, email).
class UserDisplayNameService {
  UserDisplayNameService._();

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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';

    final uid = user.uid;
    final email = (user.email ?? '').trim();

    try {
      final profile = await DatabaseService.getUserProfile(uid);
      final fromProfile = profile.displayName.trim();
      if (fromProfile.isNotEmpty) return fromProfile;
    } catch (_) {}

    try {
      final fromOnboarding = await DatabaseService.getUserNameFromOnboarding(
        userId: uid,
        email: email.isNotEmpty ? email : null,
      );
      if (fromOnboarding != null && fromOnboarding.trim().isNotEmpty) {
        return fromOnboarding.trim();
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
