import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../exercises/models/exercise_catalog.dart';
import '../../journal/models/entry_format.dart';
import '../../journal/models/mood.dart';
import '../../journal/models/thinking_patterns.dart';
import '../models/analytics_calc.dart';
import '../models/insights_calc.dart';
import '../widgets/bar_chart_view.dart';
import '../widgets/chart_colors.dart';
import '../widgets/donut_chart.dart';
import '../widgets/mood_calendar.dart';
import '../widgets/mood_trend_chart.dart';

/// The Insights page content (FR-27 to FR-29 and the Part 8 charts): one
/// period choice at the top drives every chart. It only draws what it is
/// given, so it can be tested without a database. Everything is worked out on
/// the phone; nothing is sent anywhere.
class InsightsView extends StatefulWidget {
  const InsightsView({
    super.key,
    required this.rows,
    required this.exercises,
    required this.onDayTap,
    this.today,
  });

  /// Rows from `DatabaseService.getInsightRows` (at least one).
  final List<Map<String, Object?>> rows;
  final List<ExerciseDone> exercises;
  final ValueChanged<DateTime> onDayTap;

  /// For tests; defaults to now.
  final DateTime? today;

  @override
  State<InsightsView> createState() => _InsightsViewState();
}

class _InsightsViewState extends State<InsightsView> {
  int _days = 7; // 7, 30, 90, or 0 = all time
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final t = widget.today ?? DateTime.now();
    _month = DateTime(t.year, t.month, 1);
  }

  static const _periodText = {7: 'the last 7 days', 30: 'the last 30 days', 90: 'the last 90 days', 0: 'all time'};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    final small = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);

    final today = dateOnly(widget.today ?? DateTime.now());
    final since = periodStart(today, _days);
    final inPeriod = rowsBetween(widget.rows, since: since, until: today);
    final byDay = dailyMoods(widget.rows);
    final period = _periodText[_days]!;

    // ---- Trend (FR-28) ----
    final trendDays = _days == 0 ? 90 : _days;
    DateTime dayAt(int i) =>
        DateTime(today.year, today.month, today.day - (trendDays - 1) + i);
    final series = dailySeries(byDay, today, trendDays);
    final labelEvery = trendDays <= 7 ? 1 : (trendDays <= 30 ? 5 : 15);
    final labels = <String?>[
      for (var i = 0; i < trendDays; i++)
        trendDays == 7
            ? weekdayShort(dayAt(i))
            : ((i % labelEvery == 0 && trendDays - 1 - i >= labelEvery ~/ 2) || i == trendDays - 1)
                ? (trendDays <= 30 ? '${dayAt(i).day}' : formatShortDate(dayAt(i)))
                : null,
    ];
    final tooltipLabels = [
      for (var i = 0; i < trendDays; i++)
        '${weekdayShort(dayAt(i))}, ${formatShortDate(dayAt(i))}',
    ];
    final avg = seriesAverage(series);
    final entriesInPeriod = _days == 0
        ? inPeriod.length
        : [for (var i = 0; i < trendDays; i++) byDay[dayAt(i)]?.count ?? 0]
            .fold<int>(0, (a, b) => a + b);
    final avgText = avg == null
        ? 'No entries in this period.'
        : 'Average mood ${avg.toStringAsFixed(1)} '
            '${Mood.all[moodIndex(avg)].emoji} ${Mood.all[moodIndex(avg)].label}';
    final streak = currentStreak(byDay, today);
    final notes = highlights(rows: widget.rows, today: today, days: _days);

    // ---- Mood mix ----
    final dist = moodDistribution(inPeriod);
    final distSlices = [
      for (var i = 0; i < 5; i++) DonutSlice(Mood.all[i].label, dist[i], MoodColors.byLevel[i]),
    ];

    // ---- Weekday ----
    final wd = weekdayStats(inPeriod);
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final wdBars = [
      for (var i = 0; i < 7; i++)
        ChartBar(
          label: dayShort[i],
          value: wd[i].average,
          color: wd[i].average == null
              ? scheme.surfaceContainerHighest
              : MoodColors.byLevel[moodIndex(wd[i].average!)],
          tooltip: wd[i].average == null
              ? '${dayNames[i]} · no entries'
              : '${dayNames[i]} · ${Mood.all[moodIndex(wd[i].average!)].label} '
                  '(${wd[i].average!.toStringAsFixed(1)}) · ${wd[i].count} '
                  '${wd[i].count == 1 ? 'entry' : 'entries'}',
        ),
    ];

    // ---- Time of day ----
    final parts = dayPartStats(inPeriod);
    final partBars = [
      for (var i = 0; i < parts.length; i++)
        ChartBar(
          label: DayPart.values[i].label,
          value: parts[i].count.toDouble(),
          color: chartColor(scheme, i),
          tooltip: parts[i].average == null
              ? '${DayPart.values[i].label} · no entries'
              : '${DayPart.values[i].label} · ${parts[i].count} '
                  '${parts[i].count == 1 ? 'entry' : 'entries'} · '
                  '${Mood.all[moodIndex(parts[i].average!)].label}',
        ),
    ];

    // ---- Feelings ----
    final tags = tagCounts(inPeriod);
    final tagSlices = <DonutSlice>[
      for (var i = 0; i < tags.length && i < 6; i++)
        DonutSlice(tags[i].key, tags[i].value, chartColor(scheme, i)),
      if (tags.length > 6)
        DonutSlice('Other', tags.skip(6).fold<int>(0, (a, e) => a + e.value), scheme.outline),
    ];
    final tagTotal = tags.fold<int>(0, (a, e) => a + e.value);

    // ---- Weekly rhythm (always the last 8 weeks) ----
    final weekly = weeklyEntryCounts(widget.rows, today, 8);
    final weeklyBars = [
      for (var k = 0; k < weekly.length; k++)
        () {
          final end = DateTime(today.year, today.month, today.day - (weekly.length - 1 - k) * 7);
          return ChartBar(
            label: '${end.day}/${end.month}',
            value: weekly[k].toDouble(),
            color: scheme.primary,
            tooltip: 'Week to ${formatShortDate(end)} · ${weekly[k]} '
                '${weekly[k] == 1 ? 'entry' : 'entries'}',
          );
        }(),
    ];

    // ---- Exercises ----
    final done = exercisesSince(widget.exercises, since);
    final exCounts = countKeys([for (final e in done) e.id]);
    String exTitle(String id) {
      for (final x in kExercises) {
        if (x.id == id) return x.title;
      }
      return id;
    }

    final exSlices = [
      for (var i = 0; i < exCounts.length && i < 7; i++)
        DonutSlice(exTitle(exCounts[i].key), exCounts[i].value, chartColor(scheme, i)),
      if (exCounts.length > 7)
        DonutSlice('Other', exCounts.skip(7).fold<int>(0, (a, e) => a + e.value), scheme.outline),
    ];

    // ---- Thinking patterns (FR-29) ----
    final patterns = patternCounts(widget.rows, since: since);
    final patternSlices = <DonutSlice>[
      for (var i = 0; i < patterns.length && i < 6; i++)
        DonutSlice(ThinkingPatterns.nameOf(patterns[i].key) ?? patterns[i].key,
            patterns[i].value, chartColor(scheme, i)),
      if (patterns.length > 6)
        DonutSlice('Other', patterns.skip(6).fold<int>(0, (a, e) => a + e.value), scheme.outline),
    ];
    final patternTotal = patterns.fold<int>(0, (a, e) => a + e.value);

    var delay = 0;
    Widget card(String title, Widget child, {String? subtitle}) {
      delay += 50;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FadeSlideIn(
          delay: Duration(milliseconds: delay > 300 ? 300 : delay),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: small),
                  ],
                  const SizedBox(height: 10),
                  child,
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget stat(IconData icon, String value, String label) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(
                children: [
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(height: 4),
                  Text(value, style: text.titleLarge),
                  Text(label, textAlign: TextAlign.center, style: small.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ),
        );

    Widget note(String s) => Text(s, style: small);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, AppTokens.space24),
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 days')),
            ButtonSegment(value: 30, label: Text('30 days')),
            ButtonSegment(value: 90, label: Text('90 days')),
            ButtonSegment(value: 0, label: Text('All')),
          ],
          showSelectedIcon: false,
          selected: {_days},
          onSelectionChanged: (s) => setState(() => _days = s.first),
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
        if (notes.isNotEmpty)
          card(
            'What stands out',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final n in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Symbols.lightbulb_rounded, size: 18, color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(n, style: const TextStyle(height: 1.35))),
                      ],
                    ),
                  ),
                note('These are simple counts from your own entries, not advice or a diagnosis.'),
              ],
            ),
          ),
        card(
          'Mood over time',
          subtitle: _days == 0 ? 'The last 90 days' : null,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(avgText, style: muted),
              const SizedBox(height: 8),
              MoodTrendChart(
                values: series,
                labels: labels,
                tooltipLabels: tooltipLabels,
                average: avg,
                summary: 'Mood trend for the last $trendDays days. $avgText',
              ),
              Text('Tap a point to see the day. The dashed line is your average.', style: small),
            ],
          ),
        ),
        card(
          'How your moods were spread',
          subtitle: 'Entries in $period',
          inPeriod.isEmpty
              ? Text('No entries in this period.', style: muted)
              : DonutChart(
                  slices: distSlices,
                  centerValue: '${inPeriod.length}',
                  centerLabel: inPeriod.length == 1 ? 'entry' : 'entries',
                  summary: 'Mood spread over $period: ${[
                    for (var i = 0; i < 5; i++) '${Mood.all[i].label} ${dist[i]}',
                  ].join(', ')}.',
                ),
        ),
        card(
          'Mood by day of the week',
          subtitle: 'Average mood in $period',
          inPeriod.isEmpty
              ? Text('No entries in this period.', style: muted)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BarChartView(
                      bars: wdBars,
                      maxValue: 5,
                      ticks: const [1, 3, 5],
                      averageLine: avg,
                      summary: 'Average mood for each weekday in $period.',
                    ),
                    if (inPeriod.length < 7)
                      note('A few more entries will make this clearer.'),
                  ],
                ),
        ),
        card(
          'When you write',
          subtitle: 'Entries by time of day in $period',
          inPeriod.isEmpty
              ? Text('No entries in this period.', style: muted)
              : BarChartView(
                  bars: partBars,
                  summary: 'Entries by time of day: ${[
                    for (var i = 0; i < parts.length; i++)
                      '${DayPart.values[i].label} ${parts[i].count}',
                  ].join(', ')}.',
                ),
        ),
        card(
          'Feelings you chose',
          subtitle: 'From the feeling tags in $period',
          tagSlices.isEmpty
              ? Text('Pick feelings when you write an entry and they appear here.', style: muted)
              : DonutChart(
                  slices: tagSlices,
                  centerValue: '$tagTotal',
                  centerLabel: tagTotal == 1 ? 'feeling' : 'feelings',
                  summary: 'Feelings in $period: ${[
                    for (final s in tagSlices) '${s.label} ${s.value}',
                  ].join(', ')}.',
                ),
        ),
        card(
          'Writing each week',
          subtitle: 'Entries in the last 8 weeks',
          BarChartView(
            bars: weeklyBars,
            summary: 'Entries per week for the last 8 weeks: ${weekly.join(', ')}.',
          ),
        ),
        card(
          'Exercises you finished',
          subtitle: 'In $period',
          exSlices.isEmpty
              ? Text('Finish an exercise and it appears here.', style: muted)
              : DonutChart(
                  slices: exSlices,
                  centerValue: '${done.length}',
                  centerLabel: done.length == 1 ? 'exercise' : 'exercises',
                  summary: 'Exercises finished in $period: ${[
                    for (final s in exSlices) '${s.label} ${s.value}',
                  ].join(', ')}.',
                ),
        ),
        card(
          'Most common thinking patterns',
          subtitle: 'Found in your reflections in $period',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (patternSlices.isEmpty)
                Text(
                  'No patterns in this period yet. They appear after you '
                  'get reflections on your entries.',
                  style: muted,
                )
              else
                DonutChart(
                  slices: patternSlices,
                  centerValue: '$patternTotal',
                  centerLabel: patternTotal == 1 ? 'pattern' : 'patterns',
                  summary: 'Thinking patterns in $period: ${[
                    for (final s in patternSlices) '${s.label} ${s.value}',
                  ].join(', ')}.',
                ),
              const SizedBox(height: 8),
              note('These are suggestions found in your reflections, not '
                  'diagnoses. MindPal is not therapy.'),
            ],
          ),
        ),
        card(
          'Mood calendar',
          MoodCalendar(
            month: _month,
            byDay: byDay,
            onMonthChanged: (m) => setState(() => _month = m),
            onDayTap: widget.onDayTap,
          ),
        ),
      ],
    );
  }
}
