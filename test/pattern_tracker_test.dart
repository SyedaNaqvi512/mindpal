import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/core/theme/app_palette.dart';
import 'package:mindpal/core/theme/app_theme.dart';
import 'package:mindpal/features/insights/models/pattern_guide.dart';
import 'package:mindpal/features/insights/screens/pattern_tracker_screen.dart';
import 'package:mindpal/features/journal/models/thinking_patterns.dart';

void main() {
  final today = DateTime(2026, 11, 20);
  final rows = [
    for (var i = 0; i < 20; i++)
      {
        'created_at': DateTime(2026, 11, 20 - i, 10).toIso8601String(),
        'mood': 1 + i % 5,
        'thinking_pattern': i % 2 == 0 ? 'catastrophizing' : (i % 5 == 0 ? 'labeling' : null),
        'tags': null,
      },
  ];

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  test('every thinking pattern has a plain-language guide', () {
    for (final id in ThinkingPatterns.names.keys) {
      final g = kPatternGuides[id];
      expect(g, isNotNull, reason: id);
      expect(g!.means, isNotEmpty);
      expect(g.example, isNotEmpty);
      expect(g.gentler, isNotEmpty);
    }
    expect(kPatternGuides.length, ThinkingPatterns.names.length);
  });

  test('the guides never diagnose or promise', () {
    const banned = ['disorder', 'diagnos', 'illness', 'cure', 'guarantee', 'clinical', 'symptom'];
    for (final g in kPatternGuides.values) {
      final t = '${g.means} ${g.example} ${g.gentler}'.toLowerCase();
      for (final w in banned) {
        expect(t.contains(w), isFalse, reason: w);
      }
    }
  });

  for (final p in AppPalette.all) {
    testWidgets('${p.name}: lists all nine patterns, most common first, and expands',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(p),
        home: Scaffold(body: PatternTrackerView(rows: rows, today: today)),
      ));
      await tester.pumpAndSettle();
      for (final name in ThinkingPatterns.names.values) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.textContaining('not diagnoses'), findsOneWidget);
      // Catastrophizing is named most, so it is listed first.
      final first = tester.getTopLeft(find.text('Catastrophizing')).dy;
      final other = tester.getTopLeft(find.text('Mind reading')).dy;
      expect(first, lessThan(other));

      await tester.tap(find.text('Catastrophizing'));
      await tester.pumpAndSettle();
      expect(find.text(kPatternGuides['catastrophizing']!.means), findsOneWidget);
      expect(find.text('A gentler way to look at it'), findsOneWidget);
      expect(find.textContaining('An exercise to try'), findsOneWidget);

      for (final label in ['30 days', 'All', '90 days']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('with no rows it shows an invitation, not an empty chart', (tester) async {
    tall(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppPalette.lavenderDream),
      home: Scaffold(body: PatternTrackerView(rows: const [], today: today)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to show yet'), findsOneWidget);
    expect(find.text('Catastrophizing'), findsNothing);
  });

  testWidgets('a period with no patterns says so', (tester) async {
    tall(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(AppPalette.lavenderDream),
      home: Scaffold(
        body: PatternTrackerView(
          rows: [
            {'created_at': DateTime(2026, 11, 19).toIso8601String(), 'mood': 3, 'thinking_pattern': null, 'tags': null},
          ],
          today: today,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No patterns were named in this period.'), findsOneWidget);
    expect(find.text('Not named yet'), findsNothing); // shown inside the subtitle text
    expect(find.textContaining('None in this period'), findsNWidgets(9));
  });
}
