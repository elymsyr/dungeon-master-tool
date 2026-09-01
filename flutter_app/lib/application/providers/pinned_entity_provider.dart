import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'campaign_provider.dart';

/// `world_settings.settings_json` key holding the pinned entity id list.
///
/// Lives in the settings blob (not a typed column) so it rides along for
/// free everywhere a world payload travels: marketplace publish →
/// download (`load()` spreads unknown top-level keys, `save()` folds them
/// back into the blob) and cloud/LAN world sync (the key is not in
/// `_settingsApplyBlocklist`). Pins are world-wide, not per-device —
/// that's the point: a downloaded world keeps the author's pins.
const kPinnedEntitiesKey = 'pinned_entities';

Set<String> parsePinnedEntities(dynamic raw) => {
      if (raw is List)
        for (final e in raw)
          if (e is String) e,
    };

/// Pinned entity ids of the active world. Sidebar sorts these to the top.
final pinnedEntityIdsProvider =
    NotifierProvider<PinnedEntityNotifier, Set<String>>(
        PinnedEntityNotifier.new);

class PinnedEntityNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(activeCampaignProvider);
    ref.watch(campaignRevisionProvider);
    final data = ref.read(activeCampaignProvider.notifier).data;
    return parsePinnedEntities(data?[kPinnedEntitiesKey]);
  }

  Future<void> toggle(String entityId) async {
    final next = {...state};
    if (!next.remove(entityId)) next.add(entityId);
    state = next;
    final campaign = ref.read(activeCampaignProvider.notifier);
    final list = next.toList();
    // saveSettingsPatch doesn't touch the in-memory mirror (see its doc) —
    // keep `_data` in sync so a revision bump doesn't resurrect old pins.
    campaign.data?[kPinnedEntitiesKey] = list;
    await campaign.saveSettingsPatch({kPinnedEntitiesKey: list});
  }
}
