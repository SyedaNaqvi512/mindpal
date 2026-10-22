import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

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

  void _openNewEntry() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewEntryScreen(
          onSignedOut: widget.onSignedOut,
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
      HistoryScreen(
        onSignedOut: widget.onSignedOut,
      ),
      const InsightsScreen(),
      SettingsScreen(
        onSignedOut: widget.onSignedOut,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New entry',
        onPressed: _openNewEntry,
        child: const Icon(Symbols.add_rounded),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        padding: EdgeInsets.zero,
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
            const SizedBox(width: 72),
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
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w600,
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