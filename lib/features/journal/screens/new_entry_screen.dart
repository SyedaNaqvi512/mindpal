import 'dart:math';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/breathing_circle.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/mood_face.dart';
import '../../../core/widgets/pulse_ring.dart';
import '../../auth/services/auth_service.dart';
import '../../consent/services/consent_service.dart';
import '../../consent/widgets/consent_sheet.dart';
import '../../safety/widgets/support_card.dart';
import '../models/entry_format.dart';
import '../models/mood.dart';
import '../services/cloud_reflection_engine.dart';
import '../services/quick_reflection_engine.dart';
import '../services/reflection_engine.dart';
import '../services/reflection_service.dart';
import '../widgets/reflection_panel.dart';

enum ReflectionMode { cloud, onDevice }

/// Write a new entry, or edit an existing one when [editId] is given.
class NewEntryScreen extends StatefulWidget {
  const NewEntryScreen({
    super.key,
    required this.onSignedOut,
    this.editId,
    this.initialMood,
    this.initialText,
  });

  final VoidCallback onSignedOut;
  final int? editId;

  /// A mood chosen on Home (1-5) and text started from a prompt.
  final int? initialMood;
  final String? initialText;

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
  bool _canQuick = false;
  bool _canRetry = false;
  bool _showPanel = false;
  int _panelVersion = 0;
  bool _moodMissing = false;
  bool _opening = false;
  bool _speechReady = false;
  bool _listening = false;
  String _dictationBase = '';
  int? _mood;
  final Set<String> _tags = {};
  bool _promptsOpen = false;
  final GlobalKey _resultKey = GlobalKey();
  int? _savedId;

  bool get _editing => widget.editId != null;

  ReflectionEngine get _engine =>
      _mode == ReflectionMode.cloud ? _cloudEngine : _deviceEngine;

  @override
  void initState() {
    super.initState();
    _savedId = widget.editId;
    _showPanel = widget.editId != null;
    _mood = widget.initialMood;
    final start = widget.initialText;
    if (start != null && start.isNotEmpty) {
      _controller.value = TextEditingValue(
        text: start,
        selection: TextSelection.collapsed(offset: start.length),
      );
    }
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
          setState(
            () => _notice =
                'Voice input is not available. Check that '
                'microphone permission is allowed and speech recognition is '
                'installed on this phone.',
          );
        }
        return;
      }
    }
    if (!mounted) return;

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
          selection: TextSelection.collapsed(
            offset: min(text.length, _maxLength),
          ),
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

    // The screen might have been closed while stopping speech recognition.
    if (!mounted) return null;

    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _notice = 'Write a few words first.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Write a few words first.')));
      return null;
    }
    if (_mood == null) {
      setState(() => _moodMissing = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose how you feel.')),
      );
      return null;
    }
    try {
      final tags = _tags.toList()..sort();
      if (_savedId == null) {
        _savedId = await DatabaseService.insertJournalEntry(
          content: text,
          mood: _mood!,
          tags: tags,
        );
      } else {
        await DatabaseService.updateEntry(
          id: _savedId!,
          content: text,
          mood: _mood!,
          tags: tags,
        );
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
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          editing ? 'Changes saved.' : 'Entry saved on this phone.',
        ),
      ),
    );
  }

  // ---- reflection ---------------------------------------------------------

  Future<void> _reflect() async {
    final id = await _persist();
    if (id == null || !mounted) return;
    final text = _controller.text.trim();

    // Safety check runs first, on the device, before any AI is used.
    if (ReflectionService.looksLikeCrisis(text)) {
      setState(() {
        _crisis = true;
        _result = null;
        _notice = 'Your entry is saved on this phone.';
      });
      _scrollToResult();
      return;
    }

    setState(() {
      _crisis = false;
      _loading = true;
      _result = null;
      _notice = null;
      _canQuick = false;
      _canRetry = false;
    });
    _scrollToResult();

    try {
      // FR-17: before the first cloud AI use, explain and ask for consent.
      if (_mode == ReflectionMode.cloud && !await _ensureConsent()) {
        if (!mounted) return;
        setState(() {
          _result =
              'Cloud reflections need your permission to send this '
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

      await _saveReflection(
        id,
        reply,
        _mode == ReflectionMode.cloud ? 'cloud' : 'device',
      );
    } on SessionExpiredException {
      ConsentService.instance.clear();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      widget.onSignedOut();
    } on ConsentRequiredException {
      ConsentService.instance.clear();
      if (!mounted) return;
      setState(
        () => _result =
            'Please confirm your permission, then tap '
            'Reflect again.',
      );
    } on ReflectionException catch (e) {
      if (!mounted) return;
      setState(() {
        _result = e.message;
        _canRetry = e.canRetry;
        _canQuick = _mode == ReflectionMode.cloud;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _result = e.message;
        _canRetry = true;
        _canQuick = _mode == ReflectionMode.cloud;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _result =
            'Something went wrong. Your entry is saved. Please try again.';
        _canRetry = true;
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
    if (!agreed || !mounted) return false;
    await ConsentService.instance.grant();
    return true;
  }

  // Offline fallback: rule-based, no AI. Always labelled as basic.
  Future<void> _quick() async {
    final id = await _persist();
    if (id == null || !mounted) return;
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
      _result = null;
      _canQuick = false;
      _canRetry = false;
      _notice = null;
    });
    await _saveReflection(id, reply, 'quick');
  }

  // The journal text stays on the phone, in the encrypted database.
  // The reflection starts as a draft until the user accepts, edits or dismisses it.
  Future<void> _saveReflection(
    int entryId,
    ReflectionResult reply,
    String source,
  ) async {
    try {
      await DatabaseService.replaceReflection(
        entryId: entryId,
        text: reply.text,
        thinkingPattern: reply.pattern,
        serverReflectionId: reply.serverId,
        partsJson: reply.parts?.encode(),
        source: source,
        status: 'draft',
      );
      entriesChanged.value++;
      if (mounted) {
        setState(() {
          _showPanel = true;
          _panelVersion++;
          _notice = null;
        });
        _scrollToResult();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice = 'The reflection could not be saved on this phone.',
        );
      }
    }
  }

  /// Scrolls down to the reflection area once it has appeared.
  void _scrollToResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultKey.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: Motion.of(context, AppTokens.motionSlow),
        curve: Curves.easeOutCubic,
        alignment: 0.04,
      );
    });
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
    final text = Theme.of(context).textTheme;
    final hint = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    final busy = _loading || _opening;
    final showPrompts = !_editing && _controller.text.isEmpty && !_listening;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit entry' : 'New entry'),
        leading: IconButton(
          tooltip: _editing ? 'Back' : 'Close',
          icon: Icon(
            _editing ? Symbols.arrow_back_rounded : Symbols.close_rounded,
          ),
          onPressed: busy ? null : () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${weekdayShort(now)}, ${formatShortDate(now)}',
                style: hint,
              ),
            ),
          ),
        ],
      ),
      body: _opening
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeSlideIn(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'How are you feeling?',
                                          style: text.titleMedium,
                                        ),
                                      ),
                                      Text(
                                        _mood == null ? 'required' : '',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _moodMissing
                                              ? scheme.error
                                              : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  MoodFaceRow(
                                    value: _mood,
                                    enabled: !busy,
                                    size: 44,
                                    onChanged: (v) => setState(() {
                                      _mood = v;
                                      _moodMissing = false;
                                    }),
                                  ),
                                  if (_moodMissing)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Please choose how you feel.',
                                        style: TextStyle(color: scheme.error),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 60),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showPrompts)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () => setState(
                                          () => _promptsOpen = !_promptsOpen,
                                        ),
                                        icon: const Icon(
                                          Symbols.lightbulb_rounded,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Need a starting point?',
                                        ),
                                      ),
                                    ),
                                  if (showPrompts && _promptsOpen)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          for (final p in StarterPrompts.all)
                                            ActionChip(
                                              label: Text(p),
                                              onPressed: () {
                                                final start =
                                                    StarterPrompts.asStart(p);
                                                _controller
                                                    .value = TextEditingValue(
                                                  text: start,
                                                  selection:
                                                      TextSelection.collapsed(
                                                        offset: start.length,
                                                      ),
                                                );
                                                setState(
                                                  () => _promptsOpen = false,
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  TextField(
                                    controller: _controller,
                                    minLines: 6,
                                    maxLines: 12,
                                    maxLength: _maxLength,
                                    readOnly: _listening,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    buildCounter:
                                        (
                                          context, {
                                          required currentLength,
                                          required isFocused,
                                          required maxLength,
                                        }) {
                                          if (currentLength <= 4000) {
                                            return null;
                                          }
                                          return Text(
                                            '$currentLength / $maxLength',
                                            style: hint,
                                          );
                                        },
                                    decoration: const InputDecoration(
                                      hintText: 'Write what is on your mind…',
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                  const Divider(),
                                  Row(
                                    children: [
                                      PulseRing(
                                        active: _listening,
                                        size: 48,
                                        child: Material(
                                          color: _listening
                                              ? scheme.error
                                              : scheme.primary,
                                          shape: const CircleBorder(),
                                          child: IconButton(
                                            tooltip: _listening
                                                ? 'Stop dictation'
                                                : 'Dictate',
                                            color: scheme.onPrimary,
                                            icon: Icon(
                                              _listening
                                                  ? Symbols.stop_circle_rounded
                                                  : Symbols.mic_rounded,
                                            ),
                                            onPressed: busy ? null : _toggleMic,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _listening
                                                  ? 'Listening… tap to stop'
                                                  : 'Tap to dictate',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: scheme.primary,
                                              ),
                                            ),
                                            Text(
                                              'Your phone turns speech into text. '
                                              'MindPal saves no audio.',
                                              style: hint,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Feeling tags (optional)',
                                style: text.titleSmall,
                              ),
                              const SizedBox(height: 8),
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
                                              () => on
                                                  ? _tags.add(t)
                                                  : _tags.remove(t),
                                            ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 180),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Symbols.psychology_alt_rounded,
                                        color: scheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Gentle reflection',
                                        style: text.titleMedium,
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
                                        label: Text('On this phone'),
                                        icon: Icon(Symbols.smartphone_rounded),
                                      ),
                                    ],
                                    selected: {_mode},
                                    onSelectionChanged: busy
                                        ? null
                                        : (selection) => setState(
                                            () => _mode = selection.first,
                                          ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Symbols.shield_lock_rounded,
                                        size: 18,
                                        color: scheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _mode == ReflectionMode.cloud
                                              ? 'Your entry is checked for safety on this '
                                                    'phone first. It is sent to an AI service '
                                                    'only after you agree.'
                                              : 'On-device mode keeps your entry on this '
                                                    'phone. It needs the model file and can '
                                                    'be slower.',
                                          style: hint,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Column(
                          key: _resultKey,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_loading)
                              const Padding(
                                padding: EdgeInsets.only(top: 16),
                                child: Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Center(
                                      child: BreathingCircle(
                                        label:
                                            'Reflecting gently… the first reply '
                                            'can take up to a minute.',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_crisis)
                              const Padding(
                                padding: EdgeInsets.only(top: 16),
                                child: SupportCard(),
                              ),
                            if (_result != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: SelectableText(_result!),
                                  ),
                                ),
                              ),
                            if (_canRetry) ...[
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: busy ? null : _reflect,
                                icon: const Icon(Symbols.refresh_rounded),
                                label: const Text('Try again'),
                              ),
                            ],
                            if (_showPanel && _savedId != null && !_loading)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: ReflectionPanel(
                                  entryId: _savedId!,
                                  version: _panelVersion,
                                ),
                              ),
                            if (_canQuick) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: busy ? null : _quick,
                                icon: const Icon(Symbols.bolt_rounded),
                                label: const Text(
                                  'Get a quick reflection instead',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Basic, works offline, and your entry stays on this phone.',
                                style: hint,
                              ),
                            ],
                            if (_notice != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: InlineMessage(_notice!, isError: false),
                              ),
                            if (_savedId != null && !_loading && !_editing)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Done'),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'MindPal is a reflection tool, not a therapist or medical advice.',
                          style: hint,
                        ),
                      ],
                    ),
                  ),
                ),
                Material(
                  color: scheme.surface,
                  elevation: 8,
                  shadowColor: scheme.primary.withValues(alpha: 0.3),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: busy ? null : _saveOnly,
                              child: Text(_editing ? 'Save changes' : 'Save'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: busy ? null : _reflect,
                              icon: const Icon(
                                Symbols.auto_awesome_rounded,
                                size: 20,
                              ),
                              label: const Text('Save & reflect'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
