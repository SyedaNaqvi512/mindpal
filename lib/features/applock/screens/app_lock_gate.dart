import 'package:flutter/material.dart';

import '../services/app_lock_service.dart';
import 'lock_screen.dart';

/// Wraps the whole app (MaterialApp.builder). Locks on start and every time the
/// app goes to the background, and keeps the app's own state while locked.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final _svc = AppLockService.instance;
  late bool _locked = _svc.enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _svc.addListener(_changed);
  }

  @override
  void dispose() {
    _svc.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      if (!_svc.enabled) _locked = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        _svc.enabled &&
        !_svc.suspendAutoLock &&
        !_locked) {
      setState(() => _locked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Offstage(offstage: _locked, child: widget.child),
        if (_locked)
          Positioned.fill(
            child: LockScreen(
              onUnlocked: () => setState(() => _locked = false),
            ),
          ),
      ],
    );
  }
}
