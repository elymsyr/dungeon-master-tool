import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../domain/entities/online/world_role.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';

/// Aktif worlddeki campaign id (UUID). [activeCampaignProvider] world adı
/// döner; Supabase mirror id ile çalıştığı için bu derived provider
/// `campaignInfoListProvider` üzerinden mapping yapar.
///
/// Fast path: when the active world's `_data` is already loaded, its
/// `world_id` field is the canonical id — return it without awaiting
/// `campaignInfoListProvider` (which round-trips the worlds table). This
/// keeps the post-flip route render path off the DB during the optimistic
/// open from `worlds_tab` (B1).
final activeCampaignIdProvider = FutureProvider<String?>(
  dependencies: [activeCampaignProvider, campaignRevisionProvider],
  (ref) async {
    final name = ref.watch(activeCampaignProvider);
    if (name == null) return null;
    // Bump on data populate so this provider re-resolves once `_data` lands.
    ref.watch(campaignRevisionProvider);
    final loaded = ref.read(activeCampaignProvider.notifier).data;
    final fastId = loaded?['world_id'] as String?;
    if (fastId != null && fastId.isNotEmpty) return fastId;
    final list = await ref.watch(campaignInfoListProvider.future);
    final match = list.where((c) => c.name == name).firstOrNull;
    return match?.id;
  },
);

/// Aktif worlddeki kullanıcı rolü.
///
/// Mantık:
/// - Aktif campaign yoksa → none
/// - Supabase yapılandırılmamış veya auth yoksa → none (lokal-only = DM mod
///   gibi davranır; UI sidebar/tab seçimi none'ı DM olarak ele alır)
/// - world_members.role lookup → 'dm' veya 'player'
/// - Üye değilse → none (worlds tablosunda yok = offline world)
///
/// Sonuç stream'i: campaign veya auth değişince invalidate.
final currentWorldRoleProvider = FutureProvider<WorldRole>(
  dependencies: [activeCampaignIdProvider],
  (ref) async {
    if (!SupabaseConfig.isConfigured) return WorldRole.none;
  final auth = ref.watch(authProvider);
  if (auth == null) return WorldRole.none;
  final campaignId = await ref.watch(activeCampaignIdProvider.future);
  if (campaignId == null) return WorldRole.none;

  try {
    final row = await Supabase.instance.client
        .from('world_members')
        .select('role')
        .eq('world_id', campaignId)
        .eq('user_id', auth.uid)
        .maybeSingle();
    if (row == null) return WorldRole.none;
    return switch (row['role'] as String?) {
      'dm' => WorldRole.dm,
      'player' => WorldRole.player,
      _ => WorldRole.none,
    };
  } catch (_) {
    // Network/permission hatası: lokal davran (offline edit modu).
    return WorldRole.none;
  }
  },
);

/// Convenience: senkron access (rebuild olunca güncel). UI rol-bazlı
/// dallanma için tüketir.
WorldRole readCurrentRole(WidgetRef ref) =>
    ref.watch(currentWorldRoleProvider).valueOrNull ?? WorldRole.none;

/// Belirli bir worldId için rol — aktif campaign'e bağlı değil. Hub'daki
/// world settings dialog'u (campaign load edilmeden açılır) tüketir.
final worldRoleProvider =
    FutureProvider.family<WorldRole, String>((ref, worldId) async {
  if (!SupabaseConfig.isConfigured) return WorldRole.none;
  final auth = ref.watch(authProvider);
  if (auth == null) return WorldRole.none;
  try {
    final row = await Supabase.instance.client
        .from('world_members')
        .select('role')
        .eq('world_id', worldId)
        .eq('user_id', auth.uid)
        .maybeSingle();
    if (row == null) return WorldRole.none;
    return switch (row['role'] as String?) {
      'dm' => WorldRole.dm,
      'player' => WorldRole.player,
      _ => WorldRole.none,
    };
  } catch (_) {
    return WorldRole.none;
  }
});
