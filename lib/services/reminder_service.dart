import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/reminder_plan.dart';

/// Daily study reminders. Each "HH:mm" time gets its own repeating
/// notification (id = [_baseId] + index). Mobile only; web is a no-op.
///
/// Reminders only fire while the app is NOT open: they are scheduled when the
/// app goes to the background or closes, and cancelled when it comes back to
/// the foreground.
class ReminderService {
  static const _baseId = 100;
  static const _maxReminders = 20;
  // Android fixes a channel's sound when it is created. Version 1.0.1 created
  // 'daily_study_sound' while its chime.mp3 had been stripped from the release build, so
  // that channel can be silent on installed phones. Use a new id and delete the old one.
  static const _channelId = 'daily_study_chime';
  static const _oldChannelIds = ['daily_study_sound'];
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _enabled = false;
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
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final old in _oldChannelIds) {
      try {
        await android?.deleteNotificationChannel(channelId: old);
      } catch (_) {
        // Nothing to clean up.
      }
    }
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Daily study reminders',
        description: 'Reminds you to study your daily words',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('chime'),
      ),
    );
    _watcher ??= _LifecycleWatcher()..attach();
    _ready = true;
  }

  /// True when the app may show notifications right now.
  static Future<bool> notificationsAllowed() async {
    if (kIsWeb) return false;
    return (await Permission.notification.status).isGranted;
  }

  /// Asks for notification permission. Android stops showing the prompt after
  /// two refusals, and "Don't ask again" is permanent, so in those cases the
  /// system app settings are opened instead. Returns true if granted.
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await _init();
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
      return false;
    }
    return (await Permission.notification.request()).isGranted;
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
    final inForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (inForeground || !enabled) {
      await _plugin.cancelAll();
    } else {
      await _scheduleAll();
    }
  }

  /// Supplies the planned nudges for the next days (set by AppState).
  static Future<List<NudgeMessage>> Function()? planner;

  static Future<void> _scheduleAll() async {
    await _plugin.cancelAll();
    if (!_enabled || planner == null) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Daily study reminders',
        channelDescription: 'Reminds you to study your daily words',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('chime'),
      ),
      iOS: DarwinNotificationDetails(),
    );

    final nudges = await planner!();
    for (var i = 0; i < nudges.length && i < _maxReminders; i++) {
      final n = nudges[i];
      await _plugin.zonedSchedule(
        id: _baseId + i,
        title: n.title,
        body: n.body,
        scheduledDate: tz.TZDateTime.from(n.at, tz.local),
        notificationDetails: details,
        // Inexact keeps us free of the SCHEDULE_EXACT_ALARM permission;
        // a few minutes of drift is fine for a study reminder.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
