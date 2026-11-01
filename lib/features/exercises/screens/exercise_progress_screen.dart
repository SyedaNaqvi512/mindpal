import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/empty_state.dart';
import '../../journal/models/entry_format.dart';
import '../bodies/exercise_registry.dart';
import '../models/exercise_catalog.dart';
import '../models/exercise_session.dart';
import '../services/exercise_repository.dart';

/// FR-45: previous exercises and their answers. FR-52: the user can delete them.
class ExerciseProgressScreen extends StatefulWidget {
  const ExerciseProgressScreen({super.key});

  @override
  State<ExerciseProgressScreen> createState() => _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  List<ExerciseSession> _rows = [];
  bool _loaded = false;

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
      final rows = await ExerciseRepository.completed();
      if (mounted) {
        setState(() {
          _rows = rows;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteOne(ExerciseSession s) async {
    if (s.id == null) return;
    if (!await _confirm('Delete these answers?', 'They will be removed from this phone.')) return;
    try {
      await ExerciseRepository.delete(s.id!);
    } catch (_) {}
  }

  Future<void> _deleteAll() async {
    if (!await _confirm('Delete all exercise answers?',
        'Every saved exercise and its answers will be removed from this phone. Your journal entries stay.')) {
      return;
    }
    try {
      await ExerciseRepository.deleteAll();
    } catch (_) {}
  }

  void _show(ExerciseSession s) {
    final info = exerciseById(s.exerciseId);
    final lines = describeSession(s);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Text(info?.title ?? 'Exercise', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(formatEntryDateTime((s.completedAt ?? s.updatedAt).toIso8601String()),
                style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            if (lines.isEmpty) const Text('No written answers were saved for this exercise.'),
            for (final l in lines) ...[
              Text(l.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              SelectableText(l.$2),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _deleteOne(s);
              },
              icon: const Icon(Symbols.delete_rounded),
              label: const Text('Delete these answers'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise progress'),
        actions: [
          if (_rows.isNotEmpty)
            IconButton(
              tooltip: 'Delete all exercise answers',
              icon: const Icon(Symbols.delete_sweep_rounded),
              onPressed: _deleteAll,
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const EmptyState(
                  icon: Symbols.self_improvement_rounded,
                  title: 'Nothing here yet',
                  message: 'Exercises you finish are saved here, encrypted on this phone.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _rows.length,
                  itemBuilder: (_, i) {
                    final s = _rows[i];
                    final info = exerciseById(s.exerciseId);
                    final when = formatEntryDateTime((s.completedAt ?? s.updatedAt).toIso8601String());
                    return Card(
                      child: ListTile(
                        leading: Icon(info?.icon ?? Symbols.self_improvement_rounded,
                            color: Theme.of(context).colorScheme.primary),
                        title: Text(info?.title ?? s.exerciseId),
                        subtitle: Text(when),
                        trailing: const Icon(Symbols.chevron_right_rounded),
                        onTap: () => _show(s),
                      ),
                    );
                  },
                ),
    );
  }
}
