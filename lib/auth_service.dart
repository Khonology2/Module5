import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();

  User? get currentUser => _auth.currentUser; // Public getter for currentUser

  Future<void> updateProfile(String displayName, String photoUrl) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoUrl);
      await user.reload();
      _logger.i("Profile updated: ${user.displayName}");
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _logger.i("Password reset email sent to $email");
    } catch (e) {
      _logger.e("Error sending reset email: $e");
    }
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.delete();
        _logger.i("User account deleted");
      } catch (e) {
        _logger.e("Error deleting account: $e");
      }
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _logger.i("User signed out");
  }
}
