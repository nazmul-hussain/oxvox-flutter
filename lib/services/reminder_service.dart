import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily study reminders. Each "HH:mm" time gets its own repeating
/// notification (id = [_baseId] + index). Mobile only; web is a no-op.
///
/// Reminders only fire while the app is NOT open: they are scheduled when the
/// app goes to the background or closes, and cancelled when it comes back to
/// the foreground.
class ReminderService {
  static const _baseId = 100;
  static const _maxReminders = 20;
  static const _channelId = 'daily_study';
  static const _body = "Time to study! Open OxVox to continue today's words.";
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _enabled = false;
  static List<String> _times = const [];
  static _LifecycleWatcher? _watcher;

  static Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Falls back to the default (UTC) location.
    }
    _watcher ??= _LifecycleWatcher()..attach();
    _ready = true;
  }

  /// Asks for notification permission (Android 13+, iOS). Returns true if granted.
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await _init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  /// Stores the reminder settings. Schedules them now only if the app is in the
  /// background; while the app is open, any pending reminders are cancelled.
  static Future<void> sync({
    required bool enabled,
    required List<String> times,
  }) async {
    if (kIsWeb) return;
    await _init();
    _enabled = enabled;
    _times = List.of(times);
    final inForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (inForeground || !enabled) {
      await _plugin.cancelAll();
    } else {
      await _scheduleAll();
    }
  }

  static Future<void> _scheduleAll() async {
    await _plugin.cancelAll();
    if (!_enabled) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Daily study reminders',
        channelDescription: 'Reminds you to study your daily words',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < _times.length && i < _maxReminders; i++) {
      final parts = _times[i].split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      var at = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));

      await _plugin.zonedSchedule(
        id: _baseId + i,
        title: 'OxVox',
        body: _body,
        scheduledDate: at,
        notificationDetails: details,
        // Inexact keeps us free of the SCHEDULE_EXACT_ALARM permission;
        // a few minutes of drift is fine for a study reminder.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static Future<void> onForeground() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  static Future<void> onBackground() async {
    if (!_ready) return;
    await _scheduleAll();
  }
}

/// Watches app lifecycle so reminders are scheduled only while the app is closed.
class _LifecycleWatcher with WidgetsBindingObserver {
  void attach() => WidgetsBinding.instance.addObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ReminderService.onForeground();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ReminderService.onBackground();
    }
  }
}
