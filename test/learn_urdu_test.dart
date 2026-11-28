import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/learn/learn_content.dart';
import 'package:mindpal/features/learn/learn_content_ur.dart';
import 'package:mindpal/features/learn/learn_language.dart';
import 'package:mindpal/features/learn/learn_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool hasUrdu(String s) => RegExp(r'[؀-ۿ]').hasMatch(s);

String _all(ArticleText t) =>
    [t.title, t.summary, for (final b in t.blocks) ...[b.text, ...b.items]].join(' ');

void main() {
  tearDown(() => learnLanguage.value = 'en');

  group('Urdu content', () {
    test('every English article has an Urdu version with the same shape', () {
      for (final a in kArticles) {
        final ur = kArticlesUr[a.id];
        expect(ur, isNotNull, reason: a.id);
        expect(ur!.blocks.length, a.blocks.length, reason: a.id);
        for (var i = 0; i < a.blocks.length; i++) {
          expect(ur.blocks[i].kind, a.blocks[i].kind, reason: '${a.id} block $i');
          expect(ur.blocks[i].items.length, a.blocks[i].items.length,
              reason: '${a.id} block $i');
        }
        expect(hasUrdu(ur.title), isTrue);
        expect(hasUrdu(ur.summary), isTrue);
      }
      expect(kArticlesUr.length, kArticles.length);
    });

    test('no empty text anywhere', () {
      for (final ur in kArticlesUr.values) {
        for (final b in ur.blocks) {
          if (b.kind == BlockKind.bullets) {
            expect(b.items.every((i) => i.trim().isNotEmpty), isTrue);
          } else {
            expect(b.text.trim(), isNotEmpty);
          }
        }
      }
    });

    test('careful wording is kept: no cure, proof or guarantee claims', () {
      // Urdu words for cure/guarantee/proven used as a claim.
      const banned = ['یقینی علاج', 'ثابت شدہ', 'گارنٹی', 'ضمانت', 'شفا یاب ہو جائیں گے'];
      for (final ur in kArticlesUr.values) {
        final t = _all(ur);
        for (final w in banned) {
          expect(t.contains(w), isFalse, reason: w);
        }
      }
    });

    test('the not-therapy note and the labels are in Urdu', () {
      expect(hasUrdu(kNotTherapyNoteUr), isTrue);
      expect(hasUrdu(kLearnTitleUr), isTrue);
      expect(hasUrdu(kLearnIntroUr), isTrue);
      expect(minutesReadUr(3), contains('3'));
      expect(hasUrdu(minutesReadUr(3)), isTrue);
      expect(hasUrdu(kBreathingButtonUr), isTrue);
      expect(hasUrdu(kSupportButtonUr), isTrue);
    });

    test('articleText falls back to English for another language or id', () {
      final a = kArticles.first;
      expect(articleText(a, 'en').title, a.title);
      expect(articleText(a, 'fr').title, a.title);
      expect(articleText(a, 'ur').title, kArticlesUr[a.id]!.title);
      const other = Article(
        id: 'nope',
        title: 'T',
        summary: 'S',
        minutes: 1,
        icon: Icons.abc,
        blocks: [Block.paragraph('x')],
      );
      expect(articleText(other, 'ur').title, 'T');
    });
  });

  group('language choice', () {
    test('is remembered and unknown values mean English', () async {
      SharedPreferences.setMockInitialValues({});
      await setLearnLanguage('ur');
      expect(learnLanguage.value, 'ur');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kLearnLanguageKey), 'ur');
      learnLanguage.value = 'en';
      loadLearnLanguage(prefs);
      expect(learnLanguage.value, 'ur');
      await setLearnLanguage('xx');
      expect(learnLanguage.value, 'en');
      SharedPreferences.setMockInitialValues({kLearnLanguageKey: 'junk'});
      loadLearnLanguage(await SharedPreferences.getInstance());
      expect(learnLanguage.value, 'en');
    });
  });

  group('screens', () {
    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('the list switches to Urdu and back', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tall(tester);
      await tester.pumpWidget(const MaterialApp(home: LearnScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Learn'), findsOneWidget);
      expect(find.text(kArticles.first.title), findsOneWidget);

      await tester.tap(find.text('اردو'));
      await tester.pumpAndSettle();
      expect(find.text(kLearnTitleUr), findsOneWidget);
      for (final a in kArticles) {
        expect(find.text(kArticlesUr[a.id]!.title), findsOneWidget, reason: a.id);
        expect(find.text(a.title), findsNothing, reason: a.id);
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Learn'), findsOneWidget);
      expect(find.text(kArticles.first.title), findsOneWidget);
    });

    testWidgets('an article reads right to left in Urdu and ends with the Urdu note',
        (tester) async {
      learnLanguage.value = 'ur';
      for (final a in kArticles) {
        // A new key each time: MaterialApp keeps its first home route otherwise.
        await tester.pumpWidget(MaterialApp(
          key: ValueKey(a.id),
          home: ArticleScreen(article: a),
        ));
        await tester.pumpAndSettle();
        expect(find.text(kArticlesUr[a.id]!.title), findsOneWidget, reason: a.id);
        final dir = Directionality.of(tester.element(find.text(kArticlesUr[a.id]!.title)));
        expect(dir, TextDirection.rtl);
        await tester.drag(find.byType(ListView), const Offset(0, -4000));
        await tester.pumpAndSettle();
        expect(find.text(kNotTherapyNoteUr), findsOneWidget, reason: a.id);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('the translate button changes the language inside an article',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final a = kArticles.first;
      await tester.pumpWidget(MaterialApp(home: ArticleScreen(article: a)));
      await tester.pumpAndSettle();
      expect(find.text(a.title), findsOneWidget);
      await tester.tap(find.byTooltip('اردو میں پڑھیں'));
      await tester.pumpAndSettle();
      expect(find.text(kArticlesUr[a.id]!.title), findsOneWidget);
      expect(find.byTooltip('Read in English'), findsOneWidget);
      await tester.tap(find.byTooltip('Read in English'));
      await tester.pumpAndSettle();
      expect(find.text(a.title), findsOneWidget);
    });

    testWidgets('the action buttons are in Urdu too', (tester) async {
      learnLanguage.value = 'ur';
      await tester.pumpWidget(MaterialApp(
          home: ArticleScreen(article: articleById('simple-ways-to-practise')!)));
      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(find.text(kBreathingButtonUr), findsOneWidget);
    });
  });
}
