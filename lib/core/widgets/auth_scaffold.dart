import 'package:flutter/material.dart';

import 'logo_mark.dart';

/// The shared frame of the sign-in screens: soft gradient, the logo, a title and
/// the form in a card. No endless animations, so widget tests settle.
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
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: canPop ? AppBar(backgroundColor: Colors.transparent, elevation: 0) : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.surfaceContainer, scheme.surfaceContainerLowest],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, canPop ? 40 : 24, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showLogo) ...[
                      const Center(child: LogoMark(size: 72)),
                      const SizedBox(height: 20),
                    ],
                    Semantics(
                      header: true,
                      child: Text(title,
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(subtitle!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 24),
                    Card(child: Padding(padding: const EdgeInsets.all(20), child: child)),
                    if (footer != null) ...[const SizedBox(height: 12), footer!],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
