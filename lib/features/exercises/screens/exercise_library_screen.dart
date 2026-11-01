import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/section_header.dart';
import '../models/exercise_catalog.dart';
import '../models/exercise_session.dart';
import '../services/exercise_repository.dart';
import 'exercise_progress_screen.dart';
import 'exercise_runner_screen.dart';

/// FR-35: the Exercise Library. Each exercise is a card with a title, a
/// one-line description and a Start button. Reachable from Home.
class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  List<ExerciseSession> _unfinished = [];

  @override
  void initState() {
    super.initState();
    ExerciseRepository.changed.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    ExerciseRepository.changed.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await ExerciseRepository.inProgress();
      if (mounted) setState(() => _unfinished = rows);
    } catch (_) {}
  }

  Future<void> _open(ExerciseInfo info, {ExerciseSession? resume}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExerciseRunnerScreen(info: info, resume: resume),
    ));
    _load();
  }

  Future<void> _discard(ExerciseSession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this exercise?'),
        content: const Text('What you wrote so far will be deleted from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Discard')),
        ],
      ),
    );
    if (ok != true || s.id == null) return;
    try {
      await ExerciseRepository.delete(s.id!);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final core = kExercises.where((e) => e.priority != 'C').toList();
    final more = kExercises.where((e) => e.priority == 'C').toList();

    Widget card(ExerciseInfo e) => Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(e.icon, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(e.blurb, style: TextStyle(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Text(e.timeLabel,
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(onPressed: () => _open(e), child: const Text('Start')),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises'),
        actions: [
          IconButton(
            tooltip: 'Exercise progress',
            icon: const Icon(Symbols.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExerciseProgressScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            'Short activities you can drag, slide and tap. They are guided '
            'self-reflection, not therapy or treatment.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 12),
          Card(
            color: scheme.primaryContainer,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _open(quickExercise()),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Symbols.shuffle_rounded, color: scheme.primary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Try something quick',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Icon(Symbols.chevron_right_rounded, color: scheme.primary),
                  ],
                ),
              ),
            ),
          ),
          if (_unfinished.isNotEmpty) ...[
            const SizedBox(height: 8),
            const SectionHeader('Continue where you left off'),
            for (final s in _unfinished)
              if (exerciseById(s.exerciseId) != null)
                Card(
                  child: ListTile(
                    leading: Icon(exerciseById(s.exerciseId)!.icon, color: scheme.primary),
                    title: Text(exerciseById(s.exerciseId)!.title),
                    subtitle: const Text('Saved for later'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Discard',
                          icon: const Icon(Symbols.delete_rounded),
                          onPressed: () => _discard(s),
                        ),
                        FilledButton.tonal(
                          onPressed: () => _open(exerciseById(s.exerciseId)!, resume: s),
                          child: const Text('Resume'),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 8),
          const SectionHeader('Core exercises'),
          for (final e in core) card(e),
          const SizedBox(height: 8),
          const SectionHeader('More activities'),
          for (final e in more) card(e),
        ],
      ),
    );
  }
}
