import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../../../core/widgets/breathing_circle.dart';
import '../models/reflection_progress_logic.dart';

/// Shown while a reflection is written: a breathing circle, a message that
/// changes every few seconds, and step dots showing how far along it is.
class ReflectionProgress extends StatefulWidget {
  const ReflectionProgress({super.key, this.onDevice = false});

  final bool onDevice;

  @override
  State<ReflectionProgress> createState() => _ReflectionProgressState();
}

class _ReflectionProgressState extends State<ReflectionProgress> {
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stage = reflectionStage(_seconds, onDevice: widget.onDevice);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BreathingCircle(),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: AnimatedSwitcher(
            duration: Motion.of(context, const Duration(milliseconds: 400)),
            child: Text(
              stage.message,
              key: ValueKey(stage.message),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < stage.total; i++)
              AnimatedContainer(
                duration: Motion.of(context, const Duration(milliseconds: 300)),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == stage.index ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i <= stage.index
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withValues(alpha: 0.25),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Your entry is saved on this phone.',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
