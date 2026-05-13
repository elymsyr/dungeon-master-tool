import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../domain/entities/online/world_role.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';

/// Aktif worlddeki campaign id (UUID). [activeCampaignProvider] world adı
/// döner; Supabase mirror id ile çalıştığı için bu derived provider
/// `campaignInfoListProvider` üzerinden mapping yapar.
final activeCampaignIdProvider = FutureProvider<String?>((ref) async {
  final name = ref.watch(activeCampaignProvider);
  if (name == null) return null;
  final list = await ref.watch(campaignInfoListProvider.future);
  final match = list.where((c) => c.name == name).firstOrNull;
  return match?.id;
});

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
final currentWorldRoleProvider = FutureProvider<WorldRole>((ref) async {
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
});

/// Convenience: senkron access (rebuild olunca güncel). UI rol-bazlı
/// dallanma için tüketir.
WorldRole readCurrentRole(WidgetRef ref) =>
    ref.watch(currentWorldRoleProvider).valueOrNull ?? WorldRole.none;
