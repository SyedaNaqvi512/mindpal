import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/account/models/avatars.dart';
import 'package:mindpal/features/account/models/password_rules.dart';

void main() {
  group('Avatars', () {
    test('female sees 1-5', () {
      expect(Avatars.idsFor(Gender.female), [1, 2, 3, 4, 5]);
    });
    test('male sees 6-10', () {
      expect(Avatars.idsFor(Gender.male), [6, 7, 8, 9, 10]);
    });
    test('prefer not to say sees all ten', () {
      expect(Avatars.idsFor(Gender.unspecified).length, 10);
    });
    test('cross-gender picks are not allowed', () {
      expect(Avatars.isAllowed(Gender.female, 6), isFalse);
      expect(Avatars.isAllowed(Gender.male, 1), isFalse);
      expect(Avatars.isAllowed(Gender.unspecified, 10), isTrue);
    });
    test('defaults', () {
      expect(Avatars.defaultFor(Gender.female), 1);
      expect(Avatars.defaultFor(Gender.male), 6);
      expect(Avatars.defaultFor(Gender.unspecified), 1);
    });
  });

  group('PasswordRules', () {
    test('accepts letter + digit, 8+ chars', () {
      expect(PasswordRules.isValid('abcdefg1'), isTrue);
    });
    test('rejects short, no digit, no letter', () {
      expect(PasswordRules.isValid('abc1'), isFalse);
      expect(PasswordRules.isValid('abcdefgh'), isFalse);
      expect(PasswordRules.isValid('12345678'), isFalse);
    });
  });
}
