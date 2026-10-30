import 'package:flutter/material.dart';

import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/password_field.dart';

import '../services/auth_service.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.login(_email.text, _password.text);
      if (mounted) widget.onSignedIn();
    } on EmailNotVerifiedException catch (e) {
      if (!mounted) return;
      // Send a fresh code and take the user to the code screen.
      try {
        await AuthService.instance.resendVerification(e.email);
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            VerifyEmailScreen(email: e.email, onVerified: widget.onSignedIn),
      ));
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue your journal.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Your entries stay on this phone.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Enter a valid email.' : null,
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _password,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (!_busy) _submit();
              },
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your password.' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ForgotPasswordScreen(initialEmail: _email.text),
                          ),
                        ),
                child: const Text('Forgot password?'),
              ),
            ),
            if (_error != null) ...[
              InlineMessage(_error!),
              const SizedBox(height: 12),
            ],
            BusyButton(label: 'Sign in', busy: _busy, onPressed: _submit),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => RegisterScreen(onSignedIn: widget.onSignedIn),
                      )),
              child: const Text('New here? Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}
