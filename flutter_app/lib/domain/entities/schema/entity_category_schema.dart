import 'package:freezed_annotation/freezed_annotation.dart';

import 'category_rule.dart';
import 'field_group.dart';
import 'field_schema.dart';

part 'entity_category_schema.freezed.dart';
part 'entity_category_schema.g.dart';

/// Bir entity kategorisinin tanımı (NPC, Monster, Spell, ... veya custom).
@freezed
abstract class EntityCategorySchema with _$EntityCategorySchema {
  const factory EntityCategorySchema({
    required String categoryId,
    required String schemaId,
    required String name,
    required String slug,
    @Default('') String icon,
    @Default('#808080') String color,
    @Default(false) bool isBuiltin,
    @Default(false) bool isArchived,
    @Default(0) int orderIndex,
    @Default([]) List<FieldSchema> fields,
    /// Hangi uygulama bölümlerinde kullanılabilir: 'encounter', 'mindmap', 'worldmap', 'projection'
    @Default([]) List<String> allowedInSections,
    /// Sidebar'da filtre olarak gösterilecek alan key'leri (ör. ['rarity', 'level'])
    @Default([]) List<String> filterFieldKeys,
    /// Template seviyesinde kurallar
    @Default([]) List<CategoryRule> rules,
    /// Alan grupları — field'ları görsel olarak gruplar, grid layout destekler
    @Default([]) List<FieldGroup> fieldGroups,
    required String createdAt,
    required String updatedAt,
  }) = _EntityCategorySchema;

  factory EntityCategorySchema.fromJson(Map<String, dynamic> json) =>
      _$EntityCategorySchemaFromJson(json);
}
