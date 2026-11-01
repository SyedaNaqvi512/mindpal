import '../models/exercise_catalog.dart';
import '../models/exercise_logic.dart';
import '../models/exercise_session.dart';
import '../services/exercise_controller.dart';
import 'belief_steps.dart';
import 'scale_steps.dart';
import 'simple_steps.dart';
import 'sort_steps.dart';
import 'step_kit.dart';

/// The steps of each exercise, in order. Exercises that offer a balanced
/// thought get that optional step last (FR-48).
List<ExerciseStep> buildSteps(ExerciseInfo info) {
  final steps = switch (info.id) {
    ExerciseIds.sort => [thoughtStep(), sortStep(), sortSummaryStep()],
    ExerciseIds.scale => [
        thoughtStep(),
        evidenceStep(
          title: 'Evidence for',
          prompt: 'What makes this thought seem true? Add one item at a time and watch the scale.',
          key: 'for',
          label: 'Evidence for',
        ),
        evidenceStep(
          title: 'Evidence against',
          prompt: 'What does not fit the thought, or points another way?',
          key: 'against',
          label: 'Evidence against',
        ),
        scaleSummaryStep(),
      ],
    ExerciseIds.belief => [
        thoughtStep(),
        beliefBeforeStep(),
        beliefThinkStep(),
        beliefAfterStep(),
        beliefSummaryStep(),
      ],
    ExerciseIds.breathing => breathingSteps(),
    ExerciseIds.grounding => groundingSteps(),
    ExerciseIds.thoughtRecord => thoughtRecordSteps(),
    ExerciseIds.gratitude => gratitudeSteps(),
    ExerciseIds.selfCompassion => selfCompassionSteps(),
    ExerciseIds.problemSolving => problemSolvingSteps(),
    ExerciseIds.checkIn => checkInSteps(),
    ExerciseIds.stop => stopSteps(),
    ExerciseIds.anchor => anchorSteps(),
    ExerciseIds.bodyScan => bodyScanSteps(),
    _ => <ExerciseStep>[],
  };
  return [...steps, if (info.balanced) balancedStep()];
}

String _join(Object? v) {
  if (v is List) return v.map((e) => '$e').join('; ');
  if (v == null) return '';
  return '$v'.trim();
}

/// FR-45: the answers of a finished session as label and text lines, for the
/// Exercise Progress screen. Empty answers are left out.
List<(String, String)> describeSession(ExerciseSession s) {
  final d = s.data;
  final out = <(String, String)>[];

  void add(String label, Object? value) {
    final t = _join(value);
    if (t.isNotEmpty) out.add((label, t));
  }

  switch (s.exerciseId) {
    case ExerciseIds.sort:
      add('Thought', d['thought']);
      final cards = d['cards'] is List ? (d['cards'] as List).map((e) => '$e').toList() : <String>[];
      final place = d['place'] is Map ? d['place'] as Map : const {};
      final facts = <String>[], assumptions = <String>[];
      for (var i = 0; i < cards.length; i++) {
        final w = place['$i'];
        if (w == 'fact') facts.add(cards[i]);
        if (w == 'assumption') assumptions.add(cards[i]);
      }
      add('Fact', facts);
      add('Assumption', assumptions);
    case ExerciseIds.scale:
      add('Thought', d['thought']);
      add('Evidence for', d['for']);
      add('Evidence against', d['against']);
    case ExerciseIds.belief:
      add('Thought', d['thought']);
      if (d['before'] != null && d['after'] != null) {
        add('Ratings', beliefSummary((d['before'] as num).toInt(), (d['after'] as num).toInt()));
      } else {
        add('Before', d['before']);
        add('After', d['after']);
      }
      add('What makes it feel true', d['support']);
      add('What does not fit', d['doubt']);
    case ExerciseIds.breathing:
      add('Breaths', d['breaths']);
    case ExerciseIds.grounding:
      add('Saw', d['see_note']);
      add('Felt', d['feel_note']);
      add('Heard', d['hear_note']);
      add('Smelled', d['smell_note']);
      add('Tasted', d['taste_note']);
    case ExerciseIds.thoughtRecord:
      add('Situation', d['situation']);
      add('Thought', d['thought']);
      add('Feelings', d['feelings']);
      add('Strength of feeling', d['intensity']);
      add('Evidence for', d['for']);
      add('Evidence against', d['against']);
    case ExerciseIds.gratitude:
      add('Appreciated', d['things']);
      add('Why it matters', d['why']);
      add('To remember', d['carry']);
    case ExerciseIds.selfCompassion:
      add('Something hard', d['hard']);
      add('Feelings', d['feelings']);
      add('A kind sentence', d['kind']);
    case ExerciseIds.problemSolving:
      add('Problem', d['problem']);
      add('Options', d['options']);
      add('Chosen', d['chosen']);
      add('First step', d['first']);
      add('When', d['when']);
    case ExerciseIds.checkIn:
      add('Mood (0 to 100)', d['mood']);
      add('Energy (0 to 100)', d['energy']);
      add('Words', d['words']);
      add('Note', d['note']);
    case ExerciseIds.stop:
      add('Noticed', d['observe']);
      add('Chose to', d['proceed']);
    case ExerciseIds.anchor:
      add('Phrase', d['phrase']);
    case ExerciseIds.bodyScan:
      add('Body scan', 'Completed');
  }

  add('Balanced thought', s.balancedThought);
  return out;
}
