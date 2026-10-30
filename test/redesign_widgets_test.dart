import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mindpal/core/motion/motion.dart';
import 'package:mindpal/core/theme/app_palette.dart';
import 'package:mindpal/core/theme/app_theme.dart';
import 'package:mindpal/core/widgets/busy_button.dart';
import 'package:mindpal/core/widgets/empty_state.dart';
import 'package:mindpal/core/widgets/fade_slide_in.dart';
import 'package:mindpal/core/widgets/logo_mark.dart';
import 'package:mindpal/core/widgets/mood_face.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.build(AppPalette.lavenderDream),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  tearDown(() => reduceMotionSetting.value = false);

  group('MoodFaceRow', () {
    testWidgets('shows five faces and reports the tapped mood', (tester) async {
      int? picked;
      await tester.pumpWidget(_app(MoodFaceRow(value: null, onChanged: (v) => picked = v)));

      for (final e in ['😞', '😕', '😐', '🙂', '😄']) {
        expect(find.text(e), findsOneWidget);
      }
      await tester.tap(find.text('😐'));
      await tester.pumpAndSettle();
      expect(picked, 3);
    });

    testWidgets('the chosen face shows a check mark', (tester) async {
      await tester.pumpWidget(_app(MoodFaceRow(value: 4, onChanged: (_) {})));
      await tester.pumpAndSettle();
      expect(find.byIcon(Symbols.check_rounded), findsOneWidget);
    });

    testWidgets('does nothing when disabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
          _app(MoodFaceRow(value: null, enabled: false, onChanged: (_) => taps++)));
      await tester.tap(find.text('🙂'));
      await tester.pumpAndSettle();
      expect(taps, 0);
    });
  });

  group('BusyButton', () {
    testWidgets('calls onPressed when idle', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(BusyButton(label: 'Save', onPressed: () => taps++)));
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(taps, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows a spinner and ignores taps while busy', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
          _app(BusyButton(label: 'Save', busy: true, onPressed: () => taps++)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(taps, 0);
    });
  });

  group('EmptyState', () {
    testWidgets('shows the message and an action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(EmptyState(
        icon: Symbols.edit_note_rounded,
        title: 'No entries yet',
        message: 'Write your first one.',
        actionLabel: 'Start',
        onAction: () => taps++,
      )));
      expect(find.text('No entries yet'), findsOneWidget);
      expect(find.text('Write your first one.'), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('LogoMark', () {
    testWidgets('draws at the requested size', (tester) async {
      await tester.pumpWidget(_app(const LogoMark(size: 72)));
      expect(tester.getSize(find.byType(LogoMark)), const Size(72, 72));
    });
  });

  group('Reduce motion', () {
    test('is loaded from and saved to preferences', () async {
      SharedPreferences.setMockInitialValues({'reduce_motion': true});
      final prefs = await SharedPreferences.getInstance();
      Motion.load(prefs);
      expect(reduceMotionSetting.value, isTrue);

      await Motion.setReduced(false);
      expect(reduceMotionSetting.value, isFalse);
      final again = await SharedPreferences.getInstance();
      expect(again.getBool('reduce_motion'), isFalse);
    });

    testWidgets('the phone setting also reduces motion', (tester) async {
      bool? reduced;
      Duration? length;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(builder: (context) {
          reduced = Motion.reduced(context);
          length = Motion.of(context, const Duration(milliseconds: 300));
          return const SizedBox.shrink();
        }),
      ));
      expect(reduced, isTrue);
      expect(length, Duration.zero);
    });

    testWidgets('the app switch keeps the normal length when off', (tester) async {
      Duration? length;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          length = Motion.of(context, const Duration(milliseconds: 300));
          return const SizedBox.shrink();
        }),
      ));
      expect(length, const Duration(milliseconds: 300));
    });

    testWidgets('FadeSlideIn shows its child at once when reduced', (tester) async {
      reduceMotionSetting.value = true;
      await tester.pumpWidget(_app(const FadeSlideIn(child: Text('hello'))));
      final fade = tester.widget<FadeTransition>(find.descendant(
        of: find.byType(FadeSlideIn),
        matching: find.byType(FadeTransition),
      ));
      expect(fade.opacity.value, 1.0);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('FadeSlideIn fades in when motion is on', (tester) async {
      await tester.pumpWidget(_app(const FadeSlideIn(child: Text('hello'))));
      FadeTransition fade() => tester.widget<FadeTransition>(find.descendant(
            of: find.byType(FadeSlideIn),
            matching: find.byType(FadeTransition),
          ));
      expect(fade().opacity.value, lessThan(1.0));
      await tester.pumpAndSettle();
      expect(fade().opacity.value, 1.0);
    });
  });
}
