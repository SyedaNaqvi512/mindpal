import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/exercises/bodies/exercise_guides.dart';
import 'package:mindpal/features/exercises/models/exercise_catalog.dart';
import 'package:mindpal/features/exercises/models/exercise_completion.dart';
import 'package:mindpal/features/exercises/models/exercise_logic.dart';

void main() {
  test('skipping everything never completes any exercise', () {
    for (final e in kExercises) {
      final r = evaluateCompletion(e.id, <String, dynamic>{'_step': 9});
      expect(r.complete, isFalse, reason: e.id);
      expect(r.missing, isNotNull, reason: e.id);
    }
  });

  test('meaningful text needs real words, not filler', () {
    expect(isMeaningful(''), isFalse);
    expect(isMeaningful('  '), isFalse);
    expect(isMeaningful('a'), isFalse);
    expect(isMeaningful('...'), isFalse);
    expect(isMeaningful('aaa'), isFalse);
    expect(isMeaningful('ok'), isFalse);
    expect(isMeaningful('Tired today'), isTrue);
    expect(isMeaningful('تھکا ہوا'), isTrue);
  });

  test('a filled thought record completes, a missing evidence does not', () {
    final d = <String, dynamic>{
      'situation': 'Team meeting on Tuesday',
      'thought': 'They do not value my work',
      'feelings': ['Sad'],
      'for': ['My idea was not noted'],
    };
    expect(evaluateCompletion(ExerciseIds.thoughtRecord, d).complete, isFalse);
    d['against'] = ['My report was praised'];
    expect(evaluateCompletion(ExerciseIds.thoughtRecord, d).complete, isTrue);
  });

  test('sort needs statements placed', () {
    final d = <String, dynamic>{
      'thought': 'I will fail. Everyone will laugh.',
      'cards': ['I will fail', 'Everyone will laugh'],
      'place': <String, dynamic>{'0': 'assumption'},
    };
    expect(evaluateCompletion(ExerciseIds.sort, d).complete, isFalse);
    (d['place'] as Map)['1'] = 'assumption';
    expect(evaluateCompletion(ExerciseIds.sort, d).complete, isTrue);
  });

  test('gratitude needs three things and a reason', () {
    final d = <String, dynamic>{
      'things': ['Music', 'Some rest'],
      'why': 'It helped me relax',
    };
    expect(evaluateCompletion(ExerciseIds.gratitude, d).complete, isFalse);
    d['things'] = ['Music', 'Some rest', 'A kind word'];
    expect(evaluateCompletion(ExerciseIds.gratitude, d).complete, isTrue);
  });

  test('problem solving needs two options and a chosen one', () {
    final d = <String, dynamic>{
      'problem': 'Three assignments are due together',
      'options': ['Ask for time'],
      'chosen': 'Ask for time',
      'first': 'Write the headings',
    };
    expect(evaluateCompletion(ExerciseIds.problemSolving, d).complete, isFalse);
    d['options'] = ['Ask for time', 'Start with the short one'];
    expect(evaluateCompletion(ExerciseIds.problemSolving, d).complete, isTrue);
  });

  test('breathing and anchor need the bubble to finish', () {
    expect(evaluateCompletion(ExerciseIds.breathing, {'breaths': 4}).complete, isTrue);
    expect(evaluateCompletion(ExerciseIds.breathing, {'breaths': 1}).complete, isFalse);
    final a = <String, dynamic>{'phrase': 'One breath at a time.'};
    expect(evaluateCompletion(ExerciseIds.anchor, a).complete, isFalse);
    a['anchored'] = true;
    expect(evaluateCompletion(ExerciseIds.anchor, a).complete, isTrue);
  });

  test('grounding needs most senses and the body scan needs most areas', () {
    final g = <String, dynamic>{'see': 5, 'feel': 4, 'hear': 3};
    expect(evaluateCompletion(ExerciseIds.grounding, g).complete, isFalse);
    g['smell'] = 2;
    expect(evaluateCompletion(ExerciseIds.grounding, g).complete, isTrue);

    final need = bodyScanNeeded();
    final scan = <String, dynamic>{'_done': List.generate(need - 1, (i) => i)};
    expect(evaluateCompletion(ExerciseIds.bodyScan, scan).complete, isFalse);
    scan['_done'] = List.generate(need, (i) => i);
    expect(evaluateCompletion(ExerciseIds.bodyScan, scan).complete, isTrue);
  });

  test('guides and messages never use scoring or failure words (FR-43)', () {
    final texts = <String>[
      for (final m in kStepGuides.values)
        for (final g in m.values) ...[g.why, if (g.example != null) g.example!],
      for (final g in kExerciseGuideFallback.values) g.why,
    ];
    for (final e in kExercises) {
      final r = evaluateCompletion(e.id, <String, dynamic>{});
      if (r.missing != null) texts.add(r.missing!);
    }
    for (final t in texts) {
      for (final w in kForbiddenExerciseWords) {
        expect(t.toLowerCase().contains(w), isFalse, reason: '"$w" in "$t"');
      }
    }
  });

  test('every exercise with steps has a guide for most steps', () {
    for (final id in kStepGuides.keys) {
      expect(kExercises.any((e) => e.id == id), isTrue, reason: id);
    }
  });
}
