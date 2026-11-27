import '../../journal/models/mood.dart';
import 'insights_calc.dart';

/// Pure calculations for the Insights charts (Part 8). Everything works on the
/// small rows from `DatabaseService.getInsightRows`: `created_at` (ISO text),
/// `mood` (1-5), `thinking_pattern` and `tags` (comma separated). No journal
/// text is read and nothing leaves the phone.

DateTime? _when(Map<String, Object?> r) {
  final t = DateTime.tryParse('${r['created_at']}');
  if (t == null) return null;
  return t.isUtc ? t.toLocal() : t;
}

int? _mood(Map<String, Object?> r) {
  final m = r['mood'];
  return m is int && m >= 1 && m <= 5 ? m : null;
}

/// The first day of a period of [days] days that ends on [today], or null for
/// all time ([days] is 0).
DateTime? periodStart(DateTime today, int days) =>
    days <= 0 ? null : DateTime(today.year, today.month, today.day - (days - 1));

/// Rows with a valid date and mood, from [since] (inclusive) up to and
/// including [until]'s day. Null limits mean no limit.
List<Map<String, Object?>> rowsBetween(
  List<Map<String, Object?>> rows, {
  DateTime? since,
  DateTime? until,
}) {
  final end = until == null ? null : DateTime(until.year, until.month, until.day + 1);
  return [
    for (final r in rows)
      if (_mood(r) != null && _when(r) != null)
        if ((since == null || !_when(r)!.isBefore(since)) &&
            (end == null || _when(r)!.isBefore(end)))
          r,
  ];
}

/// How many entries had each mood: five numbers, Very low to Very good.
List<int> moodDistribution(List<Map<String, Object?>> rows) {
  final counts = List<int>.filled(5, 0);
  for (final r in rows) {
    final m = _mood(r);
    if (m != null) counts[m - 1]++;
  }
  return counts;
}

/// Feeling tags of one row.
List<String> _tags(Map<String, Object?> r) => FeelingTags.parse(r['tags'])
    .where((t) => FeelingTags.all.contains(t))
    .toList();

/// How often each feeling tag was used, most common first.
List<MapEntry<String, int>> tagCounts(List<Map<String, Object?>> rows) {
  final counts = <String, int>{};
  for (final r in rows) {
    for (final t in _tags(r)) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
  }
  return _sorted(counts);
}

List<MapEntry<String, int>> _sorted(Map<String, int> counts) {
  final list = counts.entries.toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return list;
}

/// Counts a list of keys, most common first.
List<MapEntry<String, int>> countKeys(Iterable<String> keys) {
  final counts = <String, int>{};
  for (final k in keys) {
    counts[k] = (counts[k] ?? 0) + 1;
  }
  return _sorted(counts);
}

/// An average and the number of entries behind it.
class GroupStat {
  const GroupStat(this.average, this.count);

  /// Average mood 1-5, or null when [count] is 0.
  final double? average;
  final int count;
}

GroupStat _stat(List<int> moods) => moods.isEmpty
    ? const GroupStat(null, 0)
    : GroupStat(moods.reduce((a, b) => a + b) / moods.length, moods.length);

/// Average mood of the entries written on each weekday, Monday first (7 items).
List<GroupStat> weekdayStats(List<Map<String, Object?>> rows) {
  final groups = List.generate(7, (_) => <int>[]);
  for (final r in rows) {
    final t = _when(r);
    final m = _mood(r);
    if (t == null || m == null) continue;
    groups[t.weekday - 1].add(m);
  }
  return [for (final g in groups) _stat(g)];
}

/// Parts of the day.
enum DayPart { morning, afternoon, evening, night }

extension DayPartText on DayPart {
  String get label => switch (this) {
        DayPart.morning => 'Morning',
        DayPart.afternoon => 'Afternoon',
        DayPart.evening => 'Evening',
        DayPart.night => 'Night',
      };

  /// Hours, for the small caption under the label.
  String get hours => switch (this) {
        DayPart.morning => '5-11',
        DayPart.afternoon => '12-16',
        DayPart.evening => '17-20',
        DayPart.night => '21-4',
      };
}

DayPart dayPartOf(int hour) {
  if (hour >= 5 && hour <= 11) return DayPart.morning;
  if (hour >= 12 && hour <= 16) return DayPart.afternoon;
  if (hour >= 17 && hour <= 20) return DayPart.evening;
  return DayPart.night;
}

/// Entries and average mood for each part of the day (4 items, in order).
List<GroupStat> dayPartStats(List<Map<String, Object?>> rows) {
  final groups = {for (final p in DayPart.values) p: <int>[]};
  for (final r in rows) {
    final t = _when(r);
    final m = _mood(r);
    if (t == null || m == null) continue;
    groups[dayPartOf(t.hour)]!.add(m);
  }
  return [for (final p in DayPart.values) _stat(groups[p]!)];
}

/// Entries in each 7-day block, the last block ending on [today] (oldest first).
List<int> weeklyEntryCounts(List<Map<String, Object?>> rows, DateTime today, int weeks) {
  final end = dateOnly(today);
  final counts = List<int>.filled(weeks, 0);
  for (final r in rows) {
    final t = _when(r);
    if (t == null) continue;
    final age = end.difference(dateOnly(t)).inDays;
    if (age < 0 || age >= weeks * 7) continue;
    counts[weeks - 1 - age ~/ 7]++;
  }
  return counts;
}

/// The average mood of a period next to the period before it.
class PeriodComparison {
  const PeriodComparison(this.current, this.previous);

  final double? current;
  final double? previous;

  /// Current minus previous, or null when either period has no entries.
  double? get change =>
      current == null || previous == null ? null : current! - previous!;
}

/// Compares the last [days] days with the [days] days before them.
PeriodComparison comparePeriods(
  List<Map<String, Object?>> rows,
  DateTime today,
  int days,
) {
  final t = dateOnly(today);
  final curStart = DateTime(t.year, t.month, t.day - (days - 1));
  final prevStart = DateTime(t.year, t.month, t.day - (2 * days - 1));
  final prevEnd = DateTime(t.year, t.month, t.day - days);
  double? avg(List<Map<String, Object?>> r) {
    final moods = [for (final x in r) _mood(x)!];
    return moods.isEmpty ? null : moods.reduce((a, b) => a + b) / moods.length;
  }

  return PeriodComparison(
    avg(rowsBetween(rows, since: curStart, until: t)),
    avg(rowsBetween(rows, since: prevStart, until: prevEnd)),
  );
}

const _weekdayNames = [
  'Mondays', 'Tuesdays', 'Wednesdays', 'Thursdays', 'Fridays', 'Saturdays', 'Sundays',
];

/// Short, kind sentences about the period. They describe what was written and
/// never judge it, and they need enough entries to say anything (no guessing
/// from one or two entries).
List<String> highlights({
  required List<Map<String, Object?>> rows,
  required DateTime today,
  required int days,
}) {
  final out = <String>[];
  final inPeriod = rowsBetween(rows, since: periodStart(today, days), until: today);
  if (inPeriod.length < 3) return out;

  if (days > 0) {
    final cmp = comparePeriods(rows, today, days);
    final d = cmp.change;
    if (d != null) {
      final label = days == 7 ? 'the week before' : 'the $days days before';
      if (d.abs() < 0.15) {
        out.add('Your average mood is about the same as $label.');
      } else if (d > 0) {
        out.add('Your average mood is ${d.toStringAsFixed(1)} higher than $label.');
      } else {
        out.add('Your average mood is ${(-d).toStringAsFixed(1)} lower than $label. '
            'Ups and downs are normal.');
      }
    }
  }

  final wd = weekdayStats(inPeriod);
  var best = -1;
  for (var i = 0; i < 7; i++) {
    final a = wd[i].average;
    if (a == null || wd[i].count < 2) continue;
    if (best == -1 || a > wd[best].average!) best = i;
  }
  if (best != -1) {
    final others = [
      for (var i = 0; i < 7; i++)
        if (i != best && wd[i].average != null) wd[i].average!,
    ];
    final bestAvg = wd[best].average!;
    if (others.isNotEmpty && bestAvg - others.reduce((a, b) => a + b) / others.length >= 0.3) {
      out.add('Your mood tends to be highest on ${_weekdayNames[best]}.');
    }
  }

  final parts = dayPartStats(inPeriod);
  var busy = -1;
  var tie = false;
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].count == 0) continue;
    if (busy == -1 || parts[i].count > parts[busy].count) {
      busy = i;
      tie = false;
    } else if (parts[i].count == parts[busy].count) {
      tie = true;
    }
  }
  if (busy != -1 && !tie && parts[busy].count >= 3) {
    out.add('You write most in the ${DayPart.values[busy].label.toLowerCase()}.');
  }

  final tags = tagCounts(inPeriod);
  if (tags.isNotEmpty && tags.first.value >= 2) {
    out.add('The feeling you chose most is ${tags.first.key.toLowerCase()} '
        '(${tags.first.value} ${tags.first.value == 1 ? 'time' : 'times'}).');
  }
  return out.take(4).toList();
}

/// A finished exercise: which one and when (no answers are read for Insights).
class ExerciseDone {
  const ExerciseDone(this.id, this.at);

  final String id;
  final DateTime at;
}

/// Finished exercises from [since] (inclusive) on; null means all time.
List<ExerciseDone> exercisesSince(List<ExerciseDone> all, DateTime? since) => [
      for (final e in all)
        if (since == null || !e.at.isBefore(since)) e,
    ];
