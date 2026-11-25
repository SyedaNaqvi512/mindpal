import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion_kit.dart';

/// A grey placeholder that breathes softly while content loads. It shows the
/// shape of what is coming, so the screen does not jump when data arrives.
/// With Reduce motion on it stays still; it also rests after a while.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 10});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return Ambient(
      seconds: 60,
      builder: (context, t) {
        final v = (math.sin(t * 2 * math.pi / 1.6) + 1) / 2;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.05 + 0.06 * v),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      },
    );
  }
}

/// A list of placeholder cards. [tall] makes them chart-sized.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5, this.tall = false});

  final int count;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: count,
          separatorBuilder: (context, i) => const SizedBox(height: 12),
          itemBuilder: (context, i) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: tall
                  ? const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 140, height: 16),
                        SizedBox(height: 14),
                        SkeletonBox(height: 110, radius: 16),
                      ],
                    )
                  : const Row(
                      children: [
                        SkeletonBox(width: 44, height: 44, radius: 22),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 150, height: 14),
                              SizedBox(height: 10),
                              SkeletonBox(height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
