import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The four themes plus System, which follows the phone (SRS FR-31).
enum ThemeChoice { lavenderDream, roseCream, skyMist, midnightLavender, system }

/// Set in main() after SharedPreferences has loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden in main()'),
);

class ThemeController extends Notifier<ThemeChoice> {
  static const prefsKey = 'theme';

  @override
  ThemeChoice build() {
    final saved = ref.read(sharedPreferencesProvider).getString(prefsKey);
    return ThemeChoice.values.firstWhere(
      (c) => c.name == saved,
      orElse: () => ThemeChoice.lavenderDream, // default theme
    );
  }

  Future<void> select(ThemeChoice choice) async {
    state = choice;
    await ref.read(sharedPreferencesProvider).setString(prefsKey, choice.name);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeChoice>(ThemeController.new);