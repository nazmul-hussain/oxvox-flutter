import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Daily study reminders are NOT part of the app: the web app removed them
/// (web commit 5d00469 "remove reminders"), so Flutter does not schedule any.
/// This only cancels a reminder that an earlier build may have scheduled.
class ReminderService {
  static const _notificationId = 1;
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> cancelLegacyReminder() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _plugin.cancel(id: _notificationId);
  }
}
