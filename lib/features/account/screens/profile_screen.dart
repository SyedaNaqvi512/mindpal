import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../auth/services/auth_service.dart';
import '../models/avatars.dart';
import '../models/user_profile.dart';
import '../widgets/avatar_image.dart';
import 'change_password_screen.dart';

/// FR-07 and FR-08: view/edit name, pick an avatar, see email, change password.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  final _name = TextEditingController();
  int? _avatar;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await AuthService.instance.fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _name.text = p.displayName;
        _avatar = p.avatarId;
      });
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _dirty =>
      _profile != null &&
      (_name.text.trim() != _profile!.displayName || _avatar != _profile!.avatarId);

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 50) {
      setState(() => _error = 'Name must be 1 to 50 characters.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final p = await AuthService.instance.updateProfile(
        displayName: name,
        avatarId: _avatar,
      );
      if (!mounted) return;
      setState(() {
        _profile = p;
        _name.text = p.displayName;
        _avatar = p.avatarId;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final p = _profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : p == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'Could not load your profile.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(child: AvatarImage(avatarId: _avatar ?? p.avatarId, size: 112)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 50,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Display name'),
                    ),
                    const SizedBox(height: 12),
                    Text('Choose your picture', style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      p.gender == Gender.unspecified
                          ? 'All pictures are available.'
                          : 'Pictures for ${Gender.label(p.gender).toLowerCase()} profiles.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final id in Avatars.idsFor(p.gender))
                          Semantics(
                            button: true,
                            selected: _avatar == id,
                            label: 'Avatar $id',
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => setState(() => _avatar = id),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _avatar == id
                                        ? scheme.primary
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: AvatarImage(avatarId: id, size: 64),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_error!, style: TextStyle(color: scheme.error)),
                      ),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: (_dirty && !_saving) ? _save : null,
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Save changes'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Account', style: text.titleMedium),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Symbols.mail_rounded),
                            title: const Text('Email'),
                            subtitle: Text(p.email),
                            trailing: p.emailVerified
                                ? Icon(Symbols.verified_rounded,
                                    color: scheme.primary)
                                : null,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Symbols.lock_rounded),
                            title: const Text('Change password'),
                            trailing: const Icon(Symbols.chevron_right_rounded),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const ChangePasswordScreen()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
