import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/core/search_text.dart';
import 'package:mindpal/features/journal/widgets/entry_tile.dart';

void main() {
  group('splitSearchWords', () {
    test('splits on spaces, lower-cases and removes repeats', () {
      expect(splitSearchWords('  Exam   HAPPY exam '), ['exam', 'happy']);
    });

    test('removes punctuation at the ends but keeps inner hyphens', () {
      expect(splitSearchWords('"teacher," all-or-nothing!'), ['teacher', 'all-or-nothing']);
    });

    test('empty or symbol-only text gives no words', () {
      expect(splitSearchWords(''), isEmpty);
      expect(splitSearchWords('  ?! '), isEmpty);
    });

    test('keeps at most eight words', () {
      expect(splitSearchWords('a1 b2 c3 d4 e5 f6 g7 h8 i9 j0').length, 8);
    });

    test('works for other scripts, such as Urdu', () {
      expect(splitSearchWords('امتحان خوش'), ['امتحان', 'خوش']);
    });
  });

  group('matchRanges', () {
    test('finds every word, ignoring case', () {
      final r = matchRanges('I got Full marks in the EXAM', ['exam', 'full']);
      expect(r.map((e) => (e.start, e.end)).toList(), [(6, 10), (24, 28)]);
    });

    test('finds repeated matches and merges overlapping ones', () {
      expect(matchRanges('exam exam', ['exam']).length, 2);
      final merged = matchRanges('examination', ['exam', 'xamin']);
      expect(merged.length, 1);
      expect((merged.first.start, merged.first.end), (0, 6));
    });

    test('nothing to find gives an empty list', () {
      expect(matchRanges('hello', []), isEmpty);
      expect(matchRanges('', ['a']), isEmpty);
      expect(matchRanges('hello', ['zzz']), isEmpty);
    });
  });

  group('searchSnippet', () {
    test('returns the whole text when the match is near the start', () {
      const t = 'I am very happy because I got full marks.';
      expect(searchSnippet(t, ['happy']), t);
    });

    test('returns the whole text when there is no match', () {
      expect(searchSnippet('some text', ['zzz']), 'some text');
    });

    test('starts near a match that is far into the text', () {
      final t = '${'word ' * 40}the exam went well';
      final s = searchSnippet(t, ['exam']);
      expect(s.startsWith('…'), isTrue);
      expect(s.contains('exam'), isTrue);
      expect(s.length, lessThan(t.length));
      expect(matchRanges(s.substring(1), ['exam']), isNotEmpty);
    });
  });

  testWidgets('EntryTile marks the searched words in the entry text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EntryTile(
          row: const {
            'id': 1,
            'content': 'I am very happy because I got full marks in the exam.',
            'mood': 5,
            'created_at': '2026-11-02T08:00:00.000',
            'tags': 'Happy',
          },
          onSignedOut: () {},
          showDate: false,
          highlight: const ['exam'],
        ),
      ),
    ));

    final rich = tester.widgetList<RichText>(find.byType(RichText)).where(
          (w) => w.text.toPlainText().contains('full marks'),
        );
    expect(rich, isNotEmpty);

    var marked = false;
    rich.first.text.visitChildren((span) {
      if (span is TextSpan && span.text == 'exam' && span.style?.backgroundColor != null) {
        marked = true;
      }
      return true;
    });
    expect(marked, isTrue);
  });
}
