import 'package:flutter/material.dart';

import '../motion/motion.dart';

/// A ring that pulses around [child] while [active] (the mic, SRS 5.4).
/// Shows a steady ring when motion is reduced.
class PulseRing extends StatefulWidget {
  const PulseRing({super.key, required this.active, required this.child, this.size = 48});

  final bool active;
  final Widget child;
  final double size;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PulseRing old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && !Motion.reduced(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = widget.size + 24;
    final steady = widget.active && Motion.reduced(context);

    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.active)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = steady ? 0.5 : _controller.value;
                return Container(
                  width: widget.size + 24 * t,
                  height: widget.size + 24 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: steady ? 0.5 : 0.6 * (1 - t)),
                      width: 3,
                    ),
                  ),
                );
              },
            ),
          widget.child,
        ],
      ),
    );
  }
}
