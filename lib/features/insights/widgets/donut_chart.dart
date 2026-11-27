import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_look.dart';

/// One slice of a [DonutChart].
class DonutSlice {
  const DonutSlice(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

/// A donut (ring) chart. The ring sweeps round once when it appears, a tap on
/// a slice or on its legend entry shows that slice in the middle, and the
/// legend lists every slice with its count and percentage in words, so the
/// chart never relies on colour alone. Reduce motion shows the finished ring.
class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.centerValue,
    required this.centerLabel,
    required this.summary,
    this.size = 190,
  });

  /// Slices with a value of 0 are left out.
  final List<DonutSlice> slices;

  /// Shown in the middle when nothing is selected, for example "24".
  final String centerValue;
  final String centerLabel;

  /// Text alternative for screen readers.
  final String summary;
  final double size;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  int? _selected;
  bool _started = false;

  List<DonutSlice> get _slices => [for (final s in widget.slices) if (s.value > 0) s];
  int get _total => _slices.fold<int>(0, (a, s) => a + s.value);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play();
  }

  void _play() {
    _c.duration = AppLook.of(context).scaled(const Duration(milliseconds: 1000));
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(DonutChart old) {
    super.didUpdateWidget(old);
    final sameShape = old.slices.length == widget.slices.length &&
        [for (var i = 0; i < old.slices.length; i++) old.slices[i].value]
                .join(',') ==
            [for (var i = 0; i < widget.slices.length; i++) widget.slices[i].value].join(',');
    if (!sameShape) {
      _selected = null;
      _play();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _select(int? i) => setState(() => _selected = _selected == i ? null : i);

  void _onTap(Offset pos) {
    final slices = _slices;
    if (slices.isEmpty) return;
    final c = Offset(widget.size / 2, widget.size / 2);
    final d = pos - c;
    final dist = d.distance;
    final outer = widget.size / 2;
    if (dist < outer * 0.5 || dist > outer + 6) {
      setState(() => _selected = null);
      return;
    }
    var angle = math.atan2(d.dy, d.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    final frac = angle / (2 * math.pi) * _total;
    var run = 0;
    for (var i = 0; i < slices.length; i++) {
      run += slices[i].value;
      if (frac <= run) {
        _select(i);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final slices = _slices;
    final total = _total;
    final sel = _selected != null && _selected! < slices.length ? _selected : null;

    String percent(int v) => '${(v * 100 / total).round()}%';

    final centerTop = sel == null ? widget.centerValue : percent(slices[sel].value);
    final centerBottom = sel == null
        ? widget.centerLabel
        : '${slices[sel].label} (${slices[sel].value})';

    return Semantics(
      label: widget.summary,
      child: Column(
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _onTap(d.localPosition),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => CustomPaint(
                      size: Size.square(widget.size),
                      painter: _DonutPainter(
                        slices: slices,
                        progress: Curves.easeOutCubic.transform(_c.value),
                        selected: sel,
                        track: scheme.surfaceContainerHighest,
                        thickness: widget.size * 0.15,
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Padding(
                      padding: EdgeInsets.all(widget.size * 0.22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(centerTop,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.headlineSmall
                                  ?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w700)),
                          Text(
                            centerBottom,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, height: 1.2, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < slices.length; i++)
                _LegendItem(
                  slice: slices[i],
                  percent: percent(slices[i].value),
                  selected: sel == i,
                  onTap: () => _select(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.slice,
    required this.percent,
    required this.selected,
    required this.onTap,
  });

  final DonutSlice slice;
  final String percent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${slice.label}, ${slice.value}, $percent',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppLook.of(context).fieldRadius),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: slice.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.onSurface.withValues(alpha: 0.25)),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${slice.label} ${slice.value} · $percent',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.progress,
    required this.selected,
    required this.track,
    required this.thickness,
  });

  final List<DonutSlice> slices;
  final double progress;
  final int? selected;
  final Color track;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - thickness / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness,
    );

    final total = slices.fold<int>(0, (a, s) => a + s.value);
    if (total == 0) return;
    final gap = slices.length > 1 ? 0.05 : 0.0;
    final visible = 2 * math.pi * progress;
    var start = 0.0;
    for (var i = 0; i < slices.length; i++) {
      final full = slices[i].value / total * 2 * math.pi;
      final from = start;
      final to = start + full;
      start = to;
      final drawTo = math.min(to - gap, visible);
      final sweep = drawTo - (from + gap / 2);
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect,
        -math.pi / 2 + from + gap / 2,
        sweep,
        false,
        Paint()
          ..color = slices[i].color
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == selected ? thickness + 8 : thickness
          ..strokeCap = StrokeCap.butt,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.slices != slices ||
      old.track != track;
}
