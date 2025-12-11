import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotification {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    const settings =
        InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);
  }

  static Future<void> show({required String title, required String body}) async {
    const android = AndroidNotificationDetails(
      'docya_channel',
      'DocYa Notificaciones',
      importance: Importance.max,
      priority: Priority.high,
    );

    const ios = DarwinNotificationDetails();

    const notificationDetails =
        NotificationDetails(android: android, iOS: ios);

    await _plugin.show(
      1,
      title,
      body,
      notificationDetails,
    );
  }
}
