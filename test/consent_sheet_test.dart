import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/consent/widgets/consent_sheet.dart';

Future<bool?> _open(WidgetTester tester, String tapText) async {
  bool? result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async => result = await showConsentSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.text('Allow AI to write your reflection?'), findsOneWidget);
  await tester.tap(find.text(tapText));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('Allow returns true', (tester) async {
    expect(await _open(tester, 'Allow'), isTrue);
  });

  testWidgets('Not now returns false', (tester) async {
    expect(await _open(tester, 'Not now'), isFalse);
  });
}
