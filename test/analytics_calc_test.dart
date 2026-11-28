import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/insights/models/analytics_calc.dart';
import 'package:mindpal/features/insights/models/insights_calc.dart';

Map<String, Object?> row(String at, int mood, {String? tags, String? pattern}) =>
    {'created_at': at, 'mood': mood, 'thinking_pattern': pattern, 'tags': tags};

void main() {
  // 2026-11-20 is a Friday.
  final today = DateTime(2026, 11, 20);

  group('periods', () {
    test('periodStart counts today as day one', () {
      expect(periodStart(today, 7), DateTime(2026, 11, 14));
      expect(periodStart(today, 1), today);
      expect(periodStart(today, 0), isNull);
    });

    test('rowsBetween keeps valid rows inside the period, today included', () {
      final rows = [
        row('2026-11-13T23:59:00', 3), // before
        row('2026-11-14T00:00:00', 3), // first day
        row('2026-11-20T23:30:00', 4), // today, late
        row('2026-11-21T00:10:00', 5), // tomorrow
        row('garbage', 3),
        {'created_at': '2026-11-15T10:00:00', 'mood': 9},
      ];
      final r = rowsBetween(rows, since: periodStart(today, 7), until: today);
      expect(r.length, 2);
      expect(rowsBetween(rows).length, 4);
    });
  });

  group('distributions', () {
    test('moodDistribution counts each level', () {
      final d = moodDistribution([
        row('2026-11-15T10:00:00', 1),
        row('2026-11-15T11:00:00', 4),
        row('2026-11-16T11:00:00', 4),
        row('2026-11-17T11:00:00', 5),
      ]);
      expect(d, [1, 0, 0, 2, 1]);
    });

    test('tagCounts sorts by count then name and ignores unknown tags', () {
      final t = tagCounts([
        row('2026-11-15T10:00:00', 3, tags: 'Calm,Tired'),
        row('2026-11-16T10:00:00', 3, tags: 'Tired,Sad'),
        row('2026-11-17T10:00:00', 3, tags: 'Tired,Banana'),
        row('2026-11-18T10:00:00', 3),
      ]);
      expect(t.map((e) => '${e.key}:${e.value}').toList(), ['Tired:3', 'Calm:1', 'Sad:1']);
    });

    test('countKeys sorts most common first', () {
      final c = countKeys(['b', 'a', 'b', 'c', 'a', 'b']);
      expect(c.map((e) => '${e.key}:${e.value}').toList(), ['b:3', 'a:2', 'c:1']);
      expect(countKeys(const []), isEmpty);
    });
  });

  group('weekday and time of day', () {
    test('weekdayStats averages per weekday, Monday first', () {
      final s = weekdayStats([
        row('2026-11-16T09:00:00', 2), // Monday
        row('2026-11-23T09:00:00', 4), // Monday
        row('2026-11-20T09:00:00', 5), // Friday
      ]);
      expect(s.length, 7);
      expect(s[0].average, 3);
      expect(s[0].count, 2);
      expect(s[4].average, 5);
      expect(s[1].average, isNull);
      expect(s[1].count, 0);
    });

    test('dayPartOf boundaries', () {
      expect(dayPartOf(4), DayPart.night);
      expect(dayPartOf(5), DayPart.morning);
      expect(dayPartOf(11), DayPart.morning);
      expect(dayPartOf(12), DayPart.afternoon);
      expect(dayPartOf(16), DayPart.afternoon);
      expect(dayPartOf(17), DayPart.evening);
      expect(dayPartOf(20), DayPart.evening);
      expect(dayPartOf(21), DayPart.night);
      expect(dayPartOf(0), DayPart.night);
    });

    test('dayPartStats counts entries and averages mood in each part', () {
      final s = dayPartStats([
        row('2026-11-15T08:00:00', 2),
        row('2026-11-16T09:00:00', 4),
        row('2026-11-16T22:00:00', 5),
      ]);
      expect(s[0].count, 2);
      expect(s[0].average, 3);
      expect(s[1].count, 0);
      expect(s[3].count, 1);
    });
  });

  group('weeks and comparison', () {
    test('weeklyEntryCounts puts today in the last block', () {
      final c = weeklyEntryCounts([
        row('2026-11-20T09:00:00', 3), // today
        row('2026-11-14T09:00:00', 3), // 6 days ago, last block
        row('2026-11-13T09:00:00', 3), // 7 days ago, block before
        row('2026-09-01T09:00:00', 3), // too old
        row('2026-11-21T09:00:00', 3), // in the future
      ], today, 4);
      expect(c, [0, 0, 1, 2]);
    });

    test('comparePeriods compares with the period before', () {
      final rows = [
        row('2026-11-18T10:00:00', 4), // this week
        row('2026-11-19T10:00:00', 5),
        row('2026-11-10T10:00:00', 2), // the week before
        row('2026-11-11T10:00:00', 3),
      ];
      final c = comparePeriods(rows, today, 7);
      expect(c.current, 4.5);
      expect(c.previous, 2.5);
      expect(c.change, 2);
      final none = comparePeriods([row('2026-11-18T10:00:00', 4)], today, 7);
      expect(none.previous, isNull);
      expect(none.change, isNull);
    });
  });

  group('highlights', () {
    test('says nothing with fewer than three entries', () {
      expect(
        highlights(rows: [row('2026-11-18T10:00:00', 4), row('2026-11-19T10:00:00', 5)], today: today, days: 7),
        isEmpty,
      );
    });

    test('describes a higher average, a best weekday and the top feeling', () {
      final rows = [
        // week before: low
        row('2026-11-10T10:00:00', 2),
        row('2026-11-11T10:00:00', 2),
        row('2026-11-12T10:00:00', 2),
        // this week: Friday is high (twice), the rest lower
        row('2026-11-20T10:00:00', 5, tags: 'Happy'),
        row('2026-11-16T10:00:00', 3, tags: 'Happy'),
        row('2026-11-17T10:00:00', 3),
        row('2026-11-18T10:00:00', 3),
        row('2026-11-14T10:00:00', 3),
      ];
      final h = highlights(rows: rows, today: today, days: 7);
      expect(h.any((s) => s.contains('higher than the week before')), isTrue);
      expect(h.any((s) => s.contains('happy')), isTrue);
      expect(h.length, lessThanOrEqualTo(4));
    });

    test('a lower average is described kindly and with no scoring words', () {
      final rows = [
        row('2026-11-10T10:00:00', 5),
        row('2026-11-11T10:00:00', 5),
        row('2026-11-12T10:00:00', 5),
        row('2026-11-18T10:00:00', 2),
        row('2026-11-19T10:00:00', 2),
        row('2026-11-20T10:00:00', 2),
      ];
      final h = highlights(rows: rows, today: today, days: 7);
      expect(h.first, contains('lower than the week before'));
      expect(h.first, contains('normal'));
      for (final s in h) {
        expect(s.toLowerCase(), isNot(contains('fail')));
        expect(s.toLowerCase(), isNot(contains('bad')));
      }
    });

    test('all time has no comparison sentence', () {
      final rows = [
        for (var d = 1; d <= 6; d++) row('2026-11-1${d}T10:00:00', 3),
      ];
      final h = highlights(rows: rows, today: today, days: 0);
      expect(h.any((s) => s.contains('than')), isFalse);
    });
  });

  group('exercises', () {
    test('exercisesSince filters by date and keeps all for null', () {
      final all = [
        ExerciseDone('breathing', DateTime(2026, 11, 19)),
        ExerciseDone('grounding', DateTime(2026, 11, 1)),
      ];
      expect(exercisesSince(all, DateTime(2026, 11, 14)).length, 1);
      expect(exercisesSince(all, null).length, 2);
    });
  });

  group('gentle streak', () {
    Map<DateTime, DayMood> days(List<int> agoList) => dailyMoods([
          for (final a in agoList)
            row(DateTime(2026, 11, 20 - a, 10).toIso8601String(), 3),
        ]);

    test('no entries: nothing yet, and a kind message', () {
      final g = gentleStreak(const {}, today);
      expect(g.days, 0);
      expect(g.best, 0);
      expect(gentleStreakMessage(g), contains('no pressure'));
    });

    test('days in a row count, and today is noted', () {
      final g = gentleStreak(days([0, 1, 2]), today);
      expect(g.days, 3);
      expect(g.active, isTrue);
      expect(g.wroteToday, isTrue);
      expect(g.restDayUsed, isFalse);
      expect(gentleStreakMessage(g), contains('3 days of writing'));
    });

    test('one rest day does not break the run', () {
      final g = gentleStreak(days([0, 2, 3]), today);
      expect(g.days, 3);
      expect(g.restDayUsed, isTrue);
      expect(gentleStreakMessage(g), contains('rest day'));
    });

    test('two missed days end the run, but a new one starts', () {
      final g = gentleStreak(days([0, 3, 4, 5]), today);
      expect(g.days, 1);
      expect(g.best, 3);
    });

    test('yesterday still keeps it open, today is not a miss', () {
      final g = gentleStreak(days([1, 2]), today);
      expect(g.active, isTrue);
      expect(g.wroteToday, isFalse);
      expect(gentleStreakMessage(g), contains('Today is still open'));
    });

    test('a long break is a fresh start, never a failure', () {
      final g = gentleStreak(days([6, 7, 8]), today);
      expect(g.active, isFalse);
      expect(g.days, 0);
      expect(g.best, 3);
      final m = gentleStreakMessage(g).toLowerCase();
      expect(m, contains('welcome back'));
      expect(m, isNot(contains('lost')));
      expect(m, isNot(contains('broke')));
      expect(m, isNot(contains('fail')));
    });

    test('future dates are ignored and one entry counts as one day', () {
      final g = gentleStreak(days([-3, 0]), today);
      expect(g.days, 1);
      expect(gentleStreakMessage(g), contains('1 day of writing'));
    });
  });

  group('pattern tracker maths', () {
    final rows = [
      row('2026-11-20T10:00:00', 3, pattern: 'catastrophizing'),
      row('2026-11-18T10:00:00', 3, pattern: 'catastrophizing'),
      row('2026-11-05T10:00:00', 3, pattern: 'catastrophizing'),
      row('2026-11-19T10:00:00', 3, pattern: 'mind_reading'),
      row('2026-11-19T11:00:00', 3, pattern: ''),
      row('2026-11-19T12:00:00', 3),
      row('2026-01-02T10:00:00', 3, pattern: 'labeling'), // too old for 8 weeks
    ];

    test('weekly counts put each reflection in its 7-day block', () {
      final w = patternWeeklyCounts(rows, today, 8);
      expect(w['catastrophizing']!.length, 8);
      expect(w['catastrophizing']!.last, 2);
      expect(w['catastrophizing']![5], 1); // 15 days ago: block 2 weeks back
      expect(w['mind_reading']!.last, 1);
      expect(w.containsKey('labeling'), isFalse);
      expect(w.containsKey(''), isFalse);
    });

    test('last seen is the newest day', () {
      final l = patternLastSeen(rows);
      expect(l['catastrophizing'], DateTime(2026, 11, 20));
      expect(l['labeling'], DateTime(2026, 1, 2));
      expect(l.containsKey('batman'), isFalse);
    });

    test('agoText reads naturally', () {
      expect(agoText(today, today), 'today');
      expect(agoText(DateTime(2026, 11, 19), today), 'yesterday');
      expect(agoText(DateTime(2026, 11, 17), today), '3 days ago');
      expect(agoText(DateTime(2026, 11, 6), today), '2 weeks ago');
      expect(agoText(DateTime(2026, 8, 1), today), '3 months ago');
    });
  });
}
