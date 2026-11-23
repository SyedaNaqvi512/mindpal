import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/journal/models/reflection_progress_logic.dart';
import 'package:mindpal/features/journal/widgets/reflection_progress.dart';

void main() {
  group('reflectionStage (cloud)', () {
    test('starts by reading the entry', () {
      final s = reflectionStage(0, onDevice: false);
      expect(s.message, 'Reading your entry…');
      expect(s.index, 0);
      expect(s.total, 4);
      expect(s.slow, isFalse);
    });

    test('the message changes as time passes', () {
      final seen = <String>{
        for (final t in [0, 5, 12, 25, 40, 60])
          reflectionStage(t, onDevice: false).message,
      };
      expect(seen.length, 6);
    });

    test('steps move forward and never backward', () {
      var last = -1;
      for (var t = 0; t <= 90; t++) {
        final i = reflectionStage(t, onDevice: false).index;
        expect(i >= last, isTrue);
        expect(i < 4, isTrue);
        last = i;
      }
    });

    test('says it is taking longer after 35 seconds, and the entry is saved',
        () {
      expect(reflectionStage(34, onDevice: false).slow, isFalse);
      expect(reflectionStage(35, onDevice: false).slow, isTrue);
      expect(reflectionStage(60, onDevice: false).message,
          contains('already saved'));
    });
  });

  group('reflectionStage (on device)', () {
    test('uses private-mode wording', () {
      expect(reflectionStage(0, onDevice: true).message, contains('phone'));
      expect(reflectionStage(45, onDevice: true).message,
          contains('nothing leaves your phone'));
      expect(reflectionStage(0, onDevice: true).total, 3);
    });
  });

  testWidgets('the widget changes its message while waiting', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ReflectionProgress())),
    );
    expect(find.text('Reading your entry…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Looking for thinking patterns…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 20));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Writing your reflection…'), findsOneWidget);
    expect(find.text('Your entry is saved on this phone.'), findsOneWidget);

    // Remove the widget so its timer stops.
    await tester.pumpWidget(const SizedBox());
  });
}
