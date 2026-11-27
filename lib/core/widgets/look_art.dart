import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_look.dart';
import 'motion_kit.dart';

/// The decoration inside a [BrandHeader], drawn in the style of the look:
/// drifting circles, ruled lines, a dot grid or small stars. All of it is
/// finite and quiet, and it stays out of the way of the text.
class HeaderArt extends StatelessWidget {
  const HeaderArt({super.key});

  @override
  Widget build(BuildContext context) {
    final look = AppLook.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.onPrimary;
    switch (look.art) {
      case ArtStyle.blobs:
        final circle = ink.withValues(alpha: 0.10);
        return Positioned.fill(
          child: Stack(children: [
            Positioned(
              top: -50,
              right: -40,
              child: Drift(dx: 12, dy: 10, child: _Disc(190, circle)),
            ),
            Positioned(
              bottom: -30,
              left: -50,
              child: Drift(dx: 9, dy: 12, period: 11, phase: 2, child: _Disc(150, circle)),
            ),
            Positioned(
              top: 70,
              left: 30,
              child: Floating(
                  amplitude: 7, period: 5, child: _Disc(16, ink.withValues(alpha: 0.18))),
            ),
          ]),
        );
      case ArtStyle.lines:
        return Positioned.fill(
          child: ExcludeSemantics(
            child: CustomPaint(painter: _LinesPainter(ink.withValues(alpha: 0.14))),
          ),
        );
      case ArtStyle.dots:
        return Positioned.fill(
          child: ExcludeSemantics(
            child: CustomPaint(painter: _DotGridPainter(ink.withValues(alpha: 0.16))),
          ),
        );
      case ArtStyle.stars:
        return Positioned.fill(
          child: Stack(children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(painter: _StarsPainter(ink.withValues(alpha: 0.5))),
              ),
            ),
            Positioned(
              top: -60,
              right: -30,
              child: Drift(
                  dx: 14,
                  dy: 8,
                  period: 14,
                  child: _Disc(180, ink.withValues(alpha: 0.07))),
            ),
          ]),
        );
    }
  }
}

class _Disc extends StatelessWidget {
  const _Disc(this.size, this.color);

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _LinesPainter extends CustomPainter {
  _LinesPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double y = 18; y < size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_LinesPainter old) => old.color != color;
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (double x = 14; x < size.width; x += 22) {
      for (double y = 14; y < size.height; y += 22) {
        canvas.drawCircle(Offset(x, y), 1.4, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}

class _StarsPainter extends CustomPainter {
  _StarsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(7);
    final p = Paint();
    for (var i = 0; i < 26; i++) {
      p.color = color.withValues(alpha: color.a * (0.3 + 0.7 * r.nextDouble()));
      canvas.drawCircle(
          Offset(r.nextDouble() * size.width, r.nextDouble() * size.height),
          0.6 + r.nextDouble() * 1.3,
          p);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.color != color;
}

/// The picture inside the empty states and similar spots, in the look's style:
/// a round badge with small dots, a ruled paper tag, a hairline square with a
/// dot grid, or a glowing moon-like disc with stars.
class LookBadge extends StatelessWidget {
  const LookBadge({super.key, required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final look = AppLook.of(context);
    final w = size + 24;
    final h = size + 16;
    switch (look.art) {
      case ArtStyle.blobs:
        return SizedBox(
          width: w,
          height: h,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primaryContainer, scheme.secondaryContainer],
                ),
              ),
              child: Icon(icon, size: size * 0.46, color: scheme.primary),
            ),
            Positioned(right: 4, top: 4, child: _Disc(size * 0.16, scheme.tertiary)),
            Positioned(left: 6, bottom: 8, child: _Disc(size * 0.1, scheme.secondary)),
          ]),
        );
      case ArtStyle.lines:
        // A small framed "stamp", slightly tilted like a sticker on a page.
        return SizedBox(
          width: w,
          height: h,
          child: Center(
            child: Transform.rotate(
              angle: -0.05,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: scheme.primary, width: 1.6),
                ),
                child: Container(
                  margin: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
                  ),
                  child: Icon(icon, size: size * 0.44, color: scheme.primary),
                ),
              ),
            ),
          ),
        );
      case ArtStyle.dots:
        return SizedBox(
          width: w,
          height: h,
          child: Stack(alignment: Alignment.center, children: [
            Positioned.fill(
              child: CustomPaint(
                  painter: _DotGridPainter(scheme.primary.withValues(alpha: 0.22))),
            ),
            Container(
              width: size * 0.82,
              height: size * 0.82,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.7)),
              ),
              child: Icon(icon, size: size * 0.40, color: scheme.primary),
            ),
          ]),
        );
      case ArtStyle.stars:
        return SizedBox(
          width: w,
          height: h,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: size + 10,
              height: size + 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 2),
                ],
              ),
            ),
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHigh,
                border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, size: size * 0.44, color: scheme.primary),
            ),
            Positioned(right: 6, top: 6, child: _Disc(size * 0.07, scheme.onSurface)),
            Positioned(left: 10, top: 16, child: _Disc(size * 0.05, scheme.secondary)),
            Positioned(right: 18, bottom: 8, child: _Disc(size * 0.05, scheme.tertiary)),
          ]),
        );
    }
  }
}
