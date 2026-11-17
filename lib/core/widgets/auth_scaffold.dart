import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logo_mark.dart';

/// The two colors of the brand header: the main color and a deeper (light
/// themes) or softer (dark theme) shade of it. Text on it uses onPrimary.
List<Color> brandGradient(ColorScheme scheme) {
  final dark = scheme.brightness == Brightness.dark;
  final other = dark
      ? Color.lerp(scheme.primary, scheme.secondary, 0.35)!
      : Color.lerp(scheme.primary, const Color(0xFF1B1530), 0.30)!;
  return [scheme.primary, other];
}

/// A header panel with the brand gradient, rounded bottom corners and a few
/// soft circles. Used on the sign-in screens and on Home. Static, no animation.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 56),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final circle = scheme.onPrimary.withValues(alpha: 0.10);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: scheme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: brandGradient(scheme),
          ),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.30),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
          child: Stack(
            children: [
              Positioned(
                top: -50,
                right: -40,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -50,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
                ),
              ),
              Positioned(
                top: 70,
                left: 30,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shared frame of the sign-in screens: a brand header with the logo and
/// title, and the form in a raised card that overlaps the header. No endless
/// animations, so widget tests settle.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.showLogo = true,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showLogo;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final canPop = Navigator.of(context).canPop();
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: canPop
          ? AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: scheme.onPrimary,
              elevation: 0,
            )
          : null,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrandHeader(
              padding: EdgeInsets.fromLTRB(24, top + (canPop ? 56 : 28), 24, 64),
              child: Column(
                children: [
                  if (showLogo) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const LogoMark(size: 64),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: text.headlineMedium?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.92),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // The card is moved up so it overlaps the header.
            Transform.translate(
              offset: const Offset(0, -34),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          elevation: 8,
                          shadowColor: scheme.primary.withValues(alpha: 0.30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                            side: BorderSide(
                              color: scheme.primary.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: child,
                          ),
                        ),
                        if (footer != null) ...[
                          const SizedBox(height: 14),
                          footer!,
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
