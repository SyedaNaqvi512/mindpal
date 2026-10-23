import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../models/app_lock_logic.dart';

class AttemptResult {
  const AttemptResult({
    required this.ok,
    this.lockedFor,
    this.attemptsLeft = 0,
  });

  final bool ok;
  final Duration? lockedFor; // set while the lock is waiting
  final int attemptsLeft;
}

/// Keeps the PIN, the recovery answers and the fingerprint choice (FR-32).
/// Only salted hashes are stored, in the phone's secure storage. The PIN is a
/// screen lock: the journal is already encrypted with its own key.
class AppLockService extends ChangeNotifier {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  static const pinLength = 4;

  static const _kEnabled = 'applock_enabled';
  static const _kPin = 'applock_pin';
  static const _kBio = 'applock_bio';
  static const _kQuestions = 'applock_questions';
  static const _kAnswers = 'applock_answers';
  static const _kPinFails = 'applock_pin_fails';
  static const _kPinLock = 'applock_pin_lock';
  static const _kRecFails = 'applock_rec_fails';
  static const _kRecLock = 'applock_rec_lock';

  final FlutterSecureStorage _s = FlutterSecureStorage();
  final LocalAuthentication _auth = LocalAuthentication();

  bool _enabled = false;
  bool _bio = false;

  /// True while a system dialog (fingerprint) is open, so the app does not lock itself.
  bool suspendAutoLock = false;

  bool get enabled => _enabled;
  bool get biometricEnabled => _bio;

  /// Read once before the first screen, so a locked app starts locked.
  Future<void> load() async {
    try {
      _enabled = await _s.read(key: _kEnabled) == '1';
      _bio = await _s.read(key: _kBio) == '1';
    } catch (_) {
      _enabled = false;
      _bio = false;
    }
  }

  // ---- setup ----------------------------------------------------------

  Future<void> setPin(String pin) async {
    await _s.write(key: _kPin, value: hashSecret(pin));
    await _s.delete(key: _kPinFails);
    await _s.delete(key: _kPinLock);
  }

  Future<void> saveRecovery(List<String> ids, List<String> answers) async {
    final hashes = [for (final a in answers) hashSecret(normalizeAnswer(a))];
    await _s.write(key: _kQuestions, value: jsonEncode(ids));
    await _s.write(key: _kAnswers, value: jsonEncode(hashes));
    await _s.delete(key: _kRecFails);
    await _s.delete(key: _kRecLock);
  }

  Future<void> setBiometric(bool on) async {
    await _s.write(key: _kBio, value: on ? '1' : '0');
    _bio = on;
    notifyListeners();
  }

  Future<void> enable() async {
    await _s.write(key: _kEnabled, value: '1');
    _enabled = true;
    notifyListeners();
  }

  /// Turns the lock off and forgets the PIN, the answers and the fingerprint choice.
  Future<void> reset() async {
    for (final k in [
      _kEnabled,
      _kPin,
      _kBio,
      _kQuestions,
      _kAnswers,
      _kPinFails,
      _kPinLock,
      _kRecFails,
      _kRecLock,
    ]) {
      try {
        await _s.delete(key: k);
      } catch (_) {}
    }
    _enabled = false;
    _bio = false;
    notifyListeners();
  }

  // ---- checks ---------------------------------------------------------

  Future<AttemptResult> _attempt(
    String failsKey,
    String lockKey,
    Future<bool> Function() matches,
  ) async {
    final now = DateTime.now();
    final until = DateTime.tryParse(await _s.read(key: lockKey) ?? '');
    if (until != null && until.isAfter(now)) {
      return AttemptResult(ok: false, lockedFor: until.difference(now));
    }
    if (await matches()) {
      await _s.delete(key: failsKey);
      await _s.delete(key: lockKey);
      return const AttemptResult(ok: true);
    }
    final fails = (int.tryParse(await _s.read(key: failsKey) ?? '') ?? 0) + 1;
    await _s.write(key: failsKey, value: '$fails');
    final wait = lockoutFor(fails);
    if (wait > Duration.zero) {
      await _s.write(key: lockKey, value: now.add(wait).toIso8601String());
      return AttemptResult(ok: false, lockedFor: wait);
    }
    return AttemptResult(ok: false, attemptsLeft: attemptsLeft(fails));
  }

  Future<AttemptResult> verifyPin(String pin) =>
      _attempt(_kPinFails, _kPinLock, () async {
        final stored = await _s.read(key: _kPin);
        return stored != null && verifySecret(pin, stored);
      });

  Future<List<String>> recoveryQuestionIds() async {
    try {
      final raw = await _s.read(key: _kQuestions);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List).whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// All three answers must be right.
  Future<AttemptResult> verifyRecovery(List<String> answers) =>
      _attempt(_kRecFails, _kRecLock, () async {
        try {
          final raw = await _s.read(key: _kAnswers);
          if (raw == null) return false;
          final hashes = (jsonDecode(raw) as List).whereType<String>().toList();
          if (hashes.length != answers.length) return false;
          var all = true;
          for (var i = 0; i < hashes.length; i++) {
            if (!verifySecret(normalizeAnswer(answers[i]), hashes[i])) {
              all = false;
            }
          }
          return all;
        } catch (_) {
          return false;
        }
      });

  // ---- fingerprint ----------------------------------------------------

  Future<bool> biometricsAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric(String reason) async {
    suspendAutoLock = true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    } finally {
      await Future<void>.delayed(const Duration(seconds: 1));
      suspendAutoLock = false;
    }
  }
}
