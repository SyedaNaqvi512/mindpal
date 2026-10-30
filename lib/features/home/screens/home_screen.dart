import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/mood_face.dart';
import '../../../core/widgets/section_header.dart';
import '../../account/models/user_profile.dart';
import '../../account/services/profile_store.dart';
import '../../account/widgets/avatar_image.dart';
import '../../insights/models/insights_calc.dart';
import '../../journal/models/entry_format.dart';
import '../../journal/models/mood.dart';
import '../../journal/widgets/entry_tile.dart';

typedef NewEntryCallback = void Function({int? mood, String? text});

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onNewEntry,
    required this.onSeeAll,
    required this.onSignedOut,
  });

  final NewEntryCallback onNewEntry;
  final VoidCallback onSeeAll;
  final VoidCallback onSignedOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _recent = [];
  WeekSummary? _week;
  int _streak = 0;
  bool _loaded = false;
  int? _picked;

  @override
  void initState() {
    super.initState();
    entriesChanged.addListener(_load);
    ProfileStore.instance.ensureLoaded();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await DatabaseService.getRecentEntries(limit: 3);
      final insightRows = await DatabaseService.getInsightRows();
      final byDay = dailyMoods(insightRows);
      final today = DateTime.now();
      if (!mounted) return;
      setState(() {
        _recent = rows;
        _week = weekSummary(byDay, today);
        _streak = currentStreak(byDay, today);
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

  Future<void> _pickMood(int value) async {
    setState(() => _picked = value);
    if (!Motion.reduced(context)) {
      await Future<void>.delayed(const Duration(milliseconds: 320));
    }
    if (!mounted) return;
    widget.onNewEntry(mood: value);
    setState(() => _picked = null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final prompt = StarterPrompts.forDay(now);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, AppTokens.space24),
          children: [
            FadeSlideIn(child: _Header(greeting: greetingForHour(now.hour))),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How are you feeling today?', style: text.titleMedium),
                      const SizedBox(height: 12),
                      MoodFaceRow(value: _picked, onChanged: _pickMood, size: 44),
                      const SizedBox(height: 8),
                      Text('Tap a face to start a new entry',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: _WeekCard(week: _week, streak: _streak),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 180),
              child: Card(
                color: scheme.primaryContainer,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => widget.onNewEntry(text: StarterPrompts.asStart(prompt)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Symbols.lightbulb_rounded, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Today's prompt",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                  )),
                              const SizedBox(height: 2),
                              Text(prompt, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Icon(Symbols.chevron_right_rounded, color: scheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SectionHeader(
              'Recent entries',
              actionLabel: _recent.isEmpty ? null : 'See all',
              onAction: widget.onSeeAll,
            ),
            if (_loaded && _recent.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: EmptyState(
                    icon: Symbols.edit_note_rounded,
                    title: 'Your journal starts here',
                    message: 'Your first entry takes about a minute. It stays on this phone.',
                    actionLabel: 'Write your first entry',
                    onAction: () => widget.onNewEntry(),
                  ),
                ),
              )
            else
              for (var i = 0; i < _recent.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FadeSlideIn(
                    delay: Duration(milliseconds: 240 + i * 60),
                    child: EntryTile(row: _recent[i], onSignedOut: widget.onSignedOut),
                  ),
                ),
            const SizedBox(height: 16),
            Text(
              'MindPal is a reflection tool, not a therapist or medical advice.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ValueListenableBuilder<UserProfile?>(
      valueListenable: ProfileStore.instance.profile,
      builder: (context, profile, _) {
        final name = profile?.displayName.trim() ?? '';
        return Row(
          children: [
            if (profile != null)
              AvatarImage(avatarId: profile.avatarId, size: 52)
            else
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                child: Icon(Symbols.account_circle_rounded, color: scheme.primary),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                  Text(
                    name.isEmpty ? 'Welcome' : name,
                    style: text.headlineSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week, required this.streak});

  final WeekSummary? week;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final w = week;
    final today = DateTime.now();

    String summary;
    if (w == null || w.entries == 0) {
      summary = 'No entries in the last 7 days yet.';
    } else {
      final avg = w.average;
      final mood = avg == null ? null : Mood.all[moodIndex(avg)];
      summary = '${w.entries} ${w.entries == 1 ? 'entry' : 'entries'}'
          '${mood == null ? '' : ' · mostly ${mood.label.toLowerCase()}'}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Your week', style: text.titleMedium)),
                if (streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Symbols.local_fire_department_rounded,
                            size: 16, color: scheme.onTertiaryContainer),
                        const SizedBox(width: 4),
                        Text(
                          '$streak day${streak == 1 ? '' : 's'} in a row',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(summary, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 7; i++)
                  _DayDot(
                    value: w?.days[i],
                    label: weekdayShort(DateTime(today.year, today.month, today.day - 6 + i))
                        .substring(0, 1),
                    isToday: i == 6,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.value, required this.label, required this.isToday});

  final double? value;
  final String label;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = value;
    final Color? fill = v == null ? null : MoodColors.byLevel[moodIndex(v)];

    return Semantics(
      label: v == null ? 'No entry' : 'Average mood ${Mood.all[moodIndex(v)].label}',
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: fill ?? scheme.surfaceContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: isToday ? scheme.primary : scheme.outline.withValues(alpha: 0.5),
                width: isToday ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: v == null
                ? null
                : Text(Mood.all[moodIndex(v)].emoji, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: isToday ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
