import 'package:flutter/material.dart';

import '../models/exercise_logic.dart';
import '../services/exercise_controller.dart';
import 'step_kit.dart';
import '../widgets/safe_text_field.dart';

/// FR-38: Belief Slider. Rate before, think it through, rate after. Both
/// ratings are shown with no good or bad label.

ExerciseStep beliefBeforeStep() => sliderStep(
      title: 'How strongly do you believe it?',
      prompt: 'Slide to show how strongly you believe this thought right now, '
          'from 0 (not at all) to 100 (completely).',
      key: 'before',
      lowLabel: '0  Not at all',
      highLabel: '100  Completely',
    );

ExerciseStep beliefThinkStep() {
  return ExerciseStep(
    title: 'Think it through',
    build: (context, c) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Prompt(
            'Take a moment. Write whatever comes up. Both boxes are optional.'),
        SafeBox(c: c, k: 'support', label: 'What makes this thought feel true?'),
        const SizedBox(height: 12),
        SafeBox(c: c, k: 'doubt', label: 'What do I notice that does not fit it?'),
      ],
    ),
  );
}

ExerciseStep beliefAfterStep() {
  return ExerciseStep(
    title: 'Rate it again',
    canContinue: (c) => true,
    build: (context, c) {
      // Start from the first rating so the slider is easy to compare.
      final start = c.intOf('before', 50);
      if (c.data['after'] == null) c.data['after'] = start;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Prompt('How strongly do you believe the thought now?'),
          SliderBlock(
            value: c.intOf('after', start),
            lowLabel: '0  Not at all',
            highLabel: '100  Completely',
            onChanged: (v) => c.set('after', v),
          ),
        ],
      );
    },
  );
}

ExerciseStep beliefSummaryStep() {
  return ExerciseStep(
    title: 'Your two ratings',
    build: (context, c) {
      final scheme = Theme.of(context).colorScheme;
      final hasBefore = c.data['before'] != null;
      final hasAfter = c.data['after'] != null;

      Widget tile(String label, String value) => Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    Text(label,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(value,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: scheme.primary, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              tile('Before', hasBefore ? '${c.intOf('before')}' : '-'),
              const SizedBox(width: 12),
              tile('After', hasAfter ? '${c.intOf('after')}' : '-'),
            ],
          ),
          const SizedBox(height: 12),
          Prompt(hasBefore && hasAfter
              ? beliefSummary(c.intOf('before'), c.intOf('after'))
              : 'One or both ratings were skipped. That is okay.'),
        ],
      );
    },
  );
}

/// A text box wired to a controller key (with the safety screening of FR-50).
class SafeBox extends StatelessWidget {
  const SafeBox({super.key, required this.c, required this.k, required this.label});

  final ExerciseController c;
  final String k;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SafeTextField(
      initial: c.text(k),
      label: label,
      maxLines: 3,
      onChanged: (v) => c.setQuiet(k, v),
    );
  }
}
