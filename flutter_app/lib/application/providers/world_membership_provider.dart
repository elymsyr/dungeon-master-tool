import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../../data/network/no_op_world_membership_service.dart';
import '../../data/network/supabase_world_membership_service.dart';
import '../../data/network/world_membership_service.dart';
import '../../domain/entities/online/world_invite.dart';
import '../../domain/entities/online/world_member.dart';
import '../../domain/entities/online/world_role.dart';
import 'auth_provider.dart';
import 'connectivity_provider.dart';

/// WorldMembershipService — Supabase yapılandırılmış + auth varsa
/// gerçek implementasyon; aksi halde NoOp.
final worldMembershipServiceProvider =
    Provider<WorldMembershipService>((ref) {
  if (!SupabaseConfig.isConfigured) {
    return const NoOpWorldMembershipService();
  }
  final auth = ref.watch(authProvider);
  if (auth == null) return const NoOpWorldMembershipService();
  return SupabaseWorldMembershipService(Supabase.instance.client);
});

/// `world_members` granular cache. Bootstrap'te bir kez fetch eder; sonra
/// CDC event'leri `applyJoin`/`applyLeave` ile listeyi O(1) günceller —
/// her join/leave için tüm roster yeniden fetch edilmez.
class WorldMembersNotifier
    extends StateNotifier<AsyncValue<List<WorldMember>>> {
  final Ref _ref;
  final WorldMembershipService _service;
  final SupabaseClient? _client;
  final String worldId;
  bool _bootstrapped = false;

  late final _ProfileBatchLoader _profiles;

  WorldMembersNotifier(this._ref, this._service, this._client, this.worldId)
      : super(const AsyncValue.loading()) {
    _profiles = _ProfileBatchLoader(_client);
  }

  @override
  void dispose() {
    _profiles.dispose();
    super.dispose();
  }

  /// [force]=true ise `_bootstrapped` guard'ını atlar; channel re-subscribe
  /// veya world reopen sonrası taze roster çekmek için kullanılır.
  Future<void> bootstrap({bool force = false}) async {
    if (!mounted || (_bootstrapped && !force)) return;
    _bootstrapped = true;
    if (_service is NoOpWorldMembershipService) {
      if (mounted) state = const AsyncValue.data([]);
      return;
    }
    try {
      final rows =
          await guardedNetwork(_ref, () => _service.listMembers(worldId));
      if (!mounted) return;
      state = AsyncValue.data(rows);
    } catch (e, st) {
      if (isOfflineError(e)) {
        debugPrint('world members skipped: offline');
      } else {
        debugPrint('WorldMembersNotifier bootstrap error: $e');
      }
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  /// CDC INSERT/UPDATE — profile bilgisi opsiyonel olarak Supabase'den
  /// çekilir (display name vs. için). Hata olursa raw row ile devam.
  Future<void> applyJoin(Map<String, dynamic> row) async {
    final worldIdFromRow = row['world_id'] as String?;
    if (worldIdFromRow != null && worldIdFromRow != worldId) return;
    final userId = row['user_id'] as String?;
    if (userId == null) return;
    final role = _parseRole(row['role'] as String? ?? 'player');
    final joinedAtStr = row['joined_at'] as String?;
    final joinedAt = joinedAtStr == null
        ? DateTime.now()
        : DateTime.tryParse(joinedAtStr) ?? DateTime.now();

    final profile = await _fetchProfile(userId);
    if (!mounted) return;
    final member = WorldMember(
      worldId: worldId,
      userId: userId,
      role: role,
      joinedAt: joinedAt,
      username: profile?['username'] as String?,
      displayName: profile?['display_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
    );
    final list = [...(state.valueOrNull ?? const <WorldMember>[])];
    final idx = list.indexWhere((m) => m.userId == userId);
    if (idx >= 0) {
      list[idx] = member;
    } else {
      list.add(member);
    }
    state = AsyncValue.data(list);
  }

  /// CDC DELETE — userId üzerinden granular remove.
  void applyLeave(String userId) {
    if (!mounted) return;
    final list = state.valueOrNull;
    if (list == null) return;
    final next = list.where((m) => m.userId != userId).toList();
    if (next.length == list.length) return;
    state = AsyncValue.data(next);
  }

  void clear() {
    _bootstrapped = false;
    if (!mounted) return;
    state = const AsyncValue.data([]);
  }

  Future<void> refresh() async {
    _bootstrapped = false;
    await bootstrap();
  }

  /// R4: profil fetch'i 16ms penceresinde coalesce eder — çok-kişili realtime
  /// burst'te N member event ayrı sorgu yerine tek `.inFilter` sorgusuna iner.
  Future<Map<String, dynamic>?> _fetchProfile(String userId) =>
      _profiles.load(userId);

  WorldRole _parseRole(String s) => switch (s) {
        'dm' => WorldRole.dm,
        'player' => WorldRole.player,
        _ => WorldRole.none,
      };
}

/// Profil fetch'lerini kısa pencerede toplayıp tek `.inFilter` sorgusuna
/// indirir (R4). Çözülen profiller cache'lenir — aynı kullanıcının ardışık
/// join/update event'leri tekrar sorgu açmaz. Cache oturum ömürlü; profil
/// adı değişimleri `bootstrap(force: true)` (resubscribe) ile tazelenir.
class _ProfileBatchLoader {
  _ProfileBatchLoader(this._client);

  final SupabaseClient? _client;
  static const Duration _window = Duration(milliseconds: 16);

  final Map<String, Map<String, dynamic>?> _cache = {};
  final Map<String, List<Completer<Map<String, dynamic>?>>> _pending = {};
  Timer? _timer;
  bool _disposed = false;

  Future<Map<String, dynamic>?> load(String userId) {
    if (_disposed || _client == null) return Future.value(null);
    if (_cache.containsKey(userId)) return Future.value(_cache[userId]);
    final completer = Completer<Map<String, dynamic>?>();
    (_pending[userId] ??= []).add(completer);
    _timer ??= Timer(_window, _flush);
    return completer.future;
  }

  Future<void> _flush() async {
    _timer = null;
    if (_pending.isEmpty) return;
    final batch = Map<String, List<Completer<Map<String, dynamic>?>>>.from(
      _pending,
    );
    _pending.clear();
    final ids = batch.keys.toList();
    final byId = <String, Map<String, dynamic>>{};
    final client = _client;
    if (client != null) {
      try {
        final rows = await client
            .from('profiles')
            .select('user_id, username, display_name, avatar_url')
            .inFilter('user_id', ids);
        for (final r in rows as List) {
          final m = Map<String, dynamic>.from(r as Map);
          final uid = m['user_id'] as String?;
          if (uid != null) byId[uid] = m;
        }
      } catch (e) {
        debugPrint('_ProfileBatchLoader fetch error: $e');
      }
    }
    for (final entry in batch.entries) {
      final result = byId[entry.key];
      if (!_disposed) _cache[entry.key] = result;
      for (final c in entry.value) {
        if (!c.isCompleted) c.complete(result);
      }
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    for (final list in _pending.values) {
      for (final c in list) {
        if (!c.isCompleted) c.complete(null);
      }
    }
    _pending.clear();
    _cache.clear();
  }
}

/// Aktif world'ün üyeleri (DM hub'ı + player roster widget'ı tüketir).
/// CDC ile granular güncellenir; her join/leave'de tablo yeniden çekilmez.
final worldMembersProvider = StateNotifierProvider.family<
    WorldMembersNotifier, AsyncValue<List<WorldMember>>, String>(
  (ref, worldId) {
    final svc = ref.watch(worldMembershipServiceProvider);
    final client = SupabaseConfig.isConfigured && ref.watch(authProvider) != null
        ? Supabase.instance.client
        : null;
    final notifier = WorldMembersNotifier(ref, svc, client, worldId);
    // ignore: discarded_futures
    notifier.bootstrap();
    return notifier;
  },
);

/// Aktif world'ün aktif davet kodları (DM görür).
final worldInvitesProvider =
    FutureProvider.family<List<WorldInvite>, String>((ref, worldId) async {
  final svc = ref.watch(worldMembershipServiceProvider);
  if (svc is NoOpWorldMembershipService) return const [];
  return guardedNetwork(ref, () => svc.listInvites(worldId));
});

/// World için tek paylaşılabilir davet kodu. İlk çağrıda oluşturur,
/// sonraki çağrılarda aynı kodu döner. Regenerate sonrası invalidate
/// edilmeli.
///
/// `autoDispose`: Save & Sync dialog kapandığında cache temizlenir;
/// böylece offline → online geçişten önce null cache'lenmiş kodu
/// sonsuza kadar görmeyiz.
final worldActiveInviteCodeProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, worldId) async {
  final svc = ref.watch(worldMembershipServiceProvider);
  if (svc is NoOpWorldMembershipService) return null;
  try {
    return await guardedNetwork(ref, () => svc.ensureInvite(worldId));
  } catch (_) {
    return null;
  }
});
