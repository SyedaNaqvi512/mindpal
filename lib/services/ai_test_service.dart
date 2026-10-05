import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';

class AiTestService {
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;

    const token = String.fromEnvironment('HUGGINGFACE_TOKEN');

    await FlutterGemma.initialize(
      inferenceEngines: const [
        MediaPipeEngine(),
      ],
      huggingFaceToken: token.isNotEmpty ? token : null,
    );

    _initialized = true;
  }

  static Future<String> runFeasibilityTest({
    required void Function(String message) onProgress,
  }) async {
    await _ensureInitialized();

    const modelUrl =
        'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task';

    onProgress('Starting Gemma model installation...');

    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.task,
    )
        .fromNetwork(modelUrl)
        .withProgress(
          (progress) => onProgress(
            'Download progress: $progress%',
          ),
        )
        .install();

    onProgress('Model installed. Loading Gemma...');

    final model = await FlutterGemma.getActiveModel(
      maxTokens: 1024,
    );

    final session = await model.createSession();

    const prompt = '''
Analyze the following journal reflection using a CBT-informed approach.

Identify one possible unhelpful thinking pattern from this list:
- All-or-Nothing Thinking
- Overgeneralization
- Mind Reading
- Catastrophizing
- Personalization
- None Identified

Then provide one short, supportive reframing suggestion.

Important:
- Do not diagnose the user.
- Use "possible" or "may" when identifying a pattern.
- Keep the response concise.

Journal reflection:
"I always fail at everything I do, nothing ever works out for me."
''';

    onProgress('Sending prompt to Gemma...');

    await session.addQueryChunk(
      Message.text(
        text: prompt,
        isUser: true,
      ),
    );

    onProgress('Waiting for Gemma response...');

    final stopwatch = Stopwatch()..start();

    final response = await session.getResponse();

    stopwatch.stop();

    onProgress(
      'Response received in ${stopwatch.elapsedMilliseconds} ms',
    );

    return response;
  }
}