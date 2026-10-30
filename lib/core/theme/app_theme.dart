import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_tokens.dart';

class AppTheme {
  /// Muted text: 72% of the text color over the surface.
  static Color mutedText(AppPalette p) =>
      Color.alphaBlend(p.text.withValues(alpha: 0.72), p.surface);

  /// Soft fill for selected controls. Kept light enough that the main color
  /// and muted text both pass 4.5:1 on it in every theme (checked in theme_test).
  static Color selectedFill(AppPalette p) => Color.alphaBlend(
      p.primary.withValues(alpha: p.isDark ? 0.20 : 0.10), p.surface);

  static ThemeData build(AppPalette p) {
    final surface = p.surface;
    final muted = mutedText(p);
    final selectedFill = AppTheme.selectedFill(p);
    final secondaryFill =
        Color.alphaBlend(p.secondary.withValues(alpha: p.isDark ? 0.30 : 0.38), surface);
    final tertiaryFill =
        Color.alphaBlend(p.accent.withValues(alpha: p.isDark ? 0.30 : 0.42), surface);
    final errorFill =
        Color.alphaBlend(p.error.withValues(alpha: p.isDark ? 0.24 : 0.12), surface);

    final scheme = ColorScheme(
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: selectedFill,
      onPrimaryContainer: p.text,
      secondary: p.secondary,
      onSecondary: p.onFill,
      secondaryContainer: secondaryFill,
      onSecondaryContainer: p.text,
      tertiary: p.accent,
      onTertiary: p.onFill,
      tertiaryContainer: tertiaryFill,
      onTertiaryContainer: p.text,
      error: p.error,
      onError: p.onPrimary,
      errorContainer: errorFill,
      onErrorContainer: p.text,
      surface: surface,
      onSurface: p.text,
      onSurfaceVariant: muted,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: surface,
      surfaceContainer: p.surfaceTint,
      surfaceContainerHigh: p.surfaceTint,
      surfaceContainerHighest: p.surfaceTint,
      outline: p.outline,
      outlineVariant: p.surfaceTint,
      shadow: p.primary,
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
        color: surface,
        elevation: 1.5,
        shadowColor: p.primary.withValues(alpha: 0.22),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          side: BorderSide(color: p.primary.withValues(alpha: p.isDark ? 0.18 : 0.08)),
        ),
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
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: minButton,
          shape: pill,
          elevation: 0,
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
        fillColor: surface,
        contentPadding: const EdgeInsets.all(AppTokens.space16),
        border: field(p.outline, 1),
        enabledBorder: field(p.outline, 1),
        focusedBorder: field(p.primary, 2),
        errorBorder: field(p.error, 1),
        focusedErrorBorder: field(p.error, 2),
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
        errorStyle: TextStyle(color: p.error),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceTint,
        selectedColor: selectedFill,
        checkmarkColor: p.primary,
        side: BorderSide(color: p.outline),
        shape: pill,
        labelStyle: textTheme.labelMedium?.copyWith(color: p.text),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.selected) ? selectedFill : surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.selected) ? p.primary : p.text,
          ),
          side: WidgetStateProperty.resolveWith<BorderSide?>(
            (states) => BorderSide(
              color: states.contains(WidgetState.selected) ? p.primary : p.outline,
            ),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.selected) ? p.onPrimary : p.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.selected) ? p.primary : p.surfaceTint,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.transparent : p.outline,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSheet),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radiusSheet)),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.surfaceTint, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.text,
        contentTextStyle: TextStyle(color: p.background, fontFamily: AppTokens.fontFamily),
        actionTextColor: p.isDark ? p.background : p.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusField),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    );
  }
}
