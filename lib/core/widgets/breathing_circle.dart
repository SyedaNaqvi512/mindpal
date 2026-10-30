import 'package:flutter/material.dart';

import '../motion/motion.dart';

/// A slow breathing circle shown while the AI works (SRS 5.4). Still when motion is reduced.
class BreathingCircle extends StatefulWidget {
  const BreathingCircle({super.key, this.size = 120, this.label});

  final double size;
  final String? label;

  @override
  State<BreathingCircle> createState() => _BreathingCircleState();
}

class _BreathingCircleState extends State<BreathingCircle> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _controller.value = 0.5;
    } else {
      _controller.repeat(reverse: true);
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
    final size = widget.size;

    return Semantics(
      liveRegion: true,
      label: widget.label ?? 'Working on your reflection',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_controller.value);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: size * (0.70 + 0.30 * t),
                      height: size * (0.70 + 0.30 * t),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.secondary.withValues(alpha: 0.25),
                      ),
                    ),
                    Container(
                      width: size * (0.52 + 0.22 * t),
                      height: size * (0.52 + 0.22 * t),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: 0.28),
                      ),
                    ),
                    Container(
                      width: size * 0.34,
                      height: size * 0.34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [scheme.primary, scheme.secondary],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (widget.label != null) ...[
            const SizedBox(height: 8),
            Text(widget.label!,
                style: TextStyle(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
