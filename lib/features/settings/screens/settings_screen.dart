import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/theme_controller.dart';
import '../../account/models/user_profile.dart';
import '../../account/screens/delete_account_screen.dart';
import '../../account/screens/profile_screen.dart';
import '../../account/widgets/avatar_image.dart';
import '../../applock/widgets/app_lock_settings_tile.dart';
import '../../auth/services/auth_service.dart';
import '../../consent/services/consent_service.dart';
import '../../consent/widgets/consent_sheet.dart';
import '../../reminders/widgets/reminder_settings_tile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  Future<void> _signOut() async {
    ConsentService.instance.clear();
    await AuthService.instance.logout();
    onSignedOut();
  }

  List<Color> _swatches(AppPalette p) => [
    p.background,
    p.primary,
    p.secondary,
    p.accent,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    final options = <_ThemeOption>[
      for (final p in AppPalette.all)
        _ThemeOption(
          choice: ThemeChoice.values.firstWhere((c) => c.name == p.id),
          label: p.name,
          swatches: _swatches(p),
        ),
      _ThemeOption(
        choice: ThemeChoice.system,
        label: 'System',
        subtitle: 'Follows your phone',
        swatches: [
          AppPalette.lavenderDream.background,
          AppPalette.lavenderDream.primary,
          AppPalette.midnightLavender.background,
          AppPalette.midnightLavender.primary,
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: text.titleMedium),
          const SizedBox(height: 4),
          Text('Choose how MindPal looks.', style: TextStyle(color: muted)),
          const SizedBox(height: 12),
          for (final o in options)
            _ThemeCard(
              option: o,
              selected: current == o.choice,
              onTap: () => controller.select(o.choice),
            ),
          const SizedBox(height: 24),
          Text('Privacy', style: text.titleMedium),
          const SizedBox(height: 8),
          const _AiConsentTile(),
          const SizedBox(height: 24),

          // New: app lock and daily reminder settings.
          Text('Security and reminders', style: text.titleMedium),
          const SizedBox(height: 8),
          const AppLockSettingsTile(),
          const SizedBox(height: 8),
          const ReminderSettingsTile(),
          const SizedBox(height: 24),

          Text('Account', style: text.titleMedium),
          const SizedBox(height: 8),
          const _ProfileTile(),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Symbols.logout_rounded),
              title: const Text('Sign out'),
              onTap: _signOut,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                Symbols.delete_forever_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete account',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text('Remove your account and all your data'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeleteAccountScreen(onSignedOut: onSignedOut),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatefulWidget {
  const _ProfileTile();

  @override
  State<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<_ProfileTile> {
  late Future<UserProfile?> _future = _load();

  Future<UserProfile?> _load() async {
    try {
      return await AuthService.instance.fetchProfile();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<UserProfile?>(
        future: _future,
        builder: (context, snap) {
          final p = snap.data;
          return ListTile(
            leading: p == null
                ? const Icon(Symbols.account_circle_rounded)
                : AvatarImage(avatarId: p.avatarId, size: 40),
            title: Text(
              p?.displayName.isNotEmpty == true ? p!.displayName : 'Profile',
            ),
            subtitle: Text(p?.email ?? 'View and edit your profile'),
            trailing: const Icon(Symbols.chevron_right_rounded),
            onTap: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
              if (mounted) setState(() => _future = _load());
            },
          );
        },
      ),
    );
  }
}

class _AiConsentTile extends StatefulWidget {
  const _AiConsentTile();

  @override
  State<_AiConsentTile> createState() => _AiConsentTileState();
}

class _AiConsentTileState extends State<_AiConsentTile> {
  bool? _granted; // null = loading
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final g = await ConsentService.instance.isGranted(refresh: true);
      if (!mounted) return;
      setState(() => _granted = g);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    try {
      if (on) {
        final agreed = await showConsentSheet(context);
        if (agreed) {
          await ConsentService.instance.grant();
          if (mounted) setState(() => _granted = true);
        }
      } else {
        await ConsentService.instance.revoke();
        if (mounted) setState(() => _granted = false);
      }
    } on AuthException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      child: _error != null
          ? ListTile(
              leading: const Icon(Symbols.refresh_rounded),
              title: const Text('AI reflections'),
              subtitle: Text('$_error Tap to try again.'),
              onTap: _load,
            )
          : SwitchListTile(
              secondary: const Icon(Symbols.cloud_rounded),
              title: const Text('AI reflections (cloud)'),
              subtitle: Text(
                _granted == true
                    ? 'Entries you reflect on are sent securely to an AI '
                          'service. Turn off to withdraw permission.'
                    : 'Off. Entries are not sent anywhere.',
                style: TextStyle(color: muted),
              ),
              value: _granted ?? false,
              onChanged: (_granted == null || _busy) ? null : _toggle,
            ),
    );
  }
}

class _ThemeOption {
  const _ThemeOption({
    required this.choice,
    required this.label,
    required this.swatches,
    this.subtitle,
  });

  final ThemeChoice choice;
  final String label;
  final String? subtitle;
  final List<Color> swatches;
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(24);

    return Semantics(
      button: true,
      selected: selected,
      label: '${option.label} theme',
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  for (final c in option.swatches)
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.outline),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          option.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (option.subtitle != null)
                          Text(
                            option.subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Symbols.check_circle_rounded, color: scheme.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
