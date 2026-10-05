import 'package:flutter/material.dart';
import '../services/reflection_service.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _controller = TextEditingController();
  final _ai = ReflectionService();
  String? _result;
  bool _crisis = false;
  bool _loading = false;

  Future<void> _reflect() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (ReflectionService.looksLikeCrisis(text)) {
      setState(() {
        _crisis = true;
        _result = null;
      });
      return;
    }

    setState(() {
      _crisis = false;
      _loading = true;
      _result = null;
    });

    try {
      final reply = await _ai.reflect(text);
      if (!mounted) return;
      setState(() => _result = reply);
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MindPal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'How was your day? What is on your mind?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _reflect,
              child: const Text('Reflect'),
            ),
            const SizedBox(height: 16),
            if (_loading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text(
                'Thinking... the first reply can take up to a minute.',
              ),
            ],
            if (_crisis)
              Card(
                color: Colors.red.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'It sounds like you are going through something very painful. '
                    'You deserve support from a real person. Please contact your '
                    'local emergency number or a mental health service, or reach out to '
                    'someone you trust right now.\n\n'
                    'Punjab Institute of Mental Health, Lahore: +92 42 99203776',
                  ),
                ),
              ),
            if (_result != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(_result!),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'MindPal is a reflection tool, not a therapist or medical advice.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
