import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
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
  final WorldMembershipService _service;
  final SupabaseClient? _client;
  final String worldId;
  bool _bootstrapped = false;

  WorldMembersNotifier(this._service, this._client, this.worldId)
      : super(const AsyncValue.loading());

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
      final rows = await _service
          .listMembers(worldId)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      state = AsyncValue.data(rows);
    } catch (e, st) {
      debugPrint('WorldMembersNotifier bootstrap error: $e');
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

  Future<Map<String, dynamic>?> _fetchProfile(String userId) async {
    final client = _client;
    if (client == null) return null;
    try {
      final rows = await client
          .from('profiles')
          .select('user_id, username, display_name, avatar_url')
          .eq('user_id', userId)
          .limit(1);
      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
    } catch (e) {
      debugPrint('WorldMembersNotifier profile fetch error: $e');
    }
    return null;
  }

  WorldRole _parseRole(String s) => switch (s) {
        'dm' => WorldRole.dm,
        'player' => WorldRole.player,
        _ => WorldRole.none,
      };
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
    final notifier = WorldMembersNotifier(svc, client, worldId);
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
