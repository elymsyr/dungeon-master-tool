import 'package:freezed_annotation/freezed_annotation.dart';

import 'encounter_config.dart';
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
    /// Template format version. `2` = legacy embedded schema (hardcoded
    /// built-in lineage; rules live on entity cards). `3` = dynamic Template
    /// (per-field `typeConfig` + `rules`, embedded `seedRows`). Defaults to
    /// `2` so schemas persisted before this field load as legacy and keep
    /// resolving on the frozen old engine (per-world dual-stack authority,
    /// roadmap §1.4). NOT folded into the content hash — it is a structural
    /// marker, like `version`, and excluded so flipping it never spuriously
    /// drifts every dependent campaign.
    @Default(2) int formatVersion,
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
    /// Template v3 — Tier-0 seed/lookup rows embedded in the template
    /// (abilities, skills, conditions, damage types, senses, languages, …),
    /// keyed by category slug: `Map<slug, List<rowMap>>` (stored as
    /// `dynamic` for JSON robustness, mirroring `metadata`). These are not
    /// world content — they are what the system needs to function, so a
    /// self-contained template carries them instead of reading them from
    /// `lookups.dart`. Null/absent for v2 schemas; populated when the
    /// built-in is exported to v3 (PR-1.3). `includeIfNull: false` keeps it
    /// out of the JSON (and the content hash) for pre-v3 schemas so they
    /// hash byte-identically and never spuriously drift.
    @JsonKey(includeIfNull: false)
    @Default(null) Map<String, dynamic>? seedRows,
  }) = _WorldSchema;

  factory WorldSchema.fromJson(Map<String, dynamic> json) =>
      _$WorldSchemaFromJson(json);
}
