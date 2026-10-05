import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';

import 'screens/journal_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const token = String.fromEnvironment('HUGGINGFACE_TOKEN');

  await FlutterGemma.initialize(
    inferenceEngines: const [
      MediaPipeEngine(),
    ],
    huggingFaceToken: token.isNotEmpty ? token : null,
  );

  runApp(const MindPalApp());
}

class MindPalApp extends StatelessWidget {
  const MindPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindPal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const JournalScreen(),
    );
  }
}