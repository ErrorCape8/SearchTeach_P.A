import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();
bool _initialized = false;

Future<void> showDeviceNotification(String title, String body) async {
  if (!_initialized) {
    await _localNotifications.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    _initialized = true;
  }
  await _localNotifications.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'searchteach_notifications',
        'Notificaciones de SearchTeach',
        channelDescription: 'Avisos de tutorías y actividad académica.',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}
