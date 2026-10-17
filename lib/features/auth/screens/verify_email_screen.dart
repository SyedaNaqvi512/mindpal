import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';

/// FR-03: enter the 6-digit code that was emailed. On success the user is signed in.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.onVerified,
  });

  final String email;
  final VoidCallback onVerified;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _cooldown = 60;
  final _code = TextEditingController();
  Timer? _timer;
  int _left = _cooldown;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _left = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left = _left > 0 ? _left - 1 : 0);
      if (_left == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await AuthService.instance.verifyEmail(widget.email, code);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      widget.onVerified();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      await AuthService.instance.resendVerification(widget.email);
      if (!mounted) return;
      setState(() => _info = 'A new code is on its way.');
      _startTimer();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Check your inbox',
                      style: text.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('We sent a 6-digit code to\n${widget.email}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: text.headlineMedium?.copyWith(letterSpacing: 10),
                    decoration: const InputDecoration(
                        counterText: '', hintText: '000000'),
                    onChanged: (v) {
                      if (v.length == 6 && !_busy) _verify();
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.error)),
                    ),
                  if (_info != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_info!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.primary)),
                    ),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _verify,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Verify'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _left == 0 && !_busy ? _resend : null,
                    child: Text(_left == 0
                        ? 'Send a new code'
                        : 'Send a new code in ${_left}s'),
                  ),
                  Text('The code expires in 10 minutes. Check spam if you do not see it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
