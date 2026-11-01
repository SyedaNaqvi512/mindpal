// Helpers for History search. Pure functions, so they can be tested without a
// screen or a database.

/// Splits what the user typed into separate words. Every word must be found in
/// an entry for the entry to match (so "exam happy" finds entries that have both
/// words, in any order). Words are lower case, without repeats, and at most [max].
List<String> splitSearchWords(String query, {int max = 8}) {
  final seen = <String>{};
  final words = <String>[];
  for (final raw in query.toLowerCase().split(RegExp(r'\s+'))) {
    // Leave out stray quotes and punctuation at the ends of a word.
    final w = raw.replaceAll(RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true), '');
    if (w.isEmpty || !seen.add(w)) continue;
    words.add(w);
    if (words.length >= max) break;
  }
  return words;
}

/// The start and end of each place in [text] where one of [words] appears,
/// ignoring case, in order and without overlaps.
List<({int start, int end})> matchRanges(String text, List<String> words) {
  if (text.isEmpty || words.isEmpty) return const [];
  final lower = text.toLowerCase();
  // toLowerCase can change the length for a few letters; then do not guess.
  if (lower.length != text.length) return const [];

  final found = <({int start, int end})>[];
  for (final w in words) {
    if (w.isEmpty) continue;
    var from = 0;
    while (true) {
      final i = lower.indexOf(w, from);
      if (i < 0) break;
      found.add((start: i, end: i + w.length));
      from = i + w.length;
    }
  }
  found.sort((a, b) => a.start.compareTo(b.start));

  final merged = <({int start, int end})>[];
  for (final r in found) {
    if (merged.isNotEmpty && r.start <= merged.last.end) {
      final last = merged.removeLast();
      merged.add((start: last.start, end: r.end > last.end ? r.end : last.end));
    } else {
      merged.add(r);
    }
  }
  return merged;
}

/// A short piece of [text] that shows the first match. When the match is near the
/// start the whole text is returned; otherwise it starts a little before the match
/// with "...", so the user can see why the entry was found.
String searchSnippet(String text, List<String> words, {int visibleChars = 90, int lead = 30}) {
  final ranges = matchRanges(text, words);
  if (ranges.isEmpty || ranges.first.start < visibleChars - lead) return text;

  var start = ranges.first.start - lead;
  if (start < 0) start = 0;
  // Begin at a word boundary so the snippet does not start in the middle of a word.
  final space = text.indexOf(' ', start);
  if (space >= 0 && space < ranges.first.start) start = space + 1;
  return '…${text.substring(start)}';
}