import 'package:flutter/material.dart';

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
  bool _hide = true;
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

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Enter your name.';
                        if (t.length > 50) return 'Keep it under 50 characters.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                            ? null
                            : 'Enter a valid email.';
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hide,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _hide ? 'Show password' : 'Hide password',
                          icon: Icon(_hide
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
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
                        child: Text('Please choose one.',
                            style: TextStyle(color: scheme.error)),
                      ),
                    const SizedBox(height: 20),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!,
                            style: TextStyle(color: scheme.error),
                            textAlign: TextAlign.center),
                      ),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Create account'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We will email you a 6-digit code to confirm your address.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
