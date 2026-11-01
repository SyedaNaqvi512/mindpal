import 'package:flutter/material.dart';

import '../../journal/models/entry_format.dart';
import '../models/exercise_catalog.dart';
import '../models/exercise_session.dart';
import '../services/exercise_repository.dart';

/// FR-48: exercises done for an entry, with the balanced thought saved with it.
class EntryExercisesSection extends StatefulWidget {
  const EntryExercisesSection({super.key, required this.entryId});

  final int entryId;

  @override
  State<EntryExercisesSection> createState() => _EntryExercisesSectionState();
}

class _EntryExercisesSectionState extends State<EntryExercisesSection> {
  List<ExerciseSession> _rows = [];

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
      final rows = await ExerciseRepository.forEntry(widget.entryId);
      if (mounted) setState(() => _rows = rows);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_rows.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exercises for this entry', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final s in _rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exerciseById(s.exerciseId)?.title ?? s.exerciseId,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      formatEntryDateTime((s.completedAt ?? s.updatedAt).toIso8601String()),
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    if ((s.balancedThought ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Balanced thought',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary)),
                      SelectableText(s.balancedThought!.trim()),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
