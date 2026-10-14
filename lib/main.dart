import 'package:flutter/material.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_mediapipe/flutter_edge_ai_mediapipe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_palette.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const token = String.fromEnvironment('HUGGINGFACE_TOKEN');

  await FlutterEdgeAi.initialize(
    inferenceEngines: const [
      MediaPipeEngine(),
    ],
    huggingFaceToken: token.isNotEmpty ? token : null,
  );

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MindPalApp(),
    ),
  );
}

class MindPalApp extends ConsumerWidget {
  const MindPalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(themeControllerProvider);

    // System follows the phone: Lavender Dream when light, Midnight Lavender when dark.
    final lightPalette = switch (choice) {
      ThemeChoice.roseCream => AppPalette.roseCream,
      ThemeChoice.skyMist => AppPalette.skyMist,
      _ => AppPalette.lavenderDream,
    };
    final mode = switch (choice) {
      ThemeChoice.system => ThemeMode.system,
      ThemeChoice.midnightLavender => ThemeMode.dark,
      _ => ThemeMode.light,
    };

    return MaterialApp(
      title: 'MindPal',
      theme: AppTheme.build(lightPalette),
      darkTheme: AppTheme.build(AppPalette.midnightLavender),
      themeMode: mode,
      home: const AuthGate(),
    );
  }
}