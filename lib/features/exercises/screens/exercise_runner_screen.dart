import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../bodies/exercise_registry.dart';
import '../models/exercise_catalog.dart';
import '../models/exercise_session.dart';
import '../services/exercise_controller.dart';
import '../services/exercise_repository.dart';
import '../widgets/breathing_bubble.dart';

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

  @override
  void initState() {
    super.initState();
    final session = widget.resume ??
        ExerciseSession(exerciseId: widget.info.id, entryId: widget.entryId);
    _steps = buildSteps(widget.info);
    _c = ExerciseController(info: widget.info, session: session)
      ..setTotal(_steps.isEmpty ? 1 : _steps.length);
    _started = widget.resume != null;
    _loadEntry(session.entryId);
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
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not save on this phone. Please try again.'),
      ));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(false);
    messenger.showSnackBar(const SnackBar(
      content: Text('Saved. Open it from the Exercise Library to continue.'),
    ));
  }

  Future<void> _finish() async {
    if (_saving) return;
    _saving = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      _c.session.status = ExerciseSession.completed;
      _c.session.completedAt = DateTime.now();
      await ExerciseRepository.save(_c.session);
      entriesChanged.value++;
    } catch (_) {
      _saving = false;
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not save on this phone. Please try again.'),
      ));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
    messenger.showSnackBar(const SnackBar(
      content: Text('Saved in Exercise Progress, encrypted on this phone.'),
    ));
  }

  Future<void> _discard() async {
    final id = _c.session.id;
    try {
      if (id != null) await ExerciseRepository.delete(id);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _attemptLeave() async {
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
            if (_started)
              TextButton(onPressed: _saveForLater, child: const Text('Finish later')),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _c,
            builder: (context, _) => _started ? _stepView(context) : _introView(context),
          ),
        ),
      ),
    );
  }

  Widget _introView(BuildContext context) {
    final info = widget.info;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(info.icon, size: 40, color: scheme.primary),
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
        const SizedBox(height: 12),
        Text(
          'You can skip any step, or tap Finish later to save your place.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => setState(() => _started = true),
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
        const SizedBox(height: 20),
        Text(kExerciseLabel,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      ],
    );
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

    return Column(
      children: [
        LinearProgressIndicator(value: (i + 1) / _steps.length, minHeight: 4),
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
            child: KeyedSubtree(
              key: ValueKey('${widget.info.id}-$i'),
              child: step.build(context, _c),
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
          child: Row(
            children: [
              if (i > 0)
                TextButton.icon(
                  onPressed: _c.back,
                  icon: const Icon(Symbols.arrow_back_rounded),
                  label: const Text('Back'),
                ),
              const Spacer(),
              if (last)
                FilledButton(onPressed: _finish, child: const Text('Finish'))
              else if (can)
                FilledButton(onPressed: _c.next, child: const Text('Next'))
              else
                OutlinedButton(onPressed: _c.next, child: const Text('Skip')),
            ],
          ),
        ),
      ],
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
