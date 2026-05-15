import 'package:freezed_annotation/freezed_annotation.dart';

import 'entity.dart';

part 'character.freezed.dart';
part 'character.g.dart';

/// Hub-level karakter — bir template'in Player kategorisinden üretilir.
/// Kampanyadan bağımsız olarak saklanır: `{charactersDir}/{id}.json`.
///
/// Her karakter bir world'e (campaign) bağlanır; class/spell/equipment/traits
/// gibi entity'leri o world'ün entities'inden çözer. Boş `worldName` =
/// migration sırasında world bilgisi kaybedilen orphan karakter.
@freezed
abstract class Character with _$Character {
  const factory Character({
    required String id,
    required String templateId,
    required String templateName,
    /// Entity base modelinde name/description/tags/imagePath zaten var —
    /// character metadata bu alanlarda saklanır, böylece entity_card ile
    /// aynı field'ları paylaşırız.
    required Entity entity,
    /// Karakterin bağlı olduğu world (campaign) adı. DEPRECATED — PR3/PR4'te
    /// `worldId` ile değiştirilecek. Şimdilik UI ve mevcut filter'lar için
    /// paralel tutuluyor; cloud `world_characters.world_id` ile name lookup
    /// arasındaki tutarsızlık (world rename'i sessizce kopuyor) `worldId`
    /// üzerine taşındığında düzelir.
    @Default('') String worldName,
    /// Karakterin bağlı olduğu world id'si (Supabase `world_characters.world_id`
    /// + local `Campaigns.id`). NULL = orphan (worldsuz). 039 migration sonrası
    /// kanon link bu alandır. `worldName` paralel set edilir (PR2 deprecation
    /// window).
    @Default(null) String? worldId,
    /// Karakterin sahibi olan user'ın Supabase uid'si. NULL = unclaimed
    /// (world içinde DM tarafından oluşturulup release edilmiş veya leave/kick
    /// trigger'la düşmüş). Auth-always invariant altında orphan karakterler
    /// her zaman owner'lıdır — `(NULL, NULL)` durumu DB-level CHECK ile yasak.
    @Default(null) String? ownerId,
    required String createdAt,
    required String updatedAt,
  }) = _Character;

  factory Character.fromJson(Map<String, dynamic> json) =>
      _$CharacterFromJson(json);
}
