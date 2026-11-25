import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/core/motion/motion.dart';
import 'package:mindpal/core/widgets/empty_state.dart';
import 'package:mindpal/core/widgets/motion_kit.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  tearDown(() => reduceMotionSetting.value = false);

  testWidgets('floating and drifting move the child and then rest', (tester) async {
    await tester.pumpWidget(_app(const Column(children: [
      Floating(child: Text('float')),
      Drift(child: Text('drift')),
    ])));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('float'), findsOneWidget);
    expect(find.text('drift'), findsOneWidget);
    // No endless animation: the screen settles (so widget tests do not hang).
    await tester.pumpAndSettle();
  });

  testWidgets('an empty state still settles with its floating badge', (tester) async {
    await tester.pumpWidget(_app(const EmptyState(
        icon: Icons.edit, title: 'Nothing yet', message: 'Write something.')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing yet'), findsOneWidget);
  });

  testWidgets('pop in shows its child and finishes', (tester) async {
    await tester.pumpWidget(_app(const PopIn(child: Text('done'))));
    await tester.pumpAndSettle();
    expect(find.text('done'), findsOneWidget);
  });

  testWidgets('the celebration plays once and does not block taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(Stack(children: [
      TextButton(onPressed: () => taps++, child: const Text('tap me')),
      const Positioned.fill(child: Celebration()),
    ])));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.descendant(of: find.byType(Celebration), matching: find.byType(CustomPaint)),
        findsWidgets);
    await tester.tap(find.text('tap me'));
    expect(taps, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('with Reduce motion on, nothing moves and there is no confetti', (tester) async {
    reduceMotionSetting.value = true;
    await tester.pumpWidget(_app(const Column(children: [
      Floating(child: Text('float')),
      Celebration(),
      PopIn(child: Text('done')),
    ])));
    expect(find.descendant(of: find.byType(Celebration), matching: find.byType(CustomPaint)),
        findsNothing);
    expect(find.text('float'), findsOneWidget);
    expect(find.text('done'), findsOneWidget);
  });

  testWidgets('the soft page transition opens the next screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: SoftPageTransitions(),
        }),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('second')))),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('a number counts up to its value', (tester) async {
    await tester.pumpWidget(_app(const CountUp(value: 7, suffix: ' days')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('7 days'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('7 days'), findsOneWidget);
  });

  testWidgets('with Reduce motion on a number shows its value at once', (tester) async {
    reduceMotionSetting.value = true;
    await tester.pumpWidget(_app(const CountUp(value: 7)));
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('typing dots animate and then rest', (tester) async {
    await tester.pumpWidget(_app(const TypingDots()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TypingDots), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('a pressable card still receives its tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(Pressable(
      child: InkWell(onTap: () => taps++, child: const SizedBox(width: 100, height: 60, child: Text('card'))),
    )));
    await tester.tap(find.text('card'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  test('stagger delays are short and capped', () {
    expect(staggerDelay(0), Duration.zero);
    expect(staggerDelay(3), const Duration(milliseconds: 135));
    expect(staggerDelay(50), const Duration(milliseconds: 360));
  });
}
