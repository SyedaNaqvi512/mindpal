import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_palette.dart';
import '../models/entry_format.dart';
import '../models/mood.dart';
import '../screens/entry_detail_screen.dart';

/// One journal entry in a list: a colored mood circle, the first lines of text,
/// and small pills for time, thinking pattern, tags and a reflection mark.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.row,
    required this.onSignedOut,
    this.showDate = true,
    this.selecting = false,
    this.selected = false,
    this.onToggleSelect,
    this.onLongPress,
  });

  final Map<String, dynamic> row;
  final VoidCallback onSignedOut;

  /// Show the date before the time. History groups by day and turns this off.
  final bool showDate;

  /// Select mode (History batch operations): a tap ticks the entry instead of opening it.
  final bool selecting;
  final bool selected;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onLongPress;

  String _pattern(Object? p) {
    final s = p as String?;
    return (s == null || s == 'none') ? '' : s.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mood = Mood.byValue(row['mood'] as int?);
    final pattern = _pattern(row['thinking_pattern']);
    final tags = FeelingTags.parse(row['tags']);
    final created = row['created_at'] as String;
    final time = formatEntryTime(created);
    final when = showDate ? '${formatEntryDate(created)} · $time' : time;
    final hasReflection = row['reflection_text'] != null;

    Widget pill(String label, Color fill, Color on) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(999)),
          child: Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: on)),
        );

    return Card(
      clipBehavior: Clip.antiAlias,
      color: selected ? scheme.primaryContainer : null,
      child: InkWell(
        onLongPress: onLongPress,
        onTap: selecting
            ? onToggleSelect
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      EntryDetailScreen(entryId: row['id'] as int, onSignedOut: onSignedOut),
                )),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selecting)
                Semantics(
                  label: selected ? 'Selected' : 'Not selected',
                  excludeSemantics: true,
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? scheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.primary, width: 2),
                    ),
                    child: selected
                        ? Icon(Symbols.check_rounded, color: scheme.onPrimary)
                        : null,
                  ),
                )
              else
              Semantics(
                label: '${mood.label} mood',
                excludeSemantics: true,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MoodColors.byLevel[mood.value - 1],
                    shape: BoxShape.circle,
                  ),
                  child: Text(mood.emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['content'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(when,
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        if (hasReflection)
                          Semantics(
                            label: 'Has a reflection',
                            child: Icon(Symbols.psychology_alt_rounded,
                                size: 16, color: scheme.primary),
                          ),
                        if (pattern.isNotEmpty)
                          pill(pattern, scheme.tertiaryContainer, scheme.onTertiaryContainer),
                        for (final t in tags)
                          pill(t, scheme.secondaryContainer, scheme.onSecondaryContainer),
                      ],
                    ),
                  ],
                ),
              ),
              if (!selecting)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 10),
                  child: Icon(Symbols.chevron_right_rounded,
                      size: 20, color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
