import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../screens/pin_prompt_screen.dart';
import '../screens/setup_lock_screen.dart';
import '../services/app_lock_service.dart';

/// Settings card for FR-32: app lock on/off, change PIN, fingerprint.
class AppLockSettingsTile extends StatefulWidget {
  const AppLockSettingsTile({super.key});

  @override
  State<AppLockSettingsTile> createState() => _AppLockSettingsTileState();
}

class _AppLockSettingsTileState extends State<AppLockSettingsTile> {
  final _svc = AppLockService.instance;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    _svc.biometricsAvailable().then((v) {
      if (mounted) setState(() => _bioAvailable = v);
    });
  }

  Future<bool> _askPin(String title) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PinPromptScreen(title: title)),
    );
    return ok == true;
  }

  Future<void> _toggle(bool on) async {
    if (on) {
      await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => const SetupLockScreen()));
    } else if (await _askPin('Turn off app lock')) {
      await _svc.reset();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('App lock turned off.')));
      }
    }
  }

  Future<void> _changePin() async {
    if (await _askPin('Change PIN') && mounted) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const SetupLockScreen(pinOnly: true)),
      );
    }
  }

  Future<void> _toggleBio(bool on) async {
    if (on) {
      final ok = await _svc.authenticateBiometric('Confirm your fingerprint');
      if (ok) await _svc.setBiometric(true);
    } else {
      await _svc.setBiometric(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListenableBuilder(
      listenable: _svc,
      builder: (context, _) => Card(
        child: Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Symbols.lock_rounded),
              title: const Text('App lock'),
              subtitle: Text(
                _svc.enabled
                    ? 'MindPal asks for your PIN when you open it.'
                    : 'Off. Anyone with your unlocked phone can open MindPal.',
                style: TextStyle(color: muted),
              ),
              value: _svc.enabled,
              onChanged: _toggle,
            ),
            if (_svc.enabled) ...[
              ListTile(
                leading: const Icon(Symbols.password_rounded),
                title: const Text('Change PIN'),
                onTap: _changePin,
              ),
              if (_bioAvailable)
                SwitchListTile(
                  secondary: const Icon(Symbols.fingerprint_rounded),
                  title: const Text('Unlock with fingerprint'),
                  value: _svc.biometricEnabled,
                  onChanged: _toggleBio,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
