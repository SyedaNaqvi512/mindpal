/// The fixed list of thinking patterns (FR-21). The ids match the server.
/// Patterns are shown as suggestions, never as diagnoses (FR-22).
class ThinkingPatterns {
  static const names = <String, String>{
    'all_or_nothing': 'All-or-nothing thinking',
    'overgeneralization': 'Overgeneralization',
    'catastrophizing': 'Catastrophizing',
    'mind_reading': 'Mind reading',
    'emotional_reasoning': 'Emotional reasoning',
    'should_statements': 'Should statements',
    'labeling': 'Labelling',
    'personalization': 'Personalization',
    'mental_filter': 'Mental filter',
  };

  /// null when there is no pattern ("none", empty or unknown).
  static String? nameOf(String? id) => names[id];
}
