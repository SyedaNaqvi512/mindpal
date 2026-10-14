import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/core/theme/app_palette.dart';
import 'package:mindpal/core/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  final hi = x > y ? x : y;
  final lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

Future<ProviderContainer> containerWith(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('WCAG AA contrast (NFR-26)', () {
    for (final p in AppPalette.all) {
      test(p.name, () {
        // Text: 4.5:1
        expect(contrast(p.text, p.background), greaterThanOrEqualTo(4.5));
        expect(contrast(p.text, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.text, p.surfaceTint), greaterThanOrEqualTo(4.5));
        expect(contrast(p.onPrimary, p.primary), greaterThanOrEqualTo(4.5));
        expect(contrast(p.primary, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.primary, p.surfaceTint), greaterThanOrEqualTo(4.5));
        expect(contrast(p.error, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.onFill, p.secondary), greaterThanOrEqualTo(4.5));
        expect(contrast(p.onFill, p.accent), greaterThanOrEqualTo(4.5));
        // Borders and unselected controls: 3:1
        expect(contrast(p.outline, p.surface), greaterThanOrEqualTo(3.0));
        expect(contrast(p.outline, p.background), greaterThanOrEqualTo(3.0));
        expect(contrast(p.outline, p.surfaceTint), greaterThanOrEqualTo(3.0));
      });
    }
  });

  group('Theme choice is remembered (FR-63)', () {
    test('defaults to Lavender Dream', () async {
      final c = await containerWith({});
      expect(c.read(themeControllerProvider), ThemeChoice.lavenderDream);
    });

    test('loads the saved choice after a restart', () async {
      final c = await containerWith({'theme': 'midnightLavender'});
      expect(c.read(themeControllerProvider), ThemeChoice.midnightLavender);
    });

    test('saves a new choice', () async {
      final c = await containerWith({});
      await c.read(themeControllerProvider.notifier).select(ThemeChoice.skyMist);
      expect(c.read(themeControllerProvider), ThemeChoice.skyMist);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme'), 'skyMist');
    });
  });
}