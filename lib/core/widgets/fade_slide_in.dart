import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/app_look.dart';
import 'motion_kit.dart';

/// Fades a child in while it slides up a little. [delay] lets several blocks
/// appear one after another (SRS 5.4). Shows the child at once when motion is reduced.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offset = 0.08,
    this.press = false,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  /// Also shrinks a little while pressed (for tappable cards).
  final bool press;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _curve;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // The look decides how long and how far things move, and which curve.
    final look = AppLook.of(context);
    final delay = look.scaled(widget.delay);
    final total = delay + look.scaled(widget.duration);
    _controller.duration = total;
    final begin = total.inMilliseconds == 0 ? 0.0 : delay.inMilliseconds / total.inMilliseconds;
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, 1.0, curve: look.enterCurve),
    );
    if (Motion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offset = widget.offset * AppLook.of(context).slideScale;
    final animated = FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0, offset), end: Offset.zero)
            .animate(_curve),
        child: widget.child,
      ),
    );
    return widget.press ? Pressable(child: animated) : animated;
  }
}
