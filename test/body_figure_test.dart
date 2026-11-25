import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/core/motion/motion.dart';
import 'package:mindpal/features/exercises/bodies/exercise_registry.dart';
import 'package:mindpal/features/exercises/models/exercise_catalog.dart';
import 'package:mindpal/features/exercises/models/exercise_logic.dart';
import 'package:mindpal/features/exercises/widgets/body_figure.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  tearDown(() => reduceMotionSetting.value = false);

  test('every body scan area lights at least one part of the figure', () {
    for (final a in kBodyScanAreas) {
      expect(bodyFocusFor(a.$1), isNotEmpty, reason: a.$1);
    }
  });

  test('every body scan step has the figure and a timed reading', () {
    final steps = buildSteps(exerciseById(ExerciseIds.bodyScan)!);
    expect(steps.length, kBodyScanAreas.length);
    for (final s in steps) {
      expect(s.minSeconds, isNotNull, reason: s.title);
    }
  });

  testWidgets('the figure draws, changes area, and settles', (tester) async {
    var area = 'Settle';
    late StateSetter set;
    await tester.pumpWidget(_app(StatefulBuilder(builder: (context, setState) {
      set = setState;
      return BodyFigure(area: area);
    })));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BodyFigure), findsOneWidget);
    set(() => area = 'Feet and legs');
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('the figure also draws with Reduce motion on', (tester) async {
    reduceMotionSetting.value = true;
    await tester.pumpWidget(_app(const BodyFigure(area: 'Whole body')));
    await tester.pump();
    expect(find.byType(BodyFigure), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
