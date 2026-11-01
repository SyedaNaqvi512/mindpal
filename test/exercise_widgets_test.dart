import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/exercises/models/exercise_catalog.dart';
import 'package:mindpal/features/exercises/screens/exercise_library_screen.dart';
import 'package:mindpal/features/exercises/screens/exercise_runner_screen.dart';
import 'package:mindpal/features/exercises/widgets/breathing_bubble.dart';
import 'package:mindpal/features/exercises/widgets/safe_text_field.dart';
import 'package:mindpal/features/exercises/widgets/suggested_exercise_card.dart';
import 'package:mindpal/core/motion/motion.dart';

Widget _app(Widget child) => MaterialApp(home: child);

void main() {
  setUp(() => reduceMotionSetting.value = false);

  testWidgets('the library shows each exercise as a card with a Start button (FR-35)',
      (tester) async {
    tester.view.physicalSize = const Size(900, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const ExerciseLibraryScreen()));
    await tester.pump();

    for (final e in kExercises) {
      expect(find.text(e.title), findsOneWidget, reason: e.title);
    }
    expect(find.text('Start'), findsNWidgets(kExercises.length));
    expect(find.text('Try something quick'), findsOneWidget);
    expect(find.textContaining('not therapy or treatment'), findsOneWidget);
  });

  testWidgets('an exercise opens with an introduction, a time and the not-therapy label (FR-41, FR-51)',
      (tester) async {
    final info = exerciseById(ExerciseIds.sort)!;
    await tester.pumpWidget(_app(ExerciseRunnerScreen(info: info)));

    expect(find.text(info.title), findsWidgets);
    expect(find.text(info.timeLabel), findsOneWidget);
    expect(find.textContaining('Nothing is graded'), findsOneWidget);
    expect(find.textContaining('Not therapy or treatment'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('every step can be skipped or finished later (FR-41)', (tester) async {
    final info = exerciseById(ExerciseIds.sort)!;
    await tester.pumpWidget(_app(ExerciseRunnerScreen(info: info)));
    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(find.text('Finish later'), findsOneWidget);
    // Nothing is written yet, so the button says Skip and not Next.
    expect(find.text('Skip'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'I will fail. Everyone thinks I am slow.');
    await tester.pump();
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('the sort exercise splits the thought into statement cards (FR-36)',
      (tester) async {
    final info = exerciseById(ExerciseIds.sort)!;
    await tester.pumpWidget(_app(ExerciseRunnerScreen(info: info)));
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'I have a quiz. I will fail it.');
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Sort the statements'), findsOneWidget);
    expect(find.text('I have a quiz.'), findsOneWidget);
    expect(find.text('I will fail it.'), findsOneWidget);
    expect(find.text('Fact'), findsWidgets);
    expect(find.text('Assumption'), findsWidgets);
  });

  testWidgets('text typed in an exercise is screened and shows the support message (FR-50)',
      (tester) async {
    await tester.pumpWidget(_app(Scaffold(
      body: SingleChildScrollView(child: SafeTextField(onChanged: (_) {})),
    )));
    expect(find.text('You are not alone'), findsNothing);

    await tester.enterText(find.byType(TextField), 'I just want to die');
    await tester.pump();
    expect(find.text('You are not alone'), findsOneWidget);
  });

  testWidgets('ordinary text does not show the support message', (tester) async {
    await tester.pumpWidget(_app(Scaffold(
      body: SingleChildScrollView(child: SafeTextField(onChanged: (_) {})),
    )));
    await tester.enterText(find.byType(TextField), 'I am worried about my exam');
    await tester.pump();
    expect(find.text('You are not alone'), findsNothing);
  });

  testWidgets('the breathing bubble keeps working when Reduce motion is on (FR-53)',
      (tester) async {
    reduceMotionSetting.value = true;
    var finished = false;
    await tester.pumpWidget(_app(Scaffold(
      body: Center(child: BreathingBubble(cycles: 1, onFinished: () => finished = true)),
    )));
    expect(find.text('Start breathing'), findsOneWidget);

    await tester.tap(find.text('Start breathing'));
    await tester.pump();
    expect(find.text('Breathe in'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Pause'), findsWidgets);
    await tester.pump(const Duration(seconds: 8));
    expect(finished, isTrue);
  });

  testWidgets('a suggested exercise card can be opened or dismissed (FR-46)', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(
      body: SuggestedExerciseCard(entryId: 1, patternId: 'catastrophizing'),
    )));
    await tester.pump();

    expect(find.text('Suggested exercise'), findsOneWidget);
    expect(find.text('Facts vs Assumptions Sort'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(find.text('Suggested exercise'), findsNothing);
  });
}
