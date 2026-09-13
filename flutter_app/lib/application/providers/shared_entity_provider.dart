import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/online/world_role.dart';
import 'campaign_provider.dart';
import 'entity_share_provider.dart';
import 'online_worlds_provider.dart';
import 'pinned_entity_provider.dart' show parseEntityIdSet;
import 'role_provider.dart';

/// `world_settings.settings_json` key holding the DM-shared entity id list.
///
/// [kPinnedEntitiesKey] ile aynı gerekçe: tipli kolon değil blob anahtarı,
/// böylece marketplace publish → download ve LAN dünya senkronunda bedavaya
/// taşınır.
///
/// Bu set dünya **offline'ken de** tutulur. Orada hiçbir işe yaramaz; amacı
/// DM'in dünyayı kurarken neyin oyuncuya gideceğini önden işaretleyebilmesi.
/// Dünya online'a alındığında publish tohumu (`seedSharedContentToPlayers`)
/// tam olarak bu seti yükler — kategori/tier kuralı YOK, oyuncuya giden her
/// satır DM'in bilinçli işaretidir.
const kSharedEntitiesKey = 'shared_entities';

/// Aktif dünyada DM'in paylaşıma işaretlediği kart id'leri.
final sharedEntityIdsProvider =
    NotifierProvider<SharedEntityNotifier, Set<String>>(
        SharedEntityNotifier.new);

class SharedEntityNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(activeCampaignProvider);
    ref.watch(campaignRevisionProvider);
    final data = ref.read(activeCampaignProvider.notifier).data;
    final raw = data?[kSharedEntitiesKey];
    if (raw == null && data != null) {
      // ignore: discarded_futures
      _adoptCloudShares();
    }
    return parseEntityIdSet(raw);
  }

  /// İşareti ekler/kaldırır. Bulut satırını YAZMAZ — onu `EntitySharer`
  /// yapar; burası yalnızca DM'in niyetinin kalıcı hâli.
  Future<void> setShared(String entityId, bool shared) async {
    final next = {...state};
    final changed = shared ? next.add(entityId) : next.remove(entityId);
    if (!changed) return;
    state = next;
    await _persist(next);
  }

  Future<void> _persist(Set<String> ids) async {
    final campaign = ref.read(activeCampaignProvider.notifier);
    final list = ids.toList();
    // saveSettingsPatch in-memory aynayı ellemiyor (bkz. doc) — `_data`'yı
    // elde güncelle ki revision bump'ı eski listeyi diriltmesin.
    campaign.data?[kSharedEntitiesKey] = list;
    await campaign.saveSettingsPatch({kSharedEntitiesKey: list});
  }

  /// Tek seferlik geçiş. Anahtar yokken **zaten online** olan dünyaların
  /// gerçeği buluttaki `entity_shares` satırlarıydı (kaldırılan tier tohumu
  /// dahil). Onları bir kez yerele alırız; yoksa DM o kartları "paylaşılmamış"
  /// görür ve paylaşımı kapatamaz. Offline dünyada hiçbir şey yazılmaz —
  /// anahtarın yokluğu ile boş liste zaten aynı şey.
  Future<void> _adoptCloudShares() async {
    // Hangi dünya için başladıysak onun için bitmeli — await'ler sırasında
    // DM başka dünyaya geçerse A'nın id'lerini B'nin blob'una yazardık.
    final startedFor = ref.read(activeCampaignProvider);
    try {
      final worldId = await ref.read(activeCampaignIdProvider.future);
      if (worldId == null) return;
      if (!ref.read(onlineWorldIdsProvider).contains(worldId)) return;
      if (await ref.read(currentWorldRoleProvider.future) != WorldRole.dm) {
        return;
      }
      final shares = await ref.read(worldEntitySharesProvider(worldId).future);
      if (shares.isEmpty) return;
      if (ref.read(activeCampaignProvider) != startedFor) return;
      final ids = {for (final s in shares) s.entityId};
      state = ids;
      await _persist(ids);
    } catch (e) {
      debugPrint('shared entities adopt failed: $e');
    }
  }
}
