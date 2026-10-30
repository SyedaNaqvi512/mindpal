import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../journal/models/mood.dart';
import '../models/insights_calc.dart';

/// Line chart of the average mood per day (FR-28). Days without entries are gaps.
/// The line draws in from the left (SRS 5.4) and a tap on a point shows a tooltip.
class MoodTrendChart extends StatefulWidget {
  const MoodTrendChart({
    super.key,
    required this.values,
    required this.labels,
    required this.summary,
    this.tooltipLabels = const [],
  });

  final List<double?> values;

  /// One optional x-axis label per value (null = no label).
  final List<String?> labels;

  /// Text alternative for screen readers.
  final String summary;

  /// One label per value for the tooltip, for example "Thu, 22 Oct".
  final List<String> tooltipLabels;

  @override
  State<MoodTrendChart> createState() => _MoodTrendChartState();
}

const double _left = 34, _right = 12, _top = 16, _bottom = 26;

class _MoodTrendChartState extends State<MoodTrendChart> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _selected;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play();
  }

  void _play() {
    if (Motion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(MoodTrendChart old) {
    super.didUpdateWidget(old);
    if (old.values.length != widget.values.length) {
      _selected = null;
      _play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap(Offset pos, double width) {
    final n = widget.values.length;
    if (n == 0) return;
    final w = width - _left - _right;
    final raw = n == 1 ? 0.0 : (pos.dx - _left) / w * (n - 1);
    var best = raw.round().clamp(0, n - 1);
    // If that day is empty, try its neighbours.
    if (widget.values[best] == null) {
      for (final d in [-1, 1]) {
        final j = best + d;
        if (j >= 0 && j < n && widget.values[j] != null) {
          best = j;
          break;
        }
      }
    }
    setState(() => _selected = widget.values[best] == null || _selected == best ? null : best);
  }

  String? _tooltip() {
    final i = _selected;
    if (i == null || i >= widget.values.length) return null;
    final v = widget.values[i];
    if (v == null) return null;
    final mood = Mood.all[moodIndex(v)].label;
    if (i < widget.tooltipLabels.length) return '${widget.tooltipLabels[i]} · $mood';
    return mood;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: widget.summary,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _onTap(d.localPosition, width),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => SizedBox(
                height: 220,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TrendPainter(
                    values: widget.values,
                    labels: widget.labels,
                    line: scheme.primary,
                    grid: scheme.outline.withValues(alpha: 0.25),
                    text: scheme.onSurfaceVariant,
                    bubbleFill: scheme.onSurface,
                    bubbleText: scheme.surface,
                    progress: Curves.easeOutCubic.transform(_controller.value),
                    selected: _selected,
                    tooltip: _tooltip(),
                  ),
                ),
              ),
            ),
          );
        },
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
    required this.bubbleFill,
    required this.bubbleText,
    required this.progress,
    required this.selected,
    required this.tooltip,
  });

  final List<double?> values;
  final List<String?> labels;
  final Color line;
  final Color grid;
  final Color text;
  final Color bubbleFill;
  final Color bubbleText;
  final double progress;
  final int? selected;
  final String? tooltip;

  void _draw(Canvas canvas, String s, Offset center, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: fontSize, color: text)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - _left - _right;
    final h = size.height - _top - _bottom;
    final n = values.length;
    if (n == 0) return;

    double yFor(double v) => _top + h * (5 - v) / 4;
    double xFor(int i) => n == 1 ? _left + w / 2 : _left + w * i / (n - 1);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var level = 1; level <= 5; level++) {
      final y = yFor(level.toDouble());
      canvas.drawLine(Offset(_left, y), Offset(size.width - _right, y), gridPaint);
      _draw(canvas, Mood.all[level - 1].emoji, Offset(14, y), 16);
    }

    for (var i = 0; i < n; i++) {
      final l = i < labels.length ? labels[i] : null;
      if (l != null) _draw(canvas, l, Offset(xFor(i), size.height - 9), 11);
    }

    // The line and dots draw in from the left.
    canvas.save();
    final clipRight = progress >= 1 ? size.width : _left + w * progress + 2;
    canvas.clipRect(Rect.fromLTRB(0, 0, clipRight, size.height));

    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n - 1; i++) {
      final a = values[i], b = values[i + 1];
      if (a != null && b != null) {
        canvas.drawLine(Offset(xFor(i), yFor(a)), Offset(xFor(i + 1), yFor(b)), linePaint);
      }
    }

    final radius = n > 14 ? 4.5 : 6.5;
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
    canvas.restore();

    // Tooltip for the tapped point.
    final sel = selected;
    final tip = tooltip;
    if (sel != null && tip != null && sel < n && values[sel] != null) {
      final c = Offset(xFor(sel), yFor(values[sel]!));
      canvas.drawLine(
        Offset(c.dx, _top),
        Offset(c.dx, size.height - _bottom),
        Paint()
          ..color = line.withValues(alpha: 0.35)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        c,
        radius + 3,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: tip,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: bubbleText),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      const padX = 10.0, padY = 6.0;
      final bw = tp.width + padX * 2;
      final bh = tp.height + padY * 2;
      final bx = (c.dx - bw / 2).clamp(4.0, size.width - bw - 4.0);
      var by = c.dy - radius - 10 - bh;
      if (by < 0) by = c.dy + radius + 10;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(10)),
        Paint()..color = bubbleFill,
      );
      tp.paint(canvas, Offset(bx + padX, by + padY));
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.values != values ||
      old.labels != labels ||
      old.line != line ||
      old.grid != grid ||
      old.text != text ||
      old.progress != progress ||
      old.selected != selected ||
      old.tooltip != tooltip ||
      old.bubbleFill != bubbleFill;
}
