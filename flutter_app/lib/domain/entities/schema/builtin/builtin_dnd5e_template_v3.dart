import '../../../services/template_migration/legacy_content_converter.dart';
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
/// the v3 renderers + editor forms read ([pcFieldTypeSwaps]).
///
/// **PR-2.3 slice B (this slice) — value-migrating pip swap.** The three death-
/// save / heroic-inspiration `integer` fields are converted to `checkboxPouch`
/// ([pcPipFieldSwaps]). Unlike the parity renames above this is NOT wire-
/// identical: the v2 value is a clamped `0..3` integer, the v3 value is the
/// `{count, states}` pouch wire. The field's `defaultValue` is migrated here via
/// the shared, idempotent shim ([migratePipIntToCheckboxPouch],
/// content-convert §2), and the SAME shim migrates existing card values at
/// world-open — so neither the template nor stored content is ever half-built.
///
/// **PR-2.3 slice B part 2 (this slice) — the `actionButton` header fields.**
/// The three genuinely-NEW `actionButton` fields ([pcActionButtonFields] —
/// level-up / short-rest / long-rest, `placement: header`) are appended to the
/// Player Character category. They RETIRE the hardcoded `_renderRestActions`
/// row in `character_editor_screen.dart`: the sheet now hoists every header-
/// placed `actionButton` field into its action row (the slice-3b `onAction` ->
/// `_runCardAction` seam), falling back to the legacy hardcoded row only for a
/// v2 schema that carries no such field (dual-stack, roadmap §1.4).
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
  final v3 = swapPlayerCharacterFieldTypes(base);
  // STATIC-FIELD PRESERVATION CHECKPOINT (roadmap PR-2.3; prompt §4 retention
  // policy). Enforce — not just claim — that the v2->v3 transform never drops,
  // retypes, or value-mutates a player-facing narrative/static-text field.
  // Runs under `assert` so it gates debug/test builds (the same discipline as
  // the editor's validator) at zero release cost. Computed over the live schema
  // so the audit can never silently drift from the source.
  assert(() {
    auditStaticFieldPreservation(build.schema, v3);
    return true;
  }());
  return v3;
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

/// The PC-category **pip** fields converted from v2 `integer` to v3
/// `checkboxPouch` (content-convert §2 — a VALUE-MIGRATING swap, distinct from
/// the wire-identical [pcFieldTypeSwaps]). Death-save successes/failures and
/// heroic inspiration were stored as a clamped `0..3` integer and rendered as a
/// 3-checkbox widget; the v3 sheet renders them as `checkboxPouch` pips
/// (`{count, states}`). [swapPlayerCharacterFieldTypes] rewrites the field type,
/// attaches [pcPipTypeConfig], migrates the `defaultValue` through the shared
/// idempotent shim ([migratePipIntToCheckboxPouch]), and clears the now-
/// meaningless integer `minValue`/`maxValue` validation (field-cleanup policy).
const pcPipFieldKeys = <String>{
  'death_saves_successes',
  'death_saves_failures',
  'heroic_inspiration',
};

/// The fixed pip count for every built-in PC pip field — three death-save
/// successes / failures (5e: three of either ends the save) and three heroic-
/// inspiration charges (the v2 `max: 3` bound).
const pcPipCount = 3;

/// `checkboxPouch` `typeConfig` for the built-in pip fields: a fixed three-pip
/// count (so a copied template can't shrink the death-save track) rendered in
/// the `pips` style. Mirrors `defaultTypeConfig(FieldType.checkboxPouch)` in
/// `template_editor_provider` and satisfies its completeness validator, so a
/// copy of the built-in opens immediately editable.
const pcPipTypeConfig = <String, dynamic>{
  'countSource': {'kind': 'fixed', 'value': pcPipCount},
  'style': 'pips',
};

/// The PC-category `actionButton` header fields (the-template-system §2.3),
/// appended to the Player Character category by [swapPlayerCharacterFieldTypes].
/// Each entry is `(fieldKey, label, action)`; `action` is the closed verb set
/// (`level_up | short_rest | long_rest`) and the editable `label` matches the
/// legacy `_renderRestActions` button text exactly (pixel parity — the Phase-2
/// screenshot gate).
///
/// **RULE-FREE (roadmap §1.1):** they carry `typeConfig` only —
/// `{action, placement:'header'}`. What a button *does to a pouch* is declared
/// on the target pouch field via an `on_button` rule (the-template-system §2.3
/// `actionButton`), a Phase-3 JIT wave — never on the button itself. The
/// `placement:'header'` hint tells the PC sheet to hoist them into the header
/// action row (retiring the hardcoded `_renderRestActions`), and tells the
/// sheet's `_renderSchemaFields` to skip them inline so they never double-render.
const pcActionButtonFields = <({String key, String label, String action})>[
  (key: 'level_up', label: 'Level Up', action: 'level_up'),
  (key: 'short_rest', label: 'Short Rest', action: 'short_rest'),
  (key: 'long_rest', label: 'Long Rest', action: 'long_rest'),
];

/// Rewrites the Player Character category's wire-identical v2 field types to
/// their v3 equivalents ([pcFieldTypeSwaps]), attaching each type's
/// `typeConfig`, and appends the three [pcActionButtonFields] header buttons.
/// Every other category (and every other field) is returned untouched — the
/// swap is deliberately scoped to the PC sheet (roadmap PR-T6, the Phase-2
/// screenshot gate). Idempotent and value-preserving: a field already carrying
/// the v3 type is left as-is, no `defaultValue`/`subFields` (the stored value
/// wire) is altered, and an already-appended action button (matched by
/// `fieldKey`) is not duplicated.
WorldSchema swapPlayerCharacterFieldTypes(WorldSchema schema) {
  final categories = [
    for (final category in schema.categories)
      if (category.slug == builtinPlayerCharacterSlug)
        category.copyWith(
          fields: _swapAndAppendPcFields(category.categoryId, category.fields),
        )
      else
        category,
  ];
  return schema.copyWith(categories: categories);
}

/// Swaps each PC field type ([_swapPcField]) and appends the
/// [pcActionButtonFields] header buttons after the last existing field.
/// Idempotent: a button whose `fieldKey` is already present (re-run) is
/// skipped, so re-evolving an already-v3 category is a byte-identical no-op.
List<FieldSchema> _swapAndAppendPcFields(
  String categoryId,
  List<FieldSchema> fields,
) {
  final swapped = [for (final field in fields) _swapPcField(field)];
  final existingKeys = {for (final f in swapped) f.fieldKey};
  var nextOrder = swapped.fold<int>(
        0,
        (max, f) => f.orderIndex > max ? f.orderIndex : max,
      ) +
      1;
  final actions = <FieldSchema>[];
  for (final spec in pcActionButtonFields) {
    if (existingKeys.contains(spec.key)) continue;
    actions.add(FieldSchema(
      fieldId: 'fld-pc-${spec.key}',
      categoryId: categoryId,
      fieldKey: spec.key,
      label: spec.label,
      fieldType: FieldType.actionButton,
      typeConfig: {'action': spec.action, 'placement': 'header'},
      isBuiltin: true,
      orderIndex: nextOrder++,
      createdAt: builtinDnd5eTemplateTimestamp,
      updatedAt: builtinDnd5eTemplateTimestamp,
    ));
  }
  return [...swapped, ...actions];
}

/// Applies the PC-category type swap to a single field. Wire-identical parity
/// renames ([pcFieldTypeSwaps]) only rewrite the type + `typeConfig`; the value-
/// migrating pip fields ([pcPipFieldKeys]) additionally migrate `defaultValue`
/// through the shared shim and drop the integer-only `minValue`/`maxValue`
/// validation. Every other field is returned untouched. Idempotent: a field
/// already carrying the v3 pouch wire re-migrates to the byte-identical value.
FieldSchema _swapPcField(FieldSchema field) {
  final key = field.fieldKey;
  if (pcFieldTypeSwaps.containsKey(key)) {
    return field.copyWith(
      fieldType: pcFieldTypeSwaps[key]!.type,
      typeConfig: pcFieldTypeSwaps[key]!.typeConfig,
    );
  }
  if (pcPipFieldKeys.contains(key)) {
    return field.copyWith(
      fieldType: FieldType.checkboxPouch,
      typeConfig: pcPipTypeConfig,
      defaultValue:
          migratePipIntToCheckboxPouch(field.defaultValue, count: pcPipCount),
      // The v2 `integer` field carried minValue:0 / maxValue:3 — meaningless on
      // a `{count, states}` map value, so reset to the empty validation.
      validation: const FieldValidation(),
    );
  }
  return field;
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

/// The [FieldType]s that carry player-facing narrative / static prose — the
/// retention-policy-protected fields (description, notes, biography, backstory,
/// benefits, appearance, ideals/bonds/flaws, GM notes, flavor, glossary
/// summary/effects, …). Roadmap §1.4 declares these "sacred": the rule
/// migration must NEVER delete, retype, or value-mutate one. The set is a
/// deliberate **superset** — every text/textarea/markdown field is protected,
/// not just an allow-list of names, so a future category's prose field is
/// covered automatically.
const staticNarrativeFieldTypes = <FieldType>{
  FieldType.text,
  FieldType.textarea,
  FieldType.markdown,
};

/// **STATIC-FIELD PRESERVATION AUDIT** (roadmap PR-2.3 checklist; prompt §4
/// retention policy). Asserts that every narrative/static-text field present in
/// the v2 source schema ([v2]) survives the v2→v3 transform ([v3]) with an
/// IDENTICAL `fieldType` and `defaultValue`, in the same category (matched on
/// the stable `slug` + `fieldKey`). No prose field is ever dropped, retyped, or
/// value-mutated by the rule migration.
///
/// This is the binding source of truth for the preservation checklist
/// ([docs/new_system/static-field-preservation-checklist.md]) — it is computed
/// over the live schema, so the audit can never silently drift from a
/// hand-maintained list. Returns every preserved `"<slug> / <fieldKey>"`
/// identifier on success (the explicit audit list); throws [StateError] naming
/// the first offending field on any violation. Wired into
/// [generateBuiltinDnd5eTemplateV3] under an `assert`.
List<String> auditStaticFieldPreservation(WorldSchema v2, WorldSchema v3) {
  final v3Fields = <String, FieldSchema>{};
  for (final category in v3.categories) {
    for (final field in category.fields) {
      v3Fields['${category.slug} ${field.fieldKey}'] = field;
    }
  }

  final preserved = <String>[];
  for (final category in v2.categories) {
    for (final field in category.fields) {
      if (!staticNarrativeFieldTypes.contains(field.fieldType)) continue;
      final id = '${category.slug} / ${field.fieldKey}';
      final v3Field = v3Fields['${category.slug} ${field.fieldKey}'];
      if (v3Field == null) {
        throw StateError(
          'Static-field preservation VIOLATION: narrative field "$id" '
          '(${field.fieldType.name}) was DROPPED from the v3 template.',
        );
      }
      if (v3Field.fieldType != field.fieldType) {
        throw StateError(
          'Static-field preservation VIOLATION: narrative field "$id" was '
          'RETYPED ${field.fieldType.name} -> ${v3Field.fieldType.name} in the '
          'v3 template.',
        );
      }
      if (!_deepValueEquals(v3Field.defaultValue, field.defaultValue)) {
        throw StateError(
          'Static-field preservation VIOLATION: narrative field "$id" had its '
          'stored defaultValue mutated in the v3 template.',
        );
      }
      preserved.add(id);
    }
  }
  return preserved;
}

/// Structural deep-equality for a field `defaultValue` (the JSON-shaped value
/// seed: `Map` / `List` / scalar / `null`). Used by
/// [auditStaticFieldPreservation] so the preservation check compares stored
/// prose content by value, not by reference.
bool _deepValueEquals(dynamic a, dynamic b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepValueEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepValueEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
