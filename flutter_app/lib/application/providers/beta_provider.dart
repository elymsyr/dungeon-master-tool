import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../services/beta_exit_cleanup_service.dart';
import 'auth_provider.dart';
import 'connectivity_provider.dart';

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

  /// `leave_beta` — önce kullanıcının Storage object'lerini client'tan siler
  /// (Supabase plpgsql'den `storage.objects` DELETE'e izin vermiyor), sonra
  /// DB temizliği için `leave_beta` RPC'sini çağırır.
  ///
  /// RPC (migration 057) şu online verileri kalıcı siler:
  ///   • Sahip olunan online world'ler (FK cascade: members, world-bound
  ///     characters, entities, packages, invites, mind-map dahil).
  ///   • Orphan online karakterler, personal package sync kayıtları.
  ///   • Marketplace listing'leri (kapak görseli inline, satırla birlikte gider).
  ///   • free_media_assets + community_assets + transient_shares + cloud_backups.
  /// Storage tarafında `campaign-backups`, `free-media`, `shared-payloads`
  /// bucket'larındaki object'ler [BetaExitCleanupService] ile silinir.
  ///
  /// KORUNUR: cihazlardaki tüm local Drift verisi; post'lar, game_listing'ler,
  /// mesajlar — sosyal katman tamamen kullanılabilir kalır. Beta dışı kullanıcı
  /// yeni online içerik üretemez ama davetle başkasının world'üne katılıp
  /// oynamaya devam edebilir.
  Future<bool> leaveBeta() async {
    if (!_canCallRpc) return false;
    final userId = _ref.read(authProvider)?.uid;
    if (userId == null) return false;
    state = state.copyWith(loading: true, error: null);
    try {
      try {
        await _ref
            .read(betaExitCleanupServiceProvider)
            ?.wipeUserStorage(userId);
      } catch (e) {
        debugPrint('leave_beta storage cleanup warning: $e');
      }

      final res = await Supabase.instance.client.rpc('leave_beta');
      final ok = res == true || (res is List && res.isNotEmpty && res.first == true);
      await refresh();
      return ok;
    } catch (e, st) {
      debugPrint('leave_beta error: $e\n$st');
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
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
