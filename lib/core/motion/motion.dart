import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's own "Reduce motion" switch (SRS 5.4). Not Riverpod on purpose,
/// so simple widget tests do not need a ProviderScope.
final ValueNotifier<bool> reduceMotionSetting = ValueNotifier<bool>(false);

class Motion {
  static const prefsKey = 'reduce_motion';

  /// Call once in main() after SharedPreferences has loaded.
  static void load(SharedPreferences prefs) {
    reduceMotionSetting.value = prefs.getBool(prefsKey) ?? false;
  }

  static Future<void> setReduced(bool value) async {
    reduceMotionSetting.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, value);
    } catch (_) {}
  }

  /// True when the person turned Reduce motion on, or the phone asks for it.
  static bool reduced(BuildContext context) {
    final system = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return reduceMotionSetting.value || system;
  }

  /// [d], or zero when motion is reduced.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;

  /// A light vibration for taps on mood faces and keys.
  static void tap() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
