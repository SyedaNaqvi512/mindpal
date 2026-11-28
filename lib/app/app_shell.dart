import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/motion/motion.dart';
import '../core/theme/app_look.dart';
import '../core/theme/app_tokens.dart';
import '../features/home/screens/home_screen.dart';
import '../features/insights/screens/insights_screen.dart';
import '../features/journal/screens/history_screen.dart';
import '../features/journal/screens/new_entry_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/widget/widget_bridge.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  VoidCallback? _stopListening;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A tap on the home-screen widget: while the app is open, and when it was
    // opened by the tap.
    _stopListening = WidgetBridge.instance.listen(_openFromWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromWidget());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopListening?.call();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _openFromWidget();
  }

  /// Opens a new entry if the widget asked for one: with the tapped mood
  /// chosen (1 to 5), or blank (0).
  Future<void> _openFromWidget() async {
    final mood = await WidgetBridge.instance.takePending();
    if (mood == null || !mounted) return;
    _openNewEntry(mood: mood == 0 ? null : mood);
  }

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

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: AppBottomBar(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
        onNewEntry: () => _openNewEntry(),
      ),
    );
  }
}

/// The bottom bar. Its shape follows the look (see [NavStyle]): a floating
/// rounded bar, notebook tabs, a flat bar with a line, or a glowing dark bar.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.index, required this.onSelect, required this.onNewEntry});

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onNewEntry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final look = AppLook.of(context);

    final row = SizedBox(
      height: 68,
      child: Row(
        children: [
          _NavItem(
            label: 'Home',
            icon: Symbols.home_rounded,
            selected: index == 0,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            label: 'History',
            icon: Symbols.history_rounded,
            selected: index == 1,
            onTap: () => onSelect(1),
          ),
          Expanded(child: _NewEntryButton(onTap: onNewEntry)),
          _NavItem(
            label: 'Insights',
            icon: Symbols.insights_rounded,
            selected: index == 2,
            onTap: () => onSelect(2),
          ),
          _NavItem(
            label: 'Settings',
            icon: Symbols.settings_rounded,
            selected: index == 3,
            onTap: () => onSelect(3),
          ),
        ],
      ),
    );

    switch (look.nav) {
      case NavStyle.floating:
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Material(
              color: scheme.surface,
              elevation: 10,
              shadowColor: scheme.primary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(30),
              clipBehavior: Clip.antiAlias,
              child: row,
            ),
          ),
        );
      case NavStyle.tabs:
        return Material(
          color: scheme.surface,
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: scheme.onSurface, width: 1.2)),
            ),
            child: SafeArea(top: false, child: row),
          ),
        );
      case NavStyle.line:
        return Material(
          color: scheme.surface,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: scheme.onSurface.withValues(alpha: 0.12)),
              ),
            ),
            child: SafeArea(top: false, child: row),
          ),
        );
      case NavStyle.glow:
        return Material(
          color: scheme.surface,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(top: false, child: row),
          ),
        );
    }
  }
}

class _NewEntryButton extends StatelessWidget {
  const _NewEntryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final look = AppLook.of(context);

    final BoxDecoration decoration = switch (look.nav) {
      NavStyle.floating || NavStyle.glow => BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, Color.lerp(scheme.primary, scheme.secondary, 0.55)!],
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: look.nav == NavStyle.glow ? 0.55 : 0.4),
              blurRadius: look.nav == NavStyle.glow ? 18 : 12,
              offset: look.nav == NavStyle.glow ? Offset.zero : const Offset(0, 4),
            ),
          ],
        ),
      // Paper: a square stamp with an ink outline.
      NavStyle.tabs => BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.onSurface, width: 1.2),
        ),
      // Minimal: a plain rounded square, no shadow.
      NavStyle.line => BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
    };

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
              decoration: decoration,
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
    final look = AppLook.of(context);
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    final dur = look.scaled(Motion.of(context, AppTokens.motionNormal));

    // The chosen item is marked in the way of the look.
    final Widget marker = switch (look.nav) {
      // A pill behind the icon.
      NavStyle.floating => AnimatedContainer(
          duration: dur,
          curve: look.enterCurve,
          width: 56,
          height: 30,
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(icon, color: color, size: 24, fill: selected ? 1 : 0),
        ),
      // A notebook tab: filled square-ish block with an ink line on top.
      NavStyle.tabs => AnimatedContainer(
          duration: dur,
          curve: look.enterCurve,
          width: 52,
          height: 30,
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Icon(icon, color: color, size: 23, fill: selected ? 1 : 0),
        ),
      // Just the icon; the line is drawn above (see below).
      NavStyle.line => SizedBox(
          width: 56,
          height: 30,
          child: Icon(icon, color: color, size: 24, fill: selected ? 1 : 0),
        ),
      // A soft glow under the icon.
      NavStyle.glow => AnimatedContainer(
          duration: dur,
          curve: look.enterCurve,
          width: 56,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? scheme.primary.withValues(alpha: 0.18) : Colors.transparent,
            boxShadow: selected
                ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.45), blurRadius: 14)]
                : const [],
          ),
          child: Icon(icon, color: color, size: 24, fill: selected ? 1 : 0),
        ),
    };

    Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        marker,
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
    );

    if (look.nav == NavStyle.line) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          content,
          Align(
            alignment: Alignment.topCenter,
            child: AnimatedContainer(
              duration: dur,
              curve: look.enterCurve,
              width: selected ? 36 : 0,
              height: 2.5,
              color: scheme.primary,
            ),
          ),
        ],
      );
    }

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
          child: content,
        ),
      ),
    );
  }
}
