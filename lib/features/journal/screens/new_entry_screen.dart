import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../../auth/services/auth_service.dart';
import '../services/cloud_reflection_engine.dart';
import '../services/reflection_engine.dart';
import '../services/reflection_service.dart';

enum ReflectionMode { cloud, onDevice }

class NewEntryScreen extends StatefulWidget {
  const NewEntryScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  final _controller = TextEditingController();
  final ReflectionEngine _cloudEngine = CloudReflectionEngine();
  final ReflectionEngine _deviceEngine = ReflectionService();

  ReflectionMode _mode = ReflectionMode.cloud;
  String? _result;
  String? _notice;
  bool _crisis = false;
  bool _loading = false;
  int _mood = 3;

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
        _notice = null;
      });
      return;
    }

    setState(() {
      _crisis = false;
      _loading = true;
      _result = null;
      _notice = null;
    });

    try {
      final reply = await _engine.reflect(text);
      if (!mounted) return;

      if (reply.safety) {
        setState(() => _crisis = true);
        return;
      }

      setState(() => _result = reply.text);
      await _save(text, reply);
    } on SessionExpiredException {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      widget.onSignedOut();
    } on ReflectionException catch (e) {
      if (!mounted) return;
      setState(() => _result = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = 'Something went wrong: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // The journal text stays on the phone, in the encrypted database.
  Future<void> _save(String text, ReflectionResult reply) async {
    try {
      final entryId = await DatabaseService.insertJournalEntry(
        content: text,
        mood: _mood,
      );

      await DatabaseService.insertReflection(
        entryId: entryId,
        text: reply.text,
        thinkingPattern: reply.pattern,
        serverReflectionId: reply.serverId,
      );

      entriesChanged.value++;

      if (!mounted) return;
      _controller.clear();
      setState(() => _notice = 'Saved on this phone.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice = 'The reflection could not be saved on this phone.',
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hint = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New entry'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              maxLines: 6,
              maxLength: 5000,
              decoration: const InputDecoration(
                hintText: 'How was your day? What is on your mind?',
              ),
            ),
            const SizedBox(height: 8),
            Text('How do you feel? (1 = very low, 5 = very good)', style: hint),
            Wrap(
              spacing: 8,
              children: [
                for (var m = 1; m <= 5; m++)
                  ChoiceChip(
                    label: Text('$m'),
                    selected: _mood == m,
                    onSelected:
                        _loading ? null : (_) => setState(() => _mood = m),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ReflectionMode>(
              segments: const [
                ButtonSegment(
                  value: ReflectionMode.cloud,
                  label: Text('Cloud AI'),
                  icon: Icon(Symbols.cloud_rounded),
                ),
                ButtonSegment(
                  value: ReflectionMode.onDevice,
                  label: Text('Private (on-device)'),
                  icon: Icon(Symbols.smartphone_rounded),
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
              style: hint,
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
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'It sounds like you are going through something very '
                    'painful. You deserve support from a real person. Please '
                    'contact your local emergency number or a mental health '
                    'service, or reach out to someone you trust right now.\n\n'
                    'Punjab Institute of Mental Health, Lahore: '
                    '+92 42 99203776',
                    style: TextStyle(color: scheme.onErrorContainer),
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
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_notice!, style: hint),
              ),
            const SizedBox(height: 24),
            Text(
              'MindPal is a reflection tool, not a therapist or medical advice.',
              style: hint,
            ),
          ],
        ),
      ),
    );
  }
}