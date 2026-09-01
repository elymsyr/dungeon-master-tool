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

/// Guest release marker. Çıkış yapmış kullanıcının yazacak bir uid'i yok ama
/// "release" edilen karakter hub'da artık onun sayılmamalı — `null` bunu ifade
/// edemez, çünkü guest için `ownerId == null` = "benim". Tamamen yerel bir
/// işaret: [CharacterOwnership.normalizedOwnerId] buluta çıkmadan önce tekrar
/// `null`'a çevirir.
const String kGuestReleasedOwnerId = '__released__';

extension CharacterOwnership on Character {
  /// Hub char sekmesi + sidebar claim/release'in tek sahiplik predicate'i.
  /// Giriş yapılmamışken sahipsiz (`null`) karakter kullanıcınındır; guest
  /// release [kGuestReleasedOwnerId] ile bunu bozar.
  bool isOwnedBy(String? selfUid) {
    if (ownerId == kGuestReleasedOwnerId) return false;
    if (ownerId == null) return selfUid == null;
    return ownerId == selfUid;
  }

  /// Sunucuya / owner etiketine gidecek değer — guest marker'ı `null`'a maple.
  String? get normalizedOwnerId =>
      ownerId == kGuestReleasedOwnerId ? null : ownerId;
}
