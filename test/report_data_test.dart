import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/exercises/models/exercise_catalog.dart';
import 'package:mindpal/features/insights/models/analytics_calc.dart';
import 'package:mindpal/features/insights/models/pdf_fonts.dart';
import 'package:mindpal/features/insights/models/report_data.dart';

import 'simple_pdf_test.dart' show expectWellFormed;

Map<String, Object?> row(String at, int mood, {String? tags, String? pattern}) =>
    {'created_at': at, 'mood': mood, 'thinking_pattern': pattern, 'tags': tags};

void main() {
  final today = DateTime(2026, 11, 20);
  final rows = [
    for (var i = 0; i < 12; i++)
      row(DateTime(2026, 11, 20 - i, 9 + i % 10).toIso8601String(), 1 + i % 5,
          tags: i.isEven ? 'Calm,Tired' : 'Stressed',
          pattern: i % 3 == 0 ? 'catastrophizing' : null),
  ];
  final done = [
    ExerciseDone(kExercises.first.id, DateTime(2026, 11, 19)),
    ExerciseDone(kExercises.first.id, DateTime(2026, 11, 18)),
  ];

  test('report data holds counts and names, and nothing else', () {
    final d = buildReportData(rows: rows, exercises: done, today: today, days: 30);
    expect(d.periodLabel, 'Last 30 days');
    expect(d.entries, 12);
    expect(d.daysWritten, 12);
    expect(d.averageMood, isNotNull);
    expect(d.moodCounts.length, 5);
    expect(d.moodCounts.reduce((a, b) => a + b), 12);
    expect(d.weekdayAverages.length, 7);
    expect(d.dayPartCounts.length, 4);
    expect(d.feelings.length, 3);
    expect(d.feelings.first.key, 'Calm'); // a three-way tie sorts by name
    expect(d.feelings.first.value, 6);
    expect(d.patterns.first.key, 'Catastrophizing');
    expect(d.exercises.single.value, 2);
    expect(d.exercises.single.key, kExercises.first.title);
    expect(d.gentleDays, greaterThan(0));
  });

  test('the period limits the data', () {
    final week = buildReportData(rows: rows, exercises: done, today: today, days: 7);
    expect(week.entries, 7);
    final all = buildReportData(rows: rows, exercises: done, today: today, days: 0);
    expect(all.periodLabel, 'All time');
    expect(all.entries, 12);
  });

  test('the file name uses the date', () {
    expect(reportFileName(DateTime(2026, 11, 5)), 'MindPal-summary-2026-11-05.pdf');
    expect(longDate(DateTime(2026, 11, 5)), '5 November 2026');
  });

  test('the PDF is well formed, says it is not therapy and holds no journal text', () {
    final d = buildReportData(rows: rows, exercises: done, today: today, days: 30);
    final s = latin1.decode(renderReportPdf(d));
    expectWellFormed(s);
    expect(s, contains('MindPal summary'));
    expect(s, contains('not therapy'));
    expect(s, contains('Average mood by day of the week'));
    expect(s, contains('Catastrophizing'));
    expect(s, isNot(contains('thinking_pattern')));
  });

  test('an empty period gives a short, valid PDF', () {
    final d = buildReportData(rows: const [], exercises: const [], today: today, days: 7);
    expect(d.entries, 0);
    expect(d.averageMood, isNull);
    final s = latin1.decode(renderReportPdf(d));
    expectWellFormed(s, pages: 1);
    expect(s, contains('no entries in this period yet'));
  });

  test('a lot of data still makes a valid multi-page file', () {
    final many = [
      for (var i = 0; i < 400; i++)
        row(DateTime(2026, 11, 20).subtract(Duration(days: i % 120, hours: -(9 + i % 9))).toIso8601String(),
            1 + i % 5,
            tags: 'Calm,Happy,Tired,Stressed,Sad,Anxious,Hopeful,Lonely,Proud',
            pattern: ['catastrophizing', 'mind_reading', 'labeling', 'mental_filter'][i % 4]),
    ];
    final d = buildReportData(rows: many, exercises: done, today: today, days: 0);
    expectWellFormed(latin1.decode(renderReportPdf(d)));
  });

  test('with the embedded fonts the summary is still valid and keeps its text', () {
    final fonts = PdfFontSet(
      body: PdfEmbeddedFont(
          kNunitoRegularMetrics, File('assets/fonts/Nunito-Regular.ttf').readAsBytesSync()),
      bold: PdfEmbeddedFont(
          kNunitoBoldMetrics, File('assets/fonts/Nunito-Bold.ttf').readAsBytesSync()),
      display: PdfEmbeddedFont(
          kFrauncesBoldMetrics, File('assets/fonts/Fraunces-Bold.ttf').readAsBytesSync()),
    );
    final d = buildReportData(rows: rows, exercises: done, today: today, days: 30);
    final s = latin1.decode(renderReportPdf(d, fonts: fonts));
    expectWellFormed(s);
    expect(s, contains('/ShadingType 2'));
    expect(s, contains('(MindPal summary) Tj'));
    expect(s, contains('/FontFile2'));
    expect(s, contains('not therapy'));
    expect(s, contains('Catastrophizing'));
  });
}
