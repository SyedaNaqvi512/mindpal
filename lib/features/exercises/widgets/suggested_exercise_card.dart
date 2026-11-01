import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise_catalog.dart';
import '../screens/exercise_runner_screen.dart';

/// FR-46: after a reflection, one Suggested Exercise card chosen from the named
/// thinking pattern. The user can open or dismiss it. If neither the mapped
/// exercise nor its fallback exists, nothing is shown.
class SuggestedExerciseCard extends StatefulWidget {
  const SuggestedExerciseCard({super.key, required this.entryId, required this.patternId});

  final int entryId;
  final String? patternId;

  @override
  State<SuggestedExerciseCard> createState() => _SuggestedExerciseCardState();
}

class _SuggestedExerciseCardState extends State<SuggestedExerciseCard> {
  bool _dismissed = false;

  String get _key => 'suggestion_dismissed_${widget.entryId}';

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted && (prefs.getBool(_key) ?? false)) setState(() => _dismissed = true);
    } catch (_) {}
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final info = suggestExercise(widget.patternId);
    if (info == null || _dismissed) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(info.icon, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Suggested exercise',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSecondaryContainer)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(info.title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: scheme.onSecondaryContainer)),
              const SizedBox(height: 2),
              Text('${info.blurb} (${info.timeLabel})',
                  style: TextStyle(color: scheme.onSecondaryContainer)),
              const SizedBox(height: 4),
              Text('A guided self-reflection activity, not therapy.',
                  style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          ExerciseRunnerScreen(info: info, entryId: widget.entryId),
                    )),
                    icon: const Icon(Symbols.play_arrow_rounded),
                    label: const Text('Open'),
                  ),
                  TextButton(onPressed: _dismiss, child: const Text('Dismiss')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
