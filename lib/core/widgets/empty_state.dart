import 'package:flutter/material.dart';

import 'look_art.dart';
import 'motion_kit.dart';

/// The picture on empty states. Its drawing follows the current look.
class ArtBadge extends StatelessWidget {
  const ArtBadge({super.key, required this.icon, this.size = 96});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: LookBadge(icon: icon, size: size));
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Floating(child: ArtBadge(icon: icon)),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
