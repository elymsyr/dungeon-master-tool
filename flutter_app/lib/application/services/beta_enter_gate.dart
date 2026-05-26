import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-user sentinel marking that the first beta-enter merge (local→cloud
/// reconciliation) has run successfully on this device. Until set, cloud→local
/// appliers (`WorldReconciler`, `CloudCatchupService._pullPackages`,
/// `PersonalMirrorApplier.bootstrap`) must NOT overwrite local rows that
/// already exist locally — the user's pre-beta offline content would be wiped
/// when stale cloud rows are pulled down.
///
/// Lifecycle:
///   • Unset by default for a fresh install or after `clear(uid)`.
///   • Set by `BetaEnterMergeService.merge()` on success (PR-B2).
///   • Cleared by `BetaNotifier.leaveBeta()` so a future re-enter re-runs the
///     local-wins merge against potentially new local content.
class BetaEnterGate {
  static const _prefix = 'beta_first_enter_completed_at:';

  final Map<String, bool> _cache = <String, bool>{};

  String _key(String uid) => '$_prefix$uid';

  Future<bool> isCompleted(String uid) async {
    final cached = _cache[uid];
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    final done = raw != null && raw.isNotEmpty;
    _cache[uid] = done;
    return done;
  }

  Future<void> markCompleted(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), DateTime.now().toUtc().toIso8601String());
    _cache[uid] = true;
  }

  Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
    _cache[uid] = false;
  }
}

final betaEnterGateProvider = Provider<BetaEnterGate>((ref) => BetaEnterGate());
