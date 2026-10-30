/// A mood choice. The database keeps the number 1-5 (as in the SRS);
/// the app shows an emoji together with a word.
class Mood {
  const Mood(this.value, this.emoji, this.label);

  final int value;
  final String emoji;
  final String label;

  static const all = <Mood>[
    Mood(1, '😞', 'Very low'),
    Mood(2, '😕', 'Low'),
    Mood(3, '😐', 'Okay'),
    Mood(4, '🙂', 'Good'),
    Mood(5, '😄', 'Very good'),
  ];

  static Mood byValue(int? v) =>
      all.firstWhere((m) => m.value == v, orElse: () => all[2]);
}

/// Optional feeling tags (FR-10).
class FeelingTags {
  static const all = <String>[
    'Calm',
    'Happy',
    'Grateful',
    'Hopeful',
    'Motivated',
    'Tired',
    'Stressed',
    'Anxious',
    'Overwhelmed',
    'Sad',
    'Lonely',
    'Angry',
  ];

  static List<String> parse(Object? raw) {
    final s = raw as String?;
    if (s == null || s.isEmpty) return const [];
    return s.split(',').where((t) => t.isNotEmpty).toList()..sort();
  }
}

/// Optional starter prompts (FR-13).
class StarterPrompts {
  static const all = <String>[
    'Today I felt … because …',
    'Something that went well today was …',
    'What is worrying me right now is …',
    'One thing I am grateful for is …',
    'Something I found difficult today was …',
    'If a friend felt this way, I would tell them …',
  ];

  /// One prompt per calendar day: the same all day, a new one tomorrow.
  static String forDay(DateTime d) {
    final dayOfYear =
        DateTime(d.year, d.month, d.day).difference(DateTime(d.year, 1, 1)).inDays;
    return all[(d.year + dayOfYear) % all.length];
  }

  /// The text to start the writing box with: the prompt up to its "…".
  static String asStart(String prompt) {
    final i = prompt.indexOf('…');
    return i < 0 ? prompt : prompt.substring(0, i);
  }
}
