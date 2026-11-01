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
        final scale = reduced ? 0.7 : 0.45 + 0.55 * size;
        final cue = _running
            ? breathCue(phase)
            : (_finished ? 'Notice how you feel.' : 'Ready when you are');

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(
                child: Semantics(
                  liveRegion: true,
                  label: cue,
                  child: Container(
                    width: widget.size * scale,
                    height: widget.size * scale,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary.withValues(alpha: 0.22),
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
