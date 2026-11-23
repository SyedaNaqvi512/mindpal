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
  final _touched = List<bool>.filled(RecoveryQuestions.count, false);

  @override
  void dispose() {
    for (final c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _texts => [for (final c in _answers) c.text];

  bool get _valid => validateRecovery(_ids, _texts) == null;

  void _submit() {
    if (!_valid) {
      setState(() {
        for (var i = 0; i < _touched.length; i++) {
          _touched[i] = true;
        }
      });
      return;
    }
    widget.onDone([for (final i in _ids) i!], _texts);
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
            key: ValueKey('q$i-${_ids[i]}'),
            initialValue: _ids[i],
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Question ${i + 1}',
              errorText: _touched[i] && _ids[i] == null
                  ? 'Choose a question.'
                  : null,
            ),
            items: [
              for (final e in questionsFor(i, _ids).entries)
                DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() {
              _ids[i] = v;
              _touched[i] = true;
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _answers[i],
            textInputAction: TextInputAction.next,
            maxLength: 60,
            onChanged: (_) => setState(() => _touched[i] = true),
            decoration: InputDecoration(
              labelText: 'Answer ${i + 1}',
              counterText: '',
              errorText: _touched[i] && _ids[i] != null
                  ? answerError(_answers[i].text, _texts, i)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _valid ? _submit : null,
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }
}
