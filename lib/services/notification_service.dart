import 'notification_service_stub.dart'
    if (dart.library.html) 'notification_service_web.dart' as impl;

Future<bool> requestPushPermission() => impl.requestPushPermission();
Future<bool> showTestNotification(String title, String body) => impl.showTestNotification(title, body);
