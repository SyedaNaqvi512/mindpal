import 'package:flutter/material.dart';

/// A password box with a show/hide button.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hide = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hide,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: _hide ? 'Show password' : 'Hide password',
          icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _hide = !_hide),
        ),
      ),
    );
  }
}
