import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Pure rules for the app lock (FR-32). No storage here, so they are easy to test.

/// Questions the user can choose from for PIN recovery.
class RecoveryQuestions {
  static const all = <String, String>{
    'pet': 'What was the name of a pet you loved?',
    'birthplace': 'In which city or village were you born?',
    'subject': 'What was your favourite subject in school?',
    'friend': 'What was the name of your best childhood friend?',
    'phone': 'What was the brand of your first mobile phone?',
    'food': 'What food did you love most as a child?',
    'school': 'What was the name of your primary school?',
    'teacher': 'Who was your favourite teacher?',
  };

  static const count = 3;
}

/// Lowercase, trim, one space between words, so "  Lahore " matches "lahore".
String normalizeAnswer(String s) =>
    s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

/// null when the three questions and answers are fine, otherwise a message.
String? validateRecovery(List<String?> ids, List<String> answers) {
  if (ids.length != RecoveryQuestions.count ||
      answers.length != RecoveryQuestions.count) {
    return 'Choose three questions.';
  }
  if (ids.any((i) => i == null || !RecoveryQuestions.all.containsKey(i))) {
    return 'Choose three questions.';
  }
  if (ids.toSet().length != ids.length) {
    return 'Choose three different questions.';
  }
  for (final a in answers) {
    if (normalizeAnswer(a).length < 3) {
      return 'Each answer needs at least 3 characters.';
    }
  }
  return null;
}

/// All the same digit (0000) or an up/down run (1234, 4321) is too easy to guess.
bool isWeakPin(String pin) {
  if (pin.length < 2) return true;
  if (pin.split('').toSet().length == 1) return true;
  var up = true, down = true;
  for (var i = 1; i < pin.length; i++) {
    final d = pin.codeUnitAt(i) - pin.codeUnitAt(i - 1);
    if (d != 1) up = false;
    if (d != -1) down = false;
  }
  return up || down;
}

/// After every 5 wrong tries the lock waits: 1, then 5, then 15 minutes.
Duration lockoutFor(int fails) {
  if (fails <= 0 || fails % 5 != 0) return Duration.zero;
  final rounds = fails ~/ 5;
  if (rounds == 1) return const Duration(minutes: 1);
  if (rounds == 2) return const Duration(minutes: 5);
  return const Duration(minutes: 15);
}

int attemptsLeft(int fails) => 5 - (fails % 5);

/// PBKDF2 with HMAC-SHA256, 32 bytes out.
List<int> pbkdf2(List<int> password, List<int> salt, int iterations) {
  final hmac = Hmac(sha256, password);
  var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final t = List<int>.from(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < t.length; j++) {
      t[j] ^= u[j];
    }
  }
  return t;
}

const _iterations = 10000;

/// "salt:hash" in base64. The secret itself is never stored.
String hashSecret(String secret, {List<int>? salt}) {
  final s = salt ?? List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final h = pbkdf2(utf8.encode(secret), s, _iterations);
  return '${base64Encode(s)}:${base64Encode(h)}';
}

bool verifySecret(String secret, String stored) {
  final parts = stored.split(':');
  if (parts.length != 2) return false;
  try {
    final salt = base64Decode(parts[0]);
    final expected = base64Decode(parts[1]);
    final actual = pbkdf2(utf8.encode(secret), salt, _iterations);
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  } catch (_) {
    return false;
  }
}
