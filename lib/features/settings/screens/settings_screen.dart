import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/theme_controller.dart';
import '../../auth/services/auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  Future<void> _signOut() async {
    await AuthService.instance.logout();
    onSignedOut();
  }

  List<Color> _swatches(AppPalette p) =>
      [p.background, p.primary, p.secondary, p.accent];

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
          Text('Account', style: text.titleMedium),
          const SizedBox(height: 8),
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