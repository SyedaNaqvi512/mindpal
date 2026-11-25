import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../models/exercise_logic.dart';

/// FR-39: a bubble that expands, pauses, contracts and pauses. FR-53: when
/// reduced motion is on the bubble stays still and only the words change, so
/// every function stays.
class BreathingBubble extends StatefulWidget {
  const BreathingBubble({
    super.key,
    this.cycles = 4,
    this.onFinished,
    this.size = 220,
    this.autoStart = false,
    this.caption,
  });

  /// Number of full breaths.
  final int cycles;
  final VoidCallback? onFinished;
  final double size;
  final bool autoStart;

  /// Optional text shown inside the bubble, such as a calming phrase.
  final String? caption;

  @override
  State<BreathingBubble> createState() => _BreathingBubbleState();
}

class _BreathingBubbleState extends State<BreathingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  int _done = 0;
  bool _running = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: kBreathCycleSeconds),
    )..addStatusListener(_onStatus);
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  void _onStatus(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    _done++;
    if (_done >= widget.cycles) {
      setState(() {
        _running = false;
        _finished = true;
      });
      widget.onFinished?.call();
    } else {
      _ctl.forward(from: 0);
    }
  }

  void _start() {
    if (!mounted) return;
    setState(() {
      _done = 0;
      _running = true;
      _finished = false;
    });
    _ctl.forward(from: 0);
  }

  void _stop() {
    _ctl.stop();
    setState(() => _running = false);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduced = Motion.reduced(context);

    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        final (phase, size) = breathAt(_ctl.value);
        final scale = reduced ? 0.62 : 0.34 + 0.46 * size;
        final cue = _running
            ? breathCue(phase)
            : (_finished ? 'Notice how you feel.' : 'Ready when you are');

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // How far through the whole session you are.
                  CustomPaint(
                    size: Size.square(widget.size),
                    painter: _ProgressRing(
                      progress: _running
                          ? ((_done + _ctl.value) / widget.cycles).clamp(0.0, 1.0)
                          : (_finished ? 1.0 : 0.0),
                      color: scheme.primary,
                    ),
                  ),
                  // Soft halos that follow the bubble.
                  for (final (factor, alpha) in const [(1.22, 0.06), (1.10, 0.11)])
                    Container(
                      width: widget.size * scale * factor,
                      height: widget.size * scale * factor,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: alpha),
                      ),
                    ),
                  Semantics(
                    liveRegion: true,
                    label: cue,
                    child: Container(
                      width: widget.size * scale,
                      height: widget.size * scale,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            scheme.primary.withValues(alpha: 0.10),
                            scheme.primary.withValues(alpha: 0.32),
                          ],
                        ),
                        border: Border.all(color: scheme.primary, width: 3),
                      ),
                      child: widget.caption == null
                          ? null
                          : Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                widget.caption!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(cue, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              _running
                  ? 'Breath ${_done + 1} of ${widget.cycles}'
                  : '${widget.cycles} slow breaths',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (_running)
              OutlinedButton(onPressed: _stop, child: const Text('Pause'))
            else
              FilledButton(
                onPressed: _start,
                child: Text(_finished ? 'Breathe again' : 'Start breathing'),
              ),
          ],
        );
      },
    );
  }
}

/// A thin ring around the bubble that fills as the breaths are done.
class _ProgressRing extends CustomPainter {
  _ProgressRing({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = color.withValues(alpha: 0.12);
    canvas.drawOval(rect, track);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -1.5707963, 6.2831853 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_ProgressRing old) =>
      old.progress != progress || old.color != color;
}
