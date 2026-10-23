import 'package:flutter/material.dart';

import '../services/app_lock_service.dart';
import '../widgets/lockout_notice.dart';
import '../widgets/pin_keypad.dart';

/// Asks for the current PIN before a sensitive change. Pops true when correct.
class PinPromptScreen extends StatefulWidget {
  const PinPromptScreen({super.key, required this.title});

  final String title;

  @override
  State<PinPromptScreen> createState() => _PinPromptScreenState();
}

class _PinPromptScreenState extends State<PinPromptScreen> {
  int _k = 0;
  String? _msg;
  Duration? _wait;

  Future<void> _check(String pin) async {
    final r = await AppLockService.instance.verifyPin(pin);
    if (!mounted) return;
    if (r.ok) {
      Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your current PIN',
                  style: Theme.of(context).textTheme.titleLarge,
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
                PinKeypad(
                  key: ValueKey(_k),
                  length: AppLockService.pinLength,
                  enabled: _wait == null,
                  onComplete: _check,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
