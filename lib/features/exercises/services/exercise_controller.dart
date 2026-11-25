import 'package:flutter/widgets.dart';

import '../models/exercise_catalog.dart';
import '../models/exercise_session.dart';

/// One step of an exercise. Every step can be skipped (FR-41): when
/// [canContinue] is false the main button reads "Skip".
class ExerciseStep {
  const ExerciseStep({
    required this.title,
    required this.build,
    this.canContinue,
    this.minSeconds,
    this.guide,
  });

  final String title;
  final Widget Function(BuildContext context, ExerciseController c) build;
  final bool Function(ExerciseController c)? canContinue;

  /// For timed reading steps: how long the user should stay for the step to
  /// count as done. Leaving earlier is allowed (FR-41) but does not count.
  final int? minSeconds;

  /// A short "why this helps" with an example, shown above the step.
  final StepGuide? guide;

  ExerciseStep withGuide(StepGuide? g) => ExerciseStep(
        title: title,
        build: build,
        canContinue: canContinue,
        minSeconds: minSeconds,
        guide: guide ?? g,
      );

  /// True when this step asks for something (an answer or some time), so
  /// leaving it empty counts as skipped.
  bool get asksForSomething => canContinue != null || minSeconds != null;
}

class StepGuide {
  const StepGuide(this.why, [this.example]);

  final String why;
  final String? example;
}

/// Holds the running state of one exercise session: the answers, the current
/// step and whether anything changed since the last save.
class ExerciseController extends ChangeNotifier {
  ExerciseController({required this.info, required this.session, this.entryText});

  final ExerciseInfo info;
  final ExerciseSession session;

  /// The text of the related journal entry. It is only used to prefill a
  /// thought after the user agrees (FR-47).
  String? entryText;

  bool dirty = false;
  int _total = 1;

  Map<String, dynamic> get data => session.data;

  int get step => (data['_step'] as int?) ?? 0;
  int get total => _total;
  bool get isLast => step >= _total - 1;

  void setTotal(int n) => _total = n;

  /// Redraws the exercise (used after the related entry text has loaded).
  void refresh() => notifyListeners();

  void set(String key, Object? value) {
    data[key] = value;
    dirty = true;
    notifyListeners();
  }

  /// Sets a value without redrawing (used while typing, to keep the cursor).
  void setQuiet(String key, Object? value) {
    data[key] = value;
    dirty = true;
  }

  String text(String key) => (data[key] as String?) ?? '';

  List<String> list(String key) {
    final v = data[key];
    return v is List ? v.map((e) => '$e').toList() : <String>[];
  }

  int intOf(String key, [int fallback = 0]) {
    final v = data[key];
    return v is num ? v.toInt() : fallback;
  }

  void goTo(int s) {
    data['_step'] = s.clamp(0, _total - 1);
    dirty = true;
    notifyListeners();
  }

  /// Remembers that a timed step was really read (used by the body scan).
  void markDone(int index) {
    final done = (data['_done'] is List)
        ? [for (final e in data['_done'] as List) if (e is num) e.toInt()]
        : <int>[];
    if (!done.contains(index)) {
      done.add(index);
      data['_done'] = done;
      dirty = true;
    }
  }

  void next() => goTo(step + 1);
  void back() => goTo(step - 1);
}
