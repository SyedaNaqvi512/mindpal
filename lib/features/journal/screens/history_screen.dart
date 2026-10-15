import 'package:flutter/material.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../widgets/entry_tile.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    entriesChanged.addListener(_load);
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await DatabaseService.getRecentEntries();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  void dispose() {
    entriesChanged.removeListener(_load);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No entries yet. Tap the + button to write your first one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rows.length,
                  itemBuilder: (_, i) => EntryTile(row: _rows[i]),
                ),
    );
  }
}