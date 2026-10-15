import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../support_info.dart';

/// Shown instead of any AI reflection when the safety screening triggers.
/// The text never leaves the phone in this case (FR-18, FR-19).
class SupportCard extends StatelessWidget {
  const SupportCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = scheme.onErrorContainer;

    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  Icon(Symbols.favorite_rounded, color: on),
                  const SizedBox(width: 8),
                  Text(
                    'You are not alone',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: on),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'It sounds like you are going through something very painful. '
              'You deserve support from a real person. Please reach out to '
              'someone you trust, or contact a mental health service now.',
              style: TextStyle(color: on),
            ),
            const SizedBox(height: 12),
            for (final h in kHelplines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(
                  '${h.name}: ${h.number}',
                  style: TextStyle(color: on, fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'If you are in immediate danger, contact your local emergency '
              'services right away.',
              style: TextStyle(color: on),
            ),
            const SizedBox(height: 12),
            Text(
              'MindPal cannot reliably detect every crisis. It is a '
              'reflection tool, not a therapist or an emergency service. '
              'Your entry was not sent to any AI service.',
              style: TextStyle(fontSize: 12, color: on),
            ),
          ],
        ),
      ),
    );
  }
}