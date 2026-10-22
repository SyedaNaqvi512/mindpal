import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../models/entry_format.dart';
import '../models/mood.dart';
import '../widgets/reflection_panel.dart';
import 'new_entry_screen.dart';

/// FR-16: one entry with its mood, tags, text and saved reflection.
/// Also the place to edit (FR-14) or delete an entry.
class EntryDetailScreen extends StatefulWidget {
  const EntryDetailScreen({
    super.key,
    required this.entryId,
    required this.onSignedOut,
  });

  final int entryId;
  final VoidCallback onSignedOut;

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  Map<String, dynamic>? _row;
  bool _loaded = false;
  int _panelVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await DatabaseService.getEntry(widget.entryId);
      if (!mounted) return;
      setState(() {
        _row = row;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NewEntryScreen(
        onSignedOut: widget.onSignedOut,
        editId: widget.entryId,
      ),
    ));
    if (mounted) {
      setState(() => _panelVersion++);
      _load();
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text(
            'The entry and its reflection will be removed from this phone. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await DatabaseService.deleteJournalEntry(widget.entryId);
      entriesChanged.value++;
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Entry deleted.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete the entry.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final row = _row;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entry'),
        actions: [
          if (row != null) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Symbols.edit_rounded),
              onPressed: _edit,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Symbols.delete_rounded),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : row == null
              ? const Center(child: Text('This entry no longer exists.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Text(Mood.byValue(row['mood'] as int?).emoji,
                            style: const TextStyle(fontSize: 40)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(Mood.byValue(row['mood'] as int?).label,
                                  style: text.titleMedium),
                              Text(
                                formatEntryDateTime(row['created_at'] as String) +
                                    (row['updated_at'] != null ? ' · edited' : ''),
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (FeelingTags.parse(row['tags']).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final t in FeelingTags.parse(row['tags']))
                            Chip(label: Text(t)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    SelectableText(row['content'] as String,
                        style: text.bodyLarge),
                    const SizedBox(height: 24),
                    ReflectionPanel(entryId: widget.entryId, version: _panelVersion),
                    const SizedBox(height: 24),
                    Text(
                      'MindPal is a reflection tool, not a therapist or medical advice.',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
    );
  }
}
