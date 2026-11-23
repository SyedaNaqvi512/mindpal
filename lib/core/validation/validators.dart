/// Field rules used by every form, so the same rule gives the same message
/// everywhere. Each returns null when the value is fine.
class Validators {
  Validators._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
  static final _name = RegExp(r"^[\p{L}\p{M}][\p{L}\p{M} .'\-]*$", unicode: true);

  static String? email(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Enter your email.';
    if (t.length > 254 || !_email.hasMatch(t)) {
      return 'Enter a valid email, like name@example.com.';
    }
    return null;
  }

  static String? name(String? v) {
    final t = (v ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return 'Enter your name.';
    if (t.length < 2) return 'Your name needs at least 2 letters.';
    if (t.length > 40) return 'Keep your name under 40 characters.';
    if (!_name.hasMatch(t)) {
      return 'Use letters only. Spaces, dots, hyphens and apostrophes are fine.';
    }
    return null;
  }

  static String? code6(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Enter the 6-digit code.';
    if (!RegExp(r'^\d{6}$').hasMatch(t)) return 'The code is 6 digits.';
    return null;
  }

  static String? required(String? v, String message) =>
      (v == null || v.trim().isEmpty) ? message : null;
}
