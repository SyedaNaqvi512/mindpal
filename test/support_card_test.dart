import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/safety/support_info.dart';
import 'package:mindpal/features/safety/widgets/support_card.dart';

void main() {
  testWidgets('support card shows helpline, emergency advice and limits',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SupportCard()))),
    );

    for (final h in kHelplines) {
      expect(find.textContaining(h.number), findsOneWidget);
    }
    expect(find.textContaining('immediate danger'), findsOneWidget);
    expect(find.textContaining('cannot reliably detect every crisis'), findsOneWidget);
    expect(find.textContaining('not a therapist'), findsOneWidget);
  });
}