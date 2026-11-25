import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/exercises/bodies/exercise_content.dart';
import 'package:mindpal/features/exercises/bodies/exercise_registry.dart';
import 'package:mindpal/features/exercises/models/exercise_catalog.dart';
import 'package:mindpal/features/exercises/models/exercise_logic.dart';

void main() {
  test('picking is stable for one session and varies between sessions', () {
    expect(pickMany(kGratitudeThings, 12, 5), pickMany(kGratitudeThings, 12, 5));
    expect(pickMany(kGratitudeThings, 12, 5).length, 12);
    final sets = {for (var s = 0; s < 20; s++) pickMany(kGratitudeThings, 12, s).join('|')};
    expect(sets.length, greaterThan(1));
    expect(pickOne(kKindPrompts, 3), pickOne(kKindPrompts, 3));
  });

  test('every exercise has a take-away and something to try today', () {
    for (final e in kExercises) {
      expect(kTakeAway[e.id], isNotNull, reason: e.id);
      expect(kTryToday[e.id], isNotEmpty, reason: e.id);
    }
  });

  test('grounding has a cue for each circle', () {
    const counts = {'see': 5, 'feel': 4, 'hear': 3, 'smell': 2, 'taste': 1};
    counts.forEach((k, n) => expect(kGroundingCues[k]!.length, n, reason: k));
  });

  test('exercises still build for any seed', () {
    for (final e in kExercises) {
      for (final seed in [0, 1, 123456789]) {
        expect(buildSteps(e, seed: seed), isNotEmpty, reason: '${e.id} $seed');
      }
    }
  });

  test('new content never uses scoring or failure words (FR-43)', () {
    final all = <String>[
      ...kCommonThoughts, ...kSituationIdeas, ...kGratitudeThings,
      ...kGratitudeWhyPrompts, ...kGratitudeWhyIdeas, ...kHardIdeas,
      ...kKindPrompts, ...kKindIdeas, ...kProblemIdeas, ...kOptionIdeas,
      ...kFirstStepIdeas, ...kCheckInWords, ...kCheckInNotePrompts,
      ...kCheckInNoteIdeas, ...kObserveOptions, ...kProceedOptions,
      ...kTakeAway.values,
      for (final l in kTryToday.values) ...l,
      for (final l in kGroundingCues.values) ...l,
    ];
    for (final t in all) {
      for (final w in kForbiddenExerciseWords) {
        expect(t.toLowerCase().contains(w), isFalse, reason: '"$w" in "$t"');
      }
    }
  });
}
