import 'package:freezed_annotation/freezed_annotation.dart';

import 'encounter_layout.dart';
import 'entity_category_schema.dart';

part 'world_schema.freezed.dart';
part 'world_schema.g.dart';

/// Kampanya bazlı üst düzey şema.
/// Tüm entity kategorilerini, alan tanımlarını ve encounter layout'larını barındırır.
@freezed
abstract class WorldSchema with _$WorldSchema {
  const factory WorldSchema({
    required String schemaId,
    @Default('D&D 5e (Default)') String name,
    @Default('1.0.0') String version,
    String? baseSystem,
    @Default('') String description,
    @Default([]) List<EntityCategorySchema> categories,
    @Default([]) List<EncounterLayout> encounterLayouts,
    @Default({}) Map<String, dynamic> metadata,
    required String createdAt,
    required String updatedAt,
  }) = _WorldSchema;

  factory WorldSchema.fromJson(Map<String, dynamic> json) =>
      _$WorldSchemaFromJson(json);
}
