import 'package:flutter/material.dart';

import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/password_field.dart';

import '../../account/models/avatars.dart';
import '../../account/models/password_rules.dart';
import '../../account/widgets/password_checklist.dart';
import '../services/auth_service.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _gender;
  bool _genderMissing = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final okForm = _form.currentState!.validate();
    setState(() => _genderMissing = _gender == null);
    if (!okForm || _gender == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await AuthService.instance.register(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        gender: _gender!,
      );
      if (!mounted) return;
      if (result.verificationRequired) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
              email: result.email, onVerified: widget.onSignedIn),
        ));
      } else {
        Navigator.of(context).popUntil((r) => r.isFirst);
        widget.onSignedIn();
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'A calm space for your thoughts. It takes a minute.',
      showLogo: false,
      footer: Text(
        'We will email you a 6-digit code to confirm your address.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Enter your name.';
                if (t.length > 40) return 'Keep it under 40 characters.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) {
                final t = v?.trim() ?? '';
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                    ? null
                    : 'Enter a valid email.';
              },
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _password,
              onChanged: (_) => setState(() {}),
              validator: (v) => PasswordRules.validate(v ?? ''),
            ),
            const SizedBox(height: 8),
            PasswordChecklist(password: _password.text),
            const SizedBox(height: 20),
            Text('Gender', style: text.titleSmall),
            const SizedBox(height: 4),
            Text('Used only to suggest profile pictures.',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final g in Gender.all)
                  ChoiceChip(
                    label: Text(Gender.label(g)),
                    selected: _gender == g,
                    onSelected: (_) => setState(() {
                      _gender = g;
                      _genderMissing = false;
                    }),
                  ),
              ],
            ),
            if (_genderMissing)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Please choose one.', style: TextStyle(color: scheme.error)),
              ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              InlineMessage(_error!),
              const SizedBox(height: 12),
            ],
            BusyButton(label: 'Create account', busy: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
