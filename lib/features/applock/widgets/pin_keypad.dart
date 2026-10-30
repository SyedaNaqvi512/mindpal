import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/motion/motion.dart';

/// Four dots and a number pad. Change the widget's key to clear it.
class PinKeypad extends StatefulWidget {
  const PinKeypad({
    super.key,
    required this.length,
    required this.onComplete,
    this.enabled = true,
    this.bottomLeft,
  });

  final int length;
  final ValueChanged<String> onComplete;
  final bool enabled;

  /// Optional button next to 0 (for example the fingerprint).
  final Widget? bottomLeft;

  @override
  State<PinKeypad> createState() => _PinKeypadState();
}

class _PinKeypadState extends State<PinKeypad> {
  String _pin = '';

  void _tap(String d) {
    if (!widget.enabled || _pin.length >= widget.length) return;
    setState(() => _pin += d);
    if (_pin.length == widget.length) widget.onComplete(_pin);
  }

  void _back() {
    if (!widget.enabled || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Widget _key(
    BuildContext context,
    String label, {
    VoidCallback? onTap,
    Widget? child,
    String? semantics,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Semantics(
        button: true,
        label: semantics ?? label,
        child: ExcludeSemantics(
          child: InkResponse(
            onTap: widget.enabled
                ? () {
                    Motion.tap();
                    onTap?.call();
                  }
                : null,
            radius: 40,
            child: Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
              ),
              child:
                  child ??
                  Text(
                    label,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget row(List<Widget> kids) =>
        Row(mainAxisSize: MainAxisSize.min, children: kids);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '${_pin.length} of ${widget.length} digits entered',
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.length; i++)
                  Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length ? scheme.primary : null,
                      border: Border.all(color: scheme.primary, width: 2),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        for (final r in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          row([for (final d in r) _key(context, d, onTap: () => _tap(d))]),
        row([
          widget.bottomLeft != null
              ? Padding(
                  padding: const EdgeInsets.all(6),
                  child: SizedBox(
                    width: 68,
                    height: 68,
                    child: Center(child: widget.bottomLeft),
                  ),
                )
              : const SizedBox(width: 80, height: 80),
          _key(context, '0', onTap: () => _tap('0')),
          _key(
            context,
            '',
            onTap: _back,
            semantics: 'Delete',
            child: const Icon(Symbols.backspace_rounded),
          ),
        ]),
      ],
    );
  }
}
