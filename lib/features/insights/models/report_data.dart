import 'dart:typed_data';

import '../../exercises/models/exercise_catalog.dart';
import '../../journal/models/mood.dart';
import '../../journal/models/thinking_patterns.dart';
import 'analytics_calc.dart';
import 'insights_calc.dart';
import 'pdf_fonts.dart';
import 'simple_pdf.dart';

/// Everything the PDF summary says, worked out from the Insights rows. It
/// holds counts only: no journal text, no reflection text, no exercise
/// answers. It is shared only when the person chooses to share it.
class ReportData {
  const ReportData({
    required this.periodLabel,
    required this.generatedOn,
    required this.entries,
    required this.daysWritten,
    required this.averageMood,
    required this.moodCounts,
    required this.weekdayAverages,
    required this.dayPartCounts,
    required this.feelings,
    required this.patterns,
    required this.exercises,
    required this.gentleDays,
    required this.bestRun,
    required this.notes,
  });

  final String periodLabel;
  final DateTime generatedOn;
  final int entries;
  final int daysWritten;
  final double? averageMood;

  /// Entries per mood level, Very low to Very good.
  final List<int> moodCounts;

  /// Monday first; null when nothing was written that weekday.
  final List<double?> weekdayAverages;

  /// Morning, afternoon, evening, night.
  final List<int> dayPartCounts;

  final List<MapEntry<String, int>> feelings;

  /// Pattern names (not ids) with counts.
  final List<MapEntry<String, int>> patterns;

  /// Exercise titles with counts.
  final List<MapEntry<String, int>> exercises;
  final int gentleDays;
  final int bestRun;
  final List<String> notes;

  int get exerciseTotal => exercises.fold<int>(0, (a, e) => a + e.value);
}

/// [days] is 7, 30, 90 or 0 (all time).
ReportData buildReportData({
  required List<Map<String, Object?>> rows,
  required List<ExerciseDone> exercises,
  required DateTime today,
  required int days,
}) {
  final t = dateOnly(today);
  final since = periodStart(t, days);
  final inPeriod = rowsBetween(rows, since: since, until: t);
  final byDay = dailyMoods(inPeriod);
  final moods = [
    for (final r in inPeriod)
      if (r['mood'] is int) r['mood'] as int,
  ];

  String exTitle(String id) => exerciseById(id)?.title ?? id;
  final ex = countKeys([for (final e in exercisesSince(exercises, since)) exTitle(e.id)]);
  final streak = gentleStreak(dailyMoods(rows), t);

  return ReportData(
    periodLabel: days == 0 ? 'All time' : 'Last $days days',
    generatedOn: t,
    entries: inPeriod.length,
    daysWritten: byDay.length,
    averageMood: moods.isEmpty ? null : moods.reduce((a, b) => a + b) / moods.length,
    moodCounts: moodDistribution(inPeriod),
    weekdayAverages: [for (final s in weekdayStats(inPeriod)) s.average],
    dayPartCounts: [for (final s in dayPartStats(inPeriod)) s.count],
    feelings: tagCounts(inPeriod).take(8).toList(),
    patterns: [
      for (final e in patternCounts(inPeriod))
        MapEntry(ThinkingPatterns.names[e.key] ?? e.key, e.value),
    ],
    exercises: ex,
    gentleDays: streak.days,
    bestRun: streak.best,
    notes: highlights(rows: rows, today: t, days: days),
  );
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December',
];

String longDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// The file name for a report, for example `MindPal-summary-2026-11-27.pdf`.
String reportFileName(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'MindPal-summary-${d.year}-${two(d.month)}-${two(d.day)}.pdf';
}

const _moodColors = [
  PdfRgb(120, 144, 200),
  PdfRgb(140, 170, 190),
  PdfRgb(190, 180, 120),
  PdfRgb(150, 190, 140),
  PdfRgb(100, 180, 120),
];

/// Draws [d] as a PDF. English only for now (the built-in PDF font).
Uint8List renderReportPdf(ReportData d, {PdfFontSet? fonts}) {
  final pdf = SimplePdf(title: 'MindPal summary', fonts: fonts);
  pdf.brandHeader('MindPal summary', '${d.periodLabel}  -  made on ${longDate(d.generatedOn)}');
  pdf.paragraph(
      'A summary of your own mood entries. It contains counts only: no journal '
      'text, no reflections and no exercise answers. It is a self-help summary, '
      'not therapy and not a diagnosis.',
      size: 10,
      color: kPdfMuted);
  pdf.rule();

  pdf.heading('At a glance');
  pdf.bullet('Entries: ${d.entries}');
  pdf.bullet('Days with an entry: ${d.daysWritten}');
  pdf.bullet(d.averageMood == null
      ? 'Average mood: no entries in this period'
      : 'Average mood: ${d.averageMood!.toStringAsFixed(1)} out of 5 '
          '(${Mood.all[moodIndex(d.averageMood!)].label})');
  pdf.bullet('Current run of writing days: ${d.gentleDays} (one rest day does not '
      'break it). Longest run: ${d.bestRun}.');

  if (d.notes.isNotEmpty) {
    pdf.heading('What stands out');
    for (final n in d.notes) {
      pdf.bullet(n);
    }
  }

  if (d.entries == 0) {
    pdf.space(8);
    pdf.paragraph('There are no entries in this period yet.', color: kPdfMuted);
    return pdf.build();
  }

  pdf.heading('How your moods were spread');
  final topMood = d.moodCounts.fold<int>(1, (a, b) => b > a ? b : a);
  for (var i = 0; i < 5; i++) {
    final pct = (d.moodCounts[i] * 100 / d.entries).round();
    pdf.barRow(Mood.all[i].label, d.moodCounts[i] / topMood,
        '${d.moodCounts[i]} ($pct%)',
        color: _moodColors[i]);
  }

  pdf.heading('Average mood by day of the week');
  const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  for (var i = 0; i < 7; i++) {
    final a = d.weekdayAverages[i];
    pdf.barRow(names[i], a == null ? 0 : a / 5,
        a == null ? 'no entries' : a.toStringAsFixed(1));
  }

  pdf.heading('When you write');
  final topPart = d.dayPartCounts.fold<int>(1, (a, b) => b > a ? b : a);
  for (var i = 0; i < DayPart.values.length; i++) {
    pdf.barRow('${DayPart.values[i].label} (${DayPart.values[i].hours})',
        d.dayPartCounts[i] / topPart, '${d.dayPartCounts[i]}');
  }

  void listSection(String title, List<MapEntry<String, int>> items, String empty) {
    pdf.heading(title);
    if (items.isEmpty) {
      pdf.paragraph(empty, color: kPdfMuted);
      return;
    }
    final top = items.first.value;
    for (final e in items) {
      pdf.barRow(e.key, e.value / top, '${e.value}');
    }
  }

  listSection('Feelings you chose', d.feelings, 'No feelings were chosen in this period.');
  listSection('Exercises you finished', d.exercises, 'No exercises were finished in this period.');
  listSection('Thinking patterns named in reflections', d.patterns,
      'No patterns were named in this period.');
  if (d.patterns.isNotEmpty) {
    pdf.paragraph('Patterns are suggestions found in your reflections, not diagnoses.',
        size: 9.5, color: kPdfMuted);
  }

  return pdf.build();
}
