import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/journal/models/thinking_patterns.dart';
import 'package:mindpal/features/journal/services/quick_reflection_engine.dart';
import 'package:mindpal/features/journal/services/reflection_engine.dart';

void main() {
  group('ThinkingPatterns', () {
    test('has the nine patterns of the SRS', () {
      expect(ThinkingPatterns.names.length, 9);
    });
    test('none and unknown ids give no name', () {
      expect(ThinkingPatterns.nameOf('none'), isNull);
      expect(ThinkingPatterns.nameOf(null), isNull);
      expect(ThinkingPatterns.nameOf('mind_reading'), 'Mind reading');
    });
  });

  group('ReflectionParts', () {
    test('encode and decode keep every part', () {
      const p = ReflectionParts(
        acknowledgement: 'ack',
        pattern: 'catastrophizing',
        patternNote: 'note',
        questions: ['q1', 'q2'],
        balanced: 'bal',
        nextStep: 'next',
      );
      final back = ReflectionParts.decode(p.encode())!;
      expect(back.acknowledgement, 'ack');
      expect(back.pattern, 'catastrophizing');
      expect(back.questions, ['q1', 'q2']);
      expect(back.balanced, 'bal');
      expect(back.nextStep, 'next');
    });
    test('bad data gives null, not a crash', () {
      expect(ReflectionParts.decode(null), isNull);
      expect(ReflectionParts.decode('not json'), isNull);
    });
  });

  group('Quick reflection gives all five parts', () {
    final engine = QuickReflectionEngine();
    test('with a pattern', () async {
      final r = await engine.reflect('What if I fail the exam? It will be a disaster.');
      expect(r.parts, isNotNull);
      expect(r.parts!.pattern, 'catastrophizing');
      expect(r.parts!.questions, isNotEmpty);
      expect(r.parts!.balanced, isNotEmpty);
      expect(r.parts!.nextStep, isNotEmpty);
    });
    test('without a pattern', () async {
      final r = await engine.reflect('I had a quiet walk and drank tea.');
      expect(r.parts, isNotNull);
      expect(r.parts!.pattern, isNull);
    });
  });

  group('Friendly errors (FR-25)', () {
    test('each kind has a message that says the entry is kept', () {
      for (final k in ReflectionErrorKind.values) {
        if (k == ReflectionErrorKind.other) continue;
        expect(ReflectionException.of(k).message, contains('saved'));
      }
    });
    test('a rate limit cannot be retried at once', () {
      expect(ReflectionException.of(ReflectionErrorKind.rateLimited).canRetry, isFalse);
      expect(ReflectionException.of(ReflectionErrorKind.slow).canRetry, isTrue);
    });
  });
}
