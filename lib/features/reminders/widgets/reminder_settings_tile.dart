import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../services/reminder_logic.dart';
import '../services/reminder_service.dart';

/// Settings card for FR-30: reminder on/off and the time of day.
class ReminderSettingsTile extends StatefulWidget {
  const ReminderSettingsTile({super.key});

  @override
  State<ReminderSettingsTile> createState() => _ReminderSettingsTileState();
}

class _ReminderSettingsTileState extends State<ReminderSettingsTile> {
  final _svc = ReminderService.instance;

  @override
  void initState() {
    super.initState();
    _svc.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _toggle(bool on) async {
    final ok = await _svc.setEnabled(on);
    if (!ok && mounted) {
      _snack(
        'Notifications are blocked. Allow them for MindPal in your '
        'phone settings.',
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: hourOf(_svc.minutes),
        minute: minuteOf(_svc.minutes),
      ),
      helpText: 'Daily reminder time',
    );
    if (picked != null) {
      await _svc.setTime(toMinutes(picked.hour, picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListenableBuilder(
      listenable: _svc,
      builder: (context, _) => Card(
        child: Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Symbols.notifications_rounded),
              title: const Text('Daily reminder'),
              subtitle: Text(
                _svc.enabled
                    ? 'A gentle nudge every day at ${formatMinutes(_svc.minutes)}.'
                    : 'Off.',
                style: TextStyle(color: muted),
              ),
              value: _svc.enabled,
              onChanged: _toggle,
            ),
            if (_svc.enabled)
              ListTile(
                leading: const Icon(Symbols.schedule_rounded),
                title: const Text('Reminder time'),
                trailing: Text(formatMinutes(_svc.minutes)),
                onTap: _pickTime,
              ),
          ],
        ),
      ),
    );
  }
}
