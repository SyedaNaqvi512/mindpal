import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../models/exercise_logic.dart';
import '../services/exercise_controller.dart';
import 'step_kit.dart';

/// FR-37: Thought Balance Scale. The beam tilts toward the side with more items.
class ThoughtScale extends StatelessWidget {
  const ThoughtScale({super.key, required this.forCount, required this.againstCount});

  final int forCount;
  final int againstCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tilt = scaleTilt(forCount, againstCount);

    return Semantics(
      label: scaleSummary(forCount, againstCount),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: tilt),
        duration: Motion.of(context, const Duration(milliseconds: 500)),
        curve: Curves.easeOutBack,
        builder: (context, t, _) => CustomPaint(
          size: const Size(double.infinity, 190),
          painter: _ScalePainter(
            tilt: t,
            forCount: forCount,
            againstCount: againstCount,
            beam: scheme.onSurface,
            forColor: scheme.primary,
            againstColor: scheme.tertiary,
            text: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ScalePainter extends CustomPainter {
  _ScalePainter({
    required this.tilt,
    required this.forCount,
    required this.againstCount,
    required this.beam,
    required this.forColor,
    required this.againstColor,
    required this.text,
  });

  final double tilt;
  final int forCount;
  final int againstCount;
  final Color beam;
  final Color forColor;
  final Color againstColor;
  final Color text;

  void _label(Canvas canvas, String s, Offset center, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final pivot = Offset(cx, 34);
    final half = math.min(size.width / 2 - 50, 120.0);
    final angle = -tilt * 0.28; // more "for" (left) lowers the left side

    final left = pivot + Offset(-half * math.cos(angle), -half * math.sin(angle));
    final right = pivot + Offset(half * math.cos(angle), half * math.sin(angle));

    final line = Paint()
      ..color = beam
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Stand
    canvas.drawLine(pivot, Offset(cx, size.height - 8), line);
    canvas.drawLine(Offset(cx - 34, size.height - 8), Offset(cx + 34, size.height - 8), line);
    // Beam
    canvas.drawLine(left, right, line);
    canvas.drawCircle(pivot, 7, Paint()..color = beam);

    void pan(Offset end, Color color, int count, String caption) {
      final string = Paint()
        ..color = beam.withValues(alpha: 0.6)
        ..strokeWidth = 1.5;
      final bottom = end + const Offset(0, 62);
      canvas.drawLine(end, bottom + const Offset(-36, 0), string);
      canvas.drawLine(end, bottom + const Offset(36, 0), string);
      final rect = Rect.fromCenter(center: bottom + const Offset(0, 8), width: 84, height: 30);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(15)),
        Paint()..color = color.withValues(alpha: 0.85),
      );
      _label(canvas, '$count', rect.center, Colors.white, 15);
      _label(canvas, caption, bottom + const Offset(0, 36), text, 12);
    }

    pan(left, forColor, forCount, 'For');
    pan(right, againstColor, againstCount, 'Against');
  }

  @override
  bool shouldRepaint(_ScalePainter old) =>
      old.tilt != tilt ||
      old.forCount != forCount ||
      old.againstCount != againstCount ||
      old.beam != beam;
}

ExerciseStep evidenceStep({
  required String title,
  required String prompt,
  required String key,
  required String label,
}) {
  return ExerciseStep(
    title: title,
    canContinue: (c) => c.list(key).isNotEmpty,
    build: (context, c) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Prompt(prompt),
        ThoughtScale(
          forCount: c.list('for').length,
          againstCount: c.list('against').length,
        ),
        const SizedBox(height: 12),
        ItemListEditor(
          items: c.list(key),
          label: label,
          onChanged: (v) => c.set(key, v),
        ),
      ],
    ),
  );
}

ExerciseStep scaleSummaryStep() {
  return ExerciseStep(
    title: 'The scale',
    build: (context, c) {
      final f = c.list('for');
      final a = c.list('against');
      Widget group(String label, List<String> items) => items.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                for (final t in items) Text('• $t'),
              ],
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Prompt(scaleSummary(f.length, a.length)),
          ThoughtScale(forCount: f.length, againstCount: a.length),
          group('Evidence for', f),
          group('Evidence against', a),
        ],
      );
    },
  );
}
