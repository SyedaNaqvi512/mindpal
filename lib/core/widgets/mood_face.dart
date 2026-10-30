import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../features/journal/models/mood.dart';
import '../motion/motion.dart';
import '../theme/app_palette.dart';

/// One mood as a colored circle with an emoji. Bounces and vibrates lightly
/// when it becomes selected (SRS 5.4).
class MoodFace extends StatefulWidget {
  const MoodFace({
    super.key,
    required this.mood,
    required this.selected,
    required this.onTap,
    this.size = 48,
    this.showLabel = true,
    this.enabled = true,
  });

  final Mood mood;
  final bool selected;
  final VoidCallback? onTap;
  final double size;
  final bool showLabel;
  final bool enabled;

  @override
  State<MoodFace> createState() => _MoodFaceState();
}

class _MoodFaceState extends State<MoodFace> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.28), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.28, end: 0.92), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(MoodFace old) {
    super.didUpdateWidget(old);
    if (!old.selected && widget.selected && !Motion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    Motion.tap();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = MoodColors.byLevel[widget.mood.value - 1];
    final size = widget.size;

    return Semantics(
      button: true,
      selected: widget.selected,
      enabled: widget.enabled,
      label: '${widget.mood.label} mood',
      excludeSemantics: true,
      onTap: widget.enabled ? _handleTap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? _handleTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scale,
                child: SizedBox(
                  width: size + 8,
                  height: size + 8,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: fill,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.selected ? scheme.primary : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(widget.mood.emoji, style: TextStyle(fontSize: size * 0.52)),
                      ),
                      if (widget.selected)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                            child: Icon(Symbols.check_rounded, size: 13, color: scheme.onPrimary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.showLabel) ...[
                const SizedBox(height: 2),
                Text(
                  widget.mood.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w600,
                    color: widget.selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Five [MoodFace]s in a row. [value] is 1-5, or null when nothing is chosen.
class MoodFaceRow extends StatelessWidget {
  const MoodFaceRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.size = 46,
    this.showLabels = true,
  });

  final int? value;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final double size;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in Mood.all)
          Expanded(
            child: Center(
              child: MoodFace(
                mood: m,
                size: size,
                showLabel: showLabels,
                selected: value == m.value,
                enabled: enabled,
                onTap: enabled ? () => onChanged(m.value) : null,
              ),
            ),
          ),
      ],
    );
  }
}
