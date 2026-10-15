import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Placeholder. The real Insights (mood trend, patterns) is milestone M5.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.insights_rounded, size: 48, color: muted),
              const SizedBox(height: 12),
              Text(
                'Your mood trends and thinking patterns will appear here '
                'after a few entries.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}