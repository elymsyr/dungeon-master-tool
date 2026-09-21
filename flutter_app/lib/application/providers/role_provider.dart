import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../domain/entities/online/world_role.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';

/// Aktif dünyanın id'si (UUID).
///
/// Faz 2.5'ten beri [activeCampaignProvider] zaten id tutuyor, yani burada
/// çözülecek bir şey kalmadı. Provider **kaldırılmadı**: 20 küsur çağrı yeri
/// `.valueOrNull` / `.future` ile okuyor ve bu tip onlarda değişmedi.
final activeCampaignIdProvider = FutureProvider<String?>(
  dependencies: [activeCampaignProvider],
  (ref) async => ref.watch(activeCampaignProvider),
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

/// Açılış-anı rol ipucu. `worlds_tab._loadCampaign` worlds listesindeki
/// önceden cache'lenmiş [worldRoleProvider] değerinden seed eder; böylece
/// MainScreen, `currentWorldRoleProvider` async resolve olurken İLK
/// frame'de player/DM shell'ini doğru seçer — DM→player flash olmaz.
/// `currentWorldRoleProvider` resolve olunca gerçek değer kazanır; bu
/// ipucu yalnızca onun loading penceresinde tüketilir.
final worldRoleHintProvider = StateProvider<WorldRole?>((ref) => null);

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

/// Oyuncu görünümü mü? Kart render'ının dmOnly alanları ve DM Notes'u
/// kesmesi için tek kapı.
///
/// Rol çözülürken [worldRoleHintProvider]'a düşer: aksi hâlde
/// `currentWorldRoleProvider` resolve olana dek oyuncuya bir frame boyunca
/// DM içeriği çizilirdi. Belirsizlik oyuncu lehine yorumlanır — DM için
/// yanlış bir gizleme geri dönüşü olan bir hata, tersi değil.
final isPlayerViewProvider = Provider<bool>(
  dependencies: [currentWorldRoleProvider, worldRoleHintProvider],
  (ref) {
    final role = ref.watch(currentWorldRoleProvider).valueOrNull;
    if (role == WorldRole.player) return true;
    if (role == WorldRole.dm) return false;
    return ref.watch(worldRoleHintProvider) == WorldRole.player;
  },
);
