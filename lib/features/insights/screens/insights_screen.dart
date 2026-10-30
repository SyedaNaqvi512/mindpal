import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../journal/models/entry_format.dart';
import '../../journal/models/mood.dart';
import '../../journal/models/thinking_patterns.dart';
import '../../journal/screens/entry_detail_screen.dart';
import '../models/insights_calc.dart';
import '../widgets/mood_calendar.dart';
import '../widgets/mood_trend_chart.dart';

/// FR-27 mood calendar, FR-28 weekly and monthly trend, FR-29 common patterns.
/// Everything is worked out on the phone from the encrypted journal.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

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
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shrinkWrap: true,
            children: [
              Text(dayHeading(day, DateTime.now()), style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final e in entries.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: MoodColors.byLevel[Mood.byValue(e['mood'] as int?).value - 1],
                          shape: BoxShape.circle,
                        ),
                        child: Text(Mood.byValue(e['mood'] as int?).emoji,
                            style: const TextStyle(fontSize: 20)),
                      ),
                      title: Text(e['content'] as String,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${Mood.byValue(e['mood'] as int?).label} · '
                        '${formatEntryTime(e['created_at'] as String)}',
                      ),
                      trailing: const Icon(Symbols.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => EntryDetailScreen(
                            entryId: e['id'] as int,
                            onSignedOut: widget.onSignedOut,
                          ),
                        ));
                      },
                    ),
                  ),
                ),
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
        body: const EmptyState(
          icon: Symbols.insights_rounded,
          title: 'Nothing to show yet',
          message: 'Your mood calendar, trends and thinking patterns '
              'will appear here after your first entries.',
        ),
      );
    }

    final byDay = dailyMoods(_rows);
    final today = dateOnly(DateTime.now());

    // Trend (FR-28)
    DateTime dayAt(int i) =>
        DateTime(today.year, today.month, today.day - (_trendDays - 1) + i);
    final series = dailySeries(byDay, today, _trendDays);
    final labels = <String?>[
      for (var i = 0; i < _trendDays; i++)
        () {
          final d = dayAt(i);
          if (_trendDays == 7) return weekdayShort(d);
          return (i % 5 == 0 || i == _trendDays - 1) ? '${d.day}' : null;
        }(),
    ];
    final tooltipLabels = <String>[
      for (var i = 0; i < _trendDays; i++)
        '${weekdayShort(dayAt(i))}, ${formatShortDate(dayAt(i))}',
    ];
    final avg = seriesAverage(series);
    final entriesInPeriod = [
      for (var i = 0; i < _trendDays; i++) byDay[dayAt(i)]?.count ?? 0,
    ].fold<int>(0, (a, b) => a + b);
    final avgText = avg == null
        ? 'No entries in this period.'
        : 'Average mood ${avg.toStringAsFixed(1)} '
            '${Mood.all[moodIndex(avg)].emoji} ${Mood.all[moodIndex(avg)].label}'
            ' · $entriesInPeriod ${entriesInPeriod == 1 ? 'entry' : 'entries'}';
    final streak = currentStreak(byDay, today);

    // Patterns (FR-29)
    final since = _patternDays == 0
        ? null
        : DateTime(today.year, today.month, today.day - (_patternDays - 1));
    final patterns = patternCounts(_rows, since: since);
    final top = patterns.take(5).toList();
    final maxCount = top.isEmpty ? 1 : top.first.value;
    final barColors = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.primary.withValues(alpha: 0.6),
      scheme.secondary.withValues(alpha: 0.7),
    ];

    Widget card(String title, Widget child, {int delay = 0}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FadeSlideIn(
            delay: Duration(milliseconds: delay),
            child: Card(
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
            ),
          ),
        );

    Widget stat(IconData icon, String value, String label) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(
                children: [
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(height: 4),
                  Text(value, style: text.titleLarge),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, AppTokens.space24),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('Week')),
              ButtonSegment(value: 30, label: Text('Month')),
            ],
            selected: {_trendDays},
            onSelectionChanged: (s) => setState(() => _trendDays = s.first),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            child: Row(
              children: [
                stat(Symbols.edit_note_rounded, '$entriesInPeriod', 'Entries'),
                const SizedBox(width: 10),
                stat(
                  Symbols.mood_rounded,
                  avg == null ? '–' : '${Mood.all[moodIndex(avg)].emoji} ${avg.toStringAsFixed(1)}',
                  'Average mood',
                ),
                const SizedBox(width: 10),
                stat(Symbols.local_fire_department_rounded, '$streak', 'Day streak'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          card(
            _trendDays == 7 ? 'Mood this week' : 'Mood this month',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(avgText, style: muted),
                const SizedBox(height: 8),
                MoodTrendChart(
                  values: series,
                  labels: labels,
                  tooltipLabels: tooltipLabels,
                  summary: 'Mood trend for the last $_trendDays days. $avgText',
                ),
                Text('Tap a point to see the day.',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
            delay: 60,
          ),
          card(
            'Mood calendar',
            MoodCalendar(
              month: _month,
              byDay: byDay,
              onMonthChanged: (m) => setState(() => _month = m),
              onDayTap: _showDay,
            ),
            delay: 120,
          ),
          card(
            'Most common thinking patterns',
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
                  onSelectionChanged: (s) => setState(() => _patternDays = s.first),
                ),
                const SizedBox(height: 14),
                if (top.isEmpty)
                  Text(
                    'No patterns in this period yet. They appear after you '
                    'get reflections on your entries.',
                    style: muted,
                  )
                else
                  for (var i = 0; i < top.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ThinkingPatterns.nameOf(top[i].key) ?? top[i].key,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text('${top[i].value}×',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _AnimatedBar(
                            ratio: top[i].value / maxCount,
                            color: barColors[i % barColors.length],
                            track: scheme.surfaceContainer,
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
            delay: 180,
          ),
        ],
      ),
    );
  }
}

/// A horizontal bar that grows to [ratio] (0 to 1) when it appears.
class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({required this.ratio, required this.color, required this.track});

  final double ratio;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: ratio.clamp(0.0, 1.0)),
      duration: Motion.of(context, AppTokens.motionSlow),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 12,
          color: track,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: value, child: Container(color: color)),
        ),
      ),
    );
  }
}
