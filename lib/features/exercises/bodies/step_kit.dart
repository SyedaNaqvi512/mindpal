import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/motion/motion.dart';
import '../services/exercise_controller.dart';
import '../widgets/safe_text_field.dart';
import 'exercise_content.dart';

/// Small building blocks shared by the exercises. Every exercise uses touch
/// controls (tap, slide, drag) and not only text boxes (FR-42), and none uses
/// points, levels, rankings, lives, penalties or failure messages (FR-43).

class Prompt extends StatelessWidget {
  const Prompt(this.text, {super.key, this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: muted
            ? TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.4)
            : Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
      ),
    );
  }
}

/// Tappable ideas, so nobody faces a blank page. Tapping one fills the answer,
/// which the user can then change.
class IdeaChips extends StatelessWidget {
  const IdeaChips({super.key, required this.options, required this.onPick, this.label});

  final List<String> options;
  final ValueChanged<String> onPick;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label ?? 'Not sure where to start? Tap an idea.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final o in options)
                ActionChip(
                  label: Text(o),
                  onPressed: () {
                    Motion.tap();
                    onPick(o);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the user wrote earlier in this exercise, shown back to them so each
/// step builds on the last.
class EchoCard extends StatelessWidget {
  const EchoCard({super.key, required this.c, required this.items});

  final ExerciseController c;

  /// Label to data key.
  final Map<String, String> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = <(String, String)>[];
    items.forEach((label, key) {
      final v = c.data[key];
      final t = v is List ? v.map((e) => '$e').join(', ') : '${v ?? ''}'.trim();
      if (t.isNotEmpty) lines.add((label, t));
    });
    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, text) in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text.rich(TextSpan(children: [
                TextSpan(
                    text: '$label: ',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                TextSpan(text: text, style: const TextStyle(fontWeight: FontWeight.w600)),
              ])),
            ),
        ],
      ),
    );
  }
}

/// A step with one free-text answer.
ExerciseStep textStep({
  required String title,
  required String prompt,
  required String key,
  String? hint,
  String? label,
  int maxLines = 4,
  List<String> ideas = const [],
  Map<String, String> echo = const {},
}) {
  return ExerciseStep(
    title: title,
    canContinue: (c) => c.text(key).trim().isNotEmpty,
    build: (context, c) {
      final n = c.intOf('_n_$key');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (echo.isNotEmpty) EchoCard(c: c, items: echo),
          Prompt(prompt),
          if (ideas.isNotEmpty && c.text(key).trim().isEmpty)
            IdeaChips(
              options: ideas,
              onPick: (s) {
                c.data['_n_$key'] = n + 1;
                c.set(key, s);
              },
            ),
          SafeTextField(
            key: ValueKey('$key-$n'),
            initial: c.text(key),
            label: label,
            hint: hint,
            maxLines: maxLines,
            onChanged: (v) => c.set(key, v),
          ),
        ],
      );
    },
  );
}

/// A step where the user taps one or more choices.
ExerciseStep chipsStep({
  required String title,
  required String prompt,
  required String key,
  required List<String> options,
  bool multi = true,
  String? note,
}) {
  return ExerciseStep(
    title: title,
    canContinue: (c) => c.list(key).isNotEmpty,
    build: (context, c) {
      final chosen = c.list(key);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Prompt(prompt),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                FilterChip(
                  label: Text(o),
                  selected: chosen.contains(o),
                  onSelected: (on) {
                    Motion.tap();
                    final next = multi ? List<String>.of(chosen) : <String>[];
                    if (on) {
                      next.add(o);
                    } else {
                      next.remove(o);
                    }
                    c.set(key, next);
                  },
                ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 12),
            Prompt(note, muted: true),
          ],
        ],
      );
    },
  );
}

/// A step with a 0 to 100 slider.
class SliderBlock extends StatelessWidget {
  const SliderBlock({
    super.key,
    required this.value,
    required this.onChanged,
    this.lowLabel = '0',
    this.highLabel = '100',
    this.showNumber = true,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String lowLabel;
  final String highLabel;
  final bool showNumber;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (showNumber)
          Text('$value',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lowLabel, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            Text(highLabel, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

ExerciseStep sliderStep({
  required String title,
  required String prompt,
  required String key,
  String lowLabel = '0',
  String highLabel = '100',
  bool showNumber = true,
}) {
  return ExerciseStep(
    title: title,
    canContinue: (c) => true,
    build: (context, c) {
      // The slider shows 50 at first, so 50 is the answer until it is moved.
      if (c.data[key] == null) c.data[key] = 50;
      return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Prompt(prompt),
        SliderBlock(
          value: c.intOf(key, 50),
          lowLabel: lowLabel,
          highLabel: highLabel,
          showNumber: showNumber,
          onChanged: (v) => c.set(key, v),
        ),
      ],
    );
    },
  );
}

/// Circles to tap, one for each thing noticed, with an optional note.
ExerciseStep tapStep({
  required String title,
  required String prompt,
  required String key,
  required int count,
  required String noun,
  String? noteLabel,
  List<String> cues = const [],
}) {
  return ExerciseStep(
    title: title,
    canContinue: (c) => c.intOf(key) >= count,
    build: (context, c) {
      final done = c.intOf(key);
      final scheme = Theme.of(context).colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Prompt(prompt),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              for (var i = 0; i < count; i++)
                Semantics(
                  button: true,
                  label: i < done
                      ? '$noun ${i + 1} noticed'
                      : 'Tap when you have noticed $noun ${i + 1}',
                  excludeSemantics: true,
                  child: InkResponse(
                    radius: 36,
                    onTap: () {
                      Motion.tap();
                      // Tapping the next circle counts one more; tapping a done
                      // circle takes it back, so a mis-tap is easy to fix.
                      c.set(key, i < done ? i : i + 1);
                    },
                    child: AnimatedContainer(
                      duration: Motion.of(context, const Duration(milliseconds: 200)),
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < done ? scheme.primary : Colors.transparent,
                        border: Border.all(color: scheme.primary, width: 2.5),
                      ),
                      child: i < done
                          ? Icon(Symbols.check_rounded, color: scheme.onPrimary)
                          : Text('${i + 1}',
                              style: TextStyle(
                                  color: scheme.primary, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            done >= count ? 'All $count noticed.' : '$done of $count noticed',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (done < count && done < cues.length) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Next: ${cues[done]}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onPrimaryContainer)),
            ),
          ],
          if (noteLabel != null) ...[
            const SizedBox(height: 16),
            SafeTextField(
              initial: c.text('${key}_note'),
              label: noteLabel,
              maxLines: 2,
              onChanged: (v) => c.setQuiet('${key}_note', v),
            ),
          ],
        ],
      );
    },
  );
}

/// A reading step, optionally with a gentle timer hint.
ExerciseStep infoStep({
  required String title,
  required String body,
  int? seconds,
  String? extra,
}) {
  return ExerciseStep(
    title: title,
    minSeconds: seconds == null ? null : (seconds * 0.8).round(),
    build: (context, c) {
      final scheme = Theme.of(context).colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Prompt(body),
          if (extra != null) Prompt(extra, muted: true),
          if (seconds != null) ...[
            const SizedBox(height: 8),
            Text('Take about $seconds seconds, then tap Next.',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (!Motion.reduced(context))
              TweenAnimationBuilder<double>(
                key: ValueKey('timer-${c.step}'),
                tween: Tween(begin: 0, end: 1),
                duration: Duration(seconds: seconds),
                builder: (context, v, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: v, minHeight: 6),
                ),
              ),
          ],
        ],
      );
    },
  );
}

/// A small list the user builds one item at a time (evidence, options, ...).
class ItemListEditor extends StatefulWidget {
  const ItemListEditor({
    super.key,
    required this.items,
    required this.onChanged,
    required this.label,
    this.hint,
    this.ideas = const [],
  });

  final List<String> ideas;
  final List<String> items;
  final ValueChanged<List<String>> onChanged;
  final String label;
  final String? hint;

  @override
  State<ItemListEditor> createState() => _ItemListEditorState();
}

class _ItemListEditorState extends State<ItemListEditor> {
  final _ctl = TextEditingController();

  void _add() {
    final t = _ctl.text.trim();
    if (t.isEmpty) return;
    Motion.tap();
    widget.onChanged([...widget.items, t]);
    _ctl.clear();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.ideas.where((i) => !widget.items.contains(i)).isNotEmpty)
          IdeaChips(
            options: [for (final i in widget.ideas) if (!widget.items.contains(i)) i],
            onPick: (s) => widget.onChanged([...widget.items, s]),
          ),
        SafeTextField(
          controller: _ctl,
          label: widget.label,
          hint: widget.hint,
          maxLines: 2,
          onChanged: (_) {},
          onSubmitted: (_) => _add(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: _add,
            icon: const Icon(Symbols.add_rounded),
            label: const Text('Add'),
          ),
        ),
        for (var i = 0; i < widget.items.length; i++)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: ListTile(
              dense: true,
              title: Text(widget.items[i]),
              trailing: IconButton(
                tooltip: 'Remove',
                icon: Icon(Symbols.close_rounded, color: scheme.onSurfaceVariant),
                onPressed: () {
                  final next = List<String>.of(widget.items)..removeAt(i);
                  widget.onChanged(next);
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// The first step of the thought-based exercises. The thought of a related
/// journal entry is offered only as a choice the user makes (FR-47).
ExerciseStep thoughtStep({
  String title = 'Your thought',
  String prompt = 'What thought is on your mind? Write it the way it sounds in your head.',
}) {
  return ExerciseStep(
    title: title,
    canContinue: (c) => c.text('thought').trim().isNotEmpty,
    build: (context, c) {
      final entry = c.entryText?.trim() ?? '';
      final asked = c.data['_prefillAsked'] == true;
      final n = c.intOf('_prefillN');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Prompt(prompt),
          if (entry.isNotEmpty && !asked)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Use the words from your journal entry?',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                      'This exercise can start from the entry you just wrote. '
                      'It stays on this phone, and you can edit it.',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () {
                            c.data['_prefillAsked'] = true;
                            c.data['_prefillN'] = n + 1;
                            c.set('thought',
                                entry.length > 500 ? entry.substring(0, 500) : entry);
                          },
                          child: const Text('Use it'),
                        ),
                        TextButton(
                          onPressed: () => c.set('_prefillAsked', true),
                          child: const Text('No thanks'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (entry.isNotEmpty && !asked) const SizedBox(height: 12),
          if (c.text('thought').trim().isEmpty)
            IdeaChips(
              label: 'Thoughts many people have. Tap one that feels close, then change it.',
              options: kCommonThoughts,
              onPick: (s) {
                c.data['_prefillN'] = n + 1;
                c.set('thought', s);
              },
            ),
          SafeTextField(
            key: ValueKey('thought-$n'),
            initial: c.text('thought'),
            label: 'My thought',
            maxLines: 5,
            onChanged: (v) => c.set('thought', v),
          ),
        ],
      );
    },
  );
}

/// The optional last step: a new balanced thought saved with the exercise and
/// with the related entry (FR-48).
ExerciseStep balancedStep() {
  return ExerciseStep(
    title: 'A balanced thought',
    build: (context, c) {
      final thought = c.text('thought').trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Prompt(
            'If you like, write a new thought that takes in everything you '
            'noticed. This is optional; you can skip it.',
          ),
          if (thought.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your original thought',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(thought),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          SafeTextField(
            initial: c.session.balancedThought ?? '',
            label: 'A new balanced thought',
            hint: 'For example: This is hard, and I can still take one small step.',
            maxLines: 4,
            onChanged: (v) {
              c.session.balancedThought = v;
              c.dirty = true;
            },
          ),
          const SizedBox(height: 8),
          Prompt(
            c.session.entryId != null
                ? 'It will be saved with your journal entry.'
                : 'It will be saved with this exercise in Exercise Progress.',
            muted: true,
          ),
        ],
      );
    },
  );
}
