import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../../../core/widgets/empty_state.dart';
import '../../insights/models/insights_calc.dart';
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

  /// Removes an entry from the list at once and offers Undo. It is deleted from
  /// the encrypted database only after the snackbar closes without Undo.
  void _removeWithUndo(Map<String, dynamic> row) {
    final id = row['id'] as int;
    setState(() => _rows = _rows.where((r) => r['id'] != id).toList());

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger
        .showSnackBar(
          SnackBar(
            content: const Text('Entry deleted'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'Undo', onPressed: () {}),
          ),
        )
        .closed
        .then((reason) async {
      if (reason == SnackBarClosedReason.action) {
        if (mounted) _load();
        return;
      }
      try {
        await DatabaseService.deleteJournalEntry(id);
      } catch (_) {}
      entriesChanged.value++;
    });
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();

    OutlineInputBorder pillBorder(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: c, width: w),
        );

    // Entries newest first, with a heading when the day changes.
    final items = <Object>[];
    DateTime? lastDay;
    for (final row in _rows) {
      final t = DateTime.tryParse('${row['created_at']}');
      final day = t == null ? null : dateOnly(t);
      if (day != null && day != lastDay) {
        items.add(day);
        lastDay = day;
      }
      items.add(row);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search your entries',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: pillBorder(scheme.outline, 1),
                enabledBorder: pillBorder(scheme.outline, 1),
                focusedBorder: pillBorder(scheme.primary, 2),
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
                if (_filtering) TextButton(onPressed: _clear, child: const Text('Clear')),
              ],
            ),
          ),
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? (_filtering
                        ? EmptyState(
                            icon: Symbols.search_rounded,
                            title: 'Nothing matches',
                            message: 'No entries match these filters. '
                                'Try another word or clear the filters.',
                            actionLabel: 'Clear filters',
                            onAction: _clear,
                          )
                        : const EmptyState(
                            icon: Symbols.edit_note_rounded,
                            title: 'No entries yet',
                            message: 'Tap the + button to write your first one. '
                                'It stays on this phone.',
                          ))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final item = items[i];
                          if (item is DateTime) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                              child: Semantics(
                                header: true,
                                child: Text(
                                  dayHeading(item, now),
                                  style: text.titleSmall
                                      ?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ),
                            );
                          }
                          final row = item as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Dismissible(
                              key: ValueKey('entry-${row['id']}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                  color: scheme.error,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Delete',
                                        style: TextStyle(
                                          color: scheme.onError,
                                          fontWeight: FontWeight.w700,
                                        )),
                                    const SizedBox(width: 8),
                                    Icon(Symbols.delete_rounded, color: scheme.onError),
                                  ],
                                ),
                              ),
                              onDismissed: (_) => _removeWithUndo(row),
                              child: EntryTile(
                                row: row,
                                showDate: false,
                                onSignedOut: widget.onSignedOut,
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
