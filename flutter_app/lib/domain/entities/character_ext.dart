import '../../application/providers/campaign_provider.dart' show CampaignInfo;
import 'character.dart';

/// Character display helpers. `worldName` field retire edildi — UI artık
/// `worldId` + `campaignInfoListProvider` ile dünya adını çözer.
extension CharacterDisplay on Character {
  /// `infos` listesinden bu karakterin worldId'sine karşılık gelen adı bulur.
  /// worldId null veya listede yoksa `fallback` döner (varsayılan boş).
  String resolvedWorldName(
    List<CampaignInfo> infos, {
    String fallback = '',
  }) {
    final id = worldId;
    if (id == null) return fallback;
    for (final info in infos) {
      if (info.id == id) return info.name;
    }
    return fallback;
  }
}
