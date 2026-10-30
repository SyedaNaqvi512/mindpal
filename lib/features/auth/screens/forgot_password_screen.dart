import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/password_field.dart';
import 'package:flutter/services.dart';

import '../../account/models/password_rules.dart';
import '../../account/widgets/password_checklist.dart';
import '../services/auth_service.dart';

/// FR-06: ask for a code by email, then choose a new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _info;
  int _left = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _left = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left = _left > 0 ? _left - 1 : 0);
      if (_left == 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await AuthService.instance.forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _info = 'If that email has an account, a code is on its way.';
      });
      _startTimer();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    final pwError = PasswordRules.validate(_password.text);
    if (pwError != null) {
      setState(() => _error = pwError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await AuthService.instance
          .resetPassword(_email.text, _code.text, _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password changed. Please sign in.')));
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Reset password',
      subtitle: _codeSent
          ? 'Enter the code from your email and choose a new password.'
          : 'Enter your account email and we will send you a 6-digit code.',
      showLogo: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _email,
            enabled: !_codeSent,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          if (_codeSent) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _password,
              label: 'New password',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            PasswordChecklist(password: _password.text),
          ],
          const SizedBox(height: 16),
          if (_error != null) ...[
            InlineMessage(_error!),
            const SizedBox(height: 12),
          ],
          if (_info != null) ...[
            InlineMessage(_info!, isError: false),
            const SizedBox(height: 12),
          ],
          BusyButton(
            label: _codeSent ? 'Change password' : 'Send code',
            busy: _busy,
            onPressed: _codeSent ? _reset : _sendCode,
          ),
          if (_codeSent)
            TextButton(
              onPressed: _left == 0 && !_busy ? _sendCode : null,
              child: Text(_left == 0 ? 'Send a new code' : 'Send a new code in ${_left}s'),
            ),
        ],
      ),
    );
  }
}
