import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindpal/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('MindPal sign-in screen shows the title and sign-in form',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(onSignedIn: () {})),
    );

    expect(find.text('MindPal'), findsWidgets);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Create a new account'), findsOneWidget);
  });

  testWidgets('Create a new account shows the display name field',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(onSignedIn: () {})),
    );

    await tester.tap(find.text('Create a new account'));
    await tester.pump();

    expect(find.text('Display name'), findsWidgets);
  });
}