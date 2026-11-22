import 'package:flutter/material.dart';

import '../exercises/widgets/breathing_bubble.dart';
import 'learn_content.dart';

/// FR-67: the Breathing Bubble for a full five minutes. It saves nothing.
class BreathingSessionScreen extends StatelessWidget {
  const BreathingSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Breathing Bubble')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Follow the bubble for five minutes. Breathe in as it grows, '
              'pause, breathe out as it shrinks, and pause. Go at a pace that '
              'feels comfortable, and press Pause whenever you want to stop.',
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 28),
            Center(
              child: BreathingBubble(
                cycles: kLearnBreathCycles,
                size: 240,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nothing from this session is saved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
