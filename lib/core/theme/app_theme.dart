import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_tokens.dart';

class AppTheme {
  static ThemeData build(AppPalette p) {
    final scheme = ColorScheme(
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.secondary,
      onSecondary: p.onFill,
      tertiary: p.accent,
      onTertiary: p.onFill,
      error: p.error,
      onError: p.onPrimary,
      surface: p.surface,
      onSurface: p.text,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surfaceTint,
      surfaceContainerHigh: p.surfaceTint,
      surfaceContainerHighest: p.surfaceTint,
      outline: p.outline,
      outlineVariant: p.surfaceTint,
    );

    final base = ThemeData(brightness: scheme.brightness, fontFamily: AppTokens.fontFamily)
        .textTheme
        .apply(bodyColor: p.text, displayColor: p.text);

    // Headings 700, labels 600, body 400 at 16 sp (SRS 5.3)
    final textTheme = base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: AppTokens.bodySize, fontWeight: FontWeight.w400),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: AppTokens.bodySize, fontWeight: FontWeight.w400),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.w600),
    );

    const pill = StadiumBorder();
    const minButton = Size(AppTokens.minTouch, AppTokens.minTouch);

    OutlineInputBorder field(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusField),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppTokens.fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: p.background,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 2,
        shadowColor: p.primary.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusCard)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: minButton,
          shape: pill,
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: minButton,
          shape: pill,
          side: BorderSide(color: p.outline),
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: minButton,
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.all(AppTokens.space16),
        border: field(p.outline, 1),
        enabledBorder: field(p.outline, 1),
        focusedBorder: field(p.primary, 2),
        errorBorder: field(p.error, 1),
        focusedErrorBorder: field(p.error, 2),
        labelStyle: TextStyle(color: p.text.withValues(alpha: 0.75)),
        errorStyle: TextStyle(color: p.error),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceTint,
        selectedColor: p.secondary,
        side: BorderSide(color: p.outline),
        shape: pill,
        labelStyle: textTheme.labelMedium?.copyWith(color: p.text),
      ),
      dividerTheme: DividerThemeData(color: p.surfaceTint, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.text,
        contentTextStyle: TextStyle(color: p.background, fontFamily: AppTokens.fontFamily),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusField)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    );
  }
}