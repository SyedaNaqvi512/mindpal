import 'dart:math';

/// Pure helpers for the exercises, kept free of widgets so they can be tested.

/// FR-36: splits a thought into short statement cards. It cuts at sentence ends,
/// semicolons, and the words "because", "so" and "but" (and long comma parts).
List<String> splitThought(String text, {int maxCards = 8}) {
  final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return const [];

  final marked = cleaned
      .replaceAllMapped(RegExp(r'([.!?;])\s+'), (m) => '${m[1]}|')
      .replaceAllMapped(
        RegExp(r',?\s+(because|since|so|but|and then)\s+', caseSensitive: false),
        (m) => '|${m[1]} ',
      );

  final cards = <String>[];
  for (var part in marked.split('|')) {
    part = part.trim();
    part = part.replaceAll(RegExp(r'^[,;.\s]+|[;\s]+$'), '').trim();
    if (part.length < 3) continue;
    cards.add(part[0].toUpperCase() + part.substring(1));
  }
  if (cards.isEmpty) return [cleaned];
  return cards.length > maxCards ? cards.sublist(0, maxCards) : cards;
}

/// FR-36: neutral summary of a sort. No right or wrong judgement.
String sortSummary({required int facts, required int assumptions, required int unsorted}) {
  final total = facts + assumptions + unsorted;
  if (total == 0) return 'There were no statements to sort this time.';
  final parts = <String>[
    '$facts ${facts == 1 ? 'statement' : 'statements'} in Fact',
    '$assumptions ${assumptions == 1 ? 'statement' : 'statements'} in Assumption',
  ];
  if (unsorted > 0) parts.add('$unsorted left unsorted');
  return 'You placed ${parts.join(', ')}. '
      'This is only a picture of how you see the thought right now.';
}

/// FR-37: the tilt of the scale, from -1 (more "against") to 1 (more "for").
/// It only counts items; it does not judge them.
double scaleTilt(int forCount, int againstCount) {
  final total = forCount + againstCount;
  if (total == 0) return 0;
  return (forCount - againstCount) / total;
}

/// FR-37: a neutral sentence for the scale.
String scaleSummary(int forCount, int againstCount) {
  if (forCount == 0 && againstCount == 0) return 'The scale is level. Nothing has been added yet.';
  if (forCount == againstCount) {
    return 'You added $forCount for and $againstCount against. The scale is level.';
  }
  return 'You added $forCount for and $againstCount against. '
      'The scale only counts items; you decide what they mean.';
}

/// FR-38: shows both ratings without calling the change good or bad.
String beliefSummary(int before, int after) {
  final diff = after - before;
  final change = diff == 0
      ? 'The rating stayed the same.'
      : diff > 0
          ? 'The rating went up by $diff.'
          : 'The rating went down by ${-diff}.';
  return 'Before: $before. After: $after. $change '
      'Ratings can move in either direction, and both are okay.';
}

/// FR-73: the body scan areas and how many seconds to suggest for each one.
/// The total must stay at 5 minutes (300 seconds) or less.
const List<(String, String, int)> kBodyScanAreas = [
  ('Settle', 'Sit or lie in a comfortable position. Let your shoulders drop. '
      'There is nothing to fix right now.', 30),
  ('Feet and legs', 'Bring your attention to your feet, then your legs. '
      'Notice any warmth, weight or contact with the floor or seat.', 30),
  ('Hips and belly', 'Move your attention to your hips and belly. '
      'Notice the gentle rise and fall as you breathe.', 30),
  ('Chest and back', 'Notice your chest and your back. '
      'Feel where they touch the chair or the bed.', 30),
  ('Hands and arms', 'Bring your attention to your hands, then your arms. '
      'Let them be heavy and still.', 30),
  ('Shoulders and neck', 'Notice your shoulders and neck. '
      'If there is tightness, simply notice it without changing anything.', 30),
  ('Face and head', 'Soften your jaw, your eyes and your forehead. '
      'Notice your whole face.', 30),
  ('Whole body', 'Let your attention rest on your whole body, breathing slowly. '
      'When you are ready, gently open your eyes and return.', 30),
];

int bodyScanTotalSeconds() =>
    kBodyScanAreas.fold<int>(0, (sum, a) => sum + a.$3);

/// FR-39: phase lengths for the breathing bubble, in seconds.
const int kInhaleSeconds = 4;
const int kHoldFullSeconds = 2;
const int kExhaleSeconds = 4;
const int kHoldEmptySeconds = 2;
const int kBreathCycleSeconds =
    kInhaleSeconds + kHoldFullSeconds + kExhaleSeconds + kHoldEmptySeconds;

enum BreathPhase { inhale, holdFull, exhale, holdEmpty }

/// Phase and bubble size (0 = small, 1 = large) at [v] (0..1) of one breath.
(BreathPhase, double) breathAt(double v) {
  final s = v.clamp(0.0, 1.0) * kBreathCycleSeconds;
  if (s < kInhaleSeconds) {
    return (BreathPhase.inhale, _ease(s / kInhaleSeconds));
  }
  if (s < kInhaleSeconds + kHoldFullSeconds) {
    return (BreathPhase.holdFull, 1.0);
  }
  if (s < kInhaleSeconds + kHoldFullSeconds + kExhaleSeconds) {
    final t = (s - kInhaleSeconds - kHoldFullSeconds) / kExhaleSeconds;
    return (BreathPhase.exhale, 1.0 - _ease(t));
  }
  return (BreathPhase.holdEmpty, 0.0);
}

double _ease(double t) => 0.5 - 0.5 * cos(pi * t.clamp(0.0, 1.0));

String breathCue(BreathPhase p) => switch (p) {
      BreathPhase.inhale => 'Breathe in',
      BreathPhase.holdFull => 'Pause',
      BreathPhase.exhale => 'Breathe out',
      BreathPhase.holdEmpty => 'Pause',
    };

/// The words the exercises must never use (FR-43): no points, levels,
/// rankings, lives, penalties or failure messages.
const List<String> kForbiddenExerciseWords = [
  'points', 'score', 'level up', 'rank', 'lives left', 'penalty', 'you failed',
  'wrong answer', 'try again',
];
