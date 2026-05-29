import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, RealtimeChannel, Supabase;

import 'package:drift/drift.dart' show Value;

import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../../data/database/app_database.dart' show WorldsCompanion, PackagesCompanion;
import '../../data/database/database_provider.dart';
import '../services/beta_enter_gate.dart';
import '../services/beta_enter_merge_service.dart';
import '../services/beta_exit_cleanup_service.dart';
import '../services/beta_exit_preserve_service.dart';
import '../services/beta_loss_gate.dart';
import '../services/sync_telemetry.dart' show SyncTelemetry, syncTelemetryProvider;
import 'auth_provider.dart';
import 'campaign_provider.dart';
import 'connectivity_provider.dart';
import 'online_worlds_provider.dart';
import 'personal_online_provider.dart';
import 'role_provider.dart';
import 'world_mirror_provider.dart';

/// Beta program state — ilk 90 kullanıcıya açık, 100 MB / kullanıcı cloud
/// save quota'sı. 14 gün inaktif olanların slot'u otomatik serbest bırakılır.
/// Sunucu otoritedir (RLS + trigger); burası yalnızca UX gate'i ve UI kaynağı.
@immutable
class BetaState {
  final bool isActive;
  final int slotCap;            // 90
  final int slotsRemaining;     // 0..slotCap
  final int? slotNumber;        // aktif kullanıcı için 1..slotCap
  final DateTime? joinedAt;
  final DateTime? lastActiveAt;
  final int usedBytes;
  final int quotaBytes;         // sunucudan gelir (100 MB mirror)
  final int inactivityDays;     // 14
  final bool requestPending;    // admin onayı bekleyen istek var mı
  final DateTime? requestedAt;
  final String? requestMessage;
  final bool loading;
  final String? error;

  const BetaState({
    this.isActive = false,
    this.slotCap = 90,
    this.slotsRemaining = 90,
    this.slotNumber,
    this.joinedAt,
    this.lastActiveAt,
    this.usedBytes = 0,
    this.quotaBytes = 100 * 1024 * 1024,
    this.inactivityDays = 14,
    this.requestPending = false,
    this.requestedAt,
    this.requestMessage,
    this.loading = false,
    this.error,
  });

  const BetaState.initial() : this();

  const BetaState.signedOut()
      : this(
          isActive: false,
          loading: false,
          slotsRemaining: 90,
        );

  BetaState copyWith({
    bool? isActive,
    int? slotCap,
    int? slotsRemaining,
    Object? slotNumber = _sentinel,
    Object? joinedAt = _sentinel,
    Object? lastActiveAt = _sentinel,
    int? usedBytes,
    int? quotaBytes,
    int? inactivityDays,
    bool? requestPending,
    Object? requestedAt = _sentinel,
    Object? requestMessage = _sentinel,
    bool? loading,
    Object? error = _sentinel,
  }) =>
      BetaState(
        isActive: isActive ?? this.isActive,
        slotCap: slotCap ?? this.slotCap,
        slotsRemaining: slotsRemaining ?? this.slotsRemaining,
        slotNumber: slotNumber == _sentinel ? this.slotNumber : slotNumber as int?,
        joinedAt: joinedAt == _sentinel ? this.joinedAt : joinedAt as DateTime?,
        lastActiveAt:
            lastActiveAt == _sentinel ? this.lastActiveAt : lastActiveAt as DateTime?,
        usedBytes: usedBytes ?? this.usedBytes,
        quotaBytes: quotaBytes ?? this.quotaBytes,
        inactivityDays: inactivityDays ?? this.inactivityDays,
        requestPending: requestPending ?? this.requestPending,
        requestedAt:
            requestedAt == _sentinel ? this.requestedAt : requestedAt as DateTime?,
        requestMessage:
            requestMessage == _sentinel ? this.requestMessage : requestMessage as String?,
        loading: loading ?? this.loading,
        error: error == _sentinel ? this.error : error as String?,
      );

  double get usageRatio =>
      quotaBytes == 0 ? 0 : (usedBytes / quotaBytes).clamp(0.0, 1.0);
  bool get isFull => !isActive && slotsRemaining <= 0;

  static const _sentinel = Object();
}

/// Beta access request RPC sonuç enum'u.
/// • requested: yeni istek atıldı
/// • alreadyPending: istek zaten var, mesaj güncellendi
/// • alreadyActive: kullanıcı zaten beta'da
/// • notSignedIn: oturum açık değil
/// • error: ağ/sunucu hatası
enum BetaRequestStatus { requested, alreadyPending, alreadyActive, notSignedIn, error }

class BetaRequestResult {
  final BetaRequestStatus status;
  final int slotsRemaining;
  final String? errorMessage;
  const BetaRequestResult({
    required this.status,
    this.slotsRemaining = 0,
    this.errorMessage,
  });
}

class BetaNotifier extends StateNotifier<BetaState> {
  final Ref _ref;
  ProviderSubscription<AuthState?>? _authSub;
  RealtimeChannel? _rt;
  String? _rtUid;
  Timer? _rtDebounce;

  /// True while the voluntary [leaveBeta] flow runs, so the `wasActive →
  /// !nowActive` transition it triggers via its trailing [refresh] does NOT
  /// also fire the involuntary-exit handler (which would double-run preserve).
  bool _leaving = false;

  BetaNotifier(this._ref) : super(const BetaState.initial()) {
    _authSub = _ref.listen<AuthState?>(
      authProvider,
      (previous, next) {
        if (next == null) {
          _teardownRealtime();
          state = const BetaState.signedOut();
        } else {
          _ensureRealtime(next.uid);
          // Warm the involuntary-loss sentinel cache so applier
          // `isMarkedSync` works on cold start before any CDC delete runs.
          // ignore: discarded_futures, unawaited_futures
          _ref.read(betaLossGateProvider).hydrate(next.uid);
          refresh();
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _authSub?.close();
    _teardownRealtime();
    super.dispose();
  }

  /// Admin onayı/reddi/revoke için realtime CDC dinleyici. beta_participants
  /// veya beta_requests'te kullanıcının kendi satırı eklenip silindiğinde
  /// `refresh()` tetiklenir (RLS sayesinde sadece self event'ler gelir).
  void _ensureRealtime(String uid) {
    if (_rt != null && _rtUid == uid) return;
    _teardownRealtime();
    if (!SupabaseConfig.isConfigured) return;
    _rtUid = uid;
    final client = Supabase.instance.client;
    void onChange(_) {
      _rtDebounce?.cancel();
      _rtDebounce = Timer(const Duration(milliseconds: 300), refresh);
    }
    _rt = client.channel('public:beta:self:$uid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'beta_participants',
        callback: onChange,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'beta_requests',
        callback: onChange,
      )
      ..subscribe();
  }

  void _teardownRealtime() {
    _rtDebounce?.cancel();
    _rtDebounce = null;
    final c = _rt;
    _rt = null;
    _rtUid = null;
    if (c != null) {
      try {
        Supabase.instance.client.removeChannel(c);
      } catch (_) {}
    }
  }

  bool get _canCallRpc =>
      SupabaseConfig.isConfigured && _ref.read(authProvider) != null;

  /// `get_beta_status` RPC'si — tek turda tüm özet.
  Future<void> refresh() async {
    if (!SupabaseConfig.isConfigured) return;
    if (_ref.read(authProvider) == null) {
      state = const BetaState.signedOut();
      return;
    }
    final wasActive = state.isActive;
    state = state.copyWith(loading: true, error: null);
    try {
      final rows = await guardedNetwork(
          _ref, () => Supabase.instance.client.rpc('get_beta_status'));
      final row = (rows is List && rows.isNotEmpty)
          ? rows.first as Map<String, dynamic>
          : (rows is Map ? rows as Map<String, dynamic> : null);
      if (row == null) {
        state = state.copyWith(loading: false);
        return;
      }
      final nowActive = (row['is_active'] as bool?) ?? false;
      final justBecameActive = !wasActive && nowActive;
      final justLostBeta = wasActive && !nowActive;
      state = BetaState(
        isActive: nowActive,
        slotCap: (row['slot_cap'] as num?)?.toInt() ?? 90,
        slotsRemaining: (row['slots_remaining'] as num?)?.toInt() ?? 0,
        slotNumber: (row['slot_number'] as num?)?.toInt(),
        joinedAt: _parseTs(row['joined_at']),
        lastActiveAt: _parseTs(row['last_active_at']),
        usedBytes: (row['used_bytes'] as num?)?.toInt() ?? 0,
        quotaBytes: (row['quota_bytes'] as num?)?.toInt() ?? (100 * 1024 * 1024),
        inactivityDays: (row['inactivity_days'] as num?)?.toInt() ?? 14,
        requestPending: (row['request_pending'] as bool?) ?? false,
        requestedAt: _parseTs(row['requested_at']),
        requestMessage: row['request_message'] as String?,
        loading: false,
      );
      // In-session false→true transition (admin just approved while the app
      // is running). Fire the local-wins merge before any CDC-driven cloud→
      // local applier can run for the newly granted beta scope. Fire-and-
      // forget; the startup gate covers the cold-restart case separately.
      if (justBecameActive) {
        // ignore: discarded_futures, unawaited_futures
        _runEnterMerge();
      }
      // Involuntary beta loss (server inactivity sweep or admin revoke). The
      // voluntary leaveBeta() flow runs its own preserve, so skip when
      // _leaving. Fire-and-forget — protects the owner's local Drift data
      // before/as the server-side cascade DELETE CDC events arrive.
      if (justLostBeta && !_leaving) {
        // ignore: discarded_futures, unawaited_futures
        _runInvoluntaryExit();
      }
    } catch (e, st) {
      if (isOfflineError(e)) {
        debugPrint('beta refresh skipped: offline');
        state = state.copyWith(loading: false);
      } else {
        debugPrint('beta refresh error: $e\n$st');
        state = state.copyWith(loading: false, error: e.toString());
      }
    }
  }

  /// In-session false→true transition handler. Triggers the local-wins merge
  /// so that local content created BEFORE admin approval is pushed to cloud
  /// before any cloud→local applier runs and (combined with PR-B1 wipe guards)
  /// is never destroyed by a stale cloud row.
  Future<void> _runEnterMerge() async {
    // Re-granted beta: clear the involuntary-loss sentinel so owned-content
    // CDC deletes resume normal purge behaviour again.
    final uid = _ref.read(authProvider)?.uid;
    if (uid != null) {
      try {
        await _ref.read(betaLossGateProvider).clear(uid);
      } catch (e) {
        debugPrint('beta-enter clear loss-gate error: $e');
      }
    }
    try {
      await _ref.read(betaEnterMergeServiceProvider)?.merge();
    } catch (e, st) {
      debugPrint('in-session beta-enter merge error: $e\n$st');
    }
  }

  /// Involuntary beta loss handler (inactivity sweep / admin revoke). Unlike
  /// voluntary [leaveBeta], the user isn't driving this — the server already
  /// purged their cloud rows (or is about to via cascade). We can only protect
  /// the LOCAL Drift copy of content the user OWNS:
  ///   1. Set a durable per-uid sentinel FIRST — appliers consult it (plus an
  ///      owner_id == uid check) to skip purge/trash on incoming CDC deletes,
  ///      closing the realtime race and surviving cold-start replay.
  ///   2. Enumerate owned worlds / chars / personal packages from LOCAL Drift
  ///      (cloud may already be gone) and flip them to offline-only via the
  ///      shared [_reconcileAfterLeave] path.
  ///   3. Arm the per-id 60s guards for the warm realtime window too.
  ///   4. Best-effort hydrate of any still-surviving cloud rows (never aborts).
  Future<void> _runInvoluntaryExit() async {
    final uid = _ref.read(authProvider)?.uid;
    if (uid == null) return;
    try {
      // 1. Durable sentinel first (mark() updates the in-memory cache before
      // its await, so concurrent CDC events already observe the guard).
      await _ref.read(betaLossGateProvider).mark(uid);

      // 2. Enumerate LOCAL owned content.
      final db = _ref.read(appDatabaseProvider);
      final ownedWorldIds = (await db.worldsDao.getAll())
          .where((w) => w.ownerId == uid)
          .map((w) => w.id)
          .toList(growable: false);
      final ownedCharIds = (await db.worldCharactersDao.getAllChars())
          .where((c) => c.ownerId == uid)
          .map((c) => c.id)
          .toList(growable: false);
      final pkgNames =
          _ref.read(personalOnlinePackageNamesProvider).toList(growable: false);

      // 3. Arm per-id guards for the warm window.
      final mirror = _ref.read(worldMirrorServiceProvider);
      if (mirror != null) {
        for (final id in ownedWorldIds) {
          mirror.registerExpectedUnpublish(id);
        }
        for (final id in ownedCharIds) {
          mirror.registerExpectedCharDelete(id);
        }
      }

      // 4. Flip everything to offline-only (reuse voluntary reconcile).
      await _reconcileAfterLeave(PreserveResult(
        worldIds: ownedWorldIds,
        orphanCharIds: ownedCharIds,
        personalPackageNames: pkgNames,
      ));

      // 5. Best-effort hydrate of any cloud rows that still exist. Never abort
      // on failure — the loss already happened server-side.
      try {
        await _ref.read(betaExitPreserveServiceProvider)?.preserve();
      } catch (e) {
        debugPrint('involuntary exit preserve (best-effort) error: $e');
      }

      // 6. Clear the enter-gate so a future re-grant re-runs the local-wins
      // merge against current local content.
      try {
        await _ref.read(betaEnterGateProvider).clear(uid);
      } catch (e) {
        debugPrint('involuntary exit clear enter-gate error: $e');
      }
    } catch (e, st) {
      debugPrint('involuntary beta exit error: $e\n$st');
    }
  }

  /// `request_beta` RPC'si — opsiyonel mesajla admin onayı için istek atar.
  /// Var olan request'i overwrite eder (mesajı günceller).
  Future<BetaRequestResult> requestAccess({String? message}) async {
    if (!_canCallRpc) {
      return const BetaRequestResult(status: BetaRequestStatus.notSignedIn);
    }
    state = state.copyWith(loading: true, error: null);
    try {
      final rows = await Supabase.instance.client
          .rpc('request_beta', params: {'p_message': message});
      final row = (rows is List && rows.isNotEmpty)
          ? rows.first as Map<String, dynamic>
          : (rows is Map ? rows as Map<String, dynamic> : null);
      if (row == null) {
        await refresh();
        return const BetaRequestResult(status: BetaRequestStatus.error);
      }
      final statusStr = row['status'] as String? ?? 'error';
      final result = BetaRequestResult(
        status: _parseRequestStatus(statusStr),
        slotsRemaining: (row['slots_remaining'] as num?)?.toInt() ?? 0,
      );
      await refresh();
      return result;
    } catch (e, st) {
      debugPrint('request_beta error: $e\n$st');
      state = state.copyWith(loading: false, error: e.toString());
      return BetaRequestResult(
        status: BetaRequestStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// `cancel_beta_request` — kullanıcı kendi pending isteğini geri çeker.
  Future<bool> cancelRequest() async {
    if (!_canCallRpc) return false;
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await Supabase.instance.client.rpc('cancel_beta_request');
      final ok = res == true || (res is List && res.isNotEmpty && res.first == true);
      await refresh();
      return ok;
    } catch (e, st) {
      debugPrint('cancel_beta_request error: $e\n$st');
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  /// `leave_beta` — beta'dan çıkış akışı.
  ///
  /// Akış:
  ///   1. [BetaExitPreserveService.preserve] — sahip olunan online world'leri,
  ///      orphan online karakterleri ve personal paketleri lokale indirir
  ///      (zaten cached olanlar atlanır). Ardından CDC DELETE event'leri
  ///      sırasında lokal kopyayı temizlememek için guard'ları arm eder.
  ///   2. [BetaExitCleanupService.wipeUserStorage] — Storage object'lerini
  ///      siler (Supabase plpgsql `storage.objects` DELETE'i engelleniyor).
  ///   3. `leave_beta` RPC — online satırları siler:
  ///      • Sahip olunan online world'ler (cascade).
  ///      • Orphan online karakterler, personal package sync kayıtları.
  ///      • Marketplace listing'leri, free_media_assets, community_assets,
  ///        transient_shares, cloud_backups.
  ///   4. Reconcile — `onlineWorldIdsProvider`'i clear et, sahip olunan
  ///      world/package satırlarındaki cloud-association sütunlarını sıfırla,
  ///      hub liste cache'lerini invalidate et.
  ///
  /// KORUNUR: lokal Drift'teki tüm world/karakter/package verisi offline
  /// olarak; post'lar, game_listing'ler, mesajlar — sosyal katman tamamen
  /// kullanılabilir kalır.
  Future<bool> leaveBeta() async {
    if (!_canCallRpc) return false;
    final userId = _ref.read(authProvider)?.uid;
    if (userId == null) return false;
    // Suppress the involuntary-exit handler for the duration of this voluntary
    // flow (including its trailing refresh()), which has its own preserve.
    _leaving = true;
    state = state.copyWith(loading: true, error: null);
    try {
      // 1. Hydrate + arm guards. Ağ hatası halinde caller fırlat dialog'da
      // gösterir — RPC çağrılmadan abort edilir (online içerik korunmalı).
      PreserveResult? preserved;
      try {
        preserved = await _ref.read(betaExitPreserveServiceProvider)?.preserve();
      } catch (e, st) {
        debugPrint('leave_beta preserve error: $e\n$st');
        state = state.copyWith(loading: false, error: e.toString());
        return false;
      }

      // If any row failed to hydrate, abort BEFORE the destructive RPC fires.
      // User retries — better to stay in beta than to nuke data we couldn't
      // safely mirror locally first.
      if (preserved != null && preserved.hasFailures) {
        final msg =
            'Could not back up ${preserved.failedIds.length} item(s) before '
            'leaving beta. Stayed in beta — please retry.';
        debugPrint('leave_beta aborted: ${preserved.failedIds.join(", ")}');
        try {
          final telemetry = _ref.read(syncTelemetryProvider);
          for (var i = 0; i < preserved.failedIds.length; i++) {
            await telemetry.incrementCounter(
                SyncTelemetry.betaExitPreserveFailed);
          }
        } catch (_) {/* ignore */}
        state = state.copyWith(loading: false, error: msg);
        return false;
      }

      // 2. + 3. — `beta_purge_with_cleanup` Edge Function: leave_beta RPC +
      // Supabase Storage `{userId}/` sweep + R2 `{userId}/` + transient
      // sweep. Tek noktada atomik temizlik. Edge Function 4xx/5xx olursa
      // fallback yok — caller hata mesajını görsün ve tekrar denesin
      // (yetim Storage/R2 verisi bırakmaktansa beta-içi kalmak yeğdir).
      bool ok = false;
      try {
        final res = await Supabase.instance.client.functions.invoke(
          'beta_purge_with_cleanup',
          body: {'user_id': userId},
        );
        final data = res.data;
        if (data is Map && data['ok'] == true) {
          ok = true;
        } else {
          debugPrint('leave_beta function response: $data');
        }
      } catch (e) {
        debugPrint('leave_beta function error: $e');
        // Fallback to legacy RPC + client storage sweep — Edge Function
        // henüz deploy edilmemiş ortamlarda (eski self-hosted) self-exit
        // tamamen blok olmasın. R2 öksüz kalır ama DB + Supabase Storage
        // user JWT ile temizlenir.
        try {
          await _ref
              .read(betaExitCleanupServiceProvider)
              ?.wipeUserStorage(userId);
        } catch (se) {
          debugPrint('leave_beta storage fallback warning: $se');
        }
        final res = await Supabase.instance.client.rpc('leave_beta');
        ok = res == true ||
            (res is List && res.isNotEmpty && res.first == true);
      }

      // 4. Reconcile lokal state. Guard CDC delete'i yutuyor ama "online"
      // bayrakları + cloud push timestamp'leri stale kalır — burada düşür.
      if (ok && preserved != null) {
        await _reconcileAfterLeave(preserved);
      }

      // Clear the first-enter sentinel so a future re-enter re-runs the
      // local-wins merge against potentially-new local content.
      if (ok) {
        try {
          await _ref.read(betaEnterGateProvider).clear(userId);
        } catch (e) {
          debugPrint('leave_beta clear enter-gate error: $e');
        }
      }

      await refresh();
      return ok;
    } catch (e, st) {
      debugPrint('leave_beta error: $e\n$st');
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    } finally {
      _leaving = false;
    }
  }

  Future<void> _reconcileAfterLeave(PreserveResult preserved) async {
    final db = _ref.read(appDatabaseProvider);
    // Worlds: cloud sync sütunlarını sıfırla, online set'ten çıkar.
    for (final wid in preserved.worldIds) {
      try {
        await (db.update(db.worlds)..where((t) => t.id.equals(wid))).write(
          const WorldsCompanion(
            lastCloudPushAt: Value(null),
            lastPushedHash: Value(null),
          ),
        );
      } catch (e) {
        debugPrint('leave_beta reconcile world $wid error: $e');
      }
      _ref.read(onlineWorldIdsProvider.notifier).remove(wid);
      _ref.invalidate(worldRoleProvider(wid));
    }
    // Packages: cloud sync sütunlarını sıfırla + "online package names" set'i
    // boşalt (beta dışı kullanıcı yeni publish yapamaz, mevcut hepsi offline).
    for (final name in preserved.personalPackageNames) {
      try {
        final pkg = await db.packagesDao.getByName(name);
        if (pkg != null) {
          await (db.update(db.packages)..where((t) => t.id.equals(pkg.id))).write(
            const PackagesCompanion(
              lastCloudPushAt: Value(null),
              lastPushedHash: Value(null),
            ),
          );
        }
      } catch (e) {
        debugPrint('leave_beta reconcile package $name error: $e');
      }
      _ref.read(personalOnlinePackageNamesProvider.notifier).remove(name);
    }
    // Hub liste cache'lerini invalidate — UI offline rozetine geç.
    _ref.invalidate(campaignInfoListProvider);
    _ref.invalidate(campaignListProvider);
    _ref.invalidate(currentWorldRoleProvider);
  }

  /// `beta_heartbeat` — fire-and-forget; beta'da değilse sunucu no-op yapar.
  Future<void> heartbeat() async {
    if (!_canCallRpc) return;
    try {
      await guardedNetwork(
          _ref, () => Supabase.instance.client.rpc('beta_heartbeat'));
    } catch (e) {
      if (isOfflineError(e)) {
        debugPrint('beta heartbeat skipped: offline');
      } else {
        debugPrint('beta heartbeat error: $e');
      }
    }
  }

  BetaRequestStatus _parseRequestStatus(String s) {
    switch (s) {
      case 'requested':
        return BetaRequestStatus.requested;
      case 'already_pending':
        return BetaRequestStatus.alreadyPending;
      case 'already_active':
        return BetaRequestStatus.alreadyActive;
      case 'not_signed_in':
        return BetaRequestStatus.notSignedIn;
      default:
        return BetaRequestStatus.error;
    }
  }

  DateTime? _parseTs(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}

final betaProvider = StateNotifierProvider<BetaNotifier, BetaState>(
  (ref) => BetaNotifier(ref),
);

/// UI ve gate'ler için senkron okunabilir kolaylık provider'ı.
final isBetaActiveProvider = Provider<bool>(
  (ref) => ref.watch(betaProvider).isActive,
);
