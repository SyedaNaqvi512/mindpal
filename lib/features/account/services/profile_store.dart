import 'package:flutter/foundation.dart';

import '../../auth/services/auth_service.dart';
import '../models/user_profile.dart';

/// Keeps the signed-in person's profile in memory so Home and Settings can show
/// the name and avatar without waiting for the network each time.
class ProfileStore {
  ProfileStore._();

  static final ProfileStore instance = ProfileStore._();

  final ValueNotifier<UserProfile?> profile = ValueNotifier<UserProfile?>(null);
  bool _loading = false;

  /// Loads from the server. Keeps the old value if the call fails.
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      profile.value = await AuthService.instance.fetchProfile();
    } catch (_) {
      // Offline or session problem: keep what we have.
    } finally {
      _loading = false;
    }
  }

  Future<void> ensureLoaded() async {
    if (profile.value == null) await refresh();
  }

  void set(UserProfile p) => profile.value = p;

  /// Call on sign out so the next person never sees this one's name.
  void clear() => profile.value = null;
}
