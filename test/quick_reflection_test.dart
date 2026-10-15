import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/journal/services/quick_reflection_engine.dart';

void main() {
  final engine = QuickReflectionEngine();

  test('mind reading is found (teacher dislikes me)', () async {
    final r = await engine.reflect(
        'i think my teacher dislike me because she always gave me less marks.');
    expect(r.pattern, 'mind_reading');
  });

  test('mind reading is found (friends mock me)', () async {
    final r = await engine.reflect('Today my friends mock me because I look ugly.');
    expect(r.pattern, 'mind_reading');
  });

  test('labeling is found', () async {
    final r = await engine.reflect(
        'I got zero marks, I am not hardworking, I think I deserve to live alone.');
    expect(r.pattern, 'labeling');
  });

  test('catastrophizing is found', () async {
    final r = await engine.reflect('What if I fail the exam? It will be a disaster.');
    expect(r.pattern, 'catastrophizing');
  });

  test('should statements are found', () async {
    final r = await engine.reflect('I should have studied more, I must do better.');
    expect(r.pattern, 'should_statements');
  });

  test('no pattern gives a generic reflection without a pattern', () async {
    final r = await engine.reflect('I had a quiet walk and drank tea.');
    expect(r.pattern, isNull);
    expect(r.safety, isFalse);
    expect(r.text, contains('One small next step'));
  });

  test('a matched reflection has all five parts and is a suggestion', () async {
    final r = await engine.reflect('Everyone thinks I am boring.');
    expect(r.text, contains('Thank you for writing this down'));
    expect(r.text, contains('only a suggestion'));
    expect(r.text, contains('Questions to try'));
    expect(r.text, contains('A more balanced thought'));
    expect(r.text, contains('One small next step'));
  });

  test('curly apostrophes are handled', () async {
    final r = await engine.reflect('It’s my fault, I ruined it.');
    expect(r.pattern, 'personalization');
  });
}