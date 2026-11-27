import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/app/app_shell.dart';
import 'package:mindpal/core/motion/motion.dart';
import 'package:mindpal/core/theme/app_look.dart';
import 'package:mindpal/core/theme/app_palette.dart';
import 'package:mindpal/core/theme/app_theme.dart';
import 'package:mindpal/core/widgets/app_backdrop.dart';
import 'package:mindpal/core/widgets/empty_state.dart';
import 'package:mindpal/core/widgets/motion_kit.dart';

void main() {
  tearDown(() => reduceMotionSetting.value = false);

  test('each palette has its own look, and the looks really differ', () {
    expect(AppLook.forPalette('lavenderDream').id, 'soft');
    expect(AppLook.forPalette('roseCream').id, 'paper');
    expect(AppLook.forPalette('skyMist').id, 'minimal');
    expect(AppLook.forPalette('midnightLavender').id, 'night');
    final looks = AppLook.all;
    for (final pick in <Object Function(AppLook)>[
      (l) => l.displayFamily,
      (l) => l.cardStyle,
      (l) => l.backdrop,
      (l) => l.nav,
      (l) => l.art,
      (l) => l.motion,
    ]) {
      expect(looks.map(pick).toSet().length, greaterThan(1));
    }
    // Card shape, navigation, art, backdrop and motion are all different.
    expect(looks.map((l) => l.nav).toSet().length, 4);
    expect(looks.map((l) => l.art).toSet().length, 4);
    expect(looks.map((l) => l.backdrop).toSet().length, 4);
    expect(looks.map((l) => l.motion).toSet().length, 4);
    expect(looks.map((l) => l.cardRadius).toSet().length, 4);
    // Clean & Minimal is square and flat: no gradient header, small corners.
    expect(AppLook.minimal.gradientHeader, isFalse);
    expect(AppLook.minimal.cardRadius, lessThan(AppLook.soft.cardRadius / 3));
  });

  test('the theme carries its look', () {
    for (final p in AppPalette.all) {
      final theme = AppTheme.build(p);
      expect(theme.extension<AppLookExtension>()!.look.id, AppLook.forPalette(p.id).id);
    }
  });

  test('motion follows the look: minimal is quick, night is slow', () {
    expect(AppLook.minimal.durationScale, lessThan(AppLook.soft.durationScale));
    expect(AppLook.night.durationScale, greaterThan(AppLook.soft.durationScale));
    expect(AppLook.minimal.slideScale, lessThan(AppLook.soft.slideScale));
    expect(AppLook.soft.scaled(const Duration(milliseconds: 300)),
        const Duration(milliseconds: 300));
  });

  for (final p in AppPalette.all) {
    testWidgets('${p.name}: backdrop, empty state, celebration and nav settle', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(p),
        home: AppBackdrop(
          child: Scaffold(
            body: Column(children: const [
              Expanded(
                child: EmptyState(icon: Icons.book, title: 'Nothing here', message: 'Add one.'),
              ),
              SizedBox(height: 120, child: Celebration()),
            ]),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Nothing here'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });
  }

  for (final p in AppPalette.all) {
    testWidgets('${p.name}: bottom bar fits and switches tabs without overflow', (tester) async {
      var picked = -1;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(p),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: AppBottomBar(
            index: 0,
            onSelect: (i) => picked = i,
            onNewEntry: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final bar = tester.getSize(find.byType(AppBottomBar));
      expect(bar.height, lessThan(110));
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(picked, 2);
      expect(find.text('New entry'), findsOneWidget);
    });
  }

  testWidgets('Reduce motion removes the celebration', (tester) async {
    reduceMotionSetting.value = true;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppPalette.skyMist),
      home: const Scaffold(body: Celebration()),
    ));
    expect(find.byType(Celebration), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('every celebration kind paints without errors', () {
    for (final k in CelebrationKind.values) {
      final painter = ConfettiPainter(0.5, const [Colors.red, Colors.blue], k);
      painter.paint(Canvas(PictureRecorder()), const Size(300, 240));
    }
  });
}
