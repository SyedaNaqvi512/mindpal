import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_look.dart';

/// One bar of a [BarChartView].
class ChartBar {
  const ChartBar({
    required this.label,
    required this.value,
    required this.color,
    this.tooltip,
  });

  /// The x-axis label under the bar.
  final String label;

  /// Null or 0 draws a small empty stub.
  final double? value;
  final Color color;

  /// Shown above the bar when it is tapped, for example "Mon · Good (4.0)".
  final String? tooltip;
}

/// A vertical bar chart. Bars grow up from the base one after another (short
/// and finished within a second), a tap shows a tooltip, and Reduce motion
/// shows the finished bars. [maxValue] fixes the top of the scale (for
/// example 5 for mood); otherwise it fits the largest bar.
class BarChartView extends StatefulWidget {
  const BarChartView({
    super.key,
    required this.bars,
    required this.summary,
    this.maxValue,
    this.ticks,
    this.height = 190,
    this.averageLine,
  });

  final List<ChartBar> bars;
  final String summary;
  final double? maxValue;

  /// Values labelled on the left axis; defaults to 0, half and top.
  final List<double>? ticks;
  final double height;

  /// A dashed horizontal line, for example the average mood.
  final double? averageLine;

  @override
  State<BarChartView> createState() => _BarChartViewState();
}

class _BarChartViewState extends State<BarChartView> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  int? _selected;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play();
  }

  void _play() {
    _c.duration = AppLook.of(context).scaled(const Duration(milliseconds: 900));
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(BarChartView old) {
    super.didUpdateWidget(old);
    final a = [for (final b in old.bars) b.value];
    final b = [for (final x in widget.bars) x.value];
    if (a.length != b.length || a.join(',') != b.join(',')) {
      _selected = null;
      _play();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _top {
    if (widget.maxValue != null) return widget.maxValue!;
    var m = 0.0;
    for (final b in widget.bars) {
      if ((b.value ?? 0) > m) m = b.value!;
    }
    return m < 1 ? 1 : m.ceilToDouble();
  }

  void _onTap(Offset pos, double width) {
    final n = widget.bars.length;
    if (n == 0) return;
    final slot = (width - _BarPainter.left - _BarPainter.right) / n;
    final i = ((pos.dx - _BarPainter.left) / slot).floor();
    if (i < 0 || i >= n) {
      setState(() => _selected = null);
      return;
    }
    setState(() => _selected = _selected == i ? null : i);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final look = AppLook.of(context);
    final radius = (look.cardRadius / 4).clamp(1.5, 7.0).toDouble();
    final top = _top;
    final ticks = widget.ticks ?? [0.0, top / 2, top];

    return Semantics(
      label: widget.summary,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _onTap(d.localPosition, width),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => SizedBox(
                height: widget.height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _BarPainter(
                    bars: widget.bars,
                    top: top,
                    ticks: ticks,
                    progress: _c.value,
                    selected: _selected,
                    radius: radius,
                    grid: scheme.outline.withValues(alpha: 0.25),
                    text: scheme.onSurfaceVariant,
                    stub: scheme.surfaceContainerHighest,
                    bubbleFill: scheme.onSurface,
                    bubbleText: scheme.surface,
                    accent: scheme.primary,
                    averageLine: widget.averageLine,
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

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.bars,
    required this.top,
    required this.ticks,
    required this.progress,
    required this.selected,
    required this.radius,
    required this.grid,
    required this.text,
    required this.stub,
    required this.bubbleFill,
    required this.bubbleText,
    required this.accent,
    required this.averageLine,
  });

  static const double left = 30, right = 8, topPad = 18, bottom = 26;

  final List<ChartBar> bars;
  final double top;
  final List<double> ticks;
  final double progress;
  final int? selected;
  final double radius;
  final Color grid;
  final Color text;
  final Color stub;
  final Color bubbleFill;
  final Color bubbleText;
  final Color accent;
  final double? averageLine;

  TextPainter _tp(String s, double size, Color color, {FontWeight? weight}) => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(fontSize: size, color: color, fontWeight: weight),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout();

  String _fmt(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  @override
  void paint(Canvas canvas, Size size) {
    final n = bars.length;
    if (n == 0) return;
    final plotW = size.width - left - right;
    final plotH = size.height - topPad - bottom;
    final slot = plotW / n;
    final barW = (slot * 0.56).clamp(6.0, 42.0).toDouble();
    double yFor(double v) => topPad + plotH * (1 - (v / top).clamp(0.0, 1.0));

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final t in ticks) {
      final y = yFor(t);
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
      final tp = _tp(_fmt(t), 11, text);
      tp.paint(canvas, Offset(left - 6 - tp.width, y - tp.height / 2));
    }

    for (var i = 0; i < n; i++) {
      final cx = left + slot * (i + 0.5);
      final b = bars[i];

      final tp = _tp(b.label, 11, text);
      final maxLabel = slot + 4;
      final lp = tp.width > maxLabel ? _tp(b.label, 9.5, text) : tp;
      lp.paint(canvas, Offset(cx - lp.width / 2, size.height - bottom + 7));

      // Each bar starts a little after the one before it.
      final start = n <= 1 ? 0.0 : 0.45 * i / (n - 1);
      final local = ((progress - start) / (1 - 0.45)).clamp(0.0, 1.0).toDouble();
      final eased = Curves.easeOutCubic.transform(local);

      final v = b.value;
      final base = yFor(0);
      if (v == null || v <= 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - barW / 2, base - 3, barW, 3),
            Radius.circular(radius.clamp(0.0, 1.5)),
          ),
          Paint()..color = stub,
        );
        continue;
      }
      final h = (base - yFor(v)) * eased;
      final rect = Rect.fromLTWH(cx - barW / 2, base - h, barW, h);
      final r = Radius.circular(radius.clamp(0.0, barW / 2));
      final rrect = RRect.fromRectAndCorners(rect, topLeft: r, topRight: r);
      canvas.drawRRect(rrect, Paint()..color = b.color);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = (i == selected ? accent : text.withValues(alpha: 0.35))
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == selected ? 2.2 : 1,
      );
    }

    final avg = averageLine;
    if (avg != null) {
      final y = yFor(avg);
      final dash = Paint()
        ..color = accent.withValues(alpha: 0.9)
        ..strokeWidth = 1.5;
      for (double x = left; x < size.width - right; x += 9) {
        canvas.drawLine(Offset(x, y), Offset((x + 5).clamp(0.0, size.width - right), y), dash);
      }
    }

    final sel = selected;
    if (sel != null && sel < n && bars[sel].tooltip != null && progress >= 1) {
      final b = bars[sel];
      final cx = left + slot * (sel + 0.5);
      final y = (b.value == null || b.value! <= 0) ? yFor(0) : yFor(b.value!);
      final tp = _tp(b.tooltip!, 12, bubbleText, weight: FontWeight.w700);
      const padX = 10.0, padY = 6.0;
      final bw = tp.width + padX * 2;
      final bh = tp.height + padY * 2;
      final bx = (cx - bw / 2).clamp(2.0, size.width - bw - 2.0).toDouble();
      var by = y - 8 - bh;
      if (by < 0) by = 0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), Radius.circular(radius + 4)),
        Paint()..color = bubbleFill,
      );
      tp.paint(canvas, Offset(bx + padX, by + padY));
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.bars != bars ||
      old.top != top ||
      old.grid != grid ||
      old.averageLine != averageLine ||
      old.radius != radius;
}
