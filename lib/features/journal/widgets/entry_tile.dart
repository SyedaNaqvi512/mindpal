import 'package:flutter/material.dart';

class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.row});

  final Map<String, dynamic> row;

  String _pattern(Object? p) {
    final s = p as String?;
    return (s == null || s == 'none') ? '' : s.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final pattern = _pattern(row['thinking_pattern']);
    final date = (row['created_at'] as String).substring(0, 10);

          return Card(
        margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          row['content'] as String,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Mood ${row['mood']} - $date${pattern.isEmpty ? '' : ' - $pattern'}',
        ),
      ),
    );
  }
}