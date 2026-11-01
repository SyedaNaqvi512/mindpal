import 'package:flutter/widgets.dart';

import '../models/exercise_catalog.dart';
import '../models/exercise_session.dart';

/// One step of an exercise. Every step can be skipped (FR-41): when
/// [canContinue] is false the main button reads "Skip".
class ExerciseStep {
  const ExerciseStep({required this.title, required this.build, this.canContinue});

  final String title;
  final Widget Function(BuildContext context, ExerciseController c) build;
  final bool Function(ExerciseController c)? canContinue;
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

  void next() => goTo(step + 1);
  void back() => goTo(step - 1);
}
