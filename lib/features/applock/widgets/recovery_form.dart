import 'package:flutter/material.dart';

import '../models/app_lock_logic.dart';

/// Pick three different questions and answer them. Used when the lock is set up.
class RecoveryForm extends StatefulWidget {
  const RecoveryForm({super.key, required this.onDone});

  final void Function(List<String> ids, List<String> answers) onDone;

  @override
  State<RecoveryForm> createState() => _RecoveryFormState();
}

class _RecoveryFormState extends State<RecoveryForm> {
  final _ids = List<String?>.filled(RecoveryQuestions.count, null);
  final _answers = List.generate(
    RecoveryQuestions.count,
    (_) => TextEditingController(),
  );
  String? _error;

  @override
  void dispose() {
    for (final c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final texts = [for (final c in _answers) c.text];
    final err = validateRecovery(_ids, texts);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    widget.onDone([for (final i in _ids) i!], texts);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recovery questions', style: text.titleLarge),
        const SizedBox(height: 8),
        Text(
          'If you forget your PIN, answering these three questions lets you '
          'choose a new one. Pick answers only you know. Capital letters and '
          'extra spaces do not matter.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < RecoveryQuestions.count; i++) ...[
          DropdownButtonFormField<String>(
            initialValue: _ids[i],
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Question ${i + 1}'),
            items: [
              for (final e in RecoveryQuestions.all.entries)
                DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _ids[i] = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _answers[i],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: 'Answer ${i + 1}'),
          ),
          const SizedBox(height: 16),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submit,
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }
}
