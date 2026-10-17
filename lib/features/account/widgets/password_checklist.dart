import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/password_rules.dart';

/// Live list of password rules, shown under the password field.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget row(bool ok, String text) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(ok ? Symbols.check_circle_rounded : Symbols.circle,
                  size: 18, color: ok ? scheme.primary : scheme.outline),
              const SizedBox(width: 8),
              Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(PasswordRules.hasLength(password), 'At least 8 characters'),
        row(PasswordRules.hasLetter(password), 'A letter'),
        row(PasswordRules.hasDigit(password), 'A digit'),
      ],
    );
  }
}
