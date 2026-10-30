import 'package:flutter/material.dart';

import '../../../app/app_shell.dart';
import '../../../core/widgets/logo_mark.dart';
import '../../account/services/profile_store.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

/// Decides what to show: onboarding (first launch), sign in, or the app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _signedIn;
  bool? _seenOnboarding;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final signedIn = await AuthService.instance.isSignedIn();
    final seen = await onboardingSeen();
    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _seenOnboarding = seen;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_signedIn == null || _seenOnboarding == null) {
      return const Scaffold(body: Center(child: LogoMark(size: 88)));
    }
    if (_signedIn!) {
      return AppShell(onSignedOut: () {
        ProfileStore.instance.clear();
        setState(() => _signedIn = false);
      });
    }
    if (!_seenOnboarding!) {
      return OnboardingScreen(onDone: () => setState(() => _seenOnboarding = true));
    }
    return LoginScreen(onSignedIn: () => setState(() => _signedIn = true));
  }
}
