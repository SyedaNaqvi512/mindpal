/// Password rules shown on screen and checked before the request is sent.
/// The server checks the same rules again.
class PasswordRules {
  static const String hint = 'At least 8 characters, with a letter and a digit';

  static bool hasLength(String p) => p.length >= 8;
  static bool hasLetter(String p) => RegExp(r'[A-Za-z]').hasMatch(p);
  static bool hasDigit(String p) => RegExp(r'\d').hasMatch(p);

  static bool isValid(String p) => hasLength(p) && hasLetter(p) && hasDigit(p);

  /// null when fine, otherwise a short message for the field.
  static String? validate(String p) {
    if (p.isEmpty) return 'Enter a password.';
    if (!isValid(p)) return hint;
    return null;
  }
}
