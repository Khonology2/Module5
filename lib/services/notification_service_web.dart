// Only compiled on web via conditional import in notification_service.dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<bool> requestPushPermission() async {
  try {
    final permissionPromise = web.Notification.requestPermission();
    final result = await permissionPromise.toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

Future<bool> showTestNotification(String title, String body) async {
  try {
    final permission = web.Notification.permission;
    if (permission.toString() == 'granted') {
      web.Notification(
        title,
        web.NotificationOptions(body: body),
      );
      return true;
    }
  } catch (_) {}
  return false;
}
