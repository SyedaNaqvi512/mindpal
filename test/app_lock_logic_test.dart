import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/applock/models/app_lock_logic.dart';

void main() {
  group('normalizeAnswer', () {
    test('ignores case and extra spaces', () {
      expect(normalizeAnswer('  Lahore  '), 'lahore');
      expect(normalizeAnswer('New   YORK'), 'new york');
    });
  });

  group('isWeakPin', () {
    test('rejects repeats and runs', () {
      expect(isWeakPin('0000'), isTrue);
      expect(isWeakPin('1234'), isTrue);
      expect(isWeakPin('4321'), isTrue);
    });
    test('accepts others', () {
      expect(isWeakPin('1357'), isFalse);
      expect(isWeakPin('2580'), isFalse);
    });
  });

  group('lockoutFor', () {
    test('no wait until the fifth wrong try', () {
      for (final f in [0, 1, 2, 3, 4, 6, 9]) {
        expect(lockoutFor(f), Duration.zero);
      }
    });
    test('1, 5 then 15 minutes', () {
      expect(lockoutFor(5), const Duration(minutes: 1));
      expect(lockoutFor(10), const Duration(minutes: 5));
      expect(lockoutFor(15), const Duration(minutes: 15));
      expect(lockoutFor(30), const Duration(minutes: 15));
    });
    test('attempts left counts down', () {
      expect(attemptsLeft(1), 4);
      expect(attemptsLeft(4), 1);
    });
  });

  group('hashSecret', () {
    test('verifies the right secret only', () {
      final h = hashSecret('2580');
      expect(verifySecret('2580', h), isTrue);
      expect(verifySecret('2581', h), isFalse);
    });
    test('same secret gives different hashes (random salt)', () {
      expect(hashSecret('2580'), isNot(hashSecret('2580')));
    });
    test('bad stored text does not crash', () {
      expect(verifySecret('1', 'garbage'), isFalse);
      expect(verifySecret('1', 'a:b'), isFalse);
    });
    test('does not contain the secret', () {
      expect(hashSecret('2580').contains('2580'), isFalse);
    });
  });

  group('validateRecovery', () {
    const ids = ['pet', 'food', 'school'];
    test('accepts three different questions with answers', () {
      expect(
        validateRecovery(ids, ['Tommy', 'biryani', 'Beaconhouse']),
        isNull,
      );
    });
    test('rejects duplicates, blanks and short answers', () {
      expect(
        validateRecovery(['pet', 'pet', 'food'], ['abc', 'abc', 'abc']),
        isNotNull,
      );
      expect(
        validateRecovery(['pet', null, 'food'], ['abc', 'abc', 'abc']),
        isNotNull,
      );
      expect(validateRecovery(ids, ['abc', 'ab', 'abc']), isNotNull);
      expect(validateRecovery(ids, ['abc', '  ', 'abc']), isNotNull);
    });
  });
}
