import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// One exercise in the Exercise Library (SRS 3.5). Exercises are guided
/// self-reflection activities, not therapy or treatment (FR-51).
class ExerciseInfo {
  const ExerciseInfo({
    required this.id,
    required this.title,
    required this.blurb,
    required this.intro,
    required this.minutes,
    required this.icon,
    required this.priority,
    this.needsThought = false,
    this.balanced = false,
    this.quickPick = true,
  });

  final String id;
  final String title;

  /// One-line description shown on the library card (FR-35).
  final String blurb;

  /// Short introduction shown before the first step (FR-41).
  final String intro;

  /// Estimated time in minutes (FR-41).
  final int minutes;
  final IconData icon;

  /// SRS priority: M, S or C.
  final String priority;

  /// The exercise starts from a thought the user writes or brings from an entry.
  final bool needsThought;

  /// After the exercise the user may write a balanced thought (FR-48).
  final bool balanced;

  /// May be chosen by "Try something quick" (FR-49).
  final bool quickPick;

  String get timeLabel => minutes <= 1 ? 'about 1 min' : 'about $minutes min';
}

/// Ids of the exercises.
class ExerciseIds {
  static const sort = 'sort';
  static const scale = 'scale';
  static const belief = 'belief';
  static const breathing = 'breathing';
  static const grounding = 'grounding';
  static const thoughtRecord = 'thought_record';
  static const gratitude = 'gratitude';
  static const selfCompassion = 'self_compassion';
  static const problemSolving = 'problem_solving';
  static const checkIn = 'check_in';
  static const stop = 'stop';
  static const anchor = 'anchor';
  static const bodyScan = 'body_scan';
}

const List<ExerciseInfo> kExercises = [
  ExerciseInfo(
    id: ExerciseIds.sort,
    title: 'Facts vs Assumptions Sort',
    blurb: 'Drag each part of a thought into Fact or Assumption.',
    intro: 'Write a thought that is on your mind. MindPal splits it into short '
        'statements. You drag each one to Fact or Assumption. Nothing is '
        'graded; you simply see what you placed where.',
    minutes: 5,
    icon: Symbols.fact_check_rounded,
    priority: 'M',
    needsThought: true,
    balanced: true,
  ),
  ExerciseInfo(
    id: ExerciseIds.scale,
    title: 'Thought Balance Scale',
    blurb: 'Weigh evidence for and against a thought.',
    intro: 'Write a thought, then add evidence for it and evidence against it. '
        'The scale moves as you add items. It only shows how many items are on '
        'each side; it does not tell you what to think.',
    minutes: 5,
    icon: Symbols.balance_rounded,
    priority: 'S',
    needsThought: true,
    balanced: true,
  ),
  ExerciseInfo(
    id: ExerciseIds.belief,
    title: 'Belief Slider',
    blurb: 'Rate how strongly you believe a thought, before and after.',
    intro: 'Rate how strongly you believe a thought from 0 to 100, think it '
        'through, then rate it again. You will see both numbers side by side. '
        'A change in either direction is fine.',
    minutes: 4,
    icon: Symbols.tune_rounded,
    priority: 'S',
    needsThought: true,
    balanced: true,
  ),
  ExerciseInfo(
    id: ExerciseIds.breathing,
    title: 'Breathing Bubble',
    blurb: 'Breathe in, pause, breathe out, pause with a gentle bubble.',
    intro: 'A bubble grows while you breathe in, pauses, shrinks while you '
        'breathe out, and pauses again. Use it on its own or as a warm-up '
        'before another exercise.',
    minutes: 2,
    icon: Symbols.air_rounded,
    priority: 'S',
  ),
  ExerciseInfo(
    id: ExerciseIds.grounding,
    title: '5-4-3-2-1 Grounding',
    blurb: 'Notice 5 things you see, 4 feel, 3 hear, 2 smell, 1 taste.',
    intro: 'Slowly notice things around you with your senses. Tap each circle '
        'when you have noticed one. Writing a note is optional.',
    minutes: 4,
    icon: Symbols.visibility_rounded,
    priority: 'S',
  ),
  ExerciseInfo(
    id: ExerciseIds.thoughtRecord,
    title: 'Thought Record',
    blurb: 'Write down a situation, a thought and a fairer view.',
    intro: 'Walk through a moment step by step: what happened, what you '
        'thought, how you felt, and a fairer way to see it.',
    minutes: 6,
    icon: Symbols.edit_note_rounded,
    priority: 'C',
    needsThought: true,
    balanced: true,
    quickPick: false,
  ),
  ExerciseInfo(
    id: ExerciseIds.gratitude,
    title: 'Gratitude Reflection',
    blurb: 'Notice three things you appreciate today.',
    intro: 'Pick or write three things, big or small, that you appreciate '
        'today, and say why they matter to you.',
    minutes: 3,
    icon: Symbols.volunteer_activism_rounded,
    priority: 'C',
  ),
  ExerciseInfo(
    id: ExerciseIds.selfCompassion,
    title: 'Self-Compassion Reflection',
    blurb: 'Speak to yourself the way you would to a good friend.',
    intro: 'Think of something that is hard right now. You will notice the '
        'feeling, remember that others struggle too, and write a kind sentence '
        'to yourself.',
    minutes: 4,
    icon: Symbols.favorite_rounded,
    priority: 'C',
  ),
  ExerciseInfo(
    id: ExerciseIds.problemSolving,
    title: 'Problem-Solving',
    blurb: 'Break a problem into options and one small first step.',
    intro: 'Name a problem, list a few options, choose one that feels doable, '
        'and decide on a small first step.',
    minutes: 5,
    icon: Symbols.extension_rounded,
    priority: 'C',
  ),
  ExerciseInfo(
    id: ExerciseIds.checkIn,
    title: 'Daily Check-In',
    blurb: 'A quick look at your mood, energy and what is on your mind.',
    intro: 'Slide to show how you feel today, pick a few words, and add a '
        'short note if you wish.',
    minutes: 2,
    icon: Symbols.today_rounded,
    priority: 'C',
  ),
  ExerciseInfo(
    id: ExerciseIds.stop,
    title: 'STOP',
    blurb: 'Stop, take a breath, observe, proceed: four short steps.',
    intro: 'A short pause for stressful moments. Four small steps: Stop, '
        'Take a breath, Observe, Proceed.',
    minutes: 2,
    icon: Symbols.stop_circle_rounded,
    priority: 'C',
    quickPick: false,
  ),
  ExerciseInfo(
    id: ExerciseIds.anchor,
    title: 'Anchoring Phrase',
    blurb: 'Choose a calming phrase and read it while you breathe slowly.',
    intro: 'Choose a short calming phrase from the list or write your own. '
        'You will read it while a slow breathing circle moves.',
    minutes: 3,
    icon: Symbols.anchor_rounded,
    priority: 'C',
    quickPick: false,
  ),
  ExerciseInfo(
    id: ExerciseIds.bodyScan,
    title: 'Body Scan',
    blurb: 'Move your attention slowly through your body, in 5 minutes or less.',
    intro: 'On-screen text guides your attention slowly through areas of your '
        'body. No audio is needed. Take each step at your own pace.',
    minutes: 5,
    icon: Symbols.self_improvement_rounded,
    priority: 'C',
    quickPick: false,
  ),
];

ExerciseInfo? exerciseById(String id) {
  for (final e in kExercises) {
    if (e.id == id) return e;
  }
  return null;
}

/// Exercises that are in this version of the app (all of them today).
Set<String> get kAvailableExerciseIds => {for (final e in kExercises) e.id};

/// FR-46: the mapping from a named thinking pattern to a suggested exercise and
/// the fallback used when the first one is not in the app.
class SuggestionRule {
  const SuggestionRule(this.exercise, this.fallback);
  final String exercise;
  final String fallback;
}

const Map<String, SuggestionRule> kSuggestionMap = {
  'catastrophizing': SuggestionRule(ExerciseIds.sort, ExerciseIds.grounding),
  'mind_reading': SuggestionRule(ExerciseIds.sort, ExerciseIds.breathing),
  'all_or_nothing': SuggestionRule(ExerciseIds.scale, ExerciseIds.breathing),
  'overgeneralization': SuggestionRule(ExerciseIds.scale, ExerciseIds.breathing),
  'emotional_reasoning': SuggestionRule(ExerciseIds.belief, ExerciseIds.grounding),
  'should_statements': SuggestionRule(ExerciseIds.belief, ExerciseIds.breathing),
};

/// "Other patterns or none noticed".
const SuggestionRule kDefaultSuggestion =
    SuggestionRule(ExerciseIds.breathing, ExerciseIds.grounding);

/// The exercise to suggest after a reflection, or null when neither the mapped
/// exercise nor its fallback is available (then no card is shown).
/// STOP, Anchoring and Body scan are never suggested automatically.
ExerciseInfo? suggestExercise(String? patternId, {Set<String>? available}) {
  final avail = available ?? kAvailableExerciseIds;
  final rule = kSuggestionMap[patternId] ?? kDefaultSuggestion;
  if (avail.contains(rule.exercise)) return exerciseById(rule.exercise);
  if (avail.contains(rule.fallback)) return exerciseById(rule.fallback);
  return null;
}

/// FR-49: one short exercise at random (never one longer than 5 minutes that is
/// not marked quick). [random] can be passed for tests.
ExerciseInfo quickExercise({Random? random}) {
  final pool = [
    for (final e in kExercises)
      if (e.quickPick && e.minutes <= 5) e,
  ];
  return pool[(random ?? Random()).nextInt(pool.length)];
}
