import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/app_messages.dart';
import '../../../core/motion/motion.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/motion_kit.dart';
import '../../../core/widgets/toast.dart';
import '../../auth/services/auth_service.dart';
import '../../consent/services/consent_service.dart';
import '../../consent/widgets/consent_sheet.dart';
import '../../safety/widgets/support_card.dart';
import '../models/followup_logic.dart';
import '../services/followup_service.dart';
import '../services/reflection_service.dart';

/// "Talk it through": a short conversation about one entry, after its
/// reflection. Up to [maxFollowUps] questions. The AI sees the whole
/// conversation each time, so it remembers what was said.
class FollowUpChat extends StatefulWidget {
  const FollowUpChat({
    super.key,
    required this.entryId,
    required this.reflectionText,
    this.store = const DbChatStore(),
    this.client = const ApiFollowUpClient(),
    this.ensureConsent,
    this.isCrisis,
  });

  final int entryId;
  final String reflectionText;
  final ChatStore store;
  final FollowUpClient client;

  /// Replaceable in tests.
  final Future<bool> Function(BuildContext context)? ensureConsent;
  final bool Function(String text)? isCrisis;

  @override
  State<FollowUpChat> createState() => _FollowUpChatState();
}

class _FollowUpChatState extends State<FollowUpChat> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _endKey = GlobalKey();

  List<ChatMessage> _messages = const [];
  bool _loaded = false;
  bool _sending = false;
  String? _pending;
  String? _error;
  bool _safety = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    List<ChatMessage> items = const [];
    try {
      items = await widget.store.load(widget.entryId);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _messages = items;
      _loaded = true;
    });
  }

  Future<bool> _consent() async {
    final custom = widget.ensureConsent;
    if (custom != null) return custom(context);
    if (await ConsentService.instance.isGranted()) return true;
    if (!mounted) return false;
    final agreed = await showConsentSheet(context);
    if (!agreed || !mounted) return false;
    await ConsentService.instance.grant();
    return true;
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _endKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: Motion.of(context, const Duration(milliseconds: 250)),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    if (_sending) return;
    final text = (preset ?? _controller.text).trim();

    final problem = validateQuestion(text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (limitReached(_messages)) return;

    // The safety check runs on the phone first. Nothing is sent to the AI.
    final crisis = widget.isCrisis ?? ReflectionService.looksLikeCrisis;
    if (crisis(text)) {
      _controller.clear();
      setState(() {
        _safety = true;
        _error = null;
      });
      _scrollToEnd();
      return;
    }

    if (!await _consent()) {
      if (!mounted) return;
      setState(() => _error =
          'AI replies need your permission. Tap Send again to review it.');
      return;
    }
    if (!mounted) return;

    setState(() {
      _sending = true;
      _pending = text;
      _error = null;
      _controller.clear();
    });
    _scrollToEnd();

    try {
      final entry = await widget.store.entryText(widget.entryId) ?? '';
      final answer = await widget.client.ask(
        entry: entry,
        reflection: widget.reflectionText,
        history: historyPayload(_messages),
        message: text,
      );
      if (!mounted) return;

      if (answer.safety) {
        setState(() {
          _safety = true;
          _sending = false;
          _pending = null;
        });
        _scrollToEnd();
        return;
      }

      await widget.store.addPair(
        widget.entryId,
        user: text,
        assistant: answer.reply,
        suggestions: answer.suggestions,
      );
      final fresh = await widget.store.load(widget.entryId);
      if (!mounted) return;
      setState(() {
        _messages = fresh;
        _sending = false;
        _pending = null;
      });
      _scrollToEnd();
    } on SessionExpiredException {
      _fail(text, AppMessages.sessionExpired);
    } on FollowUpException catch (e) {
      _fail(text, e.message, reload: e.limitReached);
    } catch (_) {
      _fail(text, AppMessages.generic);
    }
  }

  /// A failed question does not use up one of the 10: the text goes back into
  /// the box so it can be sent again.
  void _fail(String text, String message, {bool reload = false}) {
    if (!mounted) return;
    setState(() {
      _sending = false;
      _pending = null;
      _error = message;
      _controller.text = text;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    });
    if (reload) _load();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this conversation?'),
        content: const Text(
          'The messages are removed from this phone. Your entry and '
          'reflection stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.store.clear(widget.entryId);
    if (!mounted) return;
    setState(() {
      _messages = const [];
      _error = null;
      _safety = false;
    });
    Toast.of(context, 'Conversation deleted.', kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final left = questionsLeft(_messages);
    final used = questionsUsed(_messages);
    final done = left == 0;
    final low = left <= 2 && !done;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Symbols.forum_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('Talk it through', style: text.titleMedium),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: low ? scheme.tertiaryContainer : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    done ? 'All $maxFollowUps used' : '$left of $maxFollowUps left',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                if (_messages.isNotEmpty)
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Symbols.more_vert_rounded),
                    onSelected: (v) {
                      if (v == 'delete') _delete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete conversation'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: used / maxFollowUps,
                minHeight: 4,
                backgroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 12),
            if (_messages.isEmpty && _pending == null)
              Text(
                'Reply to the reflection or ask a question. I will remember '
                'our whole conversation. You can ask up to $maxFollowUps '
                'questions about this entry.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            for (final m in _messages) _Bubble(message: m),
            if (_pending != null) _Bubble.pending(_pending!),
            if (_sending) const _Waiting(),
            if (_safety) ...[
              const SizedBox(height: 8),
              const SupportCard(),
              const SizedBox(height: 8),
              Text(
                'This conversation is paused. Please reach out to someone '
                'you trust.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              InlineMessage(_error!),
            ],
            SizedBox(key: _endKey, height: 1),
            if (done && !_safety)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InlineMessage(
                  'You have used all $maxFollowUps questions for this entry. '
                  'This is a good place to pause. To keep talking, start a '
                  'new entry. You can also try an exercise from the '
                  'Exercise Library.',
                  isError: false,
                ),
              ),
            if (!done && !_safety) ...[
              if (!_sending)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in suggestionsFor(_messages))
                        ActionChip(
                          label: Text(s),
                          onPressed: () => _send(s),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              _Input(
                controller: _controller,
                focus: _focus,
                enabled: !_sending,
                onSend: _send,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'AI support, not therapy. Replies can be wrong. Saved on this '
              'phone, encrypted.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.focus,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final canSend = enabled && value.text.trim().isNotEmpty;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focus,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                maxLength: maxChatMessageChars,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    currentLength > 400
                        ? Text('$currentLength/$maxLength')
                        : null,
                decoration: const InputDecoration(
                  hintText: 'Write your reply or question',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IconButton.filled(
                tooltip: 'Send',
                onPressed: canSend ? onSend : null,
                icon: const Icon(Symbols.send_rounded),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message}) : pending = false;
  _Bubble.pending(String text)
      : message = ChatMessage(role: 'user', content: text, createdAt: DateTime.now()),
        pending = true;

  final ChatMessage message;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = message.isUser;
    final fg = user ? scheme.onPrimary : scheme.onSurface;
    final bg = user ? scheme.primary : scheme.surfaceContainerHighest;

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: pending ? bg.withValues(alpha: 0.7) : bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(user ? 18 : 4),
          bottomRight: Radius.circular(user ? 4 : 18),
        ),
      ),
      child: ChatText(message.content, color: fg),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!user) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: scheme.primaryContainer,
              child: Icon(Symbols.spa_rounded, size: 16, color: scheme.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
              ),
              child: Semantics(
                label: user ? 'You said' : 'MindPal said',
                child: GestureDetector(
                  onLongPress: () async {
                    await Clipboard.setData(
                      ClipboardData(text: plainChatText(message.content)),
                    );
                    if (context.mounted) {
                      Toast.of(context, 'Copied.', kind: ToastKind.info);
                    }
                  },
                  child: bubble,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The AI's answer with simple formatting: paragraphs, bullets and bold.
class ChatText extends StatelessWidget {
  const ChatText(this.text, {super.key, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(color: color, height: 1.45);

    TextSpan spans(String s) => TextSpan(
          children: [
            for (final p in parseSpans(s))
              TextSpan(
                text: p.text,
                style: p.bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
              ),
          ],
        );

    final blocks = parseChatBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: blocks[i].bullet
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, right: 8),
                        child: Text('•', style: base),
                      ),
                      Expanded(
                        child: Text.rich(spans(blocks[i].text), style: base),
                      ),
                    ],
                  )
                : Text.rich(spans(blocks[i].text), style: base),
          ),
      ],
    );
  }
}

/// A typing indicator whose message changes while the answer is written.
class _Waiting extends StatefulWidget {
  const _Waiting();

  @override
  State<_Waiting> createState() => _WaitingState();
}

class _WaitingState extends State<_Waiting> {
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = followUpWaitMessage(_seconds);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const TypingDots(size: 6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: AnimatedSwitcher(
                duration: Motion.of(context, const Duration(milliseconds: 300)),
                child: Text(
                  message,
                  key: ValueKey(message),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
