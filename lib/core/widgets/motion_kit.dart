import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/app_look.dart';
import 'app_backdrop.dart';

/// Gentle animations that make the app feel alive. Every one of them:
///  * shows the finished state at once when Reduce motion is on (SRS 5.4),
///  * runs for a limited time and then rests (saves battery, and widget tests
///    can settle, so there are no endless animations).
/// They are painted or built from Flutter widgets, so they follow the active
/// theme colours and work offline.

/// Calls [builder] with the seconds elapsed, for [seconds] seconds, then rests.
class Ambient extends StatefulWidget {
  const Ambient({super.key, required this.builder, this.seconds = 40});

  final Widget Function(BuildContext context, double t) builder;
  final int seconds;

  @override
  State<Ambient> createState() => _AmbientState();
}

class _AmbientState extends State<Ambient> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: Duration(seconds: widget.seconds));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!Motion.reduced(context)) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => widget.builder(context, _c.value * widget.seconds),
    );
  }
}

/// Moves its child up and down slowly, like a gentle float.
class Floating extends StatelessWidget {
  const Floating({super.key, required this.child, this.amplitude = 5, this.period = 4});

  final Widget child;
  final double amplitude;
  final double period;

  @override
  Widget build(BuildContext context) {
    final look = AppLook.of(context);
    final amp = amplitude * look.floatScale;
    final per = period * look.periodScale;
    return Ambient(
      builder: (context, t) => Transform.translate(
        offset: Offset(0, math.sin(t * 2 * math.pi / per) * amp),
        child: child,
      ),
      seconds: 30,
    );
  }
}

/// Drifts its child in a slow loop. [phase] shifts where the loop starts so
/// several shapes do not move together.
class Drift extends StatelessWidget {
  const Drift({
    super.key,
    required this.child,
    this.dx = 10,
    this.dy = 8,
    this.period = 9,
    this.phase = 0,
  });

  final Widget child;
  final double dx;
  final double dy;
  final double period;
  final double phase;

  @override
  Widget build(BuildContext context) {
    final look = AppLook.of(context);
    final per = period * look.periodScale;
    return Ambient(
      builder: (context, t) {
        final a = t * 2 * math.pi / per + phase;
        return Transform.translate(
          offset: Offset(math.sin(a) * dx * look.floatScale, math.cos(a) * dy * look.floatScale),
          child: child,
        );
      },
      seconds: 36,
    );
  }
}

/// Grows its child in with a small bounce, once.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    final look = AppLook.of(context);
    final total = look.scaled(delay + const Duration(milliseconds: 700));
    final begin = look.scaled(delay).inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(begin, 1, curve: look.popCurve),
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: child,
    );
  }
}

/// A short burst that celebrates a finished exercise. Its form follows the
/// look: confetti (Soft & Rounded), falling petals (Paper Journal), expanding
/// rings (Clean & Minimal) or rising sparkles (Night Glow). It plays once,
/// never blocks taps and is left out when Reduce motion is on.
class Celebration extends StatefulWidget {
  const Celebration({super.key, this.height = 240});

  final double height;

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final look = AppLook.of(context);
    _c.duration = look.scaled(const Duration(milliseconds: 2000));
    if (!Motion.reduced(context)) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final colors = [scheme.primary, scheme.secondary, scheme.tertiary, scheme.error];
    final kind = switch (AppLook.of(context).motion) {
      MotionStyle.bouncy => CelebrationKind.confetti,
      MotionStyle.gentle => CelebrationKind.petals,
      MotionStyle.crisp => CelebrationKind.rings,
      MotionStyle.dreamy => CelebrationKind.sparkles,
    };
    return ExcludeSemantics(
      child: IgnorePointer(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) =>
                CustomPaint(painter: ConfettiPainter(_c.value, colors, kind)),
          ),
        ),
      ),
    );
  }
}

enum CelebrationKind { confetti, petals, rings, sparkles }

class ConfettiPainter extends CustomPainter {
  ConfettiPainter(this.t, this.colors, [this.kind = CelebrationKind.confetti]);

  final double t;
  final List<Color> colors;
  final CelebrationKind kind;

  static const int count = 30;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.28);
    final fade = t < 0.65 ? 1.0 : (1 - (t - 0.65) / 0.35).clamp(0.0, 1.0);
    switch (kind) {
      case CelebrationKind.rings:
        for (var i = 0; i < 3; i++) {
          final local = ((t * 1.6) - i * 0.22).clamp(0.0, 1.0);
          if (local <= 0) continue;
          canvas.drawCircle(
            origin,
            30 + 130 * Curves.easeOutCubic.transform(local),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = colors[i % colors.length].withValues(alpha: 0.7 * (1 - local)),
          );
        }
        return;
      case CelebrationKind.sparkles:
        final r = math.Random(5);
        for (var i = 0; i < 22; i++) {
          final x = size.width * (0.1 + 0.8 * r.nextDouble());
          final startY = size.height * (0.55 + 0.4 * r.nextDouble());
          final rise = 70 + 110 * r.nextDouble();
          final delay = 0.25 * r.nextDouble();
          final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
          if (local <= 0) continue;
          final y = startY - rise * Curves.easeOut.transform(local);
          final twinkle = 0.5 + 0.5 * math.sin(local * math.pi * 3 + i);
          final a = (math.sin(local * math.pi)).clamp(0.0, 1.0) * twinkle;
          final s = 3 + 4 * r.nextDouble();
          final paint = Paint()..color = colors[i % colors.length].withValues(alpha: 0.9 * a);
          final path = Path()
            ..moveTo(x, y - s * 1.6)
            ..quadraticBezierTo(x, y, x + s * 1.6, y)
            ..quadraticBezierTo(x, y, x, y + s * 1.6)
            ..quadraticBezierTo(x, y, x - s * 1.6, y)
            ..quadraticBezierTo(x, y, x, y - s * 1.6);
          canvas.drawPath(path, paint);
        }
        return;
      case CelebrationKind.petals:
      case CelebrationKind.confetti:
        final rnd = math.Random(11);
        final secs = t * 2.0;
        final petals = kind == CelebrationKind.petals;
        for (var i = 0; i < count; i++) {
          final angle = -math.pi * (0.1 + 0.8 * rnd.nextDouble());
          final speed = (petals ? 50 : 120) + (petals ? 90 : 220) * rnd.nextDouble();
          final spin = rnd.nextDouble() * math.pi;
          final w = 5 + 5 * rnd.nextDouble();
          final color = colors[i % colors.length];
          final gravity = petals ? 110.0 : 260.0;
          final sway = petals ? math.sin(secs * 3 + i) * 14 : 0.0;
          final x = origin.dx + math.cos(angle) * speed * secs + sway;
          final y = origin.dy + math.sin(angle) * speed * secs + gravity * secs * secs;
          final paint = Paint()..color = color.withValues(alpha: 0.9 * fade);
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(spin + secs * (petals ? 2 : 4));
          if (petals) {
            canvas.drawOval(
                Rect.fromCenter(center: Offset.zero, width: w * 1.8, height: w), paint);
          } else {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(center: Offset.zero, width: w, height: w * 1.6),
                  const Radius.circular(2)),
              paint,
            );
          }
          canvas.restore();
        }
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) => old.t != t || old.kind != kind;
}

/// A page change that fades and slides in a little, instead of a hard cut.
class SoftPageTransitions extends PageTransitionsBuilder {
  const SoftPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // The background belongs to the route, outside the fade, so the page
    // underneath is hidden at once and nothing overlaps while it moves.
    if (Motion.reduced(context)) return AppBackdrop(child: child);
    final look = AppLook.of(context);
    final curved = CurvedAnimation(parent: animation, curve: look.enterCurve);
    return AppBackdrop(
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: Offset(0.05 * look.slideScale, 0), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      ),
    );
  }
}

/// Delay for the [i]-th item of a list, so items appear one after another
/// without a long wait: at most eight steps, 45 ms each.
Duration staggerDelay(int i, {int stepMs = 45, int maxSteps = 8}) =>
    Duration(milliseconds: stepMs * (i < maxSteps ? i : maxSteps));

/// Shrinks its child a little while it is pressed, so cards feel tappable.
/// It does not take part in the tap itself.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child});

  final Widget child;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (mounted && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !Motion.reduced(context) ? AppLook.of(context).pressScale : 1.0,
        duration: Motion.of(context, const Duration(milliseconds: 110)),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A number that counts up to its value, and counts from the old value when
/// it changes.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, this.style, this.suffix = ''});

  final int value;
  final TextStyle? style;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return Text('$value$suffix', style: style);
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$v$suffix', style: style),
    );
  }
}

/// Three dots that rise and fall in turn: "someone is writing".
class TypingDots extends StatelessWidget {
  const TypingDots({super.key, this.size = 8});

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
      child: Ambient(
        seconds: 120,
        builder: (context, t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Builder(builder: (context) {
                final v = (math.sin((t * 1.1 - i * 0.22) * 2 * math.pi) + 1) / 2;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: size * 0.25),
                  child: Transform.translate(
                    offset: Offset(0, -size * 0.6 * v),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.35 + 0.65 * v),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
