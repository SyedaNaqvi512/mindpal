import 'package:flutter/material.dart';

import '../services/app_lock_service.dart';
import '../widgets/new_pin_form.dart';
import '../widgets/recovery_form.dart';

/// Turn the lock on (PIN, then recovery questions, then optional fingerprint),
/// or with [pinOnly] just choose a new PIN. Pops true when finished.
class SetupLockScreen extends StatefulWidget {
  const SetupLockScreen({super.key, this.pinOnly = false});

  final bool pinOnly;

  @override
  State<SetupLockScreen> createState() => _SetupLockScreenState();
}

enum _Step { pin, recovery, fingerprint }

class _SetupLockScreenState extends State<SetupLockScreen> {
  final _svc = AppLockService.instance;
  _Step _step = _Step.pin;
  String? _pin;
  List<String> _ids = const [];
  List<String> _answers = const [];
  bool _canBio = false;
  bool _busy = false;
  String? _error;

  Future<void> _pinChosen(String pin) async {
    if (widget.pinOnly) {
      await _svc.setPin(pin);
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    _pin = pin;
    setState(() => _step = _Step.recovery);
  }

  Future<void> _recoveryChosen(List<String> ids, List<String> answers) async {
    _ids = ids;
    _answers = answers;
    final bio = await _svc.biometricsAvailable();
    if (!mounted) return;
    if (bio) {
      setState(() {
        _canBio = true;
        _step = _Step.fingerprint;
      });
    } else {
      await _finish(false);
    }
  }

  Future<void> _finish(bool bio) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _svc.setPin(_pin!);
      await _svc.saveRecovery(_ids, _answers);
      await _svc.setBiometric(bio);
      await _svc.enable();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save the lock on this phone. Please try again.';
        });
      }
    }
  }

  Future<void> _tryFingerprint() async {
    final ok = await _svc.authenticateBiometric('Confirm your fingerprint');
    if (!mounted) return;
    if (ok) {
      await _finish(true);
    } else {
      setState(() => _error = 'Fingerprint was not confirmed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget body;
    switch (_step) {
      case _Step.pin:
        body = NewPinForm(onDone: _pinChosen);
      case _Step.recovery:
        body = RecoveryForm(onDone: _recoveryChosen);
      case _Step.fingerprint:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Use your fingerprint too?', style: text.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'You can unlock with your fingerprint instead of the PIN. '
              'The PIN always still works.',
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_busy || !_canBio) ? null : _tryFingerprint,
                child: const Text('Use fingerprint'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : () => _finish(false),
                child: const Text('PIN only'),
              ),
            ),
          ],
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pinOnly ? 'Change PIN' : 'Set up app lock'),
      ),
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
