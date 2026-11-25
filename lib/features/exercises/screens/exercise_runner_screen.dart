import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../../../core/motion/motion.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/motion_kit.dart';
import '../bodies/exercise_content.dart';
import '../bodies/exercise_registry.dart';
import '../models/exercise_catalog.dart';
import '../models/exercise_completion.dart';
import '../models/exercise_session.dart';
import '../services/exercise_controller.dart';
import '../services/exercise_repository.dart';
import '../widgets/breathing_bubble.dart';
import '../../../core/widgets/toast.dart';
import '../services/exercise_telemetry.dart';

const String kExerciseLabel =
    'Guided self-reflection activity. Not therapy or treatment.';

/// Runs one exercise: introduction and time (FR-41), the steps (each can be
/// skipped, FR-41), finish later or discard (FR-44), then saves it (FR-45).
class ExerciseRunnerScreen extends StatefulWidget {
  const ExerciseRunnerScreen({
    super.key,
    required this.info,
    this.entryId,
    this.resume,
  });

  final ExerciseInfo info;

  /// The journal entry this exercise belongs to, if it was opened from one.
  final int? entryId;

  /// An unfinished session to continue.
  final ExerciseSession? resume;

  @override
  State<ExerciseRunnerScreen> createState() => _ExerciseRunnerScreenState();
}

class _ExerciseRunnerScreenState extends State<ExerciseRunnerScreen> {
  late final ExerciseController _c;
  late final List<ExerciseStep> _steps;
  late bool _started;
  bool _saving = false;
  bool _summary = false;
  Timer? _timer;
  int _timedStep = -1;

  @override
  void initState() {
    super.initState();
    final session = widget.resume ??
        ExerciseSession(exerciseId: widget.info.id, entryId: widget.entryId);
    _steps = buildSteps(widget.info,
        seed: session.createdAt.millisecondsSinceEpoch);
    _c = ExerciseController(info: widget.info, session: session)
      ..setTotal(_steps.isEmpty ? 1 : _steps.length);
    _started = widget.resume != null;
    _c.addListener(_syncTimer);
    _syncTimer();
    _loadEntry(session.entryId);
  }

  /// A timed reading step (the body scan) counts as done once the user has
  /// stayed on it for most of the suggested time. Skipping is still allowed.
  void _syncTimer() {
    if (!_started || _steps.isEmpty) return;
    final i = _c.step.clamp(0, _steps.length - 1);
    if (i == _timedStep) return;
    _timedStep = i;
    _timer?.cancel();
    final m = _steps[i].minSeconds;
    if (m == null || doneSteps(_c.data).contains(i)) return;
    _timer = Timer(Duration(seconds: m), () {
      if (!mounted || _c.step != i) return;
      _c.markDone(i);
      _c.refresh();
    });
  }

  int _skippedCount() {
    final done = doneSteps(_c.data);
    var n = 0;
    for (var i = 0; i < _steps.length; i++) {
      final st = _steps[i];
      if (!st.asksForSomething) continue;
      final ok = st.canContinue != null ? st.canContinue!(_c) : done.contains(i);
      if (!ok) n++;
    }
    return n;
  }

  Future<void> _loadEntry(int? id) async {
    if (id == null || !widget.info.needsThought) return;
    try {
      final row = await DatabaseService.getEntry(id);
      if (!mounted || row == null) return;
      _c.entryText = row['content'] as String?;
      _c.refresh();
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.removeListener(_syncTimer);
    _c.dispose();
    super.dispose();
  }

  Future<void> _saveForLater() async {
    if (_saving) return;
    _saving = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      _c.session.status = ExerciseSession.inProgress;
      await ExerciseRepository.save(_c.session);
    } catch (_) {
      _saving = false;
      Toast.show(messenger, 'Could not save on this phone. Please try again.',
          kind: ToastKind.error);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(false);
    Toast.show(messenger, 'Saved. Open it from the Exercise Library to continue.',
        kind: ToastKind.success);
  }

  Future<void> _finish() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    // Skipping everything never makes an exercise "completed".
    final result = evaluateCompletion(_c.session.exerciseId, _c.data);
    if (!result.complete) {
      Toast.show(messenger, result.missing ?? 'A few answers are still needed.',
          kind: ToastKind.info);
      return;
    }
    _saving = true;
    try {
      _c.session.status = ExerciseSession.completed;
      _c.session.completedAt = DateTime.now();
      await ExerciseRepository.save(_c.session);
      entriesChanged.value++;
      // FR-61: only the exercise type goes to the server, never what was written.
      unawaited(ExerciseTelemetry.completed(_c.session.exerciseId));
    } catch (_) {
      _saving = false;
      Toast.show(messenger, 'Could not save on this phone. Please try again.',
          kind: ToastKind.error);
      return;
    }
    if (!mounted) return;
    _saving = false;
    setState(() => _summary = true);
  }

  Future<void> _setAfterFeel(String v) async {
    setState(() => _c.session.data['after_feel'] = v);
    try {
      await ExerciseRepository.save(_c.session);
    } catch (_) {}
  }

  Future<void> _discard() async {
    final id = _c.session.id;
    try {
      if (id != null) await ExerciseRepository.delete(id);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _attemptLeave() async {
    if (_summary) {
      Navigator.of(context).pop(true);
      return;
    }
    if (!_started || !_c.dirty) {
      Navigator.of(context).pop(false);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this exercise?'),
        content: const Text(
            'You can save your place and continue later, or discard what you have so far.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop('stay'),
              child: const Text('Keep going')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop('discard'),
              child: const Text('Discard')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop('save'),
              child: const Text('Save for later')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'save') await _saveForLater();
    if (choice == 'discard') await _discard();
  }

  Future<void> _warmUp() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BreathingWarmUpScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _attemptLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(info.title),
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Symbols.close_rounded),
            onPressed: _attemptLeave,
          ),
          actions: [
            if (_started && !_summary)
              TextButton(onPressed: _saveForLater, child: const Text('Finish later')),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _c,
            builder: (context, _) => _summary
                ? _summaryView(context)
                : _started
                    ? _stepView(context)
                    : _introView(context),
          ),
        ),
      ),
    );
  }

  Widget _introView(BuildContext context) {
    final info = widget.info;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Floating(
            child: Container(
              width: 84,
              height: 84,
              decoration:
                  BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(info.icon, size: 40, color: scheme.primary),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(info.title,
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.timer_rounded, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(info.timeLabel, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 16),
        Text(info.intro, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
        if (_steps.length > 1) ...[
          const SizedBox(height: 16),
          Text('What you will do', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          for (var n = 0; n < _steps.length; n++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: scheme.primaryContainer, shape: BoxShape.circle),
                    child: Text('${n + 1}',
                        style: TextStyle(fontSize: 11, color: scheme.onPrimaryContainer)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_steps[n].title)),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        Text(
          'You can skip a step if it does not fit. To finish, the main answers '
          'are needed, or tap Finish later to save your place.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
          ),
        ),
        // The buttons and the label stay in view however long the list is.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () {
                  setState(() => _started = true);
                  _syncTimer();
                },
                child: const Text('Start'),
              ),
              if (info.id != ExerciseIds.breathing) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _warmUp,
                  icon: const Icon(Symbols.air_rounded),
                  label: const Text('Warm up with breathing first'),
                ),
              ],
              const SizedBox(height: 10),
              Text(kExerciseLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = describeSession(_c.session);
    final skipped = _skippedCount();
    final felt = '${_c.session.data['after_feel'] ?? ''}';
    return Stack(children: [
      ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: PopIn(
            child: Container(
              width: 84,
              height: 84,
              decoration:
                  BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(Symbols.check_rounded, size: 44, color: scheme.primary),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('${widget.info.title} is done',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text('Saved in Exercise Progress, encrypted on this phone.',
            textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
        if (skipped > 0) ...[
          const SizedBox(height: 6),
          Text(
            'You skipped $skipped ${skipped == 1 ? 'step' : 'steps'}. '
            'You can do this exercise again whenever you like.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 16),
        if (lines.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What you did',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final (label, text) in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                          Text(text),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (kTakeAway[widget.info.id] != null)
          _NoteCard(
            icon: Symbols.lightbulb_rounded,
            title: 'To take with you',
            text: kTakeAway[widget.info.id]!,
          ),
        if (kTryToday[widget.info.id] != null)
          _NoteCard(
            icon: Symbols.flag_rounded,
            title: 'Try this today',
            text: pickOne(kTryToday[widget.info.id]!,
                _c.session.createdAt.millisecondsSinceEpoch, 3),
          ),
        const SizedBox(height: 16),
        Text('How do you feel now?', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in const ['Calmer', 'About the same', 'Heavier', 'Not sure'])
              ChoiceChip(
                label: Text(o),
                selected: felt == o,
                onSelected: (_) => _setAfterFeel(o),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Optional. Any answer is fine.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Close'),
        ),
        const SizedBox(height: 16),
        Text(kExerciseLabel,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      ],
    ),
      const Positioned(top: 0, left: 0, right: 0, child: Celebration()),
    ]);
  }

  Widget _stepView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_steps.isEmpty) {
      return const Center(child: Text('This exercise has no steps yet.'));
    }
    final i = _c.step.clamp(0, _steps.length - 1);
    final step = _steps[i];
    final can = step.canContinue?.call(_c) ?? true;
    final last = i == _steps.length - 1;
    final result = last ? evaluateCompletion(widget.info.id, _c.data) : null;

    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: (i + 1) / _steps.length),
          duration: Motion.of(context, const Duration(milliseconds: 350)),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 4),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Step ${i + 1} of ${_steps.length}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              header: true,
              child: Text(step.title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (step.guide != null) _GuideCard(guide: step.guide!),
                FadeSlideIn(
                  key: ValueKey('${widget.info.id}-$i'),
                  duration: const Duration(milliseconds: 280),
                  offset: 0.04,
                  child: step.build(context, _c),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text(kExerciseLabel,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (result != null && !result.complete)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'To finish: ${result.missing}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                ),
              Row(
                children: [
                  if (i > 0)
                    TextButton.icon(
                      onPressed: _c.back,
                      icon: const Icon(Symbols.arrow_back_rounded),
                      label: const Text('Back'),
                    ),
                  const Spacer(),
                  if (last && result!.complete)
                    FilledButton(onPressed: _finish, child: const Text('Finish'))
                  else if (last)
                    OutlinedButton(
                        onPressed: _saveForLater, child: const Text('Save for later'))
                  else if (can)
                    FilledButton(onPressed: _c.next, child: const Text('Next'))
                  else
                    OutlinedButton(onPressed: _c.next, child: const Text('Skip')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide});

  final StepGuide guide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.lightbulb_rounded, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guide.why, style: const TextStyle(height: 1.4)),
                if (guide.example != null) ...[
                  const SizedBox(height: 6),
                  Text('For example: ${guide.example}',
                      style: TextStyle(
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                          color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A short breathing warm-up before another exercise (FR-39).
class BreathingWarmUpScreen extends StatelessWidget {
  const BreathingWarmUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Breathing warm-up')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Take a few slow breaths before you begin. Follow the bubble.',
                textAlign: TextAlign.center,
              ),
              const Expanded(child: Center(child: BreathingBubble(cycles: 3))),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('I am ready'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
