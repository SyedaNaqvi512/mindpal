import 'dart:async';
import 'dart:io';

/// Checks whether the phone has internet (a DNS lookup). Replaceable in tests.
typedef InternetProbe = Future<bool> Function();

/// Every message the user can see when a request fails, in one place.
/// Each one says what happened and what to do next.
class AppMessages {
  AppMessages._();

  static const noInternet =
      'No internet connection. Turn on Wi-Fi or mobile data and try again.';
  static const serverUnreachable =
      "MindPal's server cannot be reached right now. Your internet looks "
      'fine, so please try again in a few minutes.';
  static const timeout =
      'The server is taking too long to answer. Check your connection and '
      'try again.';
  static const serverError =
      'Something went wrong on our side. Please try again in a moment.';
  static const tooManyRequests =
      'Too many attempts. Please wait a few minutes and try again.';
  static const generic = 'Something went wrong. Please try again.';
  static const sessionExpired = 'Your session has expired. Please sign in again.';
  static const checkDetails =
      'Please check the details you entered and try again.';

  /// Messages for the stable error codes sent by the server.
  static const Map<String, String> _codes = {
    'invalid_credentials':
        'The email or password is incorrect. Check both and try again.',
    'email_taken':
        'An account with this email already exists. Sign in instead, or use '
            'another email.',
    'account_suspended':
        'This account has been suspended, so you cannot sign in. Please '
            'contact MindPal support.',
    'account_pending_deletion':
        'This account is being deleted, so you cannot sign in.',
    'email_not_verified': 'Please verify your email first.',
    'email_already_verified':
        'This email is already verified. You can sign in now.',
    'invalid_verification_code':
        'That code is not correct or has expired. Check it, or ask for a '
            'new code.',
    'verification_code_expired':
        'This code has expired. Tap "Send a new code" to get a fresh one.',
    'verification_attempts_exceeded':
        'Too many wrong codes. Tap "Send a new code" to get a fresh one.',
    'resend_cooldown':
        'Please wait a minute before asking for another code.',
    'verification_email_failed':
        'We could not send the email. Please try again in a few minutes.',
    'invalid_reset_code':
        'That code is not correct or has expired. Check it, or ask for a '
            'new code.',
    'reset_code_expired':
        'This code has expired. Tap "Send a new code" to get a fresh one.',
    'reset_attempts_exceeded':
        'Too many wrong codes. Tap "Send a new code" to get a fresh one.',
    'invalid_current_password': 'Your current password is not correct.',
    'same_password':
        'Your new password must be different from your current password.',
    'empty_update': 'Change your name or picture first, then save.',
    'invalid_token': sessionExpired,
    'consent_required': 'Please allow AI reflections to continue.',
    'rate_limited': tooManyRequests,
    'ai_rate_limited':
        'You have reached the reflection limit for now. Please try again '
            'later.',
    'ai_timeout':
        'The AI is taking longer than usual. Please try again in a moment.',
    'ai_unavailable':
        'The AI service is not available right now. Please try again later.',
  };

  static InternetProbe probe = _defaultProbe;

  static Future<bool> _defaultProbe() async {
    // Two independent checks, so one blocked service cannot fake "offline".
    for (final host in const ['google.com', 'one.one.one.one']) {
      try {
        final r = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 3));
        if (r.isNotEmpty) return true;
      } catch (_) {}
    }
    try {
      final s = await Socket.connect('1.1.1.1', 443,
          timeout: const Duration(seconds: 3));
      s.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Why a request could not be made: slow, no internet, or server down.
  static Future<String> forNetworkError(Object error) async {
    if (error is TimeoutException) return timeout;
    return await probe() ? serverUnreachable : noInternet;
  }

  static String? forCode(String? code) => code == null ? null : _codes[code];

  static String forStatus(int? status) {
    if (status == null) return generic;
    if (status == 429) return tooManyRequests;
    if (status == 401) return sessionExpired;
    if (status >= 500) return serverError;
    if (status == 400) return checkDetails;
    return generic;
  }

  /// The best message for a server reply: the code first, then a field error
  /// the server named, then the status.
  static String resolve({String? code, int? status, String? fieldError}) {
    if (code == 'validation_failed') return fieldError ?? checkDetails;
    return forCode(code) ?? fieldError ?? forStatus(status);
  }
}