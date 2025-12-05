import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/settings_service.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // No longer used for authentication
// import 'package:logger/logger.dart'; // Commented out to reduce logging overhead

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Removed as it's not used
  // final Logger _logger = Logger(); // Commented out to reduce logging overhead

  User? get currentUser => _auth.currentUser; // Public getter for currentUser

  Future<void> updateProfile(String displayName, String photoUrl) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoUrl);
      await user.reload();
      // _logger.i("Profile updated: ${user.displayName}"); // Commented out
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      // _logger.i("Password reset email sent to $email"); // Commented out
    } catch (e) {
      // _logger.e("Error sending reset email: $e"); // Commented out
    }
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.delete();
        // _logger.i("User account deleted"); // Commented out
      } catch (e) {
        // _logger.e("Error deleting account: $e"); // Commented out
      }
    }
  }

  Future<void> signOut() async {
    // Clear all caches before signing out to prevent stream conflicts
    RoleService.instance.clearCache();
    SettingsService.clearCache();
    await _auth.signOut();
    // _logger.i("User signed out"); // Commented out
  }
}
