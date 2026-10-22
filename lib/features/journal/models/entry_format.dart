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
