import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../services/reminder_logic.dart';
import '../services/reminder_service.dart';

/// Settings for FR-30: the daily check-in reminder and the daily thought,
/// each with an on/off switch and a time of day.
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

  Future<void> _toggleQuote(bool on) async {
    final ok = await _svc.setQuoteEnabled(on);
    if (!ok && mounted) {
      _snack(
        'Notifications are blocked. Allow them for MindPal in your '
        'phone settings.',
      );
    }
  }

  Future<void> _pickTime({required bool quote}) async {
    final current = quote ? _svc.quoteMinutes : _svc.minutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hourOf(current), minute: minuteOf(current)),
      helpText: quote ? 'Daily thought time' : 'Daily reminder time',
    );
    if (picked == null) return;
    final m = toMinutes(picked.hour, picked.minute);
    if (quote) {
      await _svc.setQuoteTime(m);
    } else {
      await _svc.setTime(m);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListenableBuilder(
      listenable: _svc,
      builder: (context, _) => Column(
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Symbols.notifications_rounded),
                  title: const Text('Daily reminder'),
                  subtitle: Text(
                    _svc.enabled
                        ? 'A gentle check-in every day at ${formatMinutes(_svc.minutes)}, '
                            'in different words.'
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
                    onTap: () => _pickTime(quote: false),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Symbols.self_improvement_rounded),
                  title: const Text('Daily thought'),
                  subtitle: Text(
                    _svc.quoteEnabled
                        ? 'A new calming thought about the mind every day at '
                            '${formatMinutes(_svc.quoteMinutes)}.'
                        : 'Off. A short, calming thought each day.',
                    style: TextStyle(color: muted),
                  ),
                  value: _svc.quoteEnabled,
                  onChanged: _toggleQuote,
                ),
                if (_svc.quoteEnabled)
                  ListTile(
                    leading: const Icon(Symbols.schedule_rounded),
                    title: const Text('Thought time'),
                    trailing: Text(formatMinutes(_svc.quoteMinutes)),
                    onTap: () => _pickTime(quote: true),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
