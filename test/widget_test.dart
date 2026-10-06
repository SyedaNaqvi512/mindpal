import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindpal/main.dart';

void main() {
  testWidgets('MindPal home screen shows the journal UI',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MindPalApp());

    expect(find.text('MindPal'), findsWidgets);
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Reflect'), findsOneWidget);
    expect(find.textContaining('not a therapist'), findsOneWidget);
  });
}