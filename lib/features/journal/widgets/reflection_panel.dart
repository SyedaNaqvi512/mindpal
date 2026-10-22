import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/database_service.dart';
import '../../../core/entries_changes.dart';
import '../../auth/services/auth_service.dart';
import '../models/thinking_patterns.dart';
import '../services/reflection_engine.dart';

const _reasons = <String, String>{
  'not_relevant': 'Not relevant',
  'too_generic': 'Too generic',
  'felt_wrong': 'Felt wrong',
  'too_long': 'Too long',
  'other': 'Other',
};

/// Shows the saved reflection of one entry in its five parts and lets the user
/// accept, edit or dismiss a draft (FR-23) and rate it (FR-24). Every
/// reflection is labelled as support, not therapy (FR-22).
class ReflectionPanel extends StatefulWidget {
  const ReflectionPanel({super.key, required this.entryId, this.version = 0});

  final int entryId;

  /// Change this number to make the panel reload (after a new reflection).
  final int version;

  @override
  State<ReflectionPanel> createState() => _ReflectionPanelState();
}

class _ReflectionPanelState extends State<ReflectionPanel> {
  Map<String, dynamic>? _r;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ReflectionPanel old) {
    super.didUpdateWidget(old);
    if (old.version != widget.version || old.entryId != widget.entryId) _load();
  }

  Future<void> _load() async {
    try {
      final r = await DatabaseService.getReflection(widget.entryId);
      if (!mounted) return;
      setState(() {
        _r = r;
        _loaded = true;
      });
      // A rating that could not be sent earlier is sent now, quietly.
      if (r != null &&
          r['rating'] != null &&
          r['rating_sent'] == 0 &&
          r['server_reflection_id'] != null) {
        _send(r['rating'] as String, r['rating_reason'] as String?);
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<bool> _send(String rating, String? reason) async {
    final id = _r?['server_reflection_id'] as String?;
    if (id == null) return false;
    try {
      final res = await AuthService.instance.authorizedPost(
        '/reflections/$id/feedback',
               {'rating': rating, 'reasonCode': ?reason},
      );
      if (res.statusCode == 204 || res.statusCode == 200) {
        await DatabaseService.markRatingSent(widget.entryId);
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _accept() async {
    await DatabaseService.acceptReflection(widget.entryId);
    entriesChanged.value++;
    await _load();
    if (mounted) _snack('Reflection saved with your entry.');
  }

  Future<void> _dismiss() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dismiss this reflection?'),
        content: const Text('The draft will be deleted. Your entry stays.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Dismiss')),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseService.deleteReflection(widget.entryId);
    entriesChanged.value++;
    await _load();
  }

  Future<void> _edit() async {
    final controller =
        TextEditingController(text: (_r?['reflection_text'] as String?) ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit reflection'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          minLines: 5,
          maxLength: 3000,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    await DatabaseService.editReflection(widget.entryId, text);
    entriesChanged.value++;
    await _load();
  }

  Future<void> _rate(String rating) async {
    String? reason;
    if (rating == 'not_helpful') {
      reason = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What was wrong? (optional)',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in _reasons.entries)
                      ActionChip(
                        label: Text(e.value),
                        onPressed: () => Navigator.of(ctx).pop(e.key),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(''),
                    child: const Text('Skip')),
                Text('Only your rating is sent. Your entry text is not.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
      if (reason == null) return; // closed the sheet: no rating
      if (reason.isEmpty) reason = null;
    }
    await DatabaseService.setReflectionRating(widget.entryId,
        rating: rating, reason: reason);
    await _load();
    final sent = await _send(rating, reason);
    if (!mounted) return;
    _snack(sent || _r?['server_reflection_id'] == null
        ? 'Thanks for your feedback.'
        : 'Thanks. Your rating is saved and will be sent when possible.');
    await _load();
  }

  String _label(String? source) => switch (source) {
        'cloud' => 'AI-generated support, not therapy.',
        'device' => 'AI-generated on this phone. Support, not therapy.',
        'quick' => 'Basic reflection made on this phone. It is not AI and '
            'not therapy.',
        _ => 'Support only, not therapy.',
      };

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    final r = _r;

    if (r == null) {
      return Text(
        'No reflection saved for this entry. You can add one with '
        'Save and reflect.',
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }

    final draft = r['status'] == 'draft';
    final edited = r['edited'] == 1;
    final parts = edited ? null : ReflectionParts.decode(r['parts_json'] as String?);
    final rating = r['rating'] as String?;

    Widget section(String title, Widget body) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: text.labelLarge?.copyWith(color: scheme.primary)),
              const SizedBox(height: 4),
              body,
            ],
          ),
        );

    Widget structured(ReflectionParts p) {
      final name = ThinkingPatterns.nameOf(p.pattern);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(p.acknowledgement),
          if (name != null)
            section(
              'A pattern that might be showing up',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (p.patternNote != null) SelectableText(p.patternNote!),
                  const SizedBox(height: 4),
                  Text(
                    'This is only a suggestion, not a diagnosis.',
                    style: muted,
                  ),
                ],
              ),
            ),
          if (p.questions.isNotEmpty)
            section(
              'Questions to try',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final q in p.questions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: SelectableText('• $q'),
                    ),
                ],
              ),
            ),
          if (p.balanced.isNotEmpty)
            section('A more balanced thought', SelectableText(p.balanced)),
          if (p.nextStep.isNotEmpty)
            section('One small next step', SelectableText(p.nextStep)),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Reflection', style: text.titleMedium)),
                Chip(
                  label: Text(draft ? 'Draft' : (edited ? 'Edited' : 'Saved')),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (parts != null)
              structured(parts)
            else
              SelectableText(r['reflection_text'] as String),
            const SizedBox(height: 12),
            Text(_label(r['source'] as String?), style: muted),
            const SizedBox(height: 12),
            if (draft)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton.icon(
                    onPressed: _accept,
                    icon: const Icon(Symbols.check_rounded),
                    label: const Text('Accept'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Symbols.edit_rounded),
                    label: const Text('Edit'),
                  ),
                  TextButton(onPressed: _dismiss, child: const Text('Dismiss')),
                ],
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Symbols.edit_rounded),
                  label: const Text('Edit'),
                ),
              ),
            if (draft)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    'This draft is kept on your phone until you decide.',
                    style: muted),
              ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: Text('Was this helpful?', style: muted)),
                IconButton(
                  tooltip: 'Helpful',
                  isSelected: rating == 'helpful',
                  icon: const Icon(Symbols.thumb_up_rounded),
                  selectedIcon: Icon(Symbols.thumb_up_rounded,
                      fill: 1, color: scheme.primary),
                  onPressed: () => _rate('helpful'),
                ),
                IconButton(
                  tooltip: 'Not helpful',
                  isSelected: rating == 'not_helpful',
                  icon: const Icon(Symbols.thumb_down_rounded),
                  selectedIcon: Icon(Symbols.thumb_down_rounded,
                      fill: 1, color: scheme.primary),
                  onPressed: () => _rate('not_helpful'),
                ),
              ],
            ),
            if (rating == 'not_helpful' && r['rating_reason'] != null)
              Text('Reason: ${_reasons[r['rating_reason']] ?? r['rating_reason']}',
                  style: muted),
          ],
        ),
      ),
    );
  }
}
