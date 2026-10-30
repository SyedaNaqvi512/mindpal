import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/motion/motion.dart';
import '../../../core/widgets/logo_mark.dart';
import '../models/app_lock_logic.dart';
import '../services/app_lock_service.dart';
import '../widgets/lockout_notice.dart';
import '../widgets/new_pin_form.dart';
import '../widgets/pin_keypad.dart';

enum _Mode { pin, forgot, newPin }

/// Full-screen lock. Everything happens inside this widget (no dialogs or
/// routes) because it sits above the app's navigator.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _svc = AppLockService.instance;
  _Mode _mode = _Mode.pin;
  int _k = 0;
  String? _msg;
  Duration? _wait;
  List<String> _questionIds = const [];
  List<TextEditingController> _answers = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (_svc.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fingerprint());
    }
  }

  @override
  void dispose() {
    for (final c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fingerprint() async {
    final ok = await _svc.authenticateBiometric('Unlock MindPal');
    if (ok && mounted) widget.onUnlocked();
  }

  Future<void> _onPin(String pin) async {
    final r = await _svc.verifyPin(pin);
    if (!mounted) return;
    if (r.ok) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _k++;
      _wait = r.lockedFor;
      _msg = r.lockedFor != null
          ? null
          : 'Wrong PIN. ${r.attemptsLeft} '
                '${r.attemptsLeft == 1 ? 'try' : 'tries'} left.';
    });
  }

  Future<void> _openForgot() async {
    final ids = await _svc.recoveryQuestionIds();
    if (!mounted) return;
    setState(() {
      _questionIds = ids;
      _answers = [for (final _ in ids) TextEditingController()];
      _msg = null;
      _wait = null;
      _mode = _Mode.forgot;
    });
  }

  Future<void> _checkAnswers() async {
    if (_busy) return;
    final texts = [for (final c in _answers) c.text];
    if (texts.any((t) => normalizeAnswer(t).isEmpty)) {
      setState(() => _msg = 'Please answer all three questions.');
      return;
    }
    setState(() => _busy = true);
    final r = await _svc.verifyRecovery(texts);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok) {
        _msg = null;
        _wait = null;
        _k++;
        _mode = _Mode.newPin;
      } else {
        _k++;
        _wait = r.lockedFor;
        _msg = r.lockedFor != null
            ? null
            : 'Those answers do not match. ${r.attemptsLeft} '
                  '${r.attemptsLeft == 1 ? 'try' : 'tries'} left.';
      }
    });
  }

  Future<void> _savePin(String pin) async {
    await _svc.setPin(pin);
    if (mounted) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget body;
    switch (_mode) {
      case _Mode.pin:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LogoMark(size: 64),
            const SizedBox(height: 16),
            Text('Enter your PIN', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Your journal is locked',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: _wait != null
                  ? LockoutNotice(
                      key: ValueKey(_k),
                      wait: _wait!,
                      onDone: () => setState(() => _wait = null),
                    )
                  : Text(
                      _msg ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    ),
            ),
            _Shake(
              trigger: _k,
              child: PinKeypad(
                key: ValueKey(_k),
                length: AppLockService.pinLength,
                enabled: _wait == null,
                onComplete: _onPin,
                bottomLeft: _svc.biometricEnabled
                    ? IconButton(
                        onPressed: _fingerprint,
                        icon: const Icon(
                          Symbols.fingerprint_rounded,
                          size: 32,
                          semanticLabel: 'Use fingerprint',
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _openForgot,
              child: const Text('Forgot PIN?'),
            ),
          ],
        );
      case _Mode.forgot:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Forgot your PIN?', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              'For your safety a PIN can never be shown. Answer your three '
              'recovery questions and you can choose a new PIN. Your journal '
              'is not affected.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (_questionIds.isEmpty)
              const Text('No recovery questions were saved on this phone.')
            else
              for (var i = 0; i < _questionIds.length; i++) ...[
                Text(
                  RecoveryQuestions.all[_questionIds[i]] ?? 'Question',
                  style: text.titleSmall,
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _answers[i],
                  enabled: _wait == null,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: 'Answer ${i + 1}'),
                ),
                const SizedBox(height: 14),
              ],
            if (_wait != null)
              LockoutNotice(
                key: ValueKey(_k),
                wait: _wait!,
                onDone: () => setState(() => _wait = null),
              )
            else if (_msg != null)
              Text(_msg!, style: TextStyle(color: scheme.error)),
            const SizedBox(height: 12),
            if (_questionIds.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_wait == null && !_busy) ? _checkAnswers : null,
                  child: const Text('Check answers'),
                ),
              ),
            TextButton(
              onPressed: () => setState(() {
                _mode = _Mode.pin;
                _msg = null;
                _wait = null;
                _k++;
              }),
              child: const Text('Back to PIN'),
            ),
          ],
        );
      case _Mode.newPin:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Answers correct', style: text.labelLarge),
            const SizedBox(height: 8),
            NewPinForm(onDone: _savePin),
          ],
        );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shakes its child sideways each time [trigger] goes up (a wrong PIN).
class _Shake extends StatefulWidget {
  const _Shake({required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<_Shake> createState() => _ShakeState();
}

class _ShakeState extends State<_Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(_Shake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && !Motion.reduced(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          math.sin(_c.value * math.pi * 5) * 12 * (1 - _c.value),
          0,
        ),
        child: child,
      ),
    );
  }
}
