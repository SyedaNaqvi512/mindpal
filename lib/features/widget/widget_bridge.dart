import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The link between the app and its Android home-screen widget.
///
/// The widget shows no journal text. The app only gives it one whole number
/// (the days-of-writing count), and the widget gives the app one whole number
/// back: the mood the person tapped (1 to 5), or 0 for "write a new entry".
///
/// Everything here is safe to call anywhere: on a phone without the widget
/// code, on another platform, or in a test with no channel behind it, the calls
/// quietly do nothing.
class WidgetBridge {
  WidgetBridge._();

  static final WidgetBridge instance = WidgetBridge._();

  static const MethodChannel channel = MethodChannel('mindpal/widget');

  /// Gives the widget the number of writing days to show. Zero (or less) makes
  /// it show its calm greeting instead.
  Future<void> setDays(int days) async {
    try {
      await channel.invokeMethod<void>('setDays', {'days': days < 0 ? 0 : days});
    } on MissingPluginException {
      // No widget on this platform.
    } on PlatformException catch (e) {
      debugPrint('Widget update failed: ${e.code}');
    }
  }

  /// Clears what the widget shows (on sign-out and when the account is deleted).
  Future<void> clear() => setDays(0);

  /// The mood a widget tap asked for: 1 to 5, 0 for a blank new entry, or null
  /// when nothing is waiting. Each tap is returned once.
  Future<int?> takePending() async {
    try {
      final v = await channel.invokeMethod<int>('takePending');
      if (v == null || v < 0 || v > 5) return null;
      return v;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Calls [onTap] when a widget tap arrives while the app is already open.
  /// Returns a function that stops listening.
  VoidCallback listen(VoidCallback onTap) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'widgetAction') onTap();
      return null;
    });
    return () => channel.setMethodCallHandler(null);
  }
}
