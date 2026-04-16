import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../data/schema/rule_migration_v2.dart';
import 'field_group.dart';
import 'field_schema.dart';
import 'rule_v2.dart';

part 'entity_category_schema.freezed.dart';
part 'entity_category_schema.g.dart';

/// Eski CategoryRule → yeni RuleV2 formatına otomatik dönüşüm yapan converter.
/// JSON'da `ruleType` key'i varsa eski format, `when` key'i varsa yeni format.
class RulesJsonConverter implements JsonConverter<List<RuleV2>, List<dynamic>> {
  const RulesJsonConverter();

  @override
  List<RuleV2> fromJson(List<dynamic> json) {
    if (json.isEmpty) return [];

    final first = json.first;
    if (first is Map && first.containsKey('ruleType')) {
      // Eski format — migrate et
      return RuleMigrationV2.migrateRules(json);
    }

    // Yeni format
    return json
        .map((e) => RuleV2.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  List<dynamic> toJson(List<RuleV2> rules) {
    return rules.map((r) => r.toJson()).toList();
  }
}

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
    /// Template seviyesinde kurallar (v2)
    @RulesJsonConverter() @Default([]) List<RuleV2> rules,
    /// Alan grupları — field'ları görsel olarak gruplar, grid layout destekler
    @Default([]) List<FieldGroup> fieldGroups,
    required String createdAt,
    required String updatedAt,
  }) = _EntityCategorySchema;

  factory EntityCategorySchema.fromJson(Map<String, dynamic> json) =>
      _$EntityCategorySchemaFromJson(json);
}
