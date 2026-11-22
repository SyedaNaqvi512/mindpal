import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/core/widgets/responsive_frame.dart';
import 'package:mindpal/core/widgets/toast.dart';
import 'package:mindpal/features/exercises/models/exercise_catalog.dart';
import 'package:mindpal/features/exercises/models/exercise_logic.dart';
import 'package:mindpal/features/learn/learn_content.dart';
import 'package:mindpal/features/learn/learn_screen.dart';
import 'package:mindpal/features/safety/support_info.dart';

String _all(Article a) =>
    [a.title, a.summary, for (final b in a.blocks) ...[b.text, ...b.items]]
        .join(' ')
        .toLowerCase();

void main() {
  group('Learn content (FR-64 to FR-69)', () {
    test('has four to six articles with unique ids', () {
      expect(kArticles.length, inInclusiveRange(4, 6));
      expect(kArticles.map((a) => a.id).toSet().length, kArticles.length);
    });

    test('every article has a title, summary and body', () {
      for (final a in kArticles) {
        expect(a.title, isNotEmpty);
        expect(a.summary, isNotEmpty);
        expect(a.blocks.length, greaterThan(2));
        expect(articleById(a.id), same(a));
      }
      expect(articleById('missing'), isNull);
    });

    test('covers the five required topics', () {
      final ids = kArticles.map((a) => a.id).toList();
      expect(ids, containsAll([
        'what-is-mindfulness',
        'why-it-may-help',
        'mindfulness-and-reframing',
        'simple-ways-to-practise',
        'not-therapy-and-help',
      ]));
    });

    test('uses careful wording: no cure, proof or guarantee claims', () {
      const banned = [
        'clinically proven', 'scientifically proven', 'proven to', 'guarantee',
        'studies show', 'research shows', 'will cure', 'will heal', 'cures ',
        'buy ', 'subscribe', 'discount',
      ];
      for (final a in kArticles) {
        final t = _all(a);
        for (final w in banned) {
          expect(t.contains(w), isFalse, reason: '"$w" found in ${a.id}');
        }
      }
    });

    test('the "why it may help" article says it may, and does not promise', () {
      final t = _all(articleById('why-it-may-help')!);
      expect(t.contains('may help'), isTrue);
      expect(t.contains('does not claim'), isTrue);
    });

    test('the practice article opens the breathing bubble', () {
      expect(articleById('simple-ways-to-practise')!.action, LearnAction.breathing);
    });

    test('the help article links to the support screen', () {
      expect(articleById('not-therapy-and-help')!.action, LearnAction.support);
    });

    test('the not-therapy note says what MindPal is not', () {
      expect(kNotTherapyNote, contains('not therapy'));
    });

    test('the breathing session is five minutes', () {
      expect(kLearnBreathCycles * kBreathCycleSeconds, kLearnBreathSeconds);
      expect(kLearnBreathSeconds, 300);
    });
  });

  group('Learn screens', () {
    testWidgets('the list shows every article', (tester) async {
      // A tall screen, so the lazy list builds every card.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: LearnScreen()));
      await tester.pumpAndSettle();

      for (final a in kArticles) {
        expect(find.text(a.title), findsOneWidget);
      }
    });

    testWidgets('every article ends with the not-therapy note', (tester) async {
      for (final a in kArticles) {
        await tester.pumpWidget(MaterialApp(home: ArticleScreen(article: a)));
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(find.text(kNotTherapyNote), findsOneWidget, reason: a.id);
      }
    });

    testWidgets('the practice article opens the 5-minute breathing screen',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: ArticleScreen(article: articleById('simple-ways-to-practise')!)));
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Try the 5-minute Breathing Bubble'));
      await tester.pumpAndSettle();

      expect(find.text('Start breathing'), findsOneWidget);
      expect(find.textContaining('25 slow breaths'), findsOneWidget);
    });

    testWidgets('the help article opens the support screen', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: ArticleScreen(article: articleById('not-therapy-and-help')!)));
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('See support contacts'));
      await tester.pumpAndSettle();

      for (final h in kHelplines) {
        expect(find.textContaining(h.number), findsOneWidget);
      }
    });
  });

  group('Toast and responsive layout', () {
    testWidgets('a toast shows its message', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Toast.of(context, 'Profile saved.', kind: ToastKind.success),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(find.text('Profile saved.'), findsOneWidget);
    });

    testWidgets('a wide screen is limited to the maximum width', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: ResponsiveFrame(child: Scaffold(body: SizedBox.expand(key: Key('c')))),
      ));
      expect(tester.getSize(find.byKey(const Key('c'))).width, 720);
    });

    testWidgets('a phone-sized screen is left unchanged', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: ResponsiveFrame(child: Scaffold(body: SizedBox.expand(key: Key('c')))),
      ));
      expect(tester.getSize(find.byKey(const Key('c'))).width, 400);
    });
  });

  test('every exercise id is one the server accepts (FR-61)', () {
    const server = [
      'sort', 'scale', 'belief', 'breathing', 'grounding', 'thought_record',
      'gratitude', 'self_compassion', 'problem_solving', 'check_in', 'stop',
      'anchor', 'body_scan',
    ];
    final ids = kExercises.map((e) => e.id).toList();
    expect(ids.length, server.length);
    expect(ids.toSet(), server.toSet());
  });
}