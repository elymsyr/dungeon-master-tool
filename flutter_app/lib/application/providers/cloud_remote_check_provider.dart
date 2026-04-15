import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/supabase_config.dart';
import 'auth_provider.dart';
import 'cloud_backup_provider.dart';

/// Multi-device sync hint: compares the user's newest cloud backup timestamp
/// against the locally persisted "last seen remote" marker. When the remote
/// is ahead, the Settings icon shows a notification dot so the user knows
/// another device has pushed changes they haven't pulled yet.
///
/// This is intentionally a hint, not conflict resolution — the user is free
/// to keep working and pull whenever they want.

const _prefsKey = 'cloud_last_seen_remote_created_at';

class CloudRemoteCheckNotifier extends StateNotifier<bool> {
  final Ref _ref;
  CloudRemoteCheckNotifier(this._ref) : super(false) {
    // Fire an initial check once the notifier is first read.
    refresh();
  }

  /// Remote fetch + compare. Updates [state] with the result. Silently
  /// swallows network/auth errors — this is a best-effort hint.
  Future<void> refresh() async {
    if (!SupabaseConfig.isConfigured || _ref.read(authProvider) == null) {
      state = false;
      return;
    }
    try {
      final remote = await _ref
          .read(cloudBackupRepositoryProvider)
          .fetchLatestRemoteCreatedAt();
      if (remote == null) {
        state = false;
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      final lastSeen = raw == null ? null : DateTime.tryParse(raw);
      state = lastSeen == null || remote.isAfter(lastSeen);
    } catch (_) {
      state = false;
    }
  }

  /// Stamp the local "last seen" marker to [at] (or now() if null) and clear
  /// the badge. Called after a successful sync/restore so the user sees the
  /// badge disappear as soon as they catch up.
  Future<void> markCaughtUp([DateTime? at]) async {
    final stamp = (at ?? DateTime.now().toUtc()).toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, stamp);
    state = false;
  }
}

final cloudRemoteHasNewerProvider =
    StateNotifierProvider<CloudRemoteCheckNotifier, bool>(
  (ref) => CloudRemoteCheckNotifier(ref),
);
