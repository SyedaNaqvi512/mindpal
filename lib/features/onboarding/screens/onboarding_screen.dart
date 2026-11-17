import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/logo_mark.dart';
import '../../journal/models/mood.dart';

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
  const _Slide(this.title, this.body);
  final String title;
  final String body;
}

const _slides = [
  _Slide('Welcome to MindPal',
      'A calm place to write down how your day felt and understand your thoughts a little better.'),
  _Slide('Write it down',
      'Add a short journal entry and pick a mood. Your entries stay on your phone, encrypted.'),
  _Slide('Reflect gently',
      'Get a thoughtful CBT-style reflection that helps you notice patterns and try a kinder view.'),
  _Slide('You stay in control',
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    const LogoMark(size: 30, shadow: false),
                    const SizedBox(width: 10),
                    Text('MindPal',
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (_last)
                      const SizedBox(height: 48)
                    else
                      TextButton(onPressed: _finish, child: const Text('Skip')),
                  ],
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
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: 300,
                                height: 300,
                                child: ExcludeSemantics(child: _illustration(i)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Semantics(
                            header: true,
                            child: Text(
                              s.title,
                              textAlign: TextAlign.center,
                              style: text.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.body,
                            textAlign: TextAlign.center,
                            style: text.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
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
                      width: i == _page ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? scheme.primary
                            : scheme.outline.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _last
                        ? _finish
                        : () => _controller.nextPage(
                              duration:
                                  Motion.of(context, const Duration(milliseconds: 250)),
                              curve: Curves.easeOut,
                            ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_last ? 'Get started' : 'Next',
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        const Icon(Symbols.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _illustration(int i) {
    switch (i) {
      case 0:
        return const _WelcomeArt();
      case 1:
        return const _WriteArt();
      case 2:
        return const _ReflectArt();
      default:
        return const _ControlArt();
    }
  }
}

// ---- illustration pieces (drawn only with shapes, text and icons) ---------

BoxDecoration _raised(ColorScheme scheme, {double radius = 22}) => BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: scheme.primary.withValues(alpha: 0.10)),
      boxShadow: [
        BoxShadow(
          color: scheme.primary.withValues(alpha: 0.20),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.emoji, this.icon});

  final String label;
  final String? emoji;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 16)),
          if (icon != null) Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              )),
        ],
      ),
    );
  }
}

Widget _bar(ColorScheme scheme, double widthFactor, {double height = 10}) =>
    FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );

class _WelcomeArt extends StatelessWidget {
  const _WelcomeArt();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 270,
          height: 270,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary.withValues(alpha: 0.07),
          ),
        ),
        Container(
          width: 214,
          height: 214,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: brandGradient(scheme),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
        ),
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const LogoMark(size: 84),
        ),
        const Positioned(top: 22, right: 0, child: _Chip(emoji: '😊', label: 'Calm')),
        const Positioned(
            bottom: 34, left: 0, child: _Chip(icon: Symbols.edit_note_rounded, label: 'Write')),
        const Positioned(
            bottom: 6, right: 16, child: _Chip(icon: Symbols.spa_rounded, label: 'Reflect')),
      ],
    );
  }
}

class _WriteArt extends StatelessWidget {
  const _WriteArt();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 270,
          padding: const EdgeInsets.all(18),
          decoration: _raised(scheme, radius: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How are you feeling?',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 5; i++)
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: MoodColors.byLevel[i].withValues(alpha: i == 3 ? 1 : 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i == 3 ? scheme.primary : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(Mood.all[i].emoji, style: const TextStyle(fontSize: 19)),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _bar(scheme, 1),
              const SizedBox(height: 8),
              _bar(scheme, 0.85),
              const SizedBox(height: 8),
              _bar(scheme, 0.55),
              const SizedBox(height: 18),
              Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: brandGradient(scheme)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Save entry',
                    style: TextStyle(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ],
          ),
        ),
        const Positioned(
            top: 10, right: 0, child: _Chip(icon: Symbols.mic_rounded, label: 'Voice')),
        const Positioned(
            bottom: 8,
            left: 0,
            child: _Chip(icon: Symbols.lock_rounded, label: 'Encrypted')),
      ],
    );
  }
}

class _ReflectArt extends StatelessWidget {
  const _ReflectArt();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 270,
          padding: const EdgeInsets.all(18),
          decoration: _raised(scheme, radius: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Symbols.psychology_alt_rounded, color: scheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text('Reflection',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Pattern: all-or-nothing',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onTertiaryContainer)),
              ),
              const SizedBox(height: 14),
              _bar(scheme, 1),
              const SizedBox(height: 8),
              _bar(scheme, 0.9),
              const SizedBox(height: 8),
              _bar(scheme, 0.6),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Symbols.lightbulb_rounded, color: scheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('A kinder view',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Positioned(
            top: 6, right: 0, child: _Chip(emoji: '🌱', label: 'Gentle')),
        const Positioned(
            bottom: 6,
            right: 8,
            child: _Chip(icon: Symbols.self_improvement_rounded, label: 'Exercises')),
      ],
    );
  }
}

class _ControlArt extends StatelessWidget {
  const _ControlArt();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget row(IconData icon, String label) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: _raised(scheme, radius: 18),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface)),
              ),
              Icon(Symbols.check_circle_rounded,
                  size: 20, color: MoodColors.sage),
            ],
          ),
        );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: brandGradient(scheme),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.35),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(Symbols.shield_lock_rounded, size: 60, color: scheme.onPrimary),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: 270,
          child: Column(
            children: [
              row(Symbols.lock_rounded, 'Encrypted on your phone'),
              const SizedBox(height: 10),
              row(Symbols.tune_rounded, 'You choose what is shared'),
              const SizedBox(height: 10),
              row(Symbols.delete_rounded, 'Delete your data any time'),
            ],
          ),
        ),
      ],
    );
  }
}