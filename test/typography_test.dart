import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/core/motion/motion.dart';
import 'package:mindpal/core/theme/app_palette.dart';
import 'package:mindpal/core/theme/app_theme.dart';
import 'package:mindpal/core/theme/app_tokens.dart';
import 'package:mindpal/core/widgets/skeleton.dart';

void main() {
  tearDown(() => reduceMotionSetting.value = false);

  for (final p in AppPalette.all) {
    test('${p.name}: titles use the display font and body stays 16 sp', () {
      final t = AppTheme.build(p).textTheme;
      for (final s in [t.displaySmall, t.headlineMedium, t.headlineSmall, t.titleLarge]) {
        expect(s!.fontFamily, AppTokens.displayFamily);
      }
      for (final s in [t.bodyLarge, t.bodyMedium, t.titleMedium, t.labelLarge]) {
        expect(s!.fontFamily == null || s.fontFamily == AppTokens.fontFamily, isTrue);
      }
      expect(t.bodyMedium!.fontSize, 16); // SRS 5.3
      expect(t.bodyMedium!.height, greaterThanOrEqualTo(1.4));
      expect(t.titleMedium!.fontWeight, FontWeight.w800);
      expect(t.labelLarge!.fontWeight, FontWeight.w700);
    });
  }

  test('the type scale gets smaller from display to headline to title', () {
    final t = AppTheme.build(AppPalette.lavenderDream).textTheme;
    expect(t.displayLarge!.fontSize! > t.displayMedium!.fontSize!, isTrue);
    expect(t.displayMedium!.fontSize! > t.headlineLarge!.fontSize!, isTrue);
    expect(t.headlineLarge!.fontSize! > t.headlineMedium!.fontSize!, isTrue);
    expect(t.headlineMedium!.fontSize! > t.headlineSmall!.fontSize!, isTrue);
    expect(t.headlineSmall!.fontSize! > t.titleLarge!.fontSize!, isTrue);
  });

  testWidgets('skeleton cards show while loading and the screen settles', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppPalette.lavenderDream),
      home: const Scaffold(body: SkeletonList(count: 3)),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('tall skeletons and Reduce motion also build', (tester) async {
    reduceMotionSetting.value = true;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppPalette.midnightLavender),
      home: const Scaffold(body: SkeletonList(count: 2, tall: true)),
    ));
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
