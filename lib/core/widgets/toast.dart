import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum ToastKind { success, error, info }

/// Short confirmation messages (Week 9 toast notifications). A floating card
/// with an icon, so a result is clear at a glance. Uses the app's snack bar
/// theme for colors.
class Toast {
  Toast._();

  static void show(
    ScaffoldMessengerState messenger,
    String message, {
    ToastKind kind = ToastKind.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final (icon, color) = switch (kind) {
      ToastKind.success => (Symbols.check_circle_rounded, const Color(0xFF5CD6A0)),
      ToastKind.error => (Symbols.error_rounded, const Color(0xFFFF8A8A)),
      ToastKind.info => (Symbols.info_rounded, const Color(0xFFC6AEDB)),
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          content: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  static void of(
    BuildContext context,
    String message, {
    ToastKind kind = ToastKind.info,
  }) =>
      show(ScaffoldMessenger.of(context), message, kind: kind);
}
