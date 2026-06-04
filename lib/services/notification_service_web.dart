// Only compiled on web via conditional import in notification_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/backend_auth_service.dart';

Future<bool> requestPushPermission() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  try {
    await BackendAuthService.instance.updateUserSettings(
      user.uid,
      {'pushNotifications': true},
    );
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> showTestNotification(String title, String body) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  try {
    await BackendAuthService.instance.updateUserProfile(
      user.uid,
      {
        'data': {
          'lastNotificationTestTitle': title,
          'lastNotificationTestBody': body,
          'lastNotificationTestAt': DateTime.now().toIso8601String(),
        },
      },
    );
    return true;
  } catch (_) {
    return false;
  }
}
