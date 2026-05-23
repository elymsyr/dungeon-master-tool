import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'package:drift/drift.dart' show Value;

import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../../data/database/app_database.dart' show WorldsCompanion, PackagesCompanion;
import '../../data/database/database_provider.dart';
import '../services/beta_exit_cleanup_service.dart';
import '../services/beta_exit_preserve_service.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';
import 'connectivity_provider.dart';
import 'online_worlds_provider.dart';
import 'personal_online_provider.dart';
import 'role_provider.dart';

/// Beta program state — ilk 200 kullanıcıya açık, 50 MB / kullanıcı cloud
/// save quota'sı. 7 gün inaktif olanların slot'u otomatik serbest bırakılır.
/// Sunucu otoritedir (RLS + trigger); burası yalnızca UX gate'i ve UI kaynağı.
@immutable
class BetaState {
  final bool isActive;
  final int slotCap;            // 200
  final int slotsRemaining;     // 0..slotCap
  final int? slotNumber;        // aktif kullanıcı için 1..slotCap
  final DateTime? joinedAt;
  final DateTime? lastActiveAt;
  final int usedBytes;
  final int quotaBytes;         // sunucudan gelir (50 MB mirror)
  final int inactivityDays;     // 7
  final bool loading;
  final String? error;

  const BetaState({
    this.isActive = false,
    this.slotCap = 200,
    this.slotsRemaining = 200,
    this.slotNumber,
    this.joinedAt,
    this.lastActiveAt,
    this.usedBytes = 0,
    this.quotaBytes = 50 * 1024 * 1024,
    this.inactivityDays = 7,
    this.loading = false,
    this.error,
  });

  const BetaState.initial() : this();

  const BetaState.signedOut()
      : this(
          isActive: false,
          loading: false,
          slotsRemaining: 200,
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
        loading: loading ?? this.loading,
        error: error == _sentinel ? this.error : error as String?,
      );

  double get usageRatio =>
      quotaBytes == 0 ? 0 : (usedBytes / quotaBytes).clamp(0.0, 1.0);
  bool get isFull => !isActive && slotsRemaining <= 0;

  static const _sentinel = Object();
}

enum BetaJoinStatus { joined, already, full, notSignedIn, error }

class BetaJoinResult {
  final BetaJoinStatus status;
  final int? slotNumber;
  final int slotsRemaining;
  final String? errorMessage;
  const BetaJoinResult({
    required this.status,
    this.slotNumber,
    this.slotsRemaining = 0,
    this.errorMessage,
  });
}

class BetaNotifier extends StateNotifier<BetaState> {
  final Ref _ref;
  ProviderSubscription<AuthState?>? _authSub;

  BetaNotifier(this._ref) : super(const BetaState.initial()) {
    _authSub = _ref.listen<AuthState?>(
      authProvider,
      (previous, next) {
        if (next == null) {
          state = const BetaState.signedOut();
        } else {
          refresh();
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _authSub?.close();
    super.dispose();
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
      state = BetaState(
        isActive: (row['is_active'] as bool?) ?? false,
        slotCap: (row['slot_cap'] as num?)?.toInt() ?? 200,
        slotsRemaining: (row['slots_remaining'] as num?)?.toInt() ?? 0,
        slotNumber: (row['slot_number'] as num?)?.toInt(),
        joinedAt: _parseTs(row['joined_at']),
        lastActiveAt: _parseTs(row['last_active_at']),
        usedBytes: (row['used_bytes'] as num?)?.toInt() ?? 0,
        quotaBytes: (row['quota_bytes'] as num?)?.toInt() ?? (50 * 1024 * 1024),
        inactivityDays: (row['inactivity_days'] as num?)?.toInt() ?? 7,
        loading: false,
      );
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

  /// `join_beta` RPC'si — atomik slot alır, sonra refresh eder.
  Future<BetaJoinResult> joinBeta() async {
    if (!_canCallRpc) {
      return const BetaJoinResult(status: BetaJoinStatus.notSignedIn);
    }
    state = state.copyWith(loading: true, error: null);
    try {
      final rows = await Supabase.instance.client.rpc('join_beta');
      final row = (rows is List && rows.isNotEmpty)
          ? rows.first as Map<String, dynamic>
          : (rows is Map ? rows as Map<String, dynamic> : null);
      if (row == null) {
        await refresh();
        return const BetaJoinResult(status: BetaJoinStatus.error);
      }
      final statusStr = row['status'] as String? ?? 'error';
      final result = BetaJoinResult(
        status: _parseStatus(statusStr),
        slotNumber: (row['assigned_slot'] as num?)?.toInt(),
        slotsRemaining: (row['slots_remaining'] as num?)?.toInt() ?? 0,
      );
      await refresh();
      return result;
    } catch (e, st) {
      debugPrint('join_beta error: $e\n$st');
      state = state.copyWith(loading: false, error: e.toString());
      return BetaJoinResult(
        status: BetaJoinStatus.error,
        errorMessage: e.toString(),
      );
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

      // 2. Storage cleanup (best-effort).
      try {
        await _ref
            .read(betaExitCleanupServiceProvider)
            ?.wipeUserStorage(userId);
      } catch (e) {
        debugPrint('leave_beta storage cleanup warning: $e');
      }

      // 3. RPC.
      final res = await Supabase.instance.client.rpc('leave_beta');
      final ok = res == true || (res is List && res.isNotEmpty && res.first == true);

      // 4. Reconcile lokal state. Guard CDC delete'i yutuyor ama "online"
      // bayrakları + cloud push timestamp'leri stale kalır — burada düşür.
      if (ok && preserved != null) {
        await _reconcileAfterLeave(preserved);
      }

      await refresh();
      return ok;
    } catch (e, st) {
      debugPrint('leave_beta error: $e\n$st');
      state = state.copyWith(loading: false, error: e.toString());
      return false;
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

  BetaJoinStatus _parseStatus(String s) {
    switch (s) {
      case 'joined':
        return BetaJoinStatus.joined;
      case 'already':
        return BetaJoinStatus.already;
      case 'full':
        return BetaJoinStatus.full;
      case 'not_signed_in':
        return BetaJoinStatus.notSignedIn;
      default:
        return BetaJoinStatus.error;
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
