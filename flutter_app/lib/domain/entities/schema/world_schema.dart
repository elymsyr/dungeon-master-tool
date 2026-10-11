// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'encounter_config.dart';
import 'encounter_layout.dart';
import 'entity_category_schema.dart';
import 'field_schema.dart';

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
    @Default(EncounterConfig()) EncounterConfig encounterConfig,
    @Default({}) Map<String, dynamic> metadata,
    required String createdAt,
    required String updatedAt,
    /// Content hash of THIS template at the moment of its very first
    /// creation — frozen forever. Two templates with the same originalHash
    /// share a lineage; edits afterward update [computeWorldSchemaContentHash]
    /// (the "current" hash) but never this field. Because it is computed
    /// purely from canonical JSON of gameplay-affecting fields, two
    /// installs that generate the same template (e.g., the built-in D&D 5e
    /// default) end up with the same originalHash — i.e., it is global,
    /// not per-install. Nullable for legacy templates persisted before
    /// this field landed; lazily backfilled on next save.
    String? originalHash,
    /// Set only on free templates (docs/free-template/DESIGN.md §6.2): the
    /// schemaId this lineage started from — the built-in id for SRD copies,
    /// the template's own id when it was created empty. Copies keep it.
    /// Read through `isFreeTemplate`.
    @JsonKey(includeIfNull: false) String? freeRootId,
    /// Free templates only: presets (DESIGN §9) — fields set up once and
    /// added to many categories; a bound field names its preset in
    /// `FieldSchema.presetId`. Read through `template_edit.dart`.
    @JsonKey(includeIfNull: false) List<FieldSchema>? presets,
  }) = _WorldSchema;

  factory WorldSchema.fromJson(Map<String, dynamic> json) =>
      _$WorldSchemaFromJson(json);
}
