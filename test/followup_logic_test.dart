import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/journal/models/followup_logic.dart';

ChatMessage m(String role, String text, {List<String> s = const []}) =>
    ChatMessage(role: role, content: text, createdAt: DateTime(2026), suggestions: s);

List<ChatMessage> pairs(int n) => [
      for (var i = 1; i <= n; i++) ...[m('user', 'q$i'), m('assistant', 'a$i')],
    ];

void main() {
  group('counting questions', () {
    test('starts with 10 left', () {
      expect(questionsUsed(const []), 0);
      expect(questionsLeft(const []), 10);
      expect(limitReached(const []), isFalse);
    });

    test('each question uses one', () {
      expect(questionsLeft(pairs(3)), 7);
      expect(questionsLeft(pairs(9)), 1);
      expect(limitReached(pairs(9)), isFalse);
    });

    test('the tenth question closes the conversation', () {
      expect(questionsLeft(pairs(10)), 0);
      expect(limitReached(pairs(10)), isTrue);
    });

    test('never goes below zero', () {
      expect(questionsLeft(pairs(12)), 0);
    });
  });

  group('validateQuestion', () {
    test('empty and blank are refused', () {
      expect(validateQuestion(''), 'Type your question first.');
      expect(validateQuestion('   '), 'Type your question first.');
    });
    test('too long is refused, the limit itself is fine', () {
      expect(validateQuestion('a' * 501), isNotNull);
      expect(validateQuestion('a' * 500), isNull);
      expect(validateQuestion(' hello '), isNull);
    });
  });

  group('historyPayload (the AI remembers everything)', () {
    test('sends every earlier message in order', () {
      final h = historyPayload(pairs(4));
      expect(h.length, 8);
      expect(h.first, {'role': 'user', 'text': 'q1'});
      expect(h[1], {'role': 'assistant', 'text': 'a1'});
      expect(h.last, {'role': 'assistant', 'text': 'a4'});
    });

    test('a question without an answer is not sent', () {
      final h = historyPayload([...pairs(2), m('user', 'dangling')]);
      expect(h.length, 4);
    });

    test('empty conversation sends nothing', () {
      expect(historyPayload(const []), isEmpty);
    });
  });

  group('suggestions', () {
    test('defaults at the start', () {
      expect(suggestionsFor(const []), defaultSuggestions);
    });
    test("uses the AI's own suggestions after an answer", () {
      final list = [m('user', 'q'), m('assistant', 'a', s: ['One', 'Two'])];
      expect(suggestionsFor(list), ['One', 'Two']);
    });
    test('falls back to defaults when the answer had none', () {
      expect(suggestionsFor(pairs(1)), defaultSuggestions);
    });
  });

  group('waiting message changes over time', () {
    test('five different messages', () {
      final seen = {for (final t in [0, 5, 12, 25, 45]) followUpWaitMessage(t)};
      expect(seen.length, 5);
    });
  });

  group('formatting', () {
    test('paragraphs and bullets', () {
      final b = parseChatBlocks(
        'First part.\n\nTry this:\n- One\n- **Two** things\n* Three\n• Four\n\nLast line.',
      );
      expect(b.map((x) => x.bullet).toList(),
          [false, false, true, true, true, true, false]);
      expect(b[0].text, 'First part.');
      expect(b[1].text, 'Try this:');
      expect(b[3].text, '**Two** things');
      expect(b.last.text, 'Last line.');
    });

    test('bold at the start of a line is not a bullet', () {
      final b = parseChatBlocks('**Important** note');
      expect(b.single.bullet, isFalse);
    });

    test('lines of one paragraph stay together', () {
      final b = parseChatBlocks('line one\nline two');
      expect(b.single.text, 'line one\nline two');
    });

    test('bold spans', () {
      final s = parseSpans('a **b** c');
      expect(s.map((x) => x.text).toList(), ['a ', 'b', ' c']);
      expect(s.map((x) => x.bold).toList(), [false, true, false]);
    });

    test('an unclosed ** is ignored', () {
      final s = parseSpans('a **b');
      expect(s.map((x) => x.text).join(), 'a b');
      expect(s.any((x) => x.bold), isFalse);
    });

    test('plain text for copying has no markers', () {
      expect(plainChatText('a **b**'), 'a b');
    });
  });

  test('ChatMessage reads a database row', () {
    final c = ChatMessage.fromRow({
      'id': 3,
      'role': 'assistant',
      'content': 'hi',
      'created_at': '2026-11-24T10:00:00.000',
      'suggestions_json': '["x","y"]',
    });
    expect(c.id, 3);
    expect(c.isUser, isFalse);
    expect(c.suggestions, ['x', 'y']);

    final bad = ChatMessage.fromRow({
      'role': 'user',
      'content': 'q',
      'created_at': 'not a date',
      'suggestions_json': 'not json',
    });
    expect(bad.suggestions, isEmpty);
  });
}
