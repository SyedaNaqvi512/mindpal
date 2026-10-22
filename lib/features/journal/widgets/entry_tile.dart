import 'package:flutter/material.dart';

import '../models/entry_format.dart';
import '../models/mood.dart';
import '../screens/entry_detail_screen.dart';

class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.row, required this.onSignedOut});

  final Map<String, dynamic> row;
  final VoidCallback onSignedOut;

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
    final date = formatEntryDate(row['created_at'] as String);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => EntryDetailScreen(
            entryId: row['id'] as int,
            onSignedOut: onSignedOut,
          ),
        )),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: '${mood.label} mood',
                child: Text(mood.emoji, style: const TextStyle(fontSize: 30)),
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
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$date${pattern.isEmpty ? '' : ' · $pattern'}',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final t in tags)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(t,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSecondaryContainer)),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
