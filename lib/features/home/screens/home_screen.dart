import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../../journal/widgets/entry_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onNewEntry,
    required this.onSeeAll,
    required this.onSignedOut,
  });

  final VoidCallback onNewEntry;
  final VoidCallback onSeeAll;
  final VoidCallback onSignedOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _recent = [];

  @override
  void initState() {
    super.initState();
    entriesChanged.addListener(_load);
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await DatabaseService.getRecentEntries(limit: 3);
      if (!mounted) return;
      setState(() => _recent = rows);
    } catch (_) {}
  }

  @override
  void dispose() {
    entriesChanged.removeListener(_load);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('MindPal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('How are you feeling today?', style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Write what is on your mind. Your entries stay on this phone.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: widget.onNewEntry,
            icon: const Icon(Symbols.add_rounded),
            label: const Text('New entry'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('Recent entries', style: text.titleMedium)),
              if (_recent.isNotEmpty)
                TextButton(
                  onPressed: widget.onSeeAll,
                  child: const Text('See all'),
                ),
            ],
          ),
          if (_recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No entries yet. Your first one takes a minute.',
                style: TextStyle(color: muted),
              ),
            )
          else
            for (final row in _recent)
              EntryTile(row: row, onSignedOut: widget.onSignedOut),
          const SizedBox(height: 24),
          Text(
            'MindPal is a reflection tool, not a therapist or medical advice.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }
}
