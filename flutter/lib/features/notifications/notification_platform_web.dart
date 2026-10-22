import 'package:web/web.dart' as web;

Future<void> showDeviceNotification(String title, String body) async {
  if (web.Notification.permission == 'granted') {
    web.Notification(title, web.NotificationOptions(body: body));
  }
}
