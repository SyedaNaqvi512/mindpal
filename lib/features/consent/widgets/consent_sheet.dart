import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../services/consent_service.dart';

/// Asks for AI-processing consent. Returns true only if the user taps Allow.
Future<bool> showConsentSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ConsentSheet(),
  );
  return result == true;
}

class _ConsentSheet extends StatelessWidget {
  const _ConsentSheet();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    Widget point(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 10),
                child: Icon(Symbols.check_circle_rounded, size: 20),
              ),
              Expanded(child: Text(s)),
            ],
          ),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Allow AI to write your reflection?',
                style: text.titleLarge),
            const SizedBox(height: 16),
            point('Your entry text is sent securely to the MindPal server, '
                'which passes it to an external AI service (Google Gemini) '
                'to write the reflection.'),
            point('MindPal does not store your journal text on its server. '
                'Your entries stay on this phone.'),
            point('Entries that look high-risk are checked on your phone '
                'first and are never sent.'),
            point('You can withdraw this permission at any time in Settings.'),
            const SizedBox(height: 4),
            Text(
              'The AI service handles the text under its own terms. '
              'Policy version ${ConsentService.policyVersion}.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Allow'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
