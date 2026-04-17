import 'package:freezed_annotation/freezed_annotation.dart';

import 'entity.dart';

part 'character.freezed.dart';
part 'character.g.dart';

/// Hub-level karakter — bir template'in Player kategorisinden üretilir.
/// Kampanyadan bağımsız olarak saklanır: `{charactersDir}/{id}.json`.
@freezed
abstract class Character with _$Character {
  const factory Character({
    required String id,
    required String templateId,
    required String templateName,
    required Entity entity,
    /// Karakterin referans alabileceği paket isimleri (sınıflar, spell listeleri
    /// vs.). Entity resolution runtime'da bu paketlerden yapılır.
    @Default(<String>[]) List<String> linkedPackages,
    /// Karakterin referans alabileceği world/campaign isimleri.
    @Default(<String>[]) List<String> linkedWorlds,
    /// Metadata — UI'da kartta ve settings'te gösterilir.
    @Default('') String coverImagePath,
    @Default('') String description,
    @Default(<String>[]) List<String> tags,
    required String createdAt,
    required String updatedAt,
  }) = _Character;

  factory Character.fromJson(Map<String, dynamic> json) =>
      _$CharacterFromJson(json);
}
