import 'package:flutter/material.dart';

import '../../auth/services/auth_service.dart';
import '../models/password_rules.dart';
import '../widgets/password_checklist.dart';
import '../../../core/widgets/toast.dart';

/// FR-08: change password. Other devices are signed out by the server.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.changePassword(_current.text, _new.text);
      if (!mounted) return;
      Toast.of(context, 'Password changed. Other devices were signed out.',
          kind: ToastKind.success);
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            tooltip: _hide ? 'Show passwords' : 'Hide passwords',
            icon: Icon(_hide
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _hide = !_hide),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _current,
                      obscureText: _hide,
                      decoration: deco('Current password'),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Enter your current password.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _new,
                      obscureText: _hide,
                      onChanged: (_) => setState(() {}),
                      decoration: deco('New password'),
                      validator: (v) {
                        final rule = PasswordRules.validate(v ?? '');
                        if (rule != null) return rule;
                        if (v == _current.text) {
                          return 'Your new password must be different from your current password.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    PasswordChecklist(password: _new.text),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _hide,
                      decoration: deco('Repeat new password'),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Repeat your new password.';
                        }
                        return v == _new.text ? null : 'Passwords do not match.';
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!, style: TextStyle(color: scheme.error)),
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
                            : const Text('Change password'),
                      ),
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
