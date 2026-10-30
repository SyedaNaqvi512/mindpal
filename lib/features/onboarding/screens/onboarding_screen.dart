import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/motion/motion.dart';
import '../../../core/widgets/logo_mark.dart';

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
  const _Slide(this.icon, this.title, this.body, this.useLogo);
  final IconData icon;
  final String title;
  final String body;

  /// The first slide shows the MindPal logo instead of an icon.
  final bool useLogo;
}

const _slides = [
  _Slide(Symbols.waving_hand_rounded, 'Welcome to MindPal',
      'A calm place to write down how your day felt and understand your thoughts a little better.', true),
  _Slide(Symbols.edit_note_rounded, 'Write it down',
      'Add a short journal entry and pick a mood. Your entries stay on your phone, encrypted.', false),
  _Slide(Symbols.psychology_alt_rounded, 'Reflect gently',
      'Get a thoughtful CBT-style reflection that helps you notice patterns and try a kinder view.', false),
  _Slide(Symbols.shield_lock_rounded, 'You stay in control',
      'MindPal is a self-help tool, not therapy or an emergency service. You choose what is shared, and you can withdraw at any time.', false),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.surfaceContainer, scheme.surfaceContainerLowest],
          ),
        ),
        child: SafeArea(
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
                          _Illustration(slide: s, index: i),
                          const SizedBox(height: 32),
                          Semantics(
                            header: true,
                            child: Text(s.title,
                                textAlign: TextAlign.center, style: text.headlineSmall),
                          ),
                          const SizedBox(height: 12),
                          Text(s.body,
                              textAlign: TextAlign.center,
                              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
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
                      duration: Motion.of(context, const Duration(milliseconds: 200)),
                      margin: const EdgeInsets.all(4),
                      width: i == _page ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? scheme.primary : scheme.outline.withValues(alpha: 0.4),
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
                              duration: Motion.of(context, const Duration(milliseconds: 250)),
                              curve: Curves.easeOut,
                            ),
                    child: Text(_last ? 'Get started' : 'Next'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A picture drawn only with shapes: soft circles, small floating dots and a
/// central badge. Each slide uses a slightly different arrangement.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.slide, required this.index});

  final _Slide slide;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget dot(double size, Color color, {double? left, double? right, double? top, double? bottom}) =>
        Positioned(
          left: left,
          right: right,
          top: top,
          bottom: bottom,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        );

    // Different spots for the small dots on each slide.
    final flip = index.isOdd;

    return ExcludeSemantics(
      child: SizedBox(
        width: 240,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.secondaryContainer,
                    scheme.primaryContainer.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: slide.useLogo
                  ? const LogoMark(size: 84)
                  : Icon(slide.icon, size: 72, color: scheme.primary),
            ),
            dot(18, scheme.tertiary, top: flip ? 30 : 16, right: flip ? 22 : 36),
            dot(12, scheme.secondary, bottom: flip ? 24 : 40, left: flip ? 40 : 20),
            dot(9, scheme.primary.withValues(alpha: 0.5), top: flip ? 70 : 90, left: flip ? 6 : 12),
            dot(14, scheme.secondary.withValues(alpha: 0.7), bottom: flip ? 56 : 28, right: flip ? 10 : 14),
          ],
        ),
      ),
    );
  }
}
