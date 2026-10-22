import 'package:flutter/material.dart';

import '../models/mood.dart';

/// Five emoji moods with a word under each. [value] is 1-5, or null for none yet.
class MoodPicker extends StatelessWidget {
  const MoodPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final int? value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (final m in Mood.all)
          Expanded(
            child: Semantics(
              button: true,
              selected: value == m.value,
              label: '${m.label} mood',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: enabled ? () => onChanged(m.value) : null,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: value == m.value ? scheme.primaryContainer : null,
                    border: Border.all(
                      color: value == m.value
                          ? scheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(m.emoji, style: const TextStyle(fontSize: 30)),
                      const SizedBox(height: 2),
                      Text(
                        m.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
