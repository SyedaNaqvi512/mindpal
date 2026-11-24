import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/core/errors/app_messages.dart';
import 'package:mindpal/core/validation/validators.dart';
import 'package:mindpal/features/applock/models/app_lock_logic.dart';

void main() {
  group('AppMessages.resolve', () {
    test('wrong login gives one message that does not name the field', () {
      final m = AppMessages.resolve(code: 'invalid_credentials', status: 401);
      expect(m, contains('email or password is incorrect'));
    });

    test('each known code has its own clear message', () {
      for (final c in [
        'email_taken',
        'account_suspended',
        'account_pending_deletion',
        'invalid_verification_code',
        'verification_code_expired',
        'verification_attempts_exceeded',
        'resend_cooldown',
        'invalid_reset_code',
        'reset_code_expired',
        'invalid_current_password',
        'same_password',
        'rate_limited',
        'ai_rate_limited',
        'followup_limit_reached',
      ]) {
        expect(AppMessages.forCode(c), isNotNull, reason: c);
      }
      expect(
        AppMessages.forCode('account_suspended'),
        isNot(AppMessages.forCode('account_pending_deletion')),
      );
    });

    test('validation_failed shows the field message from the server', () {
      expect(
        AppMessages.resolve(
          code: 'validation_failed',
          status: 400,
          fieldError: 'Password is too weak.',
        ),
        'Password is too weak.',
      );
      expect(
        AppMessages.resolve(code: 'validation_failed', status: 400),
        AppMessages.checkDetails,
      );
    });

    test('unknown code falls back to the status', () {
      expect(AppMessages.resolve(status: 429), AppMessages.tooManyRequests);
      expect(AppMessages.resolve(status: 500), AppMessages.serverError);
      expect(AppMessages.resolve(status: 503), AppMessages.serverError);
      expect(AppMessages.resolve(status: 401), AppMessages.sessionExpired);
      expect(AppMessages.resolve(), AppMessages.generic);
    });
  });

  group('AppMessages.forNetworkError', () {
    tearDown(() => AppMessages.probe = () async => true);

    test('timeout', () async {
      expect(
        await AppMessages.forNetworkError(TimeoutException('slow')),
        AppMessages.timeout,
      );
    });

    test('no internet when the probe fails', () async {
      AppMessages.probe = () async => false;
      expect(await AppMessages.forNetworkError(Exception('x')),
          AppMessages.noInternet);
    });

    test('server unreachable when the internet works', () async {
      AppMessages.probe = () async => true;
      expect(await AppMessages.forNetworkError(Exception('x')),
          AppMessages.serverUnreachable);
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), 'Enter your email.');
      expect(Validators.email('abc'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email('a b@c.com'), isNotNull);
      expect(Validators.email(' name@example.com '), isNull);
    });

    test('name', () {
      expect(Validators.name(''), 'Enter your name.');
      expect(Validators.name('   '), 'Enter your name.');
      expect(Validators.name('A'), isNotNull);
      expect(Validators.name('1234'), isNotNull);
      expect(Validators.name('x' * 41), isNotNull);
      expect(Validators.name('Malaika Fatima'), isNull);
      expect(Validators.name("Anne-Marie O'Neil"), isNull);
      expect(Validators.name('ملائکہ'), isNull);
    });

    test('code', () {
      expect(Validators.code6(''), isNotNull);
      expect(Validators.code6('12345'), isNotNull);
      expect(Validators.code6('12a456'), isNotNull);
      expect(Validators.code6('123456'), isNull);
    });
  });

  group('Recovery questions', () {
    test('a question taken by another slot is not offered again', () {
      final chosen = <String?>['pet', 'food', null];
      final slot2 = questionsFor(2, chosen);
      expect(slot2.containsKey('pet'), isFalse);
      expect(slot2.containsKey('food'), isFalse);
      expect(slot2.length, RecoveryQuestions.all.length - 2);
      // the slot keeps its own choice
      expect(questionsFor(0, chosen).containsKey('pet'), isTrue);
    });

    test('answers must be filled, long enough and different', () {
      final answers = ['a', 'Lahore', 'lahore '];
      expect(answerError('', answers, 0), 'Type your answer.');
      expect(answerError('a', answers, 0), 'Use at least 3 characters.');
      expect(answerError('lahore', answers, 1),
          'Use a different answer for each question.');
      expect(answerError('Karachi', answers, 1), isNull);
    });

    test('validateRecovery rejects repeated answers', () {
      expect(
        validateRecovery(['pet', 'food', 'school'], ['Tom', 'Rice', ' rice']),
        'Use a different answer for each question.',
      );
      expect(
        validateRecovery(['pet', 'food', 'school'], ['Tom', 'Rice', 'Model']),
        isNull,
      );
    });
  });
}
