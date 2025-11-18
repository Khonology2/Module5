// Only compiled on web via conditional import in notification_service.dart
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<bool> requestPushPermission() async {
  try {
    if (!html.Notification.supported) return false;
    final result = await html.Notification.requestPermission();
    return result == 'granted';
  } catch (_) {
    return false;
  }
}

Future<bool> showTestNotification(String title, String body) async {
  try {
    if (!html.Notification.supported) return false;
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
      return true;
    }
  } catch (_) {}
  return false;
}
