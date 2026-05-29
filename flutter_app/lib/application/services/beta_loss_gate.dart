import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-user sentinel marking that the user lost beta access INVOLUNTARILY
/// (server inactivity sweep or admin revoke) on this device. While set, CDC
/// DELETE appliers must NOT purge/trash local Drift rows that the user OWNS —
/// a non-present user can't run the voluntary `BetaExitPreserveService` flow,
/// so the owner's offline copy would otherwise be wiped by the server-side
/// cascade DELETE events arriving over realtime (or replayed on cold start).
///
/// Scope is enforced by the caller: the skip only fires for rows whose
/// `owner_id == uid`. Worlds the user merely PLAYS in (non-owner) are still
/// purged/trashed normally when membership is removed.
///
/// Lifecycle:
///   • Unset by default.
///   • Set by `BetaNotifier._runInvoluntaryExit()` the instant a
///     `wasActive && !nowActive` transition is detected.
///   • Cleared on a successful beta re-enter (`BetaNotifier._runEnterMerge`).
///
/// [isMarkedSync] is used inside CDC appliers where awaiting is not possible;
/// it reads only the in-memory cache, so [hydrate] (or any [isMarked] call)
/// must run once on sign-in before appliers process deletes.
class BetaLossGate {
  static const _prefix = 'beta_loss_preserve:';

  final Map<String, bool> _cache = <String, bool>{};

  String _key(String uid) => '$_prefix$uid';

  /// Populate the in-memory cache from disk so [isMarkedSync] is reliable on
  /// cold start. Idempotent.
  Future<bool> hydrate(String uid) => isMarked(uid);

  Future<bool> isMarked(String uid) async {
    final cached = _cache[uid];
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    final marked = raw != null && raw.isNotEmpty;
    _cache[uid] = marked;
    return marked;
  }

  /// Synchronous cache read for use inside CDC appliers. Returns false until
  /// [hydrate]/[isMarked] has run for this uid.
  bool isMarkedSync(String uid) => _cache[uid] ?? false;

  Future<void> mark(String uid) async {
    // Update the cache synchronously first so concurrent CDC events in the
    // same microtask window already see the guard.
    _cache[uid] = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), DateTime.now().toUtc().toIso8601String());
  }

  Future<void> clear(String uid) async {
    _cache[uid] = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
  }
}

final betaLossGateProvider = Provider<BetaLossGate>((ref) => BetaLossGate());
