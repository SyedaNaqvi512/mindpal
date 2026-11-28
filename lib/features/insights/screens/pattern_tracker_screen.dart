import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../../../core/theme/app_look.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/skeleton.dart';
import '../../exercises/models/exercise_catalog.dart';
import '../../journal/models/thinking_patterns.dart';
import '../models/analytics_calc.dart';
import '../models/insights_calc.dart';
import '../models/pattern_guide.dart';

/// The thinking-pattern tracker: every pattern MindPal can name in a
/// reflection, how often it came up, when it was last named, a small chart of
/// the last 8 weeks, and a kind note on how to look at it. These are
/// suggestions found in the user's own reflections, never diagnoses. Nothing
/// is sent anywhere.
class PatternTrackerScreen extends StatefulWidget {
  const PatternTrackerScreen({super.key});

  @override
  State<PatternTrackerScreen> createState() => _PatternTrackerScreenState();
}

class _PatternTrackerScreenState extends State<PatternTrackerScreen> {
  List<Map<String, Object?>>? _rows;

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
    List<Map<String, Object?>> rows;
    try {
      rows = await DatabaseService.getInsightRows();
    } catch (_) {
      rows = const [];
    }
    if (mounted) setState(() => _rows = rows);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: const Text('Thinking patterns')),
      body: rows == null
          ? const SkeletonList(count: 3)
          : PatternTrackerView(rows: rows),
    );
  }
}

/// The tracker's content. It is given its rows, so it can be tested without
/// a database.
class PatternTrackerView extends StatefulWidget {
  const PatternTrackerView({super.key, required this.rows, this.today});

  final List<Map<String, Object?>> rows;
  final DateTime? today;

  @override
  State<PatternTrackerView> createState() => _PatternTrackerViewState();
}

class _PatternTrackerViewState extends State<PatternTrackerView> {
  int _days = 90; // 30, 90 or 0 = all time

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final today = dateOnly(widget.today ?? DateTime.now());
    final since = periodStart(today, _days);

    final counts = {
      for (final e in patternCounts(widget.rows, since: since)) e.key: e.value,
    };
    final weekly = patternWeeklyCounts(widget.rows, today, 8);
    final lastSeen = patternLastSeen(widget.rows);

    // Patterns named in this period first (most common first), then the rest.
    final ids = ThinkingPatterns.names.keys.toList()
      ..sort((a, b) {
        final c = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
        return c != 0 ? c : a.compareTo(b);
      });
    final total = counts.values.fold<int>(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, AppTokens.space24),
      children: [
        FadeSlideIn(
          child: Card(
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Symbols.info_rounded, size: 20, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'These are common ways of thinking that many people notice '
                      'in themselves. MindPal suggests them from your reflections. '
                      'They are not diagnoses, and MindPal is not therapy.',
                      style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 30, label: Text('30 days')),
            ButtonSegment(value: 90, label: Text('90 days')),
            ButtonSegment(value: 0, label: Text('All')),
          ],
          showSelectedIcon: false,
          selected: {_days},
          onSelectionChanged: (s) => setState(() => _days = s.first),
        ),
        const SizedBox(height: 12),
        if (widget.rows.isEmpty)
          const EmptyState(
            icon: Symbols.pattern_rounded,
            title: 'Nothing to show yet',
            message: 'Patterns appear here after you write entries and get '
                'reflections on them.',
          )
        else ...[
          Text(
            total == 0
                ? 'No patterns were named in this period.'
                : '$total ${total == 1 ? 'pattern' : 'patterns'} named in '
                    '${_days == 0 ? 'all your reflections' : 'the last $_days days'}.',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final id in ids)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PatternCard(
                id: id,
                count: counts[id] ?? 0,
                weekly: weekly[id] ?? List<int>.filled(8, 0),
                lastSeen: lastSeen[id],
                today: today,
              ),
            ),
        ],
      ],
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({
    required this.id,
    required this.count,
    required this.weekly,
    required this.lastSeen,
    required this.today,
  });

  final String id;
  final int count;
  final List<int> weekly;
  final DateTime? lastSeen;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = ThinkingPatterns.names[id] ?? id;
    final guide = kPatternGuides[id];
    final suggestion = suggestExercise(id);
    final seen = lastSeen == null ? 'Not named yet' : 'Last named ${agoText(lastSeen!, today)}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              count == 0 ? 'None in this period · $seen' : '$count in this period · $seen',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniBars(values: weekly, name: name),
              const SizedBox(width: 6),
              Icon(Symbols.expand_more_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
          children: [
            if (guide != null) ...[
              Text(guide.means, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 10),
              Text('For example', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(guide.example,
                  style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                      height: 1.4)),
              const SizedBox(height: 10),
              Text('A gentler way to look at it',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(guide.gentler, style: const TextStyle(height: 1.4)),
            ],
            if (suggestion != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Symbols.self_improvement_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('An exercise to try: ${suggestion.title}',
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Eight small bars, one for each of the last 8 weeks. It is a still picture
/// with a text description for screen readers.
class _MiniBars extends StatelessWidget {
  const _MiniBars({required this.values, required this.name});

  final List<int> values;
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = values.fold<int>(1, (a, b) => b > a ? b : a);
    final radius = (AppLook.of(context).cardRadius / 8).clamp(1.0, 3.0).toDouble();
    return Semantics(
      label: '$name by week, last 8 weeks: ${values.join(', ')}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 52,
          height: 28,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final v in values)
                Container(
                  width: 4,
                  height: v == 0 ? 3 : 5 + 23 * v / top,
                  decoration: BoxDecoration(
                    color: v == 0 ? scheme.surfaceContainerHighest : scheme.primary,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
