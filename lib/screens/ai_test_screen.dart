import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

class AiTestScreen extends StatefulWidget {
  const AiTestScreen({super.key});

  @override
  State<AiTestScreen> createState() => _AiTestScreenState();
}

class _AiTestScreenState extends State<AiTestScreen> {
  static const modelPath =
      '/data/data/com.example.mindpal/files/gemma3-1b-it-int4.task';

  String _output = 'Press the button to test Gemma.';
  bool _loading = false;

  Future<void> _runTest() async {
    setState(() {
      _loading = true;
      _output = 'Loading model... this can take 30-60 seconds.';
    });

    try {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.task,
      ).fromFile(modelPath).install();

      final model = await FlutterGemma.getActiveModel(maxTokens: 512);
      final session = await model.createSession();

      await session.addQueryChunk(
        Message.text(
          text: 'Reply with one short sentence: say hello.',
          isUser: true,
        ),
      );

      final reply = await session.getResponse();
      await session.close();
      await model.close();

      if (!mounted) return;
      setState(() => _output = reply);
    } catch (e) {
      if (!mounted) return;
      setState(() => _output = 'ERROR: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gemma Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _runTest,
              child: const Text('Test Gemma'),
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Expanded(child: SingleChildScrollView(child: SelectableText(_output))),
          ],
        ),
      ),
    );
  }
}