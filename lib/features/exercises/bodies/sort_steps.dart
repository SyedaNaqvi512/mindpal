import 'package:flutter/material.dart';

import '../../../core/motion/motion.dart';
import '../models/exercise_logic.dart';
import '../services/exercise_controller.dart';
import 'step_kit.dart';

/// FR-36: Facts vs Assumptions Sort.
/// Cards are dragged (press and hold, then drag) into Fact or Assumption. Tapping
/// a card opens a small menu as an alternative to dragging.

const _fact = 'fact';
const _assumption = 'assumption';

/// Splits the thought into cards once, and again if the thought was changed.
void _ensureCards(ExerciseController c) {
  final thought = c.text('thought');
  if (c.data['cards_for'] != thought || c.data['cards'] is! List) {
    c.data['cards'] = splitThought(thought);
    c.data['cards_for'] = thought;
    c.data['place'] = <String, dynamic>{};
  }
}

Map<String, String> _places(ExerciseController c) {
  final raw = c.data['place'];
  if (raw is! Map) return {};
  return {for (final e in raw.entries) '${e.key}': '${e.value}'};
}

void _place(ExerciseController c, int index, String? where) {
  final p = _places(c);
  if (where == null) {
    p.remove('$index');
  } else {
    p['$index'] = where;
  }
  c.set('place', p);
}

({int facts, int assumptions, int unsorted}) sortCounts(ExerciseController c) {
  final cards = c.list('cards');
  final p = _places(c);
  var f = 0, a = 0;
  for (var i = 0; i < cards.length; i++) {
    final w = p['$i'];
    if (w == _fact) f++;
    if (w == _assumption) a++;
  }
  return (facts: f, assumptions: a, unsorted: cards.length - f - a);
}

ExerciseStep sortStep() {
  return ExerciseStep(
    title: 'Sort the statements',
    canContinue: (c) {
      _ensureCards(c);
      final n = sortCounts(c);
      return n.facts + n.assumptions > 0;
    },
    build: (context, c) {
      _ensureCards(c);
      final cards = c.list('cards');
      final p = _places(c);
      final scheme = Theme.of(context).colorScheme;

      if (cards.isEmpty) {
        return const Prompt(
            'There is nothing to sort because no thought was written. You can '
            'skip this step or go back and write one.');
      }

      Widget chip(int i, {bool dragging = false}) {
        return Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outline),
              boxShadow: dragging
                  ? [BoxShadow(color: scheme.shadow.withValues(alpha: 0.2), blurRadius: 8)]
                  : null,
            ),
            child: Text(cards[i]),
          ),
        );
      }

      Future<void> choose(int i) async {
        final where = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(cards[i], style: Theme.of(ctx).textTheme.bodyLarge),
                ),
                ListTile(
                  title: const Text('Fact'),
                  subtitle: const Text('Something I can observe or check'),
                  onTap: () => Navigator.of(ctx).pop(_fact),
                ),
                ListTile(
                  title: const Text('Assumption'),
                  subtitle: const Text('Something I am guessing or interpreting'),
                  onTap: () => Navigator.of(ctx).pop(_assumption),
                ),
                if (p['$i'] != null)
                  ListTile(
                    title: const Text('Back to unsorted'),
                    onTap: () => Navigator.of(ctx).pop('none'),
                  ),
              ],
            ),
          ),
        );
        if (where == null) return;
        _place(c, i, where == 'none' ? null : where);
      }

      Widget draggable(int i) {
        return LongPressDraggable<int>(
          data: i,
          delay: const Duration(milliseconds: 120),
          feedback: chip(i, dragging: true),
          childWhenDragging: Opacity(opacity: 0.3, child: chip(i)),
          child: GestureDetector(
            onTap: () => choose(i),
            child: chip(i),
          ),
        );
      }

      Widget zone({
        required String title,
        required String subtitle,
        required String? where,
        required Color color,
      }) {
        final inside = [
          for (var i = 0; i < cards.length; i++)
            if (p['$i'] == where) i,
        ];
        return DragTarget<int>(
          onWillAcceptWithDetails: (d) => true,
          onAcceptWithDetails: (d) {
            Motion.tap();
            _place(c, d.data, where);
          },
          builder: (context, candidate, rejected) {
            final hot = candidate.isNotEmpty;
            return AnimatedContainer(
              duration: Motion.of(context, const Duration(milliseconds: 150)),
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 96),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: hot ? 0.45 : 0.22),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color, width: hot ? 2.5 : 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final i in inside) draggable(i)],
                  ),
                ],
              ),
            );
          },
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Prompt(
            'Press and hold a statement, then drag it into Fact or Assumption. '
            'You can also tap a statement to choose. There are no right or wrong '
            'answers.',
          ),
          zone(
            title: 'Statements',
            subtitle: 'Not sorted yet',
            where: null,
            color: scheme.outline,
          ),
          const SizedBox(height: 12),
          zone(
            title: 'Fact',
            subtitle: 'I can observe or check this',
            where: _fact,
            color: scheme.primary,
          ),
          const SizedBox(height: 12),
          zone(
            title: 'Assumption',
            subtitle: 'I am guessing or interpreting this',
            where: _assumption,
            color: scheme.tertiary,
          ),
        ],
      );
    },
  );
}

ExerciseStep sortSummaryStep() {
  return ExerciseStep(
    title: 'What you placed',
    build: (context, c) {
      _ensureCards(c);
      final cards = c.list('cards');
      final p = _places(c);
      final n = sortCounts(c);

      List<Widget> group(String label, String? where) {
        final items = [
          for (var i = 0; i < cards.length; i++)
            if (p['$i'] == where) cards[i],
        ];
        if (items.isEmpty) return const [];
        return [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          for (final t in items) Text('• $t'),
        ];
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Prompt(sortSummary(
              facts: n.facts, assumptions: n.assumptions, unsorted: n.unsorted)),
          ...group('Fact', _fact),
          ...group('Assumption', _assumption),
          ...group('Not sorted', null),
        ],
      );
    },
  );
}
