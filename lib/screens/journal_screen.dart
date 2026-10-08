import 'package:flutter/material.dart';

import '../services/cloud_reflection_engine.dart';
import '../services/reflection_engine.dart';
import '../services/reflection_service.dart';

enum ReflectionMode { cloud, onDevice }

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _controller = TextEditingController();
  final ReflectionEngine _cloudEngine = CloudReflectionEngine();
  final ReflectionEngine _deviceEngine = ReflectionService();

  ReflectionMode _mode = ReflectionMode.cloud;
  String? _result;
  bool _crisis = false;
  bool _loading = false;

  ReflectionEngine get _engine =>
      _mode == ReflectionMode.cloud ? _cloudEngine : _deviceEngine;

  Future<void> _reflect() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Safety check runs first, on the device, before any AI is used.
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
      final reply = await _engine.reflect(text);
      if (!mounted) return;
      setState(() => _result = reply);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = e is ReflectionException
            ? e.message
            : 'Something went wrong: $e';
      });
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
            SegmentedButton<ReflectionMode>(
              segments: const [
                ButtonSegment(
                  value: ReflectionMode.cloud,
                  label: Text('Cloud AI'),
                  icon: Icon(Icons.cloud_outlined),
                ),
                ButtonSegment(
                  value: ReflectionMode.onDevice,
                  label: Text('Private (on-device)'),
                  icon: Icon(Icons.phone_android),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _loading
                  ? null
                  : (selection) => setState(() => _mode = selection.first),
            ),
            const SizedBox(height: 8),
            Text(
              _mode == ReflectionMode.cloud
                  ? 'Cloud AI sends your entry to the MindPal server for '
                      'analysis. Use test text while developing.'
                  : 'On-device mode keeps your entry on this phone. '
                      'It needs the model file and can be slower.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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