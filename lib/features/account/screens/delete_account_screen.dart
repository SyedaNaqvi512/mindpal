import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/database_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../applock/services/app_lock_service.dart';
import '../../auth/services/auth_service.dart';
import '../../consent/services/consent_service.dart';
import '../../reminders/services/reminder_service.dart';

/// FR-34: permanently delete the account and clear the data on this phone.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _hide = true;
  bool _understood = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _ready => _understood && _password.text.isNotEmpty && !_busy;

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final res = await AuthService.instance.authorizedPost('/me/delete', {
        'password': _password.text,
      });

      if (res.statusCode != 202 && res.statusCode != 200) {
        throw AuthException(problemMessage(decodeJson(res.body)));
      }

      // The server accepted the request. Now clear everything on this phone.
      await DatabaseService.deleteAllLocalData();

      // Disable the app lock and cancel any scheduled reminder.
      await AppLockService.instance.reset();
      await ReminderService.instance.clear();

      final prefs = ref.read(sharedPreferencesProvider);
      for (final key in prefs.getKeys().toList()) {
        if (key != ThemeController.prefsKey) {
          await prefs.remove(key);
        }
      }

      ConsentService.instance.clear();
      await AuthService.instance.logout();

      navigator.popUntil((r) => r.isFirst);
      widget.onSignedOut();

      messenger.showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 8),
          content: Text(
            'Your account is scheduled for deletion and your data '
            'on this phone was cleared. Server data is removed within 7 days.',
          ),
        ),
      );
    } on SessionExpiredException {
      navigator.popUntil((r) => r.isFirst);
      widget.onSignedOut();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Something went wrong. Nothing was deleted. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget point(String s) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(s)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Symbols.warning_rounded, size: 40, color: scheme.error),
            const SizedBox(height: 12),
            Text('This cannot be undone', style: text.titleLarge),
            const SizedBox(height: 12),
            point(
              'You will be signed out and cannot sign in again with this account.',
            ),
            point(
              'Your account and the data MindPal keeps on its server are '
              'removed within 7 days.',
            ),
            point(
              'Your journal entries, reflections and settings on this phone '
              'are erased now. They cannot be recovered.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: _hide,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Enter your password to confirm',
                suffixIcon: IconButton(
                  tooltip: _hide ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _hide
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _understood,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _understood = v ?? false),
              title: const Text(
                'I understand my account and entries will be '
                'deleted permanently.',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              ),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
                onPressed: _ready ? _delete : null,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Delete my account'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Keep my account'),
            ),
          ],
        ),
      ),
    );
  }
}
