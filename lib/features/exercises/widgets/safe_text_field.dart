import 'package:flutter/material.dart';

import '../../journal/services/reflection_service.dart';
import '../../safety/widgets/support_card.dart';

/// A text field for exercises. FR-50: the same safety screening as for journal
/// entries runs on the phone on everything typed here, and the support message
/// of FR-19 is shown when it triggers. The text never leaves the phone.
class SafeTextField extends StatefulWidget {
  const SafeTextField({
    super.key,
    this.controller,
    this.initial = '',
    required this.onChanged,
    this.label,
    this.hint,
    this.maxLines = 3,
    this.maxLength = 500,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String initial;
  final ValueChanged<String> onChanged;
  final String? label;
  final String? hint;
  final int maxLines;
  final int maxLength;
  final ValueChanged<String>? onSubmitted;

  @override
  State<SafeTextField> createState() => _SafeTextFieldState();
}

class _SafeTextFieldState extends State<SafeTextField> {
  late final TextEditingController _c;
  late final bool _owns;
  bool _crisis = false;

  @override
  void initState() {
    super.initState();
    _owns = widget.controller == null;
    _c = widget.controller ?? TextEditingController(text: widget.initial);
    _c.addListener(_check);
    _check();
  }

  void _check() {
    // Once the support message has appeared it stays, so it is not lost by an edit.
    if (_crisis) return;
    if (ReflectionService.looksLikeCrisis(_c.text)) {
      setState(() => _crisis = true);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_check);
    if (_owns) _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _c,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          minLines: 1,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            counterText: '',
          ),
        ),
        if (_crisis) ...[
          const SizedBox(height: 12),
          const SupportCard(),
        ],
      ],
    );
  }
}
