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
