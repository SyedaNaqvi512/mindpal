import 'package:flutter/material.dart';

import '../../auth/services/auth_service.dart';
import '../../../core/database/database_service.dart';
import '../../../core/theme/theme_switcher_button.dart';
import '../services/cloud_reflection_engine.dart';
import '../services/reflection_engine.dart';
import '../services/reflection_service.dart';

enum ReflectionMode { cloud, onDevice }

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _controller = TextEditingController();
  final ReflectionEngine _cloudEngine = CloudReflectionEngine();
  final ReflectionEngine _deviceEngine = ReflectionService();

  ReflectionMode _mode = ReflectionMode.cloud;
  String? _result;
  String? _notice;
  bool _crisis = false;
  bool _loading = false;
  int _mood = 3;
  List<Map<String, dynamic>> _recent = [];

  ReflectionEngine get _engine =>
      _mode == ReflectionMode.cloud ? _cloudEngine : _deviceEngine;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    try {
      final rows = await DatabaseService.getRecentEntries();
      if (!mounted) return;
      setState(() => _recent = rows);
    } catch (_) {}
  }

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

      if (!mounted) return;

      _controller.clear();
      await _loadRecent();

      if (mounted) {
        setState(() => _notice = 'Saved on this phone.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice =
              'The reflection could not be saved on this phone.',
        );
      }
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.logout();
    widget.onSignedOut();
  }

  String _pattern(Object? p) {
    final s = p as String?;
    return (s == null || s == 'none') ? '' : s.replaceAll('_', ' ');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MindPal'),
        actions: [
          const ThemeSwitcherButton(),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _loading ? null : _signOut,
          ),
        ],
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
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'How do you feel? (1 = very low, 5 = very good)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (var m = 1; m <= 5; m++)
                  ChoiceChip(
                    label: Text('$m'),
                    selected: _mood == m,
                    onSelected: _loading
                        ? null
                        : (_) => setState(() => _mood = m),
                  ),
              ],
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
                  : (selection) =>
                      setState(() => _mode = selection.first),
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
                    'It sounds like you are going through something very '
                    'painful. You deserve support from a real person. Please '
                    'contact your local emergency number or a mental health '
                    'service, or reach out to someone you trust right now.\n\n'
                    'Punjab Institute of Mental Health, Lahore: '
                    '+92 42 99203776',
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
                child: Text(
                  _notice!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            if (_recent.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Recent entries',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final row in _recent)
                Card(
                  child: ListTile(
                    title: Text(
                      row['content'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Mood ${row['mood']} - '
                      '${(row['created_at'] as String).substring(0, 10)}'
                      '${_pattern(row['thinking_pattern']).isEmpty ? '' : ' - ${_pattern(row['thinking_pattern'])}'}',
                    ),
                  ),
                ),
            ],
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