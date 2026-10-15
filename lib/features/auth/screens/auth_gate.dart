import 'package:flutter/material.dart';

import '../../../app/app_shell.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

/// Shows the app when signed in, and the login screen otherwise.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _signedIn;

  @override
  void initState() {
    super.initState();
    AuthService.instance.isSignedIn().then((value) {
      if (mounted) setState(() => _signedIn = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _signedIn;
    if (signedIn == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return signedIn
        ? AppShell(onSignedOut: () => setState(() => _signedIn = false))
        : LoginScreen(onSignedIn: () => setState(() => _signedIn = true));
  }
}