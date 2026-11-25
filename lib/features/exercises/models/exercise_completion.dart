import 'exercise_catalog.dart';
import 'exercise_logic.dart';

/// Whether an exercise counts as completed. Every step can still be skipped
/// (FR-41), but an exercise is only saved as Completed when the answers that
/// matter for it were really given. There is no scoring (FR-43): this only
/// decides "finished" or "not finished yet".
class CompletionResult {
  const CompletionResult(this.complete, [this.missing]);

  final bool complete;

  /// A plain, kind sentence saying what is still needed. Null when complete.
  final String? missing;
}

/// A written answer with some substance: at least three characters, two of
/// them letters, and not one character repeated ("aaa", "...", "   ").
bool isMeaningful(Object? value) {
  final t = '${value ?? ''}'.trim();
  if (t.length < 3) return false;
  final letters = RegExp(r'\p{L}', unicode: true).allMatches(t).length;
  if (letters < 2) return false;
  return t.runes.toSet().length >= 2;
}

List<String> _list(Map<String, dynamic> d, String k) {
  final v = d[k];
  if (v is! List) return const [];
  return [
    for (final e in v)
      if ('$e'.trim().isNotEmpty) '$e'.trim(),
  ];
}

int _int(Map<String, dynamic> d, String k) {
  final v = d[k];
  return v is num ? v.toInt() : 0;
}

/// Steps of the body scan the user stayed on long enough, saved by the runner.
List<int> doneSteps(Map<String, dynamic> d) {
  final v = d['_done'];
  if (v is! List) return const [];
  return [for (final e in v) if (e is num) e.toInt()];
}

/// How many of the body scan areas must be read for it to count.
int bodyScanNeeded() => (kBodyScanAreas.length * 0.8).ceil();

CompletionResult evaluateCompletion(String exerciseId, Map<String, dynamic> d) {
  CompletionResult need(bool ok, String message) =>
      ok ? const CompletionResult(true) : CompletionResult(false, message);

  switch (exerciseId) {
    case ExerciseIds.sort:
      final cards = _list(d, 'cards');
      final place = d['place'] is Map ? d['place'] as Map : const {};
      final placed = place.values.where((v) => v == 'fact' || v == 'assumption').length;
      final wanted = cards.length >= 2 ? 2 : 1;
      if (!isMeaningful(d['thought'])) {
        return const CompletionResult(false, 'Write the thought you want to look at.');
      }
      return need(cards.isNotEmpty && placed >= wanted,
          'Place at least $wanted ${wanted == 1 ? 'statement' : 'statements'} as Fact or Assumption.');
    case ExerciseIds.scale:
      if (!isMeaningful(d['thought'])) {
        return const CompletionResult(false, 'Write the thought you want to weigh.');
      }
      return need(_list(d, 'for').isNotEmpty && _list(d, 'against').isNotEmpty,
          'Add at least one piece of evidence for the thought and one against it.');
    case ExerciseIds.belief:
      if (!isMeaningful(d['thought'])) {
        return const CompletionResult(false, 'Write the thought you want to rate.');
      }
      if (d['before'] == null || d['after'] == null) {
        return const CompletionResult(false, 'Rate the thought before and after you think it through.');
      }
      return need(isMeaningful(d['support']) || isMeaningful(d['doubt']),
          'Write at least one thing in "Think it through".');
    case ExerciseIds.breathing:
      return need(_int(d, 'breaths') >= 4, 'Follow the bubble until the four breaths are done.');
    case ExerciseIds.grounding:
      const need5 = {'see': 5, 'feel': 4, 'hear': 3, 'smell': 2, 'taste': 1};
      final full = need5.entries.where((e) => _int(d, e.key) >= e.value).length;
      return need(full >= 4 && _int(d, 'see') >= 5,
          'Tap through at least four of the five senses, starting with what you can see.');
    case ExerciseIds.thoughtRecord:
      if (!isMeaningful(d['situation'])) {
        return const CompletionResult(false, 'Describe the situation.');
      }
      if (!isMeaningful(d['thought'])) {
        return const CompletionResult(false, 'Write the thought that went through your mind.');
      }
      if (_list(d, 'feelings').isEmpty) {
        return const CompletionResult(false, 'Pick at least one feeling.');
      }
      return need(_list(d, 'for').isNotEmpty && _list(d, 'against').isNotEmpty,
          'Add at least one piece of evidence for the thought and one against it.');
    case ExerciseIds.gratitude:
      if (_list(d, 'things').length < 3) {
        return const CompletionResult(false, 'Pick three things you appreciate.');
      }
      return need(isMeaningful(d['why']), 'Write a few words about why one of them matters.');
    case ExerciseIds.selfCompassion:
      if (!isMeaningful(d['hard'])) {
        return const CompletionResult(false, 'Write what is hard right now, in a few words.');
      }
      if (_list(d, 'feelings').isEmpty) {
        return const CompletionResult(false, 'Pick at least one feeling.');
      }
      return need(isMeaningful(d['kind']), 'Write one kind sentence to yourself.');
    case ExerciseIds.problemSolving:
      if (!isMeaningful(d['problem'])) {
        return const CompletionResult(false, 'Describe the problem.');
      }
      if (_list(d, 'options').length < 2) {
        return const CompletionResult(false, 'Add at least two options.');
      }
      if ('${d['chosen'] ?? ''}'.trim().isEmpty) {
        return const CompletionResult(false, 'Choose the option that feels most doable.');
      }
      return need(isMeaningful(d['first']), 'Write one small first step.');
    case ExerciseIds.checkIn:
      return need(d['mood'] != null && _list(d, 'words').isNotEmpty,
          'Show your mood and tap at least one word for today.');
    case ExerciseIds.stop:
      return need(
          _int(d, 't') >= 1 && _list(d, 'observe').isNotEmpty && _list(d, 'proceed').isNotEmpty,
          'Take your breath, tap what you notice, and choose how to carry on.');
    case ExerciseIds.anchor:
      if (!isMeaningful(d['phrase'])) {
        return const CompletionResult(false, 'Choose or write a phrase.');
      }
      return need(d['anchored'] == true, 'Read your phrase with the circle until it finishes.');
    case ExerciseIds.bodyScan:
      final n = bodyScanNeeded();
      return need(doneSteps(d).toSet().length >= n,
          'Stay with at least $n of the ${kBodyScanAreas.length} areas for the suggested time.');
    default:
      return const CompletionResult(true);
  }
}
