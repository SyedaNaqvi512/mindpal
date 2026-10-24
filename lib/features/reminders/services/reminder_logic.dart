// Pure helpers for the daily reminder (FR-30).

/// Minutes after midnight, for example 20:30 is 1230.
int toMinutes(int hour, int minute) => hour * 60 + minute;

int hourOf(int minutes) => minutes ~/ 60;
int minuteOf(int minutes) => minutes % 60;

/// The next time the reminder should fire: today if the time is still ahead,
/// otherwise tomorrow.
DateTime nextOccurrence(DateTime now, int minutes) {
  final today = DateTime(
    now.year,
    now.month,
    now.day,
    hourOf(minutes),
    minuteOf(minutes),
  );
  return today.isAfter(now)
      ? today
      : DateTime(
          now.year,
          now.month,
          now.day + 1,
          hourOf(minutes),
          minuteOf(minutes),
        );
}

/// "8:30 PM" without needing a BuildContext.
String formatMinutes(int minutes) {
  final h = hourOf(minutes);
  final m = minuteOf(minutes).toString().padLeft(2, '0');
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m $suffix';
}
