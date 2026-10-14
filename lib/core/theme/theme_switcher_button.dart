import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_controller.dart';

/// TEMPORARY: lets us preview all themes. Replaced by the Settings screen later.
class ThemeSwitcherButton extends ConsumerWidget {
  const ThemeSwitcherButton({super.key});

  static const _labels = {
    ThemeChoice.lavenderDream: 'Lavender Dream',
    ThemeChoice.roseCream: 'Rose & Cream',
    ThemeChoice.skyMist: 'Sky Mist',
    ThemeChoice.midnightLavender: 'Midnight Lavender',
    ThemeChoice.system: 'System',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeControllerProvider);
    return PopupMenuButton<ThemeChoice>(
      tooltip: 'Change theme',
      icon: const Icon(Icons.palette_outlined),
      initialValue: current,
      onSelected: ref.read(themeControllerProvider.notifier).select,
      itemBuilder: (_) => [
        for (final c in ThemeChoice.values)
          CheckedPopupMenuItem(value: c, checked: c == current, child: Text(_labels[c]!)),
      ],
    );
  }
}