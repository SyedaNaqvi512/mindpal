import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// A short message inside a screen: an error (default) or a calm note.
class InlineMessage extends StatelessWidget {
  const InlineMessage(this.text, {super.key, this.isError = true});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = isError ? scheme.error : scheme.primary;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError ? scheme.errorContainer : scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isError ? Symbols.error_rounded : Symbols.info_rounded, size: 20, color: accent),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: scheme.onSurface))),
          ],
        ),
      ),
    );
  }
}
