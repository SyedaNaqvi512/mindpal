import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../../journal/models/entry_format.dart';
import '../../journal/models/mood.dart';
import '../../journal/models/thinking_patterns.dart';
import '../models/insights_calc.dart';
import '../widgets/mood_calendar.dart';
import '../widgets/mood_trend_chart.dart';

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// FR-27 mood calendar, FR-28 weekly and monthly trend, FR-29 common patterns.
/// Everything is worked out on the phone from the encrypted journal.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<Map<String, Object?>> _rows = [];
  bool _loaded = false;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _trendDays = 7; // 7 = week, 30 = month
  int _patternDays = 30; // 7, 30, or 0 = all time

  @override
  void initState() {
    super.initState();
    entriesChanged.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    entriesChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await DatabaseService.getInsightRows();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _showDay(DateTime day) async {
    final entries = await DatabaseService.searchEntries(from: day, to: day);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shrinkWrap: true,
            children: [
              Text(formatEntryDate(day.toIso8601String()),
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final e in entries.reversed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(Mood.byValue(e['mood'] as int?).emoji,
                      style: const TextStyle(fontSize: 26)),
                  title: Text(e['content'] as String,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${Mood.byValue(e['mood'] as int?).label} · '
                    '${formatEntryDateTime(e['created_at'] as String).split(', ').last}',
                  ),
                ),
              Text('Open History to read or edit an entry.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant);

    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_rows.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbols.insights_rounded,
                    size: 48, color: scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  'Your mood calendar, trends and thinking patterns will '
                  'appear here after your first entries.',
                  textAlign: TextAlign.center,
                  style: muted,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final byDay = dailyMoods(_rows);
    final today = dateOnly(DateTime.now());

    // Trend (FR-28)
    final series = dailySeries(byDay, today, _trendDays);
    final labels = <String?>[
      for (var i = 0; i < _trendDays; i++)
        () {
          final d = DateTime(
              today.year, today.month, today.day - (_trendDays - 1) + i);
          if (_trendDays == 7) return _weekdayShort[d.weekday - 1];
          return (i % 5 == 0 || i == _trendDays - 1) ? '${d.day}' : null;
        }(),
    ];
    final avg = seriesAverage(series);
    final entriesInPeriod = [
      for (var i = 0; i < _trendDays; i++)
        byDay[DateTime(
                today.year, today.month, today.day - (_trendDays - 1) + i)]
                ?.count ??
            0,
    ].fold<int>(0, (a, b) => a + b);
    final avgText = avg == null
        ? 'No entries in this period.'
        : 'Average mood ${avg.toStringAsFixed(1)} '
            '${Mood.all[moodIndex(avg)].emoji} ${Mood.all[moodIndex(avg)].label}'
            ' · $entriesInPeriod ${entriesInPeriod == 1 ? 'entry' : 'entries'}';

    // Patterns (FR-29)
    final since = _patternDays == 0
        ? null
        : DateTime(today.year, today.month, today.day - (_patternDays - 1));
    final patterns = patternCounts(_rows, since: since);
    final top = patterns.take(5).toList();
    final maxCount = top.isEmpty ? 1 : top.first.value;

    Widget card(String title, Widget child) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          card(
            'Mood calendar',
            MoodCalendar(
              month: _month,
              byDay: byDay,
              onMonthChanged: (m) => setState(() => _month = m),
              onDayTap: _showDay,
            ),
          ),
          card(
            'Mood trend',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('Week')),
                    ButtonSegment(value: 30, label: Text('Month')),
                  ],
                  selected: {_trendDays},
                  onSelectionChanged: (s) =>
                      setState(() => _trendDays = s.first),
                ),
                const SizedBox(height: 8),
                Text(avgText, style: muted),
                const SizedBox(height: 8),
                MoodTrendChart(
                  values: series,
                  labels: labels,
                  summary: 'Mood trend for the last $_trendDays days. $avgText',
                ),
              ],
            ),
          ),
          card(
            'Common thinking patterns',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7 days')),
                    ButtonSegment(value: 30, label: Text('30 days')),
                    ButtonSegment(value: 0, label: Text('All time')),
                  ],
                  selected: {_patternDays},
                  onSelectionChanged: (s) =>
                      setState(() => _patternDays = s.first),
                ),
                const SizedBox(height: 12),
                if (top.isEmpty)
                  Text(
                    'No patterns in this period yet. They appear after you '
                    'get reflections on your entries.',
                    style: muted,
                  )
                else
                  for (final e in top)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                    ThinkingPatterns.nameOf(e.key) ?? e.key),
                              ),
                              Text('${e.value}×', style: muted),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: e.value / maxCount,
                              minHeight: 10,
                              backgroundColor: scheme.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 4),
                Text(
                  'These are suggestions found in your reflections, not '
                  'diagnoses. MindPal is not therapy.',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
