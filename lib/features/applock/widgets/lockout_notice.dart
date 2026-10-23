import 'dart:async';

import 'package:flutter/material.dart';

/// "Too many wrong attempts. Try again in 0:45" with a live countdown.
class LockoutNotice extends StatefulWidget {
  const LockoutNotice({super.key, required this.wait, required this.onDone});

  final Duration wait;
  final VoidCallback onDone;

  @override
  State<LockoutNotice> createState() => _LockoutNoticeState();
}

class _LockoutNoticeState extends State<LockoutNotice> {
  late final DateTime _until = DateTime.now().add(widget.wait);
  Timer? _timer;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    _left = widget.wait;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = _until.difference(DateTime.now());
      if (left <= Duration.zero) {
        t.cancel();
        widget.onDone();
      } else if (mounted) {
        setState(() => _left = left);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _left.inSeconds.clamp(0, 99999);
    final text = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    return Text(
      'Too many wrong attempts. Try again in $text.',
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
