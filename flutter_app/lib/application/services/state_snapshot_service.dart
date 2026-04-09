import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/events/game_snapshot.dart';
import '../providers/campaign_provider.dart';
import '../providers/combat_provider.dart';

const _uuid = Uuid();

/// Tüm oyun state'inin snapshot'ını alır/restore eder.
/// "DM as Source of Truth" sync mekanizmasının altyapısı.
///
/// Capture stratejisi: tüm notifier'ların state'i campaign.data dict'ine
/// sync edildiğinden (debounced save), capture sırasında campaign.data
/// okunarak güvenilir bir snapshot elde edilir.
abstract final class StateSnapshotService {
  /// Aktif kampanyanın full state snapshot'ını oluştur.
  static GameSnapshot? capture(WidgetRef ref) {
    final campaign = ref.read(activeCampaignProvider.notifier);
    final data = campaign.data;
    if (data == null) return null;

    // Combat state'i en güncel haline sync et (memory'deki notifier state'i
    // henüz campaign.data'ya yazılmamış olabilir).
    final combatNotifier = ref.read(combatProvider.notifier);
    data['combat_state'] = combatNotifier.getSessionState();

    return GameSnapshot(
      campaignId: data['world_id'] as String? ?? '',
      snapshotId: _uuid.v4(),
      capturedAt: DateTime.now().toUtc(),
      entities:
          Map<String, dynamic>.from(data['entities'] as Map? ?? {}),
      combatState:
          Map<String, dynamic>.from(data['combat_state'] as Map? ?? {}),
      mapData: Map<String, dynamic>.from(data['map_data'] as Map? ?? {}),
      mindMaps:
          Map<String, dynamic>.from(data['mind_maps'] as Map? ?? {}),
    );
  }

  /// Snapshot'tan state'i geri yükle (player tarafı için).
  /// Şu an stub — Player rolü implementasyonu gelecekte.
  static void restore(WidgetRef ref, GameSnapshot snapshot) {
    final campaign = ref.read(activeCampaignProvider.notifier);
    final data = campaign.data;
    if (data == null) return;

    data['entities'] = Map<String, dynamic>.from(snapshot.entities);
    data['combat_state'] = Map<String, dynamic>.from(snapshot.combatState);
    data['map_data'] = Map<String, dynamic>.from(snapshot.mapData);
    data['mind_maps'] = Map<String, dynamic>.from(snapshot.mindMaps);
  }
}
