import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/toast.dart';
import '../../exercises/services/exercise_repository.dart';
import '../../journal/models/entry_format.dart';
import '../../journal/models/mood.dart';
import '../../journal/screens/entry_detail_screen.dart';
import '../models/analytics_calc.dart';
import '../models/report_data.dart';
import '../services/pdf_font_loader.dart';
import '../services/report_service.dart';
import 'insights_view.dart';

/// FR-27 mood calendar, FR-28 trends, FR-29 common patterns, and the Part 8
/// charts (mood spread, weekday, time of day, feelings, weekly rhythm,
/// exercises). Everything is worked out on the phone from the encrypted
/// journal; nothing is sent anywhere.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, required this.onSignedOut, this.sharer});

  final VoidCallback onSignedOut;

  /// How the PDF is handed over; tests pass a fake.
  final ReportSharer? sharer;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<Map<String, Object?>> _rows = [];
  List<ExerciseDone> _exercises = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    entriesChanged.addListener(_load);
    ExerciseRepository.changed.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    entriesChanged.removeListener(_load);
    ExerciseRepository.changed.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await DatabaseService.getInsightRows();
      var done = <ExerciseDone>[];
      try {
        final sessions = await ExerciseRepository.completed();
        done = [
          for (final s in sessions)
            if (s.completedAt != null) ExerciseDone(s.exerciseId, s.completedAt!),
        ];
      } catch (_) {
        // The exercise charts just stay empty if this cannot be read.
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _exercises = done;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _export(int days) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share a summary?'),
        content: const Text(
          'This makes a PDF with counts only: your moods, feelings, exercises '
          'and patterns. It has no journal text. You choose where it goes next, '
          'and MindPal does not send it anywhere itself.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create PDF'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final now = DateTime.now();
      final data = buildReportData(
        rows: _rows,
        exercises: _exercises,
        today: now,
        days: days,
      );
      final fonts = await loadPdfFonts();
      await (widget.sharer ?? const PhoneReportSharer())
          .share(renderReportPdf(data, fonts: fonts), reportFileName(now));
    } catch (_) {
      if (mounted) {
        Toast.of(context, 'Could not create the summary. Please try again.',
            kind: ToastKind.error);
      }
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
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights')),
        body: const SkeletonList(count: 3, tall: true),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: InsightsView(
        rows: _rows,
        exercises: _exercises,
        onDayTap: _showDay,
        onExport: _export,
      ),
    );
  }
}
