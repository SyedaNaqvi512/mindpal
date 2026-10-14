import 'package:flutter/material.dart';

/// One theme's colors (SRS 5.2). Screens never use raw hex values: they read these roles.
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceTint,
    required this.text,
    required this.error,
    required this.onPrimary,
    required this.onFill,
  });

  final String id;
  final String name;
  final bool isDark;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceTint;
  final Color text;
  final Color error;
  final Color onPrimary;

  /// Text color on secondary and accent fills (SRS: Text in light themes, Background in Midnight).
  final Color onFill;

  /// Borders and unselected controls need 3:1 contrast (NFR-26).
  /// Text color at 60% over the surface passes on surface, background and tint in all themes.
  Color get outline => Color.alphaBlend(text.withValues(alpha: 0.6), surface);

  static const lavenderDream = AppPalette(
    id: 'lavenderDream',
    name: 'Lavender Dream',
    isDark: false,
    primary: Color(0xFF6F5FB8),
    secondary: Color(0xFFE8A0BF),
    accent: Color(0xFFF6C6A8),
    background: Color(0xFFFBF8FF),
    surface: Color(0xFFFFFFFF),
    surfaceTint: Color(0xFFF1ECFB),
    text: Color(0xFF2B2540),
    error: Color(0xFFB5435B),
    onPrimary: Color(0xFFFFFFFF),
    onFill: Color(0xFF2B2540),
  );

  static const roseCream = AppPalette(
    id: 'roseCream',
    name: 'Rose & Cream',
    isDark: false,
    primary: Color(0xFFA3436B),
    secondary: Color(0xFFF3B9C8),
    accent: Color(0xFFF6D3A8),
    background: Color(0xFFFFF8F2),
    surface: Color(0xFFFFFFFF),
    surfaceTint: Color(0xFFFCEBE5),
    text: Color(0xFF3A2630),
    error: Color(0xFFB5435B),
    onPrimary: Color(0xFFFFFFFF),
    onFill: Color(0xFF3A2630),
  );

  static const skyMist = AppPalette(
    id: 'skyMist',
    name: 'Sky Mist',
    isDark: false,
    primary: Color(0xFF3A6AAA),
    secondary: Color(0xFFA9C8F0),
    accent: Color(0xFFF2C9B8),
    background: Color(0xFFF5F9FF),
    surface: Color(0xFFFFFFFF),
    surfaceTint: Color(0xFFE6F0FB),
    text: Color(0xFF1F2D44),
    error: Color(0xFFB5435B),
    onPrimary: Color(0xFFFFFFFF),
    onFill: Color(0xFF1F2D44),
  );

  static const midnightLavender = AppPalette(
    id: 'midnightLavender',
    name: 'Midnight Lavender',
    isDark: true,
    primary: Color(0xFFB7A8F0),
    secondary: Color(0xFFF0B5CB),
    accent: Color(0xFFE9B08F),
    background: Color(0xFF15121F),
    surface: Color(0xFF1F1B2E),
    surfaceTint: Color(0xFF2A2540),
    text: Color(0xFFEEE9F8),
    error: Color(0xFFF2929F),
    onPrimary: Color(0xFF15121F),
    onFill: Color(0xFF15121F),
  );

  static const all = [lavenderDream, roseCream, skyMist, midnightLavender];
}

/// Mood colors 1 to 5 (SRS 5.2), the same in every theme.
class MoodColors {
  static const rose = Color(0xFFE9A0A0);
  static const peach = Color(0xFFF3BE8B);
  static const butter = Color(0xFFF5E08E);
  static const sage = Color(0xFFB7D7A8);
  static const sky = Color(0xFFA9C8F0);
  static const byLevel = [rose, peach, butter, sage, sky];

  /// Exercise areas (SRS 5.2).
  static const fact = Color(0xFFA9C8F0);
  static const assumption = Color(0xFFE8A0BF);
}