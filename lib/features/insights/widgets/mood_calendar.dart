import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_palette.dart';
import '../../journal/models/mood.dart';
import '../models/insights_calc.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Month calendar that marks days with entries, colored and with the mood emoji (FR-27).
class MoodCalendar extends StatelessWidget {
  const MoodCalendar({
    super.key,
    required this.month,
    required this.byDay,
    required this.onMonthChanged,
    required this.onDayTap,
  });

  final DateTime month; // any day in the month shown
  final Map<DateTime, DayMood> byDay;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = dateOnly(now);
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final cells = monthGrid(month);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              icon: const Icon(Symbols.chevron_left_rounded),
              onPressed: () =>
                  onMonthChanged(DateTime(month.year, month.month - 1, 1)),
            ),
            Expanded(
              child: Text(
                '${_monthNames[month.month - 1]} ${month.year}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              icon: const Icon(Symbols.chevron_right_rounded),
              onPressed: isCurrentMonth
                  ? null
                  : () =>
                      onMonthChanged(DateTime(month.year, month.month + 1, 1)),
            ),
          ],
        ),
        Row(
          children: [
            for (final d in _weekdays)
              Expanded(
                child: Center(
                  child: Text(d,
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.85,
          children: [
            for (final c in cells)
              if (c == null)
                const SizedBox.shrink()
              else
                _DayCell(
                  day: c,
                  data: byDay[c],
                  isToday: c == today,
                  isFuture: c.isAfter(today),
                  onTap: onDayTap,
                ),
          ],
        ),
        const SizedBox(height: 12),
        // Five equal columns: emoji over its word, so nothing wraps unevenly.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final m in Mood.all)
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: MoodColors.byLevel[m.value - 1],
                        shape: BoxShape.circle,
                      ),
                      child: Text(m.emoji, style: const TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.data,
    required this.isToday,
    required this.isFuture,
    required this.onTap,
  });

  final DateTime day;
  final DayMood? data;
  final bool isToday;
  final bool isFuture;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final has = data != null;
    final mood = has ? Mood.all[moodIndex(data!.average)] : null;
    // Mood colors are pastel in every theme, so the text on them stays dark.
    const onMood = Color(0xFF2B2540);

    final label = has
        ? '${_monthNames[day.month - 1]} ${day.day}: ${data!.count} '
            '${data!.count == 1 ? 'entry' : 'entries'}, mood ${mood!.label}'
        : '${_monthNames[day.month - 1]} ${day.day}: no entries';

    return Semantics(
      button: has,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: has ? () => onTap(day) : null,
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: has ? MoodColors.byLevel[moodIndex(data!.average)] : null,
              borderRadius: BorderRadius.circular(12),
              border: isToday
                  ? Border.all(color: scheme.primary, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 11,
                    color: has
                        ? onMood
                        : (isFuture
                            ? scheme.outlineVariant
                            : scheme.onSurfaceVariant),
                    fontWeight: isToday ? FontWeight.w700 : null,
                  ),
                ),
                if (has) Text(mood!.emoji, style: const TextStyle(fontSize: 17)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
