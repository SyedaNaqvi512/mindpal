import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/logo_mark.dart';
import '../../account/models/user_profile.dart';
import '../../account/screens/change_password_screen.dart';
import '../../account/screens/delete_account_screen.dart';
import '../../account/screens/profile_screen.dart';
import '../../account/services/profile_store.dart';
import '../../account/widgets/avatar_image.dart';
import '../../applock/widgets/app_lock_settings_tile.dart';
import '../../auth/services/auth_service.dart';
import '../../consent/services/consent_service.dart';
import '../../consent/widgets/consent_sheet.dart';
import '../../reminders/widgets/reminder_settings_tile.dart';
import '../../safety/support_info.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  Future<void> _signOut() async {
    ConsentService.instance.clear();
    ProfileStore.instance.clear();
    await AuthService.instance.logout();
    onSignedOut();
  }

  /// A bottom sheet with a title and some content.
  void _showSheet(BuildContext context, String title, List<Widget> children) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _para(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: const TextStyle(height: 1.4)),
      );

  void _privacy(BuildContext context) => _showSheet(context, 'Privacy summary', [
        _para('Your journal text stays on this phone, in an encrypted database.'),
        _para('The MindPal server keeps your account, sign-in tokens, consent '
            'records and simple counts. It does not keep your journal text.'),
        _para('With Cloud AI, the entry you choose to reflect on is sent to an AI '
            'service to write the reflection. A safety check runs on your phone '
            'first, and you can withdraw permission at any time.'),
        _para('On this phone mode keeps the entry on the phone and does not use '
            'the cloud.'),
        _para('If you delete your account, your server data is removed within 7 '
            'days and the journal on this phone is erased straight away.'),
        _para('MindPal is a self-help reflection tool. It is not therapy, a '
            'diagnosis, or an emergency service.'),
      ]);

  void _about(BuildContext context) => _showSheet(context, 'About MindPal', [
        const Center(child: LogoMark(size: 72)),
        const SizedBox(height: 16),
        _para('MindPal is a calm place to write down how your day felt and to '
            'notice your thoughts a little better, with gentle CBT-style '
            'reflections.'),
        _para('It is a final-year project at Punjab Tianjin University of '
            'Technology, Lahore.'),
        _para('MindPal is not a therapist or medical advice. If you are '
            'struggling, please talk to someone you trust or a mental health '
            'service.'),
      ]);

  void _help(BuildContext context) => _showSheet(context, 'Help & support', [
        _para('If you are struggling, you deserve support from a real person. '
            'Please talk to someone you trust, or contact a mental health '
            'service.'),
        for (final h in kHelplines)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: const Icon(Symbols.favorite_rounded),
                title: Text(h.name),
                subtitle: SelectableText(h.number,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        _para('If you are in immediate danger, contact your local emergency '
            'services right away.'),
      ]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final current = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);

    final options = <_ThemeOption>[
      for (final p in AppPalette.all)
        _ThemeOption(
          choice: ThemeChoice.values.firstWhere((c) => c.name == p.id),
          label: p.name,
          palettes: [p],
        ),
      _ThemeOption(
        choice: ThemeChoice.system,
        label: 'System',
        palettes: [AppPalette.lavenderDream, AppPalette.midnightLavender],
      ),
    ];

    Widget tile(int i) => Expanded(
          child: _ThemeTile(
            option: options[i],
            selected: current == options[i].choice,
            onTap: () => controller.select(options[i].choice),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, AppTokens.space24),
        children: [
          const FadeSlideIn(child: _ProfileHeader()),
          const _SectionLabel('Appearance'),
          Row(children: [
            tile(0),
            const SizedBox(width: 10),
            tile(1),
            const SizedBox(width: 10),
            tile(2),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            tile(3),
            const SizedBox(width: 10),
            tile(4),
            const SizedBox(width: 10),
            const Expanded(child: SizedBox.shrink()),
          ]),
          const SizedBox(height: 10),
          ValueListenableBuilder<bool>(
            valueListenable: reduceMotionSetting,
            builder: (context, reduced, _) => Card(
              child: SwitchListTile(
                secondary: const Icon(Symbols.slow_motion_video_rounded),
                title: const Text('Reduce motion'),
                subtitle: Text('Fewer animations. Also follows your phone setting.',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                value: reduced,
                onChanged: (v) => Motion.setReduced(v),
              ),
            ),
          ),
          const _SectionLabel('AI and privacy'),
          const _AiConsentTile(),
          const SizedBox(height: 8),
          _NavTile(
            icon: Symbols.privacy_tip_rounded,
            title: 'Privacy summary',
            onTap: () => _privacy(context),
          ),
          const _SectionLabel('Notifications'),
          const ReminderSettingsTile(),
          const _SectionLabel('Security'),
          const AppLockSettingsTile(),
          const _SectionLabel('Help and about'),
          _NavTile(
            icon: Symbols.help_rounded,
            title: 'Help & support',
            onTap: () => _help(context),
          ),
          const SizedBox(height: 8),
          _NavTile(
            icon: Symbols.info_rounded,
            title: 'About MindPal',
            onTap: () => _about(context),
          ),
          const _SectionLabel('Account'),
          _NavTile(
            icon: Symbols.password_rounded,
            title: 'Change password',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
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
              leading: Icon(Symbols.delete_forever_rounded, color: scheme.error),
              title: Text('Delete account', style: TextStyle(color: scheme.error)),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Symbols.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

/// Avatar, name and email at the top of Settings; opens the profile.
class _ProfileHeader extends StatefulWidget {
  const _ProfileHeader();

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  @override
  void initState() {
    super.initState();
    ProfileStore.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ValueListenableBuilder<UserProfile?>(
      valueListenable: ProfileStore.instance.profile,
      builder: (context, p, _) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            ProfileStore.instance.refresh();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (p == null)
                  Container(
                    width: 60,
                    height: 60,
                    decoration:
                        BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                    child: Icon(Symbols.account_circle_rounded, color: scheme.primary),
                  )
                else
                  AvatarImage(avatarId: p.avatarId, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p?.displayName.isNotEmpty == true ? p!.displayName : 'Your profile',
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p != null)
                        Text(
                          p.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                      const SizedBox(height: 2),
                      Text('View profile',
                          style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary)),
                    ],
                  ),
                ),
                Icon(Symbols.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
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
              secondary: const Icon(Symbols.shield_lock_rounded),
              title: const Text('AI processing consent'),
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
  const _ThemeOption({required this.choice, required this.label, required this.palettes});

  final ThemeChoice choice;
  final String label;

  /// One palette for a theme, two (light and dark) for System.
  final List<AppPalette> palettes;
}

/// A tiny preview of a palette: its background, a pill in the main color, two dots.
class _MiniPreview extends StatelessWidget {
  const _MiniPreview(this.p);

  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: p.background,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 9,
            decoration:
                BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(999)),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(color: p.secondary, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.option, required this.selected, required this.onTap});

  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: '${option.label} theme',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outline.withValues(alpha: 0.4),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 54,
                    child: Row(
                      children: [
                        for (final p in option.palettes) Expanded(child: _MiniPreview(p)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          option.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (selected)
                        Icon(Symbols.check_circle_rounded,
                            size: 16, color: scheme.primary, fill: 1),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
