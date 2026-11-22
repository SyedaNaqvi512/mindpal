import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'support_info.dart';

/// Help and support contacts as a full screen. Opened from the "when to get
/// help" article. The same contacts are in Settings and in the support card.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'If you are struggling, you deserve support from a real person. '
            'Please talk to someone you trust, or contact a mental health '
            'service.',
            style: TextStyle(fontSize: 16, height: 1.5, color: scheme.onSurface),
          ),
          const SizedBox(height: 14),
          for (final h in kHelplines)
            Card(
              child: ListTile(
                leading: const Icon(Symbols.favorite_rounded),
                title: Text(h.name),
                subtitle: SelectableText(h.number,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'If you are in immediate danger, contact your local emergency '
            'services right away.',
            style: TextStyle(fontSize: 16, height: 1.5, color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}
