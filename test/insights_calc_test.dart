import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/insights/models/insights_calc.dart';

Map<String, Object?> row(String at, int mood, [String? pattern]) =>
    {'created_at': at, 'mood': mood, 'thinking_pattern': pattern};

void main() {
  group('dailyMoods', () {
    test('averages several entries of the same day', () {
      final m = dailyMoods([
        row('2026-10-20T09:00:00.000', 2),
        row('2026-10-20T21:00:00.000', 4),
        row('2026-10-21T10:00:00.000', 5),
      ]);
      expect(m.length, 2);
      expect(m[DateTime(2026, 10, 20)]!.average, 3);
      expect(m[DateTime(2026, 10, 20)]!.count, 2);
      expect(m[DateTime(2026, 10, 21)]!.average, 5);
    });
    test('bad rows are skipped', () {
      final m = dailyMoods([
        {'created_at': 'garbage', 'mood': 3},
        {'created_at': '2026-10-20T09:00:00.000', 'mood': 'x'},
      ]);
      expect(m, isEmpty);
    });
  });

  group('dailySeries', () {
    test('has one value per day with gaps as null', () {
      final m = dailyMoods([
        row('2026-10-21T10:00:00.000', 4),
        row('2026-10-23T10:00:00.000', 2),
      ]);
      final s = dailySeries(m, DateTime(2026, 10, 23), 4);
      expect(s, [null, 4.0, null, 2.0]);
      expect(seriesAverage(s), 3.0);
    });
    test('empty series has no average', () {
      expect(seriesAverage([null, null]), isNull);
    });
    test('crosses a month boundary', () {
      final m = dailyMoods([row('2026-09-30T10:00:00.000', 3)]);
      final s = dailySeries(m, DateTime(2026, 10, 2), 3);
      expect(s, [3.0, null, null]);
    });
  });

  group('moodIndex', () {
    test('maps an average to the five levels', () {
      expect(moodIndex(1.0), 0);
      expect(moodIndex(2.6), 2);
      expect(moodIndex(4.4), 3);
      expect(moodIndex(5.0), 4);
    });
  });

  group('patternCounts', () {
    final rows = [
      row('2026-10-01T10:00:00.000', 3, 'mind_reading'),
      row('2026-10-10T10:00:00.000', 3, 'mind_reading'),
      row('2026-10-20T10:00:00.000', 3, 'catastrophizing'),
      row('2026-10-21T10:00:00.000', 3, null),
      row('2026-10-22T10:00:00.000', 3, 'none'),
      row('2026-10-22T11:00:00.000', 3, 'made_up'),
    ];
    test('counts known patterns, most common first', () {
      final c = patternCounts(rows);
      expect(c.map((e) => e.key), ['mind_reading', 'catastrophizing']);
      expect(c.first.value, 2);
    });
    test('limits to a period', () {
      final c = patternCounts(rows, since: DateTime(2026, 10, 15));
      expect(c.map((e) => e.key), ['catastrophizing']);
    });
  });

  group('monthGrid', () {
    test('October 2026 starts on a Thursday and has 31 days', () {
      final g = monthGrid(DateTime(2026, 10, 15));
      expect(g.where((c) => c == null).length, 3); // Mon, Tue, Wed blank
      expect(g.whereType<DateTime>().length, 31);
      expect(g[3], DateTime(2026, 10, 1));
    });
    test('February in a leap year has 29 days', () {
      expect(monthGrid(DateTime(2028, 2, 1)).whereType<DateTime>().length, 29);
    });
  });
}
