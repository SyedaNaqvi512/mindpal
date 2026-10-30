import 'package:flutter/material.dart';

/// A filled pill button that shows a spinner while [busy]. It is not greyed out
/// while busy, so the spinner (onPrimary) stays visible.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed == null ? null : (busy ? () {} : onPressed),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy) ...[
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: scheme.onPrimary),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
