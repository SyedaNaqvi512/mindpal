import 'package:flutter/material.dart';

/// Keeps the app at a comfortable reading width on tablets, foldables and
/// landscape phones, and centers it. On a normal phone it changes nothing.
class ResponsiveFrame extends StatelessWidget {
  const ResponsiveFrame({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= maxWidth) return child;

    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: ClipRect(
          child: SizedBox(
            width: maxWidth,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: Size(maxWidth, MediaQuery.sizeOf(context).height),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
