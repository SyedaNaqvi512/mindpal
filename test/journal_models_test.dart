import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/journal/models/entry_format.dart';
import 'package:mindpal/features/journal/models/mood.dart';
import 'package:mindpal/features/journal/widgets/mood_picker.dart';

void main() {
  group('Mood', () {
    test('has five moods, 1 to 5, each with emoji and label', () {
      expect(Mood.all.map((m) => m.value), [1, 2, 3, 4, 5]);
      for (final m in Mood.all) {
        expect(m.emoji, isNotEmpty);
        expect(m.label, isNotEmpty);
      }
    });
    test('byValue finds the mood and falls back to Okay', () {
      expect(Mood.byValue(5).label, 'Very good');
      expect(Mood.byValue(1).label, 'Very low');
      expect(Mood.byValue(null).value, 3);
      expect(Mood.byValue(99).value, 3);
    });
  });

  group('FeelingTags and prompts', () {
    test('parse splits and sorts the stored list', () {
      expect(FeelingTags.parse('Sad,Calm'), ['Calm', 'Sad']);
      expect(FeelingTags.parse(null), isEmpty);
      expect(FeelingTags.parse(''), isEmpty);
    });
    test('there are starter prompts and tags', () {
      expect(StarterPrompts.all.length, greaterThanOrEqualTo(5));
      expect(FeelingTags.all.length, greaterThanOrEqualTo(8));
    });
  });

  group('date format', () {
    test('formats date and time', () {
      expect(formatEntryDate('2026-10-20T11:53:00.000'), '20 Oct 2026');
      expect(formatEntryDateTime('2026-10-20T09:05:00.000'), '20 Oct 2026, 09:05');
    });
    test('bad input does not crash', () {
      expect(formatEntryDate('2026-10-20'), '20 Oct 2026');
      expect(formatEntryDate('garbage'), 'garbage');
    });
  });

  testWidgets('MoodPicker reports the tapped mood', (tester) async {
    int? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MoodPicker(value: null, onChanged: (v) => picked = v),
      ),
    ));
    await tester.tap(find.text('Good'));
    expect(picked, 4);
  });
}
