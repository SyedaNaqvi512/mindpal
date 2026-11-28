import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_content.dart';

/// Two optional daily notifications, each at a time the user picks (FR-30):
///  - the check-in reminder, a gentle invitation to write;
///  - the daily thought, a short line about the mind, different every day.
/// Both are local notifications: nothing is sent to a server and the text never
/// holds journal data.
///
/// Each day has its own words, so the app schedules the next [horizon] days
/// at once and plans them again every time it starts (and whenever a setting
/// changes). If the app is not opened for longer than that, the notifications
/// simply stop until it is opened again.
class ReminderService extends ChangeNotifier {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const _kOn = 'reminder_on';
  static const _kTime = 'reminder_minutes';
  static const _kQuoteOn = 'quote_on';
  static const _kQuoteTime = 'quote_minutes';

  static const _legacyId = 1001; // the old single repeating reminder
  static const _checkInBase = 2000;
  static const _quoteBase = 3000;
  static const horizon = 14;

  static const defaultMinutes = 20 * 60; // 8:00 PM
  static const defaultQuoteMinutes = 9 * 60; // 9:00 AM

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool enabled = false;
  int minutes = defaultMinutes;
  bool quoteEnabled = false;
  int quoteMinutes = defaultQuoteMinutes;

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
    quoteEnabled = prefs.getBool(_kQuoteOn) ?? false;
    quoteMinutes = prefs.getInt(_kQuoteTime) ?? defaultQuoteMinutes;
    _ready = true;
    // The old single repeating reminder is replaced by the planned ones.
    await _plugin.cancel(id: _legacyId);
    // Plan the next days again on every start (this also follows a change of
    // the phone's time zone).
    await _plan();
    notifyListeners();
  }

  Future<bool> _askPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> _cancelRange(int base) async {
    for (var i = 0; i < horizon; i++) {
      await _plugin.cancel(id: base + i);
    }
  }

  Future<void> _scheduleAll(int base, List<PlannedNotification> plan, NotificationDetails Function(String body) details) async {
    await _cancelRange(base);
    for (var i = 0; i < plan.length; i++) {
      final p = plan[i];
      await _plugin.zonedSchedule(
        id: base + i,
        title: p.title,
        body: p.body,
        scheduledDate: tz.TZDateTime(
            tz.local, p.when.year, p.when.month, p.when.day, p.when.hour, p.when.minute),
        notificationDetails: details(p.body),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// Cancels and plans both notifications from the current settings.
  Future<void> _plan() async {
    final now = DateTime.now();
    try {
      if (enabled) {
        await _scheduleAll(
          _checkInBase,
          planCheckIns(now, minutes, count: horizon),
          (body) => NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_reminder',
              'Daily reminder',
              channelDescription: 'One gentle reminder a day to write in MindPal.',
              styleInformation: BigTextStyleInformation(body),
            ),
          ),
        );
      } else {
        await _cancelRange(_checkInBase);
      }
      if (quoteEnabled) {
        await _scheduleAll(
          _quoteBase,
          planQuotes(now, quoteMinutes, count: horizon),
          (body) => NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_thought',
              'Daily thought',
              channelDescription: 'A short, calming thought about the mind, once a day.',
              styleInformation: BigTextStyleInformation(body),
            ),
          ),
        );
      } else {
        await _cancelRange(_quoteBase);
      }
    } catch (e) {
      debugPrint('Could not plan notifications: $e');
    }
  }

  Future<void> _save(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }

  /// Returns false when the phone's notification permission was refused.
  Future<bool> setEnabled(bool on) async {
    await init();
    if (on && !await _askPermission()) return false;
    enabled = on;
    await _save(_kOn, on);
    await _plan();
    notifyListeners();
    return true;
  }

  Future<void> setTime(int newMinutes) async {
    await init();
    minutes = newMinutes;
    await _save(_kTime, newMinutes);
    await _plan();
    notifyListeners();
  }

  /// Returns false when the phone's notification permission was refused.
  Future<bool> setQuoteEnabled(bool on) async {
    await init();
    if (on && !await _askPermission()) return false;
    quoteEnabled = on;
    await _save(_kQuoteOn, on);
    await _plan();
    notifyListeners();
    return true;
  }

  Future<void> setQuoteTime(int newMinutes) async {
    await init();
    quoteMinutes = newMinutes;
    await _save(_kQuoteTime, newMinutes);
    await _plan();
    notifyListeners();
  }

  /// Used when the account is deleted.
  Future<void> clear() async {
    try {
      await init();
      await _cancelRange(_checkInBase);
      await _cancelRange(_quoteBase);
      await _plugin.cancel(id: _legacyId);
    } catch (_) {}
    enabled = false;
    minutes = defaultMinutes;
    quoteEnabled = false;
    quoteMinutes = defaultQuoteMinutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOn);
    await prefs.remove(_kTime);
    await prefs.remove(_kQuoteOn);
    await prefs.remove(_kQuoteTime);
    notifyListeners();
  }
}
