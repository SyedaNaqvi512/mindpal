import 'dart:math';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../../auth/services/auth_service.dart';
import '../../consent/services/consent_service.dart';
import '../../consent/widgets/consent_sheet.dart';
import '../../safety/widgets/support_card.dart';
import '../models/mood.dart';
import '../services/cloud_reflection_engine.dart';
import '../services/quick_reflection_engine.dart';
import '../services/reflection_engine.dart';
import '../services/reflection_service.dart';
import '../widgets/mood_picker.dart';

enum ReflectionMode { cloud, onDevice }

/// Write a new entry, or edit an existing one when [editId] is given.
class NewEntryScreen extends StatefulWidget {
  const NewEntryScreen({super.key, required this.onSignedOut, this.editId});

  final VoidCallback onSignedOut;
  final int? editId;

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  static const _maxLength = 5000;

  final _controller = TextEditingController();
  final ReflectionEngine _cloudEngine = CloudReflectionEngine();
  final ReflectionEngine _deviceEngine = ReflectionService();
  final SpeechToText _speech = SpeechToText();

  ReflectionMode _mode = ReflectionMode.cloud;
  String? _result;
  String? _notice;
  bool _crisis = false;
  bool _loading = false;
  bool _canQuick = false; // cloud failed: offer the offline Quick reflection
  bool _quickUsed = false;
  bool _moodMissing = false;
  bool _opening = false; // loading an entry to edit
  bool _speechReady = false;
  bool _listening = false;
  String _dictationBase = '';
  int? _mood; // null until the user chooses (FR-10: required)
  final Set<String> _tags = {};
  int? _savedId; // set once the entry is stored on the phone

  bool get _editing => widget.editId != null;

  ReflectionEngine get _engine =>
      _mode == ReflectionMode.cloud ? _cloudEngine : _deviceEngine;

  @override
  void initState() {
    super.initState();
    _savedId = widget.editId;
    _controller.addListener(() => setState(() {}));
    if (_editing) _openForEdit();
  }

  Future<void> _openForEdit() async {
    setState(() => _opening = true);
    try {
      final row = await DatabaseService.getEntry(widget.editId!);
      if (!mounted) return;
      if (row == null) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _controller.text = row['content'] as String;
        _mood = row['mood'] as int;
        _tags
          ..clear()
          ..addAll(FeelingTags.parse(row['tags']));
      });
    } catch (_) {
      if (mounted) setState(() => _notice = 'Could not open this entry.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  // ---- voice dictation (FR-11, FR-12) ------------------------------------
  // The phone's speech recognition turns speech into text. MindPal never
  // records or stores audio: only the text appears in the editor.

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_speechReady) {
      try {
        _speechReady = await _speech.initialize(
          onError: (_) {
            if (mounted) setState(() => _listening = false);
          },
          onStatus: (s) {
            if (mounted && (s == 'done' || s == 'notListening')) {
              setState(() => _listening = false);
            }
          },
        );
      } catch (_) {
        _speechReady = false;
      }
      if (!_speechReady) {
        if (mounted) {
          setState(() => _notice = 'Voice input is not available. Check that '
              'microphone permission is allowed and speech recognition is '
              'installed on this phone.');
        }
        return;
      }
    }
    _dictationBase = _controller.text.trimRight();
    setState(() {
      _listening = true;
      _notice = null;
    });
    await _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        final words = r.recognizedWords;
        var text = _dictationBase.isEmpty ? words : '$_dictationBase $words';
        if (text.length > _maxLength) text = text.substring(0, _maxLength);
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: min(text.length, _maxLength)),
        );
      },
            listenOptions: SpeechListenOptions(
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _stopMic() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
    }
  }

  // ---- saving -------------------------------------------------------------

  /// Stores the entry on the phone (insert the first time, update after).
  /// Returns the entry id, or null when something is missing.
  Future<int?> _persist() async {
    await _stopMic();
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _notice = 'Write a few words first.');
      return null;
    }
    if (_mood == null) {
      setState(() => _moodMissing = true);
      return null;
    }
    try {
      final tags = _tags.toList()..sort();
      if (_savedId == null) {
        _savedId = await DatabaseService.insertJournalEntry(
            content: text, mood: _mood!, tags: tags);
      } else {
        await DatabaseService.updateEntry(
            id: _savedId!, content: text, mood: _mood!, tags: tags);
      }
      entriesChanged.value++;
      return _savedId;
    } catch (_) {
      if (mounted) {
        setState(() => _notice = 'The entry could not be saved on this phone.');
      }
      return null;
    }
  }

  Future<void> _saveOnly() async {
    final id = await _persist();
    if (id == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final editing = _editing;
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text(editing ? 'Changes saved.' : 'Entry saved on this phone.'),
    ));
  }

  // ---- reflection ---------------------------------------------------------

  Future<void> _reflect() async {
    final id = await _persist();
    if (id == null) return;
    final text = _controller.text.trim();

    // Safety check runs first, on the device, before any AI is used.
    if (ReflectionService.looksLikeCrisis(text)) {
      setState(() {
        _crisis = true;
        _result = null;
        _notice = 'Your entry is saved on this phone.';
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
              'or get a quick reflection on this phone instead. '
              'Your entry is already saved.';
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
      await _saveReflection(id, reply);
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
    final id = await _persist();
    if (id == null) return;
    final text = _controller.text.trim();

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
    await _saveReflection(id, reply);
  }

  // The journal text stays on the phone, in the encrypted database.
  Future<void> _saveReflection(int entryId, ReflectionResult reply) async {
    try {
      await DatabaseService.replaceReflection(
        entryId: entryId,
        text: reply.text,
        thinkingPattern: reply.pattern,
        serverReflectionId: reply.serverId,
      );
      entriesChanged.value++;
      if (mounted) setState(() => _notice = 'Saved on this phone.');
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
    _speech.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hint = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    final busy = _loading || _opening;
    final showPrompts = !_editing && _controller.text.isEmpty && !_listening;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit entry' : 'New entry'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: busy ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: _opening
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showPrompts) ...[
                    Text('Need a starting point? (optional)', style: hint),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final p in StarterPrompts.all)
                          ActionChip(
                            label: Text(p),
                            onPressed: () {
                              _controller.value = TextEditingValue(
                                text: '${p.replaceAll('…', '').trimRight()} ',
                                selection: TextSelection.collapsed(
                                    offset:
                                        '${p.replaceAll('…', '').trimRight()} '
                                            .length),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _controller,
                    maxLines: 7,
                    maxLength: _maxLength,
                    readOnly: _listening,
                    decoration: InputDecoration(
                      hintText: 'How was your day? What is on your mind?',
                      suffixIcon: IconButton(
                        tooltip: _listening ? 'Stop dictation' : 'Dictate',
                        icon: Icon(
                          _listening
                              ? Symbols.stop_circle_rounded
                              : Symbols.mic_rounded,
                          color: _listening ? scheme.error : null,
                        ),
                        onPressed: busy ? null : _toggleMic,
                      ),
                    ),
                  ),
                  if (_listening)
                    Text('Listening… speak, then tap stop. You can correct the '
                        'text before saving.', style: hint)
                  else
                    Text(
                      'Voice is turned into text by your phone. MindPal does '
                      'not save any audio.',
                      style: hint,
                    ),
                  const SizedBox(height: 16),
                  Text('How do you feel?',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  MoodPicker(
                    value: _mood,
                    enabled: !busy,
                    onChanged: (v) => setState(() {
                      _mood = v;
                      _moodMissing = false;
                    }),
                  ),
                  if (_moodMissing)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Please choose how you feel.',
                          style: TextStyle(color: scheme.error)),
                    ),
                  const SizedBox(height: 16),
                  Text('Feelings (optional)',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final t in FeelingTags.all)
                        FilterChip(
                          label: Text(t),
                          selected: _tags.contains(t),
                          onSelected: busy
                              ? null
                              : (on) => setState(
                                  () => on ? _tags.add(t) : _tags.remove(t)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: busy ? null : _saveOnly,
                      icon: const Icon(Symbols.check_rounded),
                      label: Text(_editing ? 'Save changes' : 'Save entry'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Want a gentle reflection too?',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
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
                    onSelectionChanged: busy
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
                    style: hint,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: busy ? null : _reflect,
                    child: const Text('Save and reflect'),
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
                        'Quick reflection: a basic, rule-based reply made on '
                        'this phone. It is not AI and not therapy.',
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
                      onPressed: busy ? null : _quick,
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
                  if (_savedId != null && !_loading && !_editing)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
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
