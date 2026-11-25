import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/widgets/motion_kit.dart';

/// The parts of the simple body drawing used by the body scan.
enum BodyPart { head, neck, shoulders, chest, belly, arms, hands, legs, feet }

/// How strongly each part is lit for each body scan area (0 to 1). The keys
/// are the area titles in `kBodyScanAreas`.
const Map<String, Map<BodyPart, double>> kBodyFocus = {
  'Settle': {
    BodyPart.head: 0.4, BodyPart.neck: 0.4, BodyPart.shoulders: 0.4,
    BodyPart.chest: 0.4, BodyPart.belly: 0.4, BodyPart.arms: 0.4,
    BodyPart.hands: 0.4, BodyPart.legs: 0.4, BodyPart.feet: 0.4,
  },
  'Feet and legs': {BodyPart.legs: 1, BodyPart.feet: 1},
  'Hips and belly': {BodyPart.belly: 1},
  'Chest and back': {BodyPart.chest: 1},
  'Hands and arms': {BodyPart.arms: 1, BodyPart.hands: 1},
  'Shoulders and neck': {BodyPart.shoulders: 1, BodyPart.neck: 1},
  'Face and head': {BodyPart.head: 1},
  'Whole body': {
    BodyPart.head: 1, BodyPart.neck: 1, BodyPart.shoulders: 1,
    BodyPart.chest: 1, BodyPart.belly: 1, BodyPart.arms: 1,
    BodyPart.hands: 1, BodyPart.legs: 1, BodyPart.feet: 1,
  },
};

Map<BodyPart, double> bodyFocusFor(String area) => kBodyFocus[area] ?? const {};

/// A calm, simple figure that glows where the body scan asks you to look. When
/// the area changes, the old glow fades out while the new one fades in. With
/// Reduce motion on, the glow is steady and does not pulse.
class BodyFigure extends StatefulWidget {
  const BodyFigure({super.key, required this.area, this.height = 230});

  final String area;
  final double height;

  @override
  State<BodyFigure> createState() => _BodyFigureState();
}

class _BodyFigureState extends State<BodyFigure> {
  String? _previous;

  @override
  void didUpdateWidget(BodyFigure old) {
    super.didUpdateWidget(old);
    if (old.area != widget.area) _previous = old.area;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduced = Motion.reduced(context);
    final prev = _previous;

    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(widget.area),
          tween: Tween<double>(begin: reduced ? 1 : 0, end: 1),
          duration: Motion.of(context, const Duration(milliseconds: 600)),
          curve: Curves.easeOut,
          builder: (context, t, _) => Ambient(
            seconds: 45,
            builder: (context, secs) {
              final pulse =
                  reduced ? 0.6 : 0.5 + 0.5 * math.sin(secs * 2 * math.pi / 4);
              return CustomPaint(
                painter: BodyPainter(
                  now: bodyFocusFor(widget.area),
                  before: prev == null ? const {} : bodyFocusFor(prev),
                  t: t,
                  pulse: pulse,
                  base: scheme.onSurfaceVariant.withValues(alpha: 0.16),
                  glow: scheme.primary,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class BodyPainter extends CustomPainter {
  BodyPainter({
    required this.now,
    required this.before,
    required this.t,
    required this.pulse,
    required this.base,
    required this.glow,
  });

  final Map<BodyPart, double> now;
  final Map<BodyPart, double> before;
  final double t;
  final double pulse;
  final Color base;
  final Color glow;

  double _strength(BodyPart p) =>
      ((now[p] ?? 0) * t + (before[p] ?? 0) * (1 - t)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final cx = size.width / 2;

    RRect box(double l, double top, double r, double bottom, double radius) =>
        RRect.fromLTRBR(l, top, r, bottom, Radius.circular(radius));

    final shapes = <(BodyPart, Path)>[
      (BodyPart.head, Path()..addOval(Rect.fromCircle(center: Offset(cx, .10 * h), radius: .075 * h))),
      (BodyPart.neck, Path()..addRRect(box(cx - .025 * h, .17 * h, cx + .025 * h, .21 * h, .015 * h))),
      (BodyPart.shoulders, Path()..addRRect(box(cx - .19 * h, .205 * h, cx + .19 * h, .265 * h, .03 * h))),
      (BodyPart.chest, Path()..addRRect(box(cx - .16 * h, .27 * h, cx + .16 * h, .42 * h, .04 * h))),
      (BodyPart.belly, Path()..addRRect(box(cx - .15 * h, .425 * h, cx + .15 * h, .58 * h, .05 * h))),
      (
        BodyPart.arms,
        Path()
          ..addRRect(box(cx - .27 * h, .22 * h, cx - .21 * h, .50 * h, .03 * h))
          ..addRRect(box(cx + .21 * h, .22 * h, cx + .27 * h, .50 * h, .03 * h))
      ),
      (
        BodyPart.hands,
        Path()
          ..addOval(Rect.fromCircle(center: Offset(cx - .24 * h, .545 * h), radius: .035 * h))
          ..addOval(Rect.fromCircle(center: Offset(cx + .24 * h, .545 * h), radius: .035 * h))
      ),
      (
        BodyPart.legs,
        Path()
          ..addRRect(box(cx - .145 * h, .585 * h, cx - .02 * h, .90 * h, .05 * h))
          ..addRRect(box(cx + .02 * h, .585 * h, cx + .145 * h, .90 * h, .05 * h))
      ),
      (
        BodyPart.feet,
        Path()
          ..addOval(Rect.fromLTRB(cx - .17 * h, .905 * h, cx - .02 * h, .955 * h))
          ..addOval(Rect.fromLTRB(cx + .02 * h, .905 * h, cx + .17 * h, .955 * h))
      ),
    ];

    for (final (part, path) in shapes) {
      final s = _strength(part);
      if (s > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..color = glow.withValues(alpha: 0.38 * s * (0.55 + 0.45 * pulse))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, .035 * h),
        );
      }
      canvas.drawPath(
        path,
        Paint()..color = Color.lerp(base, glow.withValues(alpha: 0.9), 0.85 * s)!,
      );
    }
  }

  @override
  bool shouldRepaint(BodyPainter old) =>
      old.t != t || old.pulse != pulse || old.now != now || old.before != before;
}
