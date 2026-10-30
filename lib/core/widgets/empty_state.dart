import 'package:flutter/material.dart';

/// A soft round badge with an icon and two small decorative dots.
class ArtBadge extends StatelessWidget {
  const ArtBadge({super.key, required this.icon, this.size = 96});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        width: size + 24,
        height: size + 16,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primaryContainer, scheme.secondaryContainer],
                ),
              ),
              child: Icon(icon, size: size * 0.46, color: scheme.primary),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                width: size * 0.16,
                height: size * 0.16,
                decoration: BoxDecoration(color: scheme.tertiary, shape: BoxShape.circle),
              ),
            ),
            Positioned(
              left: 6,
              bottom: 8,
              child: Container(
                width: size * 0.1,
                height: size * 0.1,
                decoration: BoxDecoration(color: scheme.secondary, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
            ArtBadge(icon: icon),
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
