import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_logic.dart';

/// One reminder a day at a time the user picks (FR-30). It is a local
/// notification: nothing is sent to a server and the text holds no journal data.
class ReminderService extends ChangeNotifier {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const _kOn = 'reminder_on';
  static const _kTime = 'reminder_minutes';
  static const _id = 1001;
  static const defaultMinutes = 20 * 60; // 8:00 PM

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool enabled = false;
  int minutes = defaultMinutes;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Falls back to UTC; the time may be off but nothing breaks.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_kOn) ?? false;
    minutes = prefs.getInt(_kTime) ?? defaultMinutes;
    _ready = true;
    // Re-create the schedule on every start, in case the phone's time zone changed.
    if (enabled) await _schedule();
  }

  Future<bool> _askPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> _schedule() async {
    final next = nextOccurrence(DateTime.now(), minutes);
    final when = tz.TZDateTime(
      tz.local,
      next.year,
      next.month,
      next.day,
      next.hour,
      next.minute,
    );
    await _plugin.zonedSchedule(
      id: _id,
      title: 'MindPal',
      body: 'How are you feeling today? Take a minute to check in.',
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily reminder',
          channelDescription: 'One gentle reminder a day to write in MindPal.',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Returns false when the phone's notification permission was refused.
  Future<bool> setEnabled(bool on) async {
    await init();
    if (on) {
      if (!await _askPermission()) return false;
      await _schedule();
    } else {
      await _plugin.cancel(id: _id);
    }
    enabled = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOn, on);
    notifyListeners();
    return true;
  }

  Future<void> setTime(int newMinutes) async {
    await init();
    minutes = newMinutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTime, newMinutes);
    if (enabled) await _schedule();
    notifyListeners();
  }

  /// Used when the account is deleted.
  Future<void> clear() async {
    try {
      await init();
      await _plugin.cancel(id: _id);
    } catch (_) {}
    enabled = false;
    minutes = defaultMinutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOn);
    await prefs.remove(_kTime);
    notifyListeners();
  }
}
