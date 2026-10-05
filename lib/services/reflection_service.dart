import 'package:flutter_edge_ai/flutter_edge_ai.dart';

class ReflectionService {
  static const modelPath =
      '/data/data/com.example.mindpal/files/gemma3-1b-it-int4.task';

    static const _crisisWords = [
    'suicide', 'suicidal', 'kill myself', 'end my life', 'want to die',
    'hurt myself', 'self-harm', 'self harm', 'no reason to live',
    "don't want to live", 'dont want to live', 'better off dead',
    'end it all', 'take my own life',
  ];

  InferenceModel? _model;

  /// Checked BEFORE the AI runs, so safety never depends on the model.
  static bool looksLikeCrisis(String text) {
    final t = text.toLowerCase();
    return _crisisWords.any(t.contains);
  }

  Future<void> init() async {
    if (_model != null) return;
    await FlutterEdgeAi.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.task,
    ).fromFile(modelPath).install();
    _model = await FlutterEdgeAi.getActiveModel(maxTokens: 1024);
  }

    String _buildPrompt(String entry) => '''
You are a kind CBT reflection helper. You are not a therapist.
Reply in exactly 3 lines, with no bold or markdown.
The gentle question must challenge the thought by asking for evidence or another explanation. Do not ask about feelings.

Example entry: I made one mistake in my presentation, so everyone thinks I am stupid.
Thinking pattern: Mind reading
Why: You are assuming what others think without evidence.
Gentle question: What evidence do you have that everyone thinks this, and what else could their reaction mean?

Now do the same for this entry:
$entry
''';

  Future<String> reflect(String entry) async {
    await init();
    final session = await _model!.createSession();
    try {
      await session.addQueryChunk(
        Message.text(text: _buildPrompt(entry), isUser: true),
      );
            final reply = await session.getResponse();
      return reply.replaceAll('**', '').replaceAll('*', '').trim();
    } finally {
      await session.close();
    }
  }
}