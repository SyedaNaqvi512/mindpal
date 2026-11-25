import 'package:flutter/material.dart';

import '../widgets/motion_kit.dart';
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

    // Type scale (SRS 5.3). Titles use the display serif; body, labels and
    // controls use Nunito. Body is 16 sp with a relaxed line height.
    TextStyle display(TextStyle? s, double size, double height,
            [FontWeight weight = FontWeight.w600]) =>
        (s ?? const TextStyle()).copyWith(
          fontFamily: AppTokens.displayFamily,
          fontSize: size,
          height: height,
          fontWeight: weight,
          letterSpacing: -0.2,
        );

    final textTheme = base.copyWith(
      displayLarge: display(base.displayLarge, 40, 1.15),
      displayMedium: display(base.displayMedium, 34, 1.15),
      displaySmall: display(base.displaySmall, 30, 1.2),
      headlineLarge: display(base.headlineLarge, 28, 1.2),
      headlineMedium: display(base.headlineMedium, 24, 1.25),
      headlineSmall: display(base.headlineSmall, 22, 1.25),
      titleLarge: display(base.titleLarge, 20, 1.3),
      titleMedium: base.titleMedium?.copyWith(fontSize: 17, height: 1.3, fontWeight: FontWeight.w800),
      titleSmall: base.titleSmall?.copyWith(fontSize: 14.5, height: 1.3, fontWeight: FontWeight.w700),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: AppTokens.bodySize, height: 1.5, fontWeight: FontWeight.w400),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: AppTokens.bodySize, height: 1.5, fontWeight: FontWeight.w400),
      bodySmall: base.bodySmall?.copyWith(fontSize: 14, height: 1.45, fontWeight: FontWeight.w400),
      labelLarge: base.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
      labelMedium: base.labelMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2),
      labelSmall: base.labelSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.2),
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
        elevation: 3,
        shadowColor: p.primary.withValues(alpha: 0.20),
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
          minimumSize: const Size(AppTokens.minTouch, 52),
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
        floatingLabelStyle: TextStyle(color: p.primary, fontWeight: FontWeight.w700),
        prefixIconColor: muted,
        suffixIconColor: muted,
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
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.surfaceTint,
        circularTrackColor: p.surfaceTint,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary,
        selectionColor: p.primary.withValues(alpha: 0.25),
        selectionHandleColor: p.primary,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        inactiveTrackColor: p.surfaceTint,
        thumbColor: p.primary,
        overlayColor: p.primary.withValues(alpha: 0.12),
        trackHeight: 6,
        valueIndicatorColor: p.primary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.text,
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        ),
        textStyle: TextStyle(color: p.background, fontFamily: AppTokens.fontFamily),
        waitDuration: const Duration(milliseconds: 500),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusField),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusField),
        ),
      ),
      splashColor: p.primary.withValues(alpha: 0.08),
      highlightColor: p.primary.withValues(alpha: 0.04),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: SoftPageTransitions(),
        TargetPlatform.iOS: SoftPageTransitions(),
      }),
    );
  }
}
