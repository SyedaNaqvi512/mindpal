import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/reminders/services/reminder_logic.dart';

void main() {
  test('minutes conversion', () {
    expect(toMinutes(20, 30), 1230);
    expect(hourOf(1230), 20);
    expect(minuteOf(1230), 30);
  });

  test('next occurrence is today when still ahead', () {
    final now = DateTime(2026, 10, 23, 10, 0);
    expect(
      nextOccurrence(now, toMinutes(20, 0)),
      DateTime(2026, 10, 23, 20, 0),
    );
  });

  test('next occurrence is tomorrow when already passed or equal', () {
    final now = DateTime(2026, 10, 23, 21, 0);
    expect(
      nextOccurrence(now, toMinutes(20, 0)),
      DateTime(2026, 10, 24, 20, 0),
    );
    final exact = DateTime(2026, 10, 23, 20, 0);
    expect(
      nextOccurrence(exact, toMinutes(20, 0)),
      DateTime(2026, 10, 24, 20, 0),
    );
  });

  test('rolls over month end', () {
    final now = DateTime(2026, 10, 31, 23, 0);
    expect(nextOccurrence(now, toMinutes(8, 0)), DateTime(2026, 11, 1, 8, 0));
  });

  test('formats 12-hour time', () {
    expect(formatMinutes(0), '12:00 AM');
    expect(formatMinutes(toMinutes(8, 5)), '8:05 AM');
    expect(formatMinutes(toMinutes(12, 0)), '12:00 PM');
    expect(formatMinutes(toMinutes(20, 30)), '8:30 PM');
  });
}
