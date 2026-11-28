import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The language the Learn articles are read in: 'en' or 'ur' (Urdu). It is a
/// plain notifier, not Riverpod, so the Learn screens work in simple widget
/// tests with no ProviderScope. Only this one choice is saved on the phone.
final ValueNotifier<String> learnLanguage = ValueNotifier<String>('en');

const String kLearnLanguageKey = 'learn_language';

/// The bundled Urdu face (Noto Nastaliq Urdu, SIL Open Font Licence).
const String kUrduFamily = 'NotoNastaliqUrdu';

bool get learnIsUrdu => learnLanguage.value == 'ur';

/// Call once in main() after SharedPreferences has loaded.
void loadLearnLanguage(SharedPreferences prefs) {
  final v = prefs.getString(kLearnLanguageKey);
  learnLanguage.value = v == 'ur' ? 'ur' : 'en';
}

Future<void> setLearnLanguage(String code) async {
  final value = code == 'ur' ? 'ur' : 'en';
  learnLanguage.value = value;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLearnLanguageKey, value);
  } catch (_) {
    // The choice still works for this session.
  }
}
