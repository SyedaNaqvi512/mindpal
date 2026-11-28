import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/reminders/services/notification_content.dart';

void main() {
  final pools = <String, List<String>>{
    'check-in titles': kCheckInTitles,
    'check-in bodies': kCheckInBodies,
    'thoughts': kQuotes,
    'thought titles': kQuoteTitles,
  };

  group('the words', () {
    test('there is plenty of variety', () {
      expect(kCheckInBodies.length, greaterThanOrEqualTo(25));
      expect(kQuotes.length, greaterThanOrEqualTo(50));
      expect(kCheckInTitles.length, greaterThanOrEqualTo(4));
      expect(kQuoteTitles.length, greaterThanOrEqualTo(3));
    });

    test('no line is empty or repeated', () {
      for (final e in pools.entries) {
        expect(e.value.every((s) => s.trim().isNotEmpty), isTrue, reason: e.key);
        expect(e.value.toSet().length, e.value.length, reason: '${e.key} has a repeat');
      }
    });

    test('lines fit a notification and use plain characters', () {
      for (final s in [...kCheckInBodies, ...kQuotes]) {
        expect(s.length, lessThanOrEqualTo(120), reason: s);
        expect(s.runes.every((r) => r >= 0x20 && r < 0x7F), isTrue, reason: s);
      }
      for (final s in [...kCheckInTitles, ...kQuoteTitles]) {
        expect(s.length, lessThanOrEqualTo(30), reason: s);
      }
    });

    test('nothing guilt-making, diagnostic or pushy', () {
      const banned = [
        r'streak', r'\bmiss', r'fail', r'lazy', r'behind', r'\bmust\b', r'\bshould\b',
        r'\bcure', r'diagnos', r'disorder', r'depress', r'therapy', r'treatment',
        r'medic', r'last chance', r'hurry', r'\blost\b',
      ];
      for (final s in [...kCheckInBodies, ...kQuotes]) {
        final low = s.toLowerCase();
        for (final w in banned) {
          expect(RegExp(w).hasMatch(low), isFalse, reason: '"$w" in: $s');
        }
      }
    });

    test('no quote is credited to a real person', () {
      for (final s in kQuotes) {
        expect(s.contains(' - '), isFalse, reason: s);
        expect(s.contains('--'), isFalse, reason: s);
      }
    });
  });

  group('picking a line for a day', () {
    test('the same day always gives the same line', () {
      final d = DateTime(2026, 12, 3, 9);
      expect(pickForDay(kQuotes, d), pickForDay(kQuotes, DateTime(2026, 12, 3, 23, 59)));
    });

    test('the next day gives a different line', () {
      for (final pool in pools.values) {
        var day = DateTime(2026, 11, 1);
        for (var i = 0; i < 200; i++) {
          final next = DateTime(day.year, day.month, day.day + 1);
          expect(pickForDay(pool, day), isNot(pickForDay(pool, next)));
          day = next;
        }
      }
    });

    test('the whole pool is used before any line comes back', () {
      for (final pool in pools.values) {
        final seen = <String>{};
        for (var i = 0; i < pool.length; i++) {
          seen.add(pickForDay(pool, DateTime(2026, 11, 1 + i)));
        }
        expect(seen.length, pool.length);
      }
    });

    test('a different salt can give a different line on the same day', () {
      var differs = 0;
      for (var i = 0; i < 20; i++) {
        final d = DateTime(2026, 11, 1 + i);
        if (pickForDay(kCheckInTitles, d) != pickForDay(kCheckInTitles, d, salt: 2)) differs++;
      }
      expect(differs, greaterThan(10));
    });

    test('daylight saving does not move the day number', () {
      expect(dayNumber(DateTime(2026, 3, 29, 0, 30)), dayNumber(DateTime(2026, 3, 29, 23, 30)));
      expect(dayNumber(DateTime(2026, 3, 30)) - dayNumber(DateTime(2026, 3, 29)), 1);
    });
  });

  group('planning the next days', () {
    final now = DateTime(2026, 11, 28, 10, 0);

    test('starts today when the time is still ahead', () {
      final t = upcomingTimes(now, 20 * 60);
      expect(t.first, DateTime(2026, 11, 28, 20, 0));
      expect(t.length, 14);
    });

    test('starts tomorrow when the time has passed', () {
      final t = upcomingTimes(now, 9 * 60);
      expect(t.first, DateTime(2026, 11, 29, 9, 0));
    });

    test('one day apart, in order, across a month end', () {
      final t = upcomingTimes(DateTime(2026, 12, 25, 12), 8 * 60 + 30, count: 14);
      for (var i = 1; i < t.length; i++) {
        expect(t[i].isAfter(t[i - 1]), isTrue);
        expect(DateTime(t[i].year, t[i].month, t[i].day).difference(
            DateTime(t[i - 1].year, t[i - 1].month, t[i - 1].day)).inHours, inInclusiveRange(23, 25));
      }
      expect(t.last, DateTime(2027, 1, 8, 8, 30));
    });

    test('the quotes for two weeks are all different', () {
      final plan = planQuotes(now, 9 * 60);
      expect(plan.map((p) => p.body).toSet().length, 14);
      expect(plan.every((p) => kQuoteTitles.contains(p.title)), isTrue);
    });

    test('the check-ins for two weeks are all different', () {
      final plan = planCheckIns(now, 20 * 60);
      expect(plan.map((p) => p.body).toSet().length, 14);
      expect(plan.every((p) => kCheckInTitles.contains(p.title)), isTrue);
    });

    test('a plan is the same when made twice', () {
      final a = planQuotes(now, 9 * 60).map((p) => '${p.when}${p.body}').toList();
      final b = planQuotes(now, 9 * 60).map((p) => '${p.when}${p.body}').toList();
      expect(a, b);
    });
  });
}
