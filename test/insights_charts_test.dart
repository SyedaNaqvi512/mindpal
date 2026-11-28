import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/core/motion/motion.dart';
import 'package:mindpal/core/theme/app_palette.dart';
import 'package:mindpal/core/theme/app_theme.dart';
import 'package:mindpal/features/exercises/models/exercise_catalog.dart';
import 'package:mindpal/features/insights/models/analytics_calc.dart';
import 'package:mindpal/features/insights/screens/insights_view.dart';
import 'package:mindpal/features/insights/widgets/bar_chart_view.dart';
import 'package:mindpal/features/insights/widgets/donut_chart.dart';
import 'package:mindpal/features/insights/widgets/mood_trend_chart.dart';

Widget host(Widget child, {AppPalette? palette}) => MaterialApp(
      theme: AppTheme.build(palette ?? AppPalette.lavenderDream),
      home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child))),
    );

void main() {
  tearDown(() => reduceMotionSetting.value = false);

  group('DonutChart', () {
    const slices = [
      DonutSlice('Low', 2, Colors.red),
      DonutSlice('Good', 4, Colors.green),
      DonutSlice('Empty', 0, Colors.blue),
    ];

    testWidgets('shows a legend with counts and percentages and settles', (tester) async {
      await tester.pumpWidget(host(const DonutChart(
        slices: slices,
        centerValue: '6',
        centerLabel: 'entries',
        summary: 'Test donut',
      )));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Low 2 · 33%'), findsOneWidget);
      expect(find.text('Good 4 · 67%'), findsOneWidget);
      expect(find.textContaining('Empty'), findsNothing); // zero slices are left out
      expect(find.text('6'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a legend entry shows it in the middle, tapping again clears it',
        (tester) async {
      await tester.pumpWidget(host(const DonutChart(
        slices: slices,
        centerValue: '6',
        centerLabel: 'entries',
        summary: 'Test donut',
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Good 4 · 67%'));
      await tester.pump();
      expect(find.text('67%'), findsOneWidget);
      expect(find.text('Good (4)'), findsOneWidget);
      await tester.tap(find.text('Good 4 · 67%'));
      await tester.pump();
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('Reduce motion shows the finished ring and a single slice works',
        (tester) async {
      reduceMotionSetting.value = true;
      await tester.pumpWidget(host(const DonutChart(
        slices: [DonutSlice('Calm', 3, Colors.teal)],
        centerValue: '3',
        centerLabel: 'feelings',
        summary: 'One slice',
      )));
      expect(find.text('Calm 3 · 100%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('BarChartView', () {
    final bars = [
      const ChartBar(label: 'Mon', value: 4, color: Colors.green, tooltip: 'Monday · Good'),
      const ChartBar(label: 'Tue', value: null, color: Colors.grey, tooltip: 'Tuesday · none'),
      const ChartBar(label: 'Wed', value: 2, color: Colors.orange, tooltip: 'Wednesday · Low'),
    ];

    testWidgets('draws, takes taps and settles', (tester) async {
      await tester.pumpWidget(host(BarChartView(bars: bars, maxValue: 5, ticks: const [1, 3, 5], summary: 'Bars')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(BarChartView)));
      await tester.pump();
      await tester.tapAt(tester.getTopLeft(find.byType(BarChartView)) + const Offset(2, 40));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles no bars, all empty bars and an average line', (tester) async {
      await tester.pumpWidget(host(Column(children: [
        const BarChartView(bars: [], summary: 'none'),
        BarChartView(
          bars: [for (final l in ['A', 'B', 'C', 'D']) ChartBar(label: l, value: 0, color: Colors.blue)],
          summary: 'zeros',
        ),
        BarChartView(bars: bars, maxValue: 5, averageLine: 3, summary: 'avg'),
      ])));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reduce motion shows finished bars at once', (tester) async {
      reduceMotionSetting.value = true;
      await tester.pumpWidget(host(BarChartView(bars: bars, summary: 'Bars')));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('trend chart draws the average line and the area fill', (tester) async {
    await tester.pumpWidget(host(MoodTrendChart(
      values: const [3, 4, null, 2, 5, 5, 4],
      labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      average: 3.8,
      summary: 'Trend',
    )));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byType(MoodTrendChart)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  group('InsightsView', () {
    final today = DateTime(2026, 11, 20);

    List<Map<String, Object?>> sample({bool tags = true}) => [
          for (var i = 0; i < 40; i++)
            {
              'created_at': today.subtract(Duration(days: i)).add(Duration(hours: 6 + (i * 5) % 17)).toIso8601String(),
              'mood': 1 + (i * 3) % 5,
              'thinking_pattern': i % 4 == 0 ? 'catastrophizing' : (i % 7 == 0 ? 'mind_reading' : null),
              'tags': tags ? (i % 2 == 0 ? 'Calm,Tired' : 'Stressed') : null,
            },
        ];

    final exercises = [
      ExerciseDone(kExercises.first.id, today),
      ExerciseDone(kExercises.first.id, today.subtract(const Duration(days: 2))),
      ExerciseDone(kExercises.last.id, today.subtract(const Duration(days: 20))),
    ];

    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 9000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    for (final p in AppPalette.all) {
      testWidgets('${p.name}: every chart builds, periods switch and the page settles',
          (tester) async {
        tall(tester);
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.build(p),
          home: Scaffold(
            body: InsightsView(
              rows: sample(),
              exercises: exercises,
              today: today,
              onDayTap: (_) {},
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Mood over time'), findsOneWidget);
        expect(find.text('How your moods were spread'), findsOneWidget);
        expect(find.text('Mood by day of the week'), findsOneWidget);
        expect(find.text('When you write'), findsOneWidget);
        expect(find.text('Feelings you chose'), findsOneWidget);
        expect(find.text('Writing each week'), findsOneWidget);
        expect(find.text('Exercises you finished'), findsOneWidget);
        expect(find.text('Most common thinking patterns'), findsOneWidget);
        expect(find.text('Mood calendar'), findsOneWidget);
        expect(find.byType(DonutChart), findsNWidgets(4));
        expect(tester.takeException(), isNull);

        for (final label in ['30 days', '90 days', 'All', '7 days']) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('empty parts show a helpful sentence instead of a chart', (tester) async {
      tall(tester);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(AppPalette.lavenderDream),
        home: Scaffold(
          body: InsightsView(
            rows: [
              {
                'created_at': today.toIso8601String(),
                'mood': 4,
                'thinking_pattern': null,
                'tags': null,
              },
            ],
            exercises: const [],
            today: today,
            onDayTap: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pick feelings'), findsOneWidget);
      expect(find.textContaining('Finish an exercise'), findsOneWidget);
      expect(find.textContaining('No patterns in this period'), findsOneWidget);
      expect(find.text('What stands out'), findsNothing); // one entry is not enough
      expect(tester.takeException(), isNull);
    });

    testWidgets('the share card appears only when export is wired and reports the period',
        (tester) async {
      tall(tester);
      var asked = -1;
      Widget page({required bool wired}) => MaterialApp(
            theme: AppTheme.build(AppPalette.skyMist),
            home: Scaffold(
              body: InsightsView(
                rows: sample(),
                exercises: exercises,
                today: today,
                onDayTap: (_) {},
                onExport: wired ? (d) => asked = d : null,
              ),
            ),
          );
      await tester.pumpWidget(page(wired: false));
      await tester.pumpAndSettle();
      expect(find.text('Share a summary'), findsNothing);

      await tester.pumpWidget(page(wired: true));
      await tester.pumpAndSettle();
      expect(find.text('Share a summary'), findsOneWidget);
      await tester.tap(find.text('30 days'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create PDF summary'));
      await tester.pump();
      expect(asked, 30);
    });

    testWidgets('the gentle streak shows in the stats row', (tester) async {
      tall(tester);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(AppPalette.lavenderDream),
        home: Scaffold(
          body: InsightsView(rows: sample(), exercises: exercises, today: today, onDayTap: (_) {}),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Days of writing'), findsOneWidget);
      expect(find.textContaining('Day streak'), findsNothing);
    });

    testWidgets('Reduce motion builds the whole page with no animation left', (tester) async {
      reduceMotionSetting.value = true;
      tall(tester);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(AppPalette.midnightLavender),
        home: Scaffold(
          body: InsightsView(rows: sample(), exercises: exercises, today: today, onDayTap: (_) {}),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
