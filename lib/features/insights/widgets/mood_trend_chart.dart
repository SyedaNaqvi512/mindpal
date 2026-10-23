import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../journal/models/mood.dart';
import '../models/insights_calc.dart';

/// Line chart of the average mood per day (FR-28). Days without entries are gaps.
class MoodTrendChart extends StatelessWidget {
  const MoodTrendChart({
    super.key,
    required this.values,
    required this.labels,
    required this.summary,
  });

  final List<double?> values;

  /// One optional x-axis label per value (null = no label).
  final List<String?> labels;

  /// Text alternative for screen readers.
  final String summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: summary,
      child: SizedBox(
        height: 210,
        width: double.infinity,
        child: CustomPaint(
          painter: _TrendPainter(
            values: values,
            labels: labels,
            line: scheme.primary,
            grid: scheme.outlineVariant,
            text: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.labels,
    required this.line,
    required this.grid,
    required this.text,
  });

  final List<double?> values;
  final List<String?> labels;
  final Color line;
  final Color grid;
  final Color text;

  void _draw(Canvas canvas, String s, Offset center, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: fontSize, color: text)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0, right = 10.0, top = 10.0, bottom = 24.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    final n = values.length;
    if (n == 0) return;

    double yFor(double v) => top + h * (5 - v) / 4;
    double xFor(int i) => n == 1 ? left + w / 2 : left + w * i / (n - 1);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var level = 1; level <= 5; level++) {
      final y = yFor(level.toDouble());
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
      _draw(canvas, Mood.all[level - 1].emoji, Offset(12, y), 15);
    }

    for (var i = 0; i < n; i++) {
      final l = i < labels.length ? labels[i] : null;
      if (l != null) _draw(canvas, l, Offset(xFor(i), size.height - 9), 11);
    }

    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n - 1; i++) {
      final a = values[i], b = values[i + 1];
      if (a != null && b != null) {
        canvas.drawLine(
            Offset(xFor(i), yFor(a)), Offset(xFor(i + 1), yFor(b)), linePaint);
      }
    }

    final radius = n > 14 ? 4.0 : 6.0;
    for (var i = 0; i < n; i++) {
      final v = values[i];
      if (v == null) continue;
      final c = Offset(xFor(i), yFor(v));
      canvas.drawCircle(c, radius, Paint()..color = MoodColors.byLevel[moodIndex(v)]);
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.values != values ||
      old.labels != labels ||
      old.line != line ||
      old.grid != grid ||
      old.text != text;
}
