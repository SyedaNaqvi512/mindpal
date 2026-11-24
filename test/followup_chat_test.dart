import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/journal/models/followup_logic.dart';
import 'package:mindpal/features/journal/services/followup_service.dart';
import 'package:mindpal/features/journal/widgets/followup_chat.dart';

class FakeStore implements ChatStore {
  final List<ChatMessage> items = [];
  int cleared = 0;

  @override
  Future<List<ChatMessage>> load(int entryId) async => List.of(items);

  @override
  Future<void> addPair(int entryId,
      {required String user,
      required String assistant,
      List<String> suggestions = const []}) async {
    items.add(ChatMessage(role: 'user', content: user, createdAt: DateTime(2026)));
    items.add(ChatMessage(
        role: 'assistant',
        content: assistant,
        createdAt: DateTime(2026),
        suggestions: suggestions));
  }

  @override
  Future<void> clear(int entryId) async {
    items.clear();
    cleared++;
  }

  @override
  Future<String?> entryText(int entryId) async => 'My entry';
}

class FakeClient implements FollowUpClient {
  FakeClient(this.handler);
  final Future<FollowUpAnswer> Function(List<Map<String, String>> history, String message) handler;
  final List<List<Map<String, String>>> histories = [];

  @override
  Future<FollowUpAnswer> ask({
    required String entry,
    required String reflection,
    required List<Map<String, String>> history,
    required String message,
  }) {
    histories.add(history);
    return handler(history, message);
  }
}

Future<void> pump(WidgetTester tester, FakeStore store, FakeClient client) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FollowUpChat(
            entryId: 1,
            reflectionText: 'reflection',
            store: store,
            client: client,
            ensureConsent: (_) async => true,
            isCrisis: (t) => t.contains('hurt myself'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byTooltip('Send'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('shows the counter and suggestions at the start', (tester) async {
    await pump(tester, FakeStore(), FakeClient((_, _) async => const FollowUpAnswer(reply: 'x')));
    expect(find.text('10 of 10 left'), findsOneWidget);
    expect(find.text('Help me look at this differently'), findsOneWidget);
  });

  testWidgets('a question gets an answer, the counter drops, formatting shows',
      (tester) async {
    final store = FakeStore();
    final client = FakeClient((_, _) async => const FollowUpAnswer(
        reply: 'That makes sense.\n\n- Look at the **facts**',
        suggestions: ['What are the facts?']));
    await pump(tester, store, client);

    await send(tester, 'Why do I feel stuck?');

    expect(find.text('Why do I feel stuck?'), findsOneWidget);
    expect(find.text('That makes sense.'), findsOneWidget);
    expect(find.text('9 of 10 left'), findsOneWidget);
    expect(find.text('What are the facts?'), findsOneWidget);
    expect(store.items.length, 2);
  });

  testWidgets('the whole earlier conversation goes with the next question',
      (tester) async {
    final store = FakeStore();
    final client = FakeClient((_, m) async => FollowUpAnswer(reply: 'answer to $m'));
    await pump(tester, store, client);

    await send(tester, 'first');
    await send(tester, 'second');
    await send(tester, 'third');

    expect(client.histories[0], isEmpty);
    expect(client.histories[1].length, 2);
    expect(client.histories[2].length, 4);
    expect(client.histories[2].first['text'], 'first');
    expect(client.histories[2].last['text'], 'answer to second');
  });

  testWidgets('a failed question is not counted and the text comes back',
      (tester) async {
    final store = FakeStore();
    final client = FakeClient((_, _) async => throw FollowUpException('No internet connection.'));
    await pump(tester, store, client);

    await send(tester, 'Will this fail?');

    expect(find.text('No internet connection.'), findsOneWidget);
    expect(find.text('10 of 10 left'), findsOneWidget);
    expect(store.items, isEmpty);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Will this fail?');
  });

  testWidgets('after 10 questions the box is gone and a closing note shows',
      (tester) async {
    final store = FakeStore();
    for (var i = 0; i < 10; i++) {
      await store.addPair(1, user: 'q$i', assistant: 'a$i');
    }
    await pump(tester, store, FakeClient((_, _) async => const FollowUpAnswer(reply: 'x')));

    expect(find.text('All 10 used'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('good place to pause'), findsOneWidget);
  });

  testWidgets('a crisis message is not sent to the AI', (tester) async {
    var called = false;
    final store = FakeStore();
    final client = FakeClient((_, _) async {
      called = true;
      return const FollowUpAnswer(reply: 'x');
    });
    await pump(tester, store, client);

    await send(tester, 'I want to hurt myself');

    expect(called, isFalse);
    expect(find.text('You are not alone'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(store.items, isEmpty);
  });

  testWidgets('the server can also pause the conversation for safety',
      (tester) async {
    final store = FakeStore();
    final client = FakeClient((_, _) async =>
        const FollowUpAnswer(reply: 'support', safety: true));
    await pump(tester, store, client);

    await send(tester, 'a normal looking message');

    expect(find.text('You are not alone'), findsOneWidget);
    expect(store.items, isEmpty);
  });

  testWidgets('delete conversation removes the messages', (tester) async {
    final store = FakeStore();
    await store.addPair(1, user: 'hello', assistant: 'hi there');
    await pump(tester, store, FakeClient((_, _) async => const FollowUpAnswer(reply: 'x')));
    expect(find.text('hi there'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete conversation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(store.cleared, 1);
    expect(find.text('hi there'), findsNothing);
    expect(find.text('10 of 10 left'), findsOneWidget);
  });
}