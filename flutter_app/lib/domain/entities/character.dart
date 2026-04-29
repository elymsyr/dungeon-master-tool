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
    /// Karakterin bağlı olduğu world (campaign) adı. Boş ise orphan:
    /// kullanıcı editorde world seçene kadar bazı özellikler kapalı kalır.
    @Default('') String worldName,
    /// Karakterin sahibi olan user'ın Supabase uid'si. DM tarafından
    /// oluşturulan karakterler için null bırakılır (DM-owned implicit).
    /// User-side flow eklendiğinde creator'ın uid'si yazılır.
    @Default(null) String? ownerId,
    required String createdAt,
    required String updatedAt,
  }) = _Character;

  factory Character.fromJson(Map<String, dynamic> json) =>
      _$CharacterFromJson(json);
}
