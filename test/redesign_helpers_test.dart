import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/insights/models/insights_calc.dart';
import 'package:mindpal/features/journal/models/entry_format.dart';
import 'package:mindpal/features/journal/models/mood.dart';

Map<String, Object?> row(String at, int mood) =>
    {'created_at': at, 'mood': mood, 'thinking_pattern': null};

void main() {
  group('currentStreak', () {
    final byDay = dailyMoods([
      row('2026-10-18T09:00:00.000', 3),
      row('2026-10-20T09:00:00.000', 2),
      row('2026-10-20T21:00:00.000', 4),
      row('2026-10-21T10:00:00.000', 5),
      row('2026-10-22T08:00:00.000', 3),
    ]);

    test('counts days in a row ending today', () {
      expect(currentStreak(byDay, DateTime(2026, 10, 22, 15)), 3);
    });
    test('a streak that ended yesterday still counts', () {
      expect(currentStreak(byDay, DateTime(2026, 10, 23, 9)), 3);
    });
    test('is zero after a missed day', () {
      expect(currentStreak(byDay, DateTime(2026, 10, 24, 9)), 0);
    });
    test('is zero with no entries', () {
      expect(currentStreak(const {}, DateTime(2026, 10, 22)), 0);
    });
  });

  group('weekSummary', () {
    final byDay = dailyMoods([
      row('2026-10-20T09:00:00.000', 2),
      row('2026-10-20T21:00:00.000', 4),
      row('2026-10-22T08:00:00.000', 5),
      row('2026-10-10T08:00:00.000', 1), // outside the 7 days
    ]);

    test('covers seven days ending today, oldest first', () {
      final w = weekSummary(byDay, DateTime(2026, 10, 22, 12));
      expect(w.days.length, 7);
      expect(w.days[4], 3); // 20 Oct: average of 2 and 4
      expect(w.days[6], 5); // 22 Oct
      expect(w.days[0], isNull);
      expect(w.entries, 3);
      expect(w.daysWritten, 2);
      expect(w.average, 4); // (3 + 5) / 2
    });
    test('an empty week has no average', () {
      final w = weekSummary(const {}, DateTime(2026, 10, 22));
      expect(w.entries, 0);
      expect(w.average, isNull);
      expect(w.daysWritten, 0);
    });
  });

  group('dayHeading', () {
    final now = DateTime(2026, 10, 22, 15, 30);
    test('Today and Yesterday', () {
      expect(dayHeading(DateTime(2026, 10, 22), now), 'Today');
      expect(dayHeading(DateTime(2026, 10, 21, 23, 59), now), 'Yesterday');
    });
    test('older days show weekday and date', () {
      expect(dayHeading(DateTime(2026, 10, 19), now), 'Mon, 19 Oct');
    });
    test('another year adds the year', () {
      expect(dayHeading(DateTime(2025, 12, 31), now), 'Wed, 31 Dec 2025');
    });
  });

  group('greetingForHour', () {
    test('morning, afternoon and evening', () {
      expect(greetingForHour(0), 'Good morning');
      expect(greetingForHour(11), 'Good morning');
      expect(greetingForHour(12), 'Good afternoon');
      expect(greetingForHour(17), 'Good afternoon');
      expect(greetingForHour(18), 'Good evening');
      expect(greetingForHour(23), 'Good evening');
    });
  });

  group('time and weekday formats', () {
    test('formatEntryTime uses a 12-hour clock', () {
      expect(formatEntryTime('2026-10-20T09:05:00.000'), '9:05 AM');
      expect(formatEntryTime('2026-10-20T00:30:00.000'), '12:30 AM');
      expect(formatEntryTime('2026-10-20T12:00:00.000'), '12:00 PM');
      expect(formatEntryTime('2026-10-20T21:07:00.000'), '9:07 PM');
      expect(formatEntryTime('garbage'), '');
    });
    test('weekdayShort', () {
      expect(weekdayShort(DateTime(2026, 10, 22)), 'Thu');
      expect(weekdayShort(DateTime(2026, 10, 19)), 'Mon');
    });
  });

  group('StarterPrompts for the day', () {
    test('the same day always gives the same prompt', () {
      final a = StarterPrompts.forDay(DateTime(2026, 10, 22, 8));
      final b = StarterPrompts.forDay(DateTime(2026, 10, 22, 22));
      expect(a, b);
      expect(StarterPrompts.all, contains(a));
    });
    test('the next day gives a different prompt', () {
      expect(StarterPrompts.forDay(DateTime(2026, 10, 22)),
          isNot(StarterPrompts.forDay(DateTime(2026, 10, 23))));
    });
    test('asStart cuts the prompt at the ellipsis', () {
      expect(StarterPrompts.asStart('Today I felt … because …'), 'Today I felt ');
      expect(StarterPrompts.asStart('No dots here'), 'No dots here');
    });
  });
}
