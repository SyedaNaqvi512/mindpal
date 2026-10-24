import 'package:flutter/material.dart';

import '../models/app_lock_logic.dart';
import '../services/app_lock_service.dart';
import 'pin_keypad.dart';

/// Choose a PIN, then type it again to confirm.
class NewPinForm extends StatefulWidget {
  const NewPinForm({super.key, required this.onDone});

  final ValueChanged<String> onDone;

  @override
  State<NewPinForm> createState() => _NewPinFormState();
}

class _NewPinFormState extends State<NewPinForm> {
  String? _first;
  int _k = 0;
  String? _msg;

  void _complete(String pin) {
    if (_first == null) {
      if (isWeakPin(pin)) {
        setState(() {
          _msg =
              'That PIN is too easy to guess (like 0000 or 1234). Try another.';
          _k++;
        });
        return;
      }
      setState(() {
        _first = pin;
        _msg = null;
        _k++;
      });
    } else if (pin == _first) {
      widget.onDone(pin);
    } else {
      setState(() {
        _first = null;
        _msg = 'The PINs did not match. Start again.';
        _k++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _first == null
              ? 'Choose a ${AppLockService.pinLength}-digit PIN'
              : 'Enter the PIN again',
          style: text.titleLarge,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: Text(
            _msg ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        PinKeypad(
          key: ValueKey(_k),
          length: AppLockService.pinLength,
          onComplete: _complete,
        ),
      ],
    );
  }
}
