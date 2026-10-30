import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_tokens.dart';
import '../features/home/screens/home_screen.dart';
import '../features/insights/screens/insights_screen.dart';
import '../features/journal/screens/history_screen.dart';
import '../features/journal/screens/new_entry_screen.dart';
import '../features/settings/screens/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _openNewEntry({int? mood, String? text}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => NewEntryScreen(
          onSignedOut: widget.onSignedOut,
          initialMood: mood,
          initialText: text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        onNewEntry: _openNewEntry,
        onSeeAll: () => setState(() => _index = 1),
        onSignedOut: widget.onSignedOut,
      ),
      HistoryScreen(onSignedOut: widget.onSignedOut),
      InsightsScreen(onSignedOut: widget.onSignedOut),
      SettingsScreen(onSignedOut: widget.onSignedOut),
    ];

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Material(
        color: scheme.surface,
        elevation: 10,
        shadowColor: scheme.primary.withValues(alpha: 0.35),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                _NavItem(
                  label: 'Home',
                  icon: Symbols.home_rounded,
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _NavItem(
                  label: 'History',
                  icon: Symbols.history_rounded,
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                Expanded(child: _NewEntryButton(onTap: () => _openNewEntry())),
                _NavItem(
                  label: 'Insights',
                  icon: Symbols.insights_rounded,
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2),
                ),
                _NavItem(
                  label: 'Settings',
                  icon: Symbols.settings_rounded,
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewEntryButton extends StatelessWidget {
  const _NewEntryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'New entry',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, Color.lerp(scheme.primary, scheme.secondary, 0.55)!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Symbols.add_rounded, color: scheme.onPrimary, size: 28),
            ),
            const SizedBox(height: 2),
            Text(
              'New entry',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: Motion.of(context, AppTokens.motionNormal),
                curve: Curves.easeOut,
                width: 56,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? scheme.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon, color: color, size: 24, fill: selected ? 1 : 0),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
