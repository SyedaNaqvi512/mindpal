import '../../journal/models/thinking_patterns.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The average mood (1-5) of one day and how many entries it had.
class DayMood {
  const DayMood(this.day, this.average, this.count);

  final DateTime day;
  final double average;
  final int count;
}

/// 0-4: the position in the five mood colors and emojis for an average mood.
int moodIndex(double average) => average.round().clamp(1, 5) - 1;

/// Groups entries by calendar day. Rows need `created_at` (ISO text) and `mood` (int).
Map<DateTime, DayMood> dailyMoods(List<Map<String, Object?>> rows) {
  final moods = <DateTime, List<int>>{};
  for (final r in rows) {
    final t = DateTime.tryParse('${r['created_at']}');
    final m = r['mood'];
    if (t == null || m is! int) continue;
    moods.putIfAbsent(dateOnly(t), () => []).add(m);
  }
  return {
    for (final e in moods.entries)
      e.key: DayMood(
        e.key,
        e.value.reduce((a, b) => a + b) / e.value.length,
        e.value.length,
      ),
  };
}

/// One value per day for [days] days ending on [end] (oldest first).
/// null means no entry that day.
List<double?> dailySeries(Map<DateTime, DayMood> byDay, DateTime end, int days) {
  return [
    for (var i = 0; i < days; i++)
      byDay[DateTime(end.year, end.month, end.day - (days - 1) + i)]?.average,
  ];
}

/// Average over the days that have a value, or null when there are none.
double? seriesAverage(List<double?> values) {
  final present = values.whereType<double>().toList();
  if (present.isEmpty) return null;
  return present.reduce((a, b) => a + b) / present.length;
}

/// Thinking patterns from reflections, most common first (FR-29).
/// Rows need `created_at` and `thinking_pattern`. [since] limits the period.
List<MapEntry<String, int>> patternCounts(
  List<Map<String, Object?>> rows, {
  DateTime? since,
}) {
  final counts = <String, int>{};
  for (final r in rows) {
    final p = r['thinking_pattern'];
    if (p is! String || !ThinkingPatterns.names.containsKey(p)) continue;
    if (since != null) {
      final t = DateTime.tryParse('${r['created_at']}');
      if (t == null || t.isBefore(since)) continue;
    }
    counts[p] = (counts[p] ?? 0) + 1;
  }
  final list = counts.entries.toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return list;
}

/// Cells of a month grid, Monday first: null for the empty cells before day 1.
List<DateTime?> monthGrid(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final days = DateTime(month.year, month.month + 1, 0).day;
  return [
    ...List<DateTime?>.filled(first.weekday - 1, null),
    for (var d = 1; d <= days; d++) DateTime(month.year, month.month, d),
  ];
}

/// How many days in a row, ending today, have at least one entry.
/// If today has no entry yet, a streak that ended yesterday still counts.
int currentStreak(Map<DateTime, DayMood> byDay, DateTime today) {
  var day = dateOnly(today);
  if (!byDay.containsKey(day)) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  var count = 0;
  while (byDay.containsKey(day)) {
    count++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return count;
}

/// The last seven days ending on [today], for the Home "your week" card.
class WeekSummary {
  const WeekSummary({
    required this.days,
    required this.entries,
    required this.average,
    required this.daysWritten,
  });

  /// Average mood per day, oldest first (7 values, null = no entry).
  final List<double?> days;
  final int entries;
  final double? average;
  final int daysWritten;
}

WeekSummary weekSummary(Map<DateTime, DayMood> byDay, DateTime today) {
  final series = dailySeries(byDay, dateOnly(today), 7);
  var entries = 0;
  for (var i = 0; i < 7; i++) {
    entries += byDay[DateTime(today.year, today.month, today.day - 6 + i)]?.count ?? 0;
  }
  return WeekSummary(
    days: series,
    entries: entries,
    average: seriesAverage(series),
    daysWritten: series.whereType<double>().length,
  );
}
