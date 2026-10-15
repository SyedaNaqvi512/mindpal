import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../../auth/services/auth_service.dart';
import '../../consent/services/consent_service.dart';
import '../../consent/widgets/consent_sheet.dart';
import '../../safety/widgets/support_card.dart';
import '../services/cloud_reflection_engine.dart';
import '../services/quick_reflection_engine.dart';
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
  bool _canQuick = false; // cloud failed: offer the offline Quick reflection
  bool _quickUsed = false;
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
      _canQuick = false;
      _quickUsed = false;
    });

    try {
      // FR-17: before the first cloud AI use, explain and ask for consent.
      if (_mode == ReflectionMode.cloud && !await _ensureConsent()) {
        if (!mounted) return;
        setState(() {
          _result = 'Cloud reflections need your permission to send this '
              'entry to an AI service. You can allow it later in Settings, '
              'or get a quick reflection on this phone instead.';
          _canQuick = true;
        });
        return;
      }

      final reply = await _engine.reflect(text);
      if (!mounted) return;

      if (reply.safety) {
        setState(() => _crisis = true);
        return;
      }

      setState(() => _result = reply.text);
      await _save(text, reply);
    } on SessionExpiredException {
      ConsentService.instance.clear();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      widget.onSignedOut();
    } on ConsentRequiredException {
      ConsentService.instance.clear();
      if (!mounted) return;
      setState(() => _result = 'Please confirm your permission, then tap '
          'Reflect again.');
    } on ReflectionException catch (e) {
      if (!mounted) return;
      setState(() {
        _result = e.message;
        _canQuick = _mode == ReflectionMode.cloud;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _result = e.message;
        _canQuick = _mode == ReflectionMode.cloud;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = 'Something went wrong: $e';
        _canQuick = _mode == ReflectionMode.cloud;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }


  Future<bool> _ensureConsent() async {
    if (await ConsentService.instance.isGranted()) return true;
    if (!mounted) return false;
    final agreed = await showConsentSheet(context);
    if (!agreed) return false;
    await ConsentService.instance.grant();
    return true;
  }

  // Offline fallback: rule-based, no AI. Always labelled as basic.
  Future<void> _quick() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (ReflectionService.looksLikeCrisis(text)) {
      setState(() {
        _crisis = true;
        _result = null;
        _canQuick = false;
      });
      return;
    }

    final reply = await QuickReflectionEngine().reflect(text);
    if (!mounted) return;
    setState(() {
      _crisis = false;
      _result = reply.text;
      _quickUsed = true;
      _canQuick = false;
      _notice = null;
    });
    await _save(text, reply);
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
            if (_crisis) const SupportCard(),
            if (_quickUsed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Quick reflection: a basic, rule-based reply made on this '
                  'phone. It is not AI and not therapy.',
                  style: hint,
                ),
              ),
            if (_result != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(_result!),
                ),
              ),
            if (_canQuick) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _quick,
                icon: const Icon(Symbols.bolt_rounded),
                label: const Text('Get a quick reflection instead'),
              ),
              const SizedBox(height: 4),
              Text(
                'Basic, works offline, and your entry stays on this phone.',
                style: hint,
              ),
            ],
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
