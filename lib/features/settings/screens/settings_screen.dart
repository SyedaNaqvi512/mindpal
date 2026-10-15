import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/theme_switcher_button.dart';
import '../../auth/services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  Future<void> _signOut() async {
    await AuthService.instance.logout();
    onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        // Temporary: replaced by theme cards in the next step.
        actions: const [ThemeSwitcherButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Use the palette button at the top to change the theme.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 24),
          Text('Account', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Card(
            child: ListTile(
              leading: const Icon(Symbols.logout_rounded),
              title: const Text('Sign out'),
              onTap: _signOut,
            ),
          ),
        ],
      ),
    );
  }
}