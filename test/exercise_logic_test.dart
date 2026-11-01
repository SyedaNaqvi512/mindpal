import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/exercises/bodies/exercise_registry.dart';
import 'package:mindpal/features/exercises/models/exercise_catalog.dart';
import 'package:mindpal/features/exercises/models/exercise_logic.dart';
import 'package:mindpal/features/exercises/models/exercise_session.dart';

void main() {
  group('Catalog (FR-35, FR-36 to FR-40, FR-70 to FR-73)', () {
    test('has the 13 exercises of SRS 3.5 with unique ids', () {
      expect(kExercises.length, 13);
      expect(kExercises.map((e) => e.id).toSet().length, 13);
      for (final id in [
        ExerciseIds.sort, ExerciseIds.scale, ExerciseIds.belief, ExerciseIds.breathing,
        ExerciseIds.grounding, ExerciseIds.thoughtRecord, ExerciseIds.gratitude,
        ExerciseIds.selfCompassion, ExerciseIds.problemSolving, ExerciseIds.checkIn,
        ExerciseIds.stop, ExerciseIds.anchor, ExerciseIds.bodyScan,
      ]) {
        expect(exerciseById(id), isNotNull, reason: id);
      }
    });

    test('priorities follow the SRS: Sort is Must, four are Should, eight are Could', () {
      expect(exerciseById(ExerciseIds.sort)!.priority, 'M');
      final should = kExercises.where((e) => e.priority == 'S').map((e) => e.id).toSet();
      expect(should, {
        ExerciseIds.scale, ExerciseIds.belief, ExerciseIds.breathing, ExerciseIds.grounding,
      });
      expect(kExercises.where((e) => e.priority == 'C').length, 8);
    });

    test('every exercise has a title, one-line description, intro and time (FR-35, FR-41)', () {
      for (final e in kExercises) {
        expect(e.title, isNotEmpty);
        expect(e.blurb, isNotEmpty);
        expect(e.blurb.contains('\n'), isFalse);
        expect(e.intro.length, greaterThan(30));
        expect(e.minutes, greaterThan(0));
        expect(e.timeLabel, contains('min'));
      }
    });

    test('no exercise text uses points, levels, ranks, lives, penalties or failure words (FR-43)', () {
      for (final e in kExercises) {
        final text = '${e.title} ${e.blurb} ${e.intro}'.toLowerCase();
        for (final w in kForbiddenExerciseWords) {
          expect(text.contains(w), isFalse, reason: '${e.id} contains "$w"');
        }
      }
    });

    test('every exercise has steps, and thought exercises end with the optional balanced thought (FR-48)', () {
      for (final e in kExercises) {
        final steps = buildSteps(e);
        expect(steps, isNotEmpty, reason: e.id);
        for (final s in steps) {
          expect(s.title, isNotEmpty);
        }
        if (e.balanced) expect(steps.last.title, 'A balanced thought');
      }
    });
  });

  group('Suggested exercise (FR-46)', () {
    test('uses the mapping table for each named pattern', () {
      expect(suggestExercise('catastrophizing')!.id, ExerciseIds.sort);
      expect(suggestExercise('mind_reading')!.id, ExerciseIds.sort);
      expect(suggestExercise('all_or_nothing')!.id, ExerciseIds.scale);
      expect(suggestExercise('overgeneralization')!.id, ExerciseIds.scale);
      expect(suggestExercise('emotional_reasoning')!.id, ExerciseIds.belief);
      expect(suggestExercise('should_statements')!.id, ExerciseIds.belief);
    });

    test('other patterns or none noticed suggest the Breathing Bubble', () {
      for (final p in ['labeling', 'personalization', 'mental_filter', 'none', null, 'zzz']) {
        expect(suggestExercise(p)!.id, ExerciseIds.breathing, reason: '$p');
      }
    });

    test('uses the fallback when the mapped exercise is not available', () {
      expect(suggestExercise('catastrophizing', available: {ExerciseIds.grounding})!.id,
          ExerciseIds.grounding);
      expect(suggestExercise('mind_reading', available: {ExerciseIds.breathing})!.id,
          ExerciseIds.breathing);
      expect(suggestExercise('all_or_nothing', available: {ExerciseIds.breathing})!.id,
          ExerciseIds.breathing);
      expect(suggestExercise('emotional_reasoning', available: {ExerciseIds.grounding})!.id,
          ExerciseIds.grounding);
      expect(suggestExercise(null, available: {ExerciseIds.grounding})!.id,
          ExerciseIds.grounding);
    });

    test('shows no card when neither the exercise nor its fallback is available', () {
      expect(suggestExercise('catastrophizing', available: {ExerciseIds.belief}), isNull);
      expect(suggestExercise('none', available: <String>{}), isNull);
    });

    test('STOP, Anchoring phrase and Body scan are never suggested automatically', () {
      const never = {ExerciseIds.stop, ExerciseIds.anchor, ExerciseIds.bodyScan};
      final all = [...kSuggestionMap.keys, 'none', null];
      for (final p in all) {
        expect(never.contains(suggestExercise(p)!.id), isFalse);
      }
      for (final r in [...kSuggestionMap.values, kDefaultSuggestion]) {
        expect(never.contains(r.exercise) || never.contains(r.fallback), isFalse);
      }
    });
  });

  group('Try something quick (FR-49)', () {
    test('only picks short exercises that are marked quick', () {
      final r = Random(1);
      for (var i = 0; i < 200; i++) {
        final e = quickExercise(random: r);
        expect(e.quickPick, isTrue);
        expect(e.minutes, lessThanOrEqualTo(5));
      }
    });

    test('is random, not always the same exercise', () {
      final r = Random(7);
      final ids = {for (var i = 0; i < 100; i++) quickExercise(random: r).id};
      expect(ids.length, greaterThan(3));
    });
  });

  group('Facts vs Assumptions Sort (FR-36)', () {
    test('splits a thought into short statement cards', () {
      final cards = splitThought(
          'I failed the quiz. My teacher dislikes me, so I will fail the course because I am bad at this.');
      expect(cards.length, greaterThanOrEqualTo(3));
      expect(cards.first, 'I failed the quiz.');
      expect(cards.any((c) => c.toLowerCase().startsWith('so ')), isTrue);
      expect(cards.any((c) => c.toLowerCase().startsWith('because ')), isTrue);
    });

    test('handles empty and single-sentence thoughts', () {
      expect(splitThought('   '), isEmpty);
      expect(splitThought('I am tired'), ['I am tired']);
      expect(splitThought('I am tired.'), ['I am tired.']);
    });

    test('limits the number of cards', () {
      final long = List.generate(20, (i) => 'Statement number $i.').join(' ');
      expect(splitThought(long).length, 8);
    });

    test('the summary is neutral and has no right or wrong judgement', () {
      final s = sortSummary(facts: 2, assumptions: 3, unsorted: 1);
      expect(s, contains('2 statements in Fact'));
      expect(s, contains('3 statements in Assumption'));
      expect(s, contains('1 left unsorted'));
      for (final w in ['wrong', 'correct', 'good', 'bad', 'mistake']) {
        expect(s.toLowerCase().contains(w), isFalse, reason: w);
      }
    });
  });

  group('Thought Balance Scale (FR-37)', () {
    test('tilts toward the side with more items and is level when equal', () {
      expect(scaleTilt(0, 0), 0);
      expect(scaleTilt(2, 2), 0);
      expect(scaleTilt(3, 1), greaterThan(0));
      expect(scaleTilt(1, 3), lessThan(0));
      expect(scaleTilt(4, 0), 1);
      expect(scaleTilt(0, 4), -1);
    });

    test('summary only counts items', () {
      expect(scaleSummary(2, 1), contains('2 for and 1 against'));
      expect(scaleSummary(1, 1), contains('level'));
    });
  });

  group('Belief Slider (FR-38)', () {
    test('shows both ratings and does not call the change good or bad', () {
      for (final pair in [(80, 40), (40, 80), (50, 50)]) {
        final s = beliefSummary(pair.$1, pair.$2);
        expect(s, contains('Before: ${pair.$1}'));
        expect(s, contains('After: ${pair.$2}'));
        for (final w in ['improved', 'worse', 'better', 'failed', 'success']) {
          expect(s.toLowerCase().contains(w), isFalse, reason: w);
        }
      }
      expect(beliefSummary(80, 40), contains('down by 40'));
      expect(beliefSummary(40, 80), contains('up by 40'));
      expect(beliefSummary(50, 50), contains('stayed the same'));
    });
  });

  group('Breathing Bubble (FR-39)', () {
    test('expands, pauses, contracts and pauses', () {
      final phases = <BreathPhase>[];
      for (var s = 0.0; s < kBreathCycleSeconds; s += 0.25) {
        final (p, _) = breathAt(s / kBreathCycleSeconds);
        if (phases.isEmpty || phases.last != p) phases.add(p);
      }
      expect(phases, [
        BreathPhase.inhale, BreathPhase.holdFull, BreathPhase.exhale, BreathPhase.holdEmpty,
      ]);
    });

    test('bubble size grows during inhale and shrinks during exhale', () {
      expect(breathAt(0).$2, closeTo(0, 0.01));
      final full = breathAt(kInhaleSeconds / kBreathCycleSeconds + 0.001).$2;
      expect(full, 1.0);
      final endOfExhale = breathAt(0.999).$2;
      expect(endOfExhale, closeTo(0, 0.01));
    });

    test('has a spoken cue for every phase', () {
      for (final p in BreathPhase.values) {
        expect(breathCue(p), isNotEmpty);
      }
    });
  });

  group('Body scan (FR-73)', () {
    test('is at most 5 minutes in total and needs no audio', () {
      expect(bodyScanTotalSeconds(), lessThanOrEqualTo(300));
      expect(kBodyScanAreas.length, greaterThanOrEqualTo(6));
    });
  });

  group('Sessions (FR-44, FR-45)', () {
    test('a session survives being saved to a row and read back', () {
      final s = ExerciseSession(
        id: 3,
        exerciseId: ExerciseIds.scale,
        entryId: 9,
        data: {'thought': 'x', 'for': ['a', 'b'], '_step': 2},
        balancedThought: 'a fairer thought',
      );
      final row = s.toRow();
      row['id'] = 3;
      final back = ExerciseSession.fromRow(row);
      expect(back.id, 3);
      expect(back.exerciseId, ExerciseIds.scale);
      expect(back.entryId, 9);
      expect(back.data['thought'], 'x');
      expect(back.data['for'], ['a', 'b']);
      expect(back.data['_step'], 2);
      expect(back.balancedThought, 'a fairer thought');
      expect(back.isCompleted, isFalse);
    });

    test('a damaged data column gives an empty session instead of a crash', () {
      final back = ExerciseSession.fromRow({
        'id': 1,
        'exercise_id': 'sort',
        'status': 'in_progress',
        'data_json': '{not json',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      expect(back.data, isEmpty);
    });

    test('describeSession lists the answers of a finished exercise', () {
      final sort = ExerciseSession(
        exerciseId: ExerciseIds.sort,
        data: {
          'thought': 'I will fail',
          'cards': ['I have a quiz', 'I will fail'],
          'place': {'0': 'fact', '1': 'assumption'},
        },
        balancedThought: 'I can prepare',
      );
      final lines = describeSession(sort);
      expect(lines.any((l) => l.$1 == 'Fact' && l.$2 == 'I have a quiz'), isTrue);
      expect(lines.any((l) => l.$1 == 'Assumption' && l.$2 == 'I will fail'), isTrue);
      expect(lines.any((l) => l.$1 == 'Balanced thought' && l.$2 == 'I can prepare'), isTrue);

      final belief = ExerciseSession(
        exerciseId: ExerciseIds.belief,
        data: {'thought': 't', 'before': 80, 'after': 60},
      );
      expect(describeSession(belief).any((l) => l.$2.contains('Before: 80')), isTrue);

      final empty = ExerciseSession(exerciseId: ExerciseIds.gratitude);
      expect(describeSession(empty), isEmpty);
    });
  });
}
