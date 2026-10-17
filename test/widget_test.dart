
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindpal/features/auth/screens/login_screen.dart';
import 'package:mindpal/features/auth/screens/register_screen.dart';

void main() {
  testWidgets('Login screen shows the sign-in form',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onSignedIn: () {}),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('New here? Create an account'), findsOneWidget);
  });

  testWidgets('Create account opens the registration screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onSignedIn: () {}),
      ),
    );

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
  });
}
