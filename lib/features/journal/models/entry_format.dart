const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "20 Oct 2026" from a stored ISO timestamp.
String formatEntryDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso.length >= 10 ? iso.substring(0, 10) : iso;
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "20 Oct 2026, 11:53"
String formatEntryDateTime(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${formatEntryDate(iso)}, ${_two(d.hour)}:${_two(d.minute)}';
}

/// "20 Oct" for filter chips.
String formatShortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Mon" to "Sun" for a date.
String weekdayShort(DateTime d) => _weekdays[d.weekday - 1];

/// "11:53 AM" from a stored ISO timestamp.
String formatEntryTime(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final suffix = d.hour < 12 ? 'AM' : 'PM';
  return '$h12:${_two(d.minute)} $suffix';
}

/// A heading for a group of entries: "Today", "Yesterday" or "Mon, 20 Oct".
/// The year is added when it differs from [now]'s year.
String dayHeading(DateTime day, DateTime now) {
  final a = DateTime(day.year, day.month, day.day);
  final b = DateTime(now.year, now.month, now.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  final base = '${weekdayShort(a)}, ${a.day} ${_months[a.month - 1]}';
  return a.year == b.year ? base : '$base ${a.year}';
}

/// "Good morning", "Good afternoon" or "Good evening" for an hour 0-23.
String greetingForHour(int hour) {
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}
