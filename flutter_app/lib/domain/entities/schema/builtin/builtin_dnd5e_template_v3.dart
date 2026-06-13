import '../field_schema.dart';
import '../world_schema.dart';
import 'builtin_dnd5e_v2_schema.dart';

/// Schema id for the v3 dynamic Template (Template & Package architecture,
/// roadmap §1.2). Distinct lineage from the v2 embedded schema
/// ([builtinDnd5eV2SchemaId]) so the two coexist during the per-world
/// dual-stack migration: v2 worlds keep resolving on the frozen old engine
/// until migrated, v3 worlds run on the new infrastructure (roadmap §1.4).
const builtinDnd5eV3SchemaId = 'builtin-dnd5e-default-v3';

/// Globally stable lineage identifier for the v3 built-in template. Frozen
/// forever; world/template copies preserve it (fresh `schemaId`, preserved
/// `originalHash`) so the dual-hash drift-detection machinery keeps matching
/// a copy back to its built-in ancestor (the-template-system §5.2).
const builtinDnd5eV3OriginalHash = 'builtin-dnd5e-default-v3';

/// Asset path of the exported built-in template JSON. Single source of truth
/// for both the one-shot exporter (`tool/export_builtin_template.dart`) and
/// the runtime [BuiltinTemplateLoader]. Registered in `pubspec.yaml` under
/// the `assets/templates/` directory.
const builtinDnd5eTemplateAssetPath =
    'assets/templates/dnd5e_srd.template.json';

/// Deterministic timestamp stamped on the exported v3 template so re-running
/// the exporter yields a BYTE-IDENTICAL asset (idempotent export — a clean
/// `git diff` proves the asset is in sync with the generator). `createdAt`/
/// `updatedAt` are volatile fields excluded from `computeWorldSchemaContentHash`,
/// so this value never affects drift detection — it only keeps the committed
/// asset stable across export runs.
const builtinDnd5eTemplateTimestamp = '2026-06-10T00:00:00.000Z';

/// Builds the v3 built-in D&D 5e [WorldSchema] (Template `formatVersion` 3) by
/// evolving the v2 generator output IN PLACE — not replacing it
/// (the-template-system §1, roadmap §1.2). The transform is intentionally
/// small and deterministic:
///
///   * `formatVersion` → 3; `schemaId`/`originalHash` → the v3 lineage;
///     `version` → `3.0.0`; `name` → `D&D 5e (Default)`.
///   * Tier-0 lookup `seedRows` are LIFTED out of the generator's typed
///     side-channel ([BuiltinDnd5eV2Build.seedRows]) and embedded into the
///     template itself ([liftSeedRows]) so it is self-contained — a custom
///     template with different abilities carries its own lookup rows. Only
///     non-empty catalogs are embedded (Tier-1 content shapes and Tier-2 DM
///     categories ship shape only). `computeWorldSchemaContentHash` folds the
///     embedded `seedRows` into the content hash.
///   * **RULE RESET (roadmap §1.1 shift 1):** every field's `rules` stays
///     absent (`null` → omitted via `includeIfNull:false`). The template is
///     fully rule-free; the first rule-assigned field lands just-in-time in a
///     Phase 3 conversion wave. Emitting `null` rather than a literal `[]` is
///     deliberate — it keeps each field's JSON byte-identical to its v2 form,
///     so the only hash delta from v2→v3 is the embedded `seedRows` (and the
///     hash-excluded structural markers). "Zero rule-assigned fields" is the
///     binding contract; the empty/absent distinction is cosmetic.
///
/// **PR-2.3 PC-category parity type swap (this slice):** the Player Character
/// category's v2 field types are migrated to their v3 equivalents IN THE v3
/// GENERATOR ONLY — the v2 schema ([generateBuiltinDnd5eV2Schema], the shared
/// `dm.dart` `_playerCharacterCategory`) stays frozen so existing v2 worlds
/// keep resolving on the old engine (dual-stack invariant, roadmap §1.4). Only
/// the **wire-identical** renames land here (content-convert §1 — value-
/// preserving no-ops needing no card migration): `statBlock` →
/// `abilityScoreTable`, `combatStats` → `combatStatsTable`, `proficiencyTable`
/// → `skillTree`, `spellSlotGrid` → `pouchMatrix`. Each gains the `typeConfig`
/// the v3 renderers + editor forms read ([pcFieldTypeSwaps]). The genuinely-NEW
/// conversions that need a value migration — death-save/heroic-inspiration
/// integers → `checkboxPouch` (int `n` → `{count, states}`) and the
/// `actionButton` rest/level-up fields that retire the hardcoded
/// `_renderRestActions` row — are the NEXT slice (they ship with the world-open
/// value-migration shim so neither side is half-built).
///
/// This is the SINGLE SOURCE OF TRUTH consumed by both the exporter and the
/// loader's hash-equality assert, so the on-disk asset and the in-code
/// generator can never silently diverge.
WorldSchema generateBuiltinDnd5eTemplateV3() {
  final build = generateBuiltinDnd5eV2Schema();
  final base = build.schema.copyWith(
    schemaId: builtinDnd5eV3SchemaId,
    formatVersion: 3,
    name: 'D&D 5e (Default)',
    version: '3.0.0',
    originalHash: builtinDnd5eV3OriginalHash,
    seedRows: liftSeedRows(build.seedRows),
    createdAt: builtinDnd5eTemplateTimestamp,
    updatedAt: builtinDnd5eTemplateTimestamp,
  );
  return swapPlayerCharacterFieldTypes(base);
}

/// Slug of the built-in Player Character category (set in `dm.dart`
/// `_playerCharacterCategory`). The parity type swap is keyed off this so the
/// transform finds the right category regardless of its generated `categoryId`.
const builtinPlayerCharacterSlug = 'player-character';

/// The PC-category parity type swaps: `fieldKey` → (v3 [FieldType], `typeConfig`).
///
/// **RULE-FREE:** these carry `typeConfig` only — never `rules` (roadmap §1.1
/// rule reset; the first rule-assigned field lands in a Phase 3 JIT wave). The
/// `typeConfig` shapes mirror `defaultTypeConfig` in `template_editor_provider`
/// (the-template-system §2.3) and satisfy the editor's completeness validator,
/// so a copy of the built-in opens immediately editable.
///
/// The value wire is **byte-identical** before/after each rename, so no card
/// migration runs:
///   * `abilityScoreTable` columns use **UPPERCASE** keys (`STR`…`CHA`) to match
///     the stored `{"STR":10,…}` stat-block value verbatim.
///   * `combatStatsTable.visibleKeys` lists only canonical PC stats (the
///     monster-only `cr` sub-field is dropped from the visible set — the stored
///     value map is untouched).
///   * `skillTree` reuses the proficiency-table `{name,ability,proficient,
///     expertise,misc}` rows unchanged.
///   * `pouchMatrix` reuses the `{max{},remaining{}}` spell-slot wire; the
///     renderer derives its rows from `max.keys`, so `rowKeys` is advisory.
const Map<String, ({FieldType type, Map<String, dynamic> typeConfig})>
    pcFieldTypeSwaps = {
  'stat_block': (
    type: FieldType.abilityScoreTable,
    typeConfig: {
      'columns': [
        {'key': 'STR', 'label': 'STR'},
        {'key': 'DEX', 'label': 'DEX'},
        {'key': 'CON', 'label': 'CON'},
        {'key': 'INT', 'label': 'INT'},
        {'key': 'WIS', 'label': 'WIS'},
        {'key': 'CHA', 'label': 'CHA'},
      ],
      'modifierBase': 10,
      'modifierStep': 2,
      'publishAspects': true,
    },
  ),
  'combat_stats': (
    type: FieldType.combatStatsTable,
    typeConfig: {
      'visibleKeys': ['hp', 'max_hp', 'ac', 'speed', 'level', 'initiative', 'xp'],
    },
  ),
  'saving_throws': (
    type: FieldType.skillTree,
    typeConfig: {
      'abilityFieldKey': 'stat_block',
      'proficiencyBonusAspect': 'prof_bonus',
      'rowSeed': 'ability',
      // Saving throws are proficient-only — no expertise tier in 5e.
      'tiers': ['proficient'],
    },
  ),
  'skills': (
    type: FieldType.skillTree,
    typeConfig: {
      'abilityFieldKey': 'stat_block',
      'proficiencyBonusAspect': 'prof_bonus',
      'rowSeed': 'skill',
      'tiers': ['proficient', 'expertise'],
    },
  ),
  'class_resources': (
    type: FieldType.skillTree,
    typeConfig: {
      'abilityFieldKey': 'stat_block',
      'proficiencyBonusAspect': 'prof_bonus',
      'rowSeed': 'skill',
      'tiers': ['proficient', 'expertise'],
    },
  ),
  'spell_slots': (
    type: FieldType.pouchMatrix,
    typeConfig: {
      'rowKeys': ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
      'rowLabelPrefix': 'Level ',
      'maxSource': {'kind': 'manual'},
    },
  ),
};

/// Rewrites the Player Character category's wire-identical v2 field types to
/// their v3 equivalents ([pcFieldTypeSwaps]), attaching each type's
/// `typeConfig`. Every other category (and every other field) is returned
/// untouched — the swap is deliberately scoped to the PC sheet (roadmap PR-T6,
/// the Phase-2 screenshot gate). Idempotent and value-preserving: a field
/// already carrying the v3 type is left as-is, and no `defaultValue`/`subFields`
/// (the stored value wire) is altered.
WorldSchema swapPlayerCharacterFieldTypes(WorldSchema schema) {
  final categories = [
    for (final category in schema.categories)
      if (category.slug == builtinPlayerCharacterSlug)
        category.copyWith(
          fields: [
            for (final field in category.fields)
              if (pcFieldTypeSwaps.containsKey(field.fieldKey))
                field.copyWith(
                  fieldType: pcFieldTypeSwaps[field.fieldKey]!.type,
                  typeConfig: pcFieldTypeSwaps[field.fieldKey]!.typeConfig,
                )
              else
                field,
          ],
        )
      else
        category,
  ];
  return schema.copyWith(categories: categories);
}

/// Converts the generator's strongly-typed seed-row side-channel
/// (`Map<slug, List<rowMap>>`) into the template's embedded `seedRows` map
/// (`Map<String, dynamic>`, mirroring `metadata` for JSON robustness). Empty
/// categories — Tier-1 content shapes and Tier-2 DM categories, which carry no
/// built-in rows — are dropped so the embedded map holds only the Tier-0
/// lookup catalogs and the asset stays lean.
Map<String, dynamic> liftSeedRows(
  Map<String, List<Map<String, dynamic>>> seedRows,
) {
  return <String, dynamic>{
    for (final entry in seedRows.entries)
      if (entry.value.isNotEmpty) entry.key: entry.value,
  };
}
