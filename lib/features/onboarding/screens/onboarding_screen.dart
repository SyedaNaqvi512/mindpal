import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSeen = 'mindpal_onboarding_seen';

Future<bool> onboardingSeen() async {
  try {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kSeen) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> markOnboardingSeen() async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSeen, true);
  } catch (_) {}
}

class _Slide {
  const _Slide(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

const _slides = [
  _Slide(Symbols.waving_hand_rounded, 'Welcome to MindPal',
      'A calm place to write down how your day felt and understand your thoughts a little better.'),
  _Slide(Symbols.edit_note_rounded, 'Write it down',
      'Add a short journal entry and pick a mood. Your entries stay on your phone, encrypted.'),
  _Slide(Symbols.psychology_alt_rounded, 'Reflect gently',
      'Get a thoughtful CBT-style reflection that helps you notice patterns and try a kinder view.'),
  _Slide(Symbols.shield_lock_rounded, 'You stay in control',
      'MindPal is a self-help tool, not therapy or an emergency service. You choose what is shared, and you can withdraw at any time.'),
];

/// FR-01: welcome + onboarding slides. [onDone] runs after the last slide or Skip.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _last => _page == _slides.length - 1;

  Future<void> _finish() async {
    await markOnboardingSeen();
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _last ? null : _finish,
                child: Text(_last ? '' : 'Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s.icon,
                              size: 68, color: scheme.onPrimaryContainer),
                        ),
                        const SizedBox(height: 32),
                        Text(s.title,
                            textAlign: TextAlign.center,
                            style: text.headlineSmall),
                        const SizedBox(height: 12),
                        Text(s.body,
                            textAlign: TextAlign.center,
                            style: text.bodyLarge
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? scheme.primary : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _last
                      ? _finish
                      : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                  child: Text(_last ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
