import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../models/entry_format.dart';
import '../models/mood.dart';
import '../widgets/entry_tile.dart';

/// FR-15: entries by date, with keyword search and date-range and mood filters.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _rows = [];
  bool _loaded = false;
  int? _mood;
  DateTimeRange? _range;
  int _loadId = 0;

  bool get _filtering =>
      _search.text.trim().isNotEmpty || _mood != null || _range != null;

  @override
  void initState() {
    super.initState();
    entriesChanged.addListener(_load);
    _load();
  }

  Future<void> _load() async {
    final id = ++_loadId;
    try {
      final rows = await DatabaseService.searchEntries(
        query: _search.text,
        mood: _mood,
        from: _range?.start,
        to: _range?.end,
      );
      if (!mounted || id != _loadId) return;
      setState(() {
        _rows = rows;
        _loaded = true;
      });
    } catch (_) {
      if (mounted && id == _loadId) setState(() => _loaded = true);
    }
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    _load();
  }

  void _clear() {
    _search.clear();
    setState(() {
      _mood = null;
      _range = null;
    });
    _load();
  }

  @override
  void dispose() {
    entriesChanged.removeListener(_load);
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search your entries',
                prefixIcon: const Icon(Symbols.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Symbols.close_rounded),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                          _load();
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                ActionChip(
                  avatar: const Icon(Symbols.date_range_rounded, size: 18),
                  label: Text(_range == null
                      ? 'Any date'
                      : '${formatShortDate(_range!.start)} - ${formatShortDate(_range!.end)}'),
                  onPressed: _pickRange,
                ),
                const SizedBox(width: 8),
                for (final m in Mood.all) ...[
                  FilterChip(
                    label: Text('${m.emoji} ${m.label}'),
                    selected: _mood == m.value,
                    onSelected: (on) {
                      setState(() => _mood = on ? m.value : null);
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                if (_filtering)
                  TextButton(onPressed: _clear, child: const Text('Clear')),
              ],
            ),
          ),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _filtering
                                ? 'No entries match these filters.'
                                : 'No entries yet. Tap the + button to write your first one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: muted),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _rows.length,
                        itemBuilder: (_, i) => EntryTile(
                          row: _rows[i],
                          onSignedOut: widget.onSignedOut,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
