import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_look.dart';

/// The page background of the current look: soft colour blobs, ruled paper,
/// plain colour or a still star field. It is painted once (no animation), is
/// not part of the semantics and never takes taps. Each page route draws its
/// own copy underneath the page, so a page never shows the one behind it
/// while it slides in.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final look = AppLook.of(context);
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (look.backdrop != BackdropStyle.plain)
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: BackdropPainter(look.backdrop, scheme)),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class BackdropPainter extends CustomPainter {
  BackdropPainter(this.style, this.scheme);

  final BackdropStyle style;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case BackdropStyle.plain:
        return;
      case BackdropStyle.blobs:
        _blob(canvas, Offset(size.width * 0.95, size.height * 0.08), size.width * 0.55,
            scheme.secondary.withValues(alpha: 0.22));
        _blob(canvas, Offset(size.width * 0.05, size.height * 0.62), size.width * 0.60,
            scheme.primary.withValues(alpha: 0.10));
        _blob(canvas, Offset(size.width * 0.85, size.height * 0.95), size.width * 0.50,
            scheme.tertiary.withValues(alpha: 0.20));
      case BackdropStyle.paper:
        final line = Paint()
          ..color = scheme.primary.withValues(alpha: 0.07)
          ..strokeWidth = 1;
        for (double y = 64; y < size.height; y += 32) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
        canvas.drawLine(
          Offset(34, 0),
          Offset(34, size.height),
          Paint()
            ..color = scheme.error.withValues(alpha: 0.12)
            ..strokeWidth = 1,
        );
      case BackdropStyle.stars:
        _blob(canvas, Offset(size.width * 0.8, size.height * 0.1), size.width * 0.7,
            scheme.primary.withValues(alpha: 0.16));
        _blob(canvas, Offset(size.width * 0.1, size.height * 0.85), size.width * 0.6,
            scheme.secondary.withValues(alpha: 0.10));
        final r = math.Random(42);
        final paint = Paint();
        for (var i = 0; i < 46; i++) {
          final p = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
          final s = 0.6 + r.nextDouble() * 1.2;
          paint.color = scheme.onSurface.withValues(alpha: 0.10 + r.nextDouble() * 0.22);
          canvas.drawCircle(p, s, paint);
        }
    }
  }

  void _blob(Canvas canvas, Offset c, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: c, radius: radius));
    canvas.drawCircle(c, radius, paint);
  }

  @override
  bool shouldRepaint(BackdropPainter old) => old.style != style || old.scheme != scheme;
}
