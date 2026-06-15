import '../../../services/template_migration/legacy_content_converter.dart';
import '../entity_category_schema.dart';
import '../field_schema.dart';
import '../world_schema.dart';
import 'builtin_dnd5e_v2_schema.dart';
import 'groups.dart';

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
///   * **RULE RESET → FIRST JIT RULE (roadmap §1.1 shift 1 / Phase 3 wave):**
///     the v2→v3 transform starts every field `rules`-free (`null` → omitted via
///     `includeIfNull:false`) so the only structural delta from v2 is the
///     embedded `seedRows`. The rule-assigned fields now land here as the
///     Phase-3 Armor JIT wave ([attachArmorRules]): a `when_equipped modify_stat`
///     AC rule on the existing `category_ref` anchor PLUS a NEW `prereq_clauses`
///     recordList field carrying a `prereq_to_equip check_clauses` Strength-
///     requirement rule. The Phase-3 **species/subspecies grant wave**
///     ([attachSpeciesGrantRules]) then attaches a `when_granted grant_refs` rule
///     to each existing trait/sense/language/resistance/immunity/action/spell
///     relation list field on the Species and Subspecies categories (each rule
///     reads its field's own stored refs into a named PC grant bucket), and the
///     **species/subspecies skill wave** ([_speciesGrantProficiencyRule]) attaches
///     a `when_granted grant_proficiency` rule to `granted_skill_proficiencies`
///     (each lineage's granted skills become proficient on the PC `skills`
///     skillTree). Every OTHER field stays byte-identical to its v2 form;
///     subsequent waves (the lineage `subspecies_options` `choose` preset,
///     granted-modifier `modify_stat`) append the same way.
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
  final swapped = swapPlayerCharacterFieldTypes(base);
  // FIRST/SECOND JIT RULE WAVE (roadmap Phase 3): attach the Armor equip-time
  // rule(s) to the v3 template. Runs after the PC type swap and before the
  // preservation audit so the audit sees the final shipped template.
  final withArmor = attachArmorRules(swapped);
  // THIRD JIT RULE WAVE (roadmap Phase 3, the-template-system §4.2 `grant_refs`):
  // attach the species/subspecies trait/sense/language/resistance/action/spell
  // grant rules. Additive — each rule lands on an existing relation list field
  // and reads that field's own stored refs; no card migration is needed.
  final withGrants = attachSpeciesGrantRules(withArmor);
  // FIFTH JIT RULE WAVE (roadmap Phase 3, the-template-system §4.2 `modify_stat`):
  // the lineage scalar stat-bonus rules. Appends the canonical `speed_bonus` /
  // `hp_bonus` data fields (the `effect_field_mapper` vocabulary) to the
  // Subspecies category and folds them into the PC `speed` / `max_hp` aspects via
  // anchored `when_granted modify_stat` rules. Additive — no card migration to
  // existing fields, the bonus value is read from each card's own new field.
  final v3 = attachLineageModifierRules(withGrants);
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

// --- Armor JIT rule wave (roadmap Phase 3, the-template-system §4.2) ---------

/// Slug of the built-in Armor category (set in `content.dart` `_armorCategory`).
/// The armor rule wave is keyed off this so the transform finds the category
/// regardless of its generated `categoryId`.
const builtinArmorSlug = 'armor';

/// The rule-capable Armor field that carries the equip-time rules. `category_ref`
/// (the armor's defining `relation`) is the stable, always-present rule-capable
/// anchor — the scalar fields the rules *read* (`base_ac`, later
/// `strength_requirement`) are integer aspect/value sources only and are never
/// themselves rule-capable (`template_validator.ruleCapableTypes`). Folding
/// reads card data via the rule's value/clause sources, not via the anchor
/// field's own value, so the anchor choice is purely structural.
const armorRuleAnchorFieldKey = 'category_ref';

/// The **FIRST built-in template rule** (roadmap Phase 3 JIT wave). When a PC
/// equips a piece of armor, the worn armor's `base_ac` is folded into the
/// character's `ac` aspect — `modify_stat` "adds to … ac" (the-template-system
/// §4.2) under the `when_equipped` trigger, read from the card via the `field`
/// value source (`TemplateRuleResolver._resolveValueSource`). The `kind`/
/// `trigger` strings are the canonical wire values from `RuleKinds.modifyStat`/
/// `RuleTriggers.whenEquipped` (kept as literals so this entity-layer generator
/// does not import the services-layer resolver; the closed sets are enforced by
/// `validateTemplateCategories`, which `tool/validate_template.dart` runs).
///
/// **Scope of this rule (deliberately one rule):** the Dex contribution
/// (`adds_dex`/`dex_cap`) is reconciled by the `combatStatsTable` widget
/// (the-template-system §2.3 — AC overrides live in the widget). The per-card
/// Strength-requirement `check_clauses` rule is the SECOND armor wave and lands
/// alongside this one ([armorPrereqClausesRules]) on a NEW `prereq-clauses`
/// recordList field, since a clause's `value` is a fixed literal
/// (`TemplateRuleResolver._evalClause`) and cannot read the scalar
/// `strength_requirement` inline.
///
/// Authored as raw maps — the `rules` wire is validated lazily by
/// `validateTemplateCategories` (PR-T2 decision: raw maps avoid a freezed
/// explosion on the open-ended rule grammar).
const armorRules = <Map<String, dynamic>>[
  {
    'ruleId': 'armor-ac-when-equipped',
    'trigger': 'when_equipped',
    'kind': 'modify_stat',
    'target': 'ac',
    'value': {'kind': 'field', 'field': 'base_ac'},
  },
];

/// The Armor `prereq_clauses` field key — the recordList that holds each piece's
/// equip prerequisites as `{aspect, op, value}` clause rows (the-template-system
/// §2.3 recordList preset `prereq-clauses`, §4.2 `check_clauses`). This is a
/// genuinely-NEW field (it did not exist in the v2 schema), so it is APPENDED to
/// the Armor category here rather than evolved from an existing field — additive,
/// so it never collides with the static-field preservation audit (which only
/// guards v2 narrative fields).
const armorPrereqClausesFieldKey = 'prereq_clauses';

/// `typeConfig` for the armor `prereq_clauses` recordList. The `preset:
/// 'prereq-clauses'` keeps the bespoke clause renderer (the-template-system §2.3,
/// the listed preset set) while the data model is the generic three-column
/// `{aspect, op, value}` shape the resolver's `check_clauses` reads
/// (`TemplateRuleResolver._evalClause`). Column `kind`s are drawn from the
/// validator's closed [recordListColumnKinds] set so the field passes
/// `_validateTypeConfig`'s recordList branch.
const armorPrereqClausesTypeConfig = <String, dynamic>{
  'columns': [
    {'key': 'aspect', 'label': 'Aspect', 'kind': 'text'},
    {'key': 'op', 'label': 'Operator', 'kind': 'text'},
    {'key': 'value', 'label': 'Value', 'kind': 'int'},
  ],
  'preset': 'prereq-clauses',
};

/// The **SECOND built-in template rule** (roadmap Phase 3 JIT wave). When a PC
/// attempts to equip armor whose Strength prerequisite they do not meet, the
/// `check_clauses` rule evaluates the worn piece's stored `prereq_clauses` rows
/// against the character's published ability-score aspects and pushes a
/// policy-tagged warning into the resolution (`warn` — the sheet warn-keeps:
/// the AC still applies, but a banner flags the unmet Str req; a `block` policy
/// would instead gate a picker — the-template-system §4.2 `check_clauses`, the
/// same warn/block split as the legacy `prereq_clauses` engine).
///
/// The rule carries NO inline `clauses` — they are read from the field's own
/// stored rows (`TemplateRuleResolver._gatherClauses` falls back to
/// `attachment.values[field.fieldKey]`), i.e. each armor card's migrated
/// `prereq_clauses` value (`srd_core/armor.dart`). The clause `aspect` is the
/// **uppercase** ability key `STR` to match the v3 PC `abilityScoreTable`, which
/// publishes aspects under its verbatim column keys (`STR`…`CHA`,
/// [pcFieldTypeSwaps]) — `AspectContext._publishAbilityScores`. Trigger
/// `prereq_to_equip` only fires while the piece is equipped
/// (`_checkActive`); `kind`/`trigger`/`policy` are the canonical wire strings
/// (`RuleKinds.checkClauses` / `RuleTriggers.prereqToEquip` / `warn`).
const armorPrereqClausesRules = <Map<String, dynamic>>[
  {
    'ruleId': 'armor-strength-requirement',
    'trigger': 'prereq_to_equip',
    'kind': 'check_clauses',
    'policy': 'warn',
  },
];

/// Attaches the armor JIT rule waves to the [builtinArmorSlug] category:
///   1. [armorRules] — the first rule — folds onto the [armorRuleAnchorFieldKey]
///      anchor field (AC `modify_stat` when equipped); and
///   2. a NEW `prereq_clauses` recordList field ([armorPrereqClausesFieldKey]) is
///      APPENDED carrying [armorPrereqClausesRules] (the Strength-requirement
///      `check_clauses`), since a clause's `value` is a fixed literal and must
///      live in per-card field rows, not inline on a scalar.
///
/// Every other category and field is returned untouched — the wave is scoped to
/// the Armor category. Idempotent and additive: the anchor field is only given
/// rules if it carries none (a re-run / copied built-in is left as-is), the
/// `prereq_clauses` field is appended only if absent, and no other field property
/// is changed (so the static-field preservation audit and the v2-parity of every
/// untouched field both hold).
WorldSchema attachArmorRules(WorldSchema schema) {
  final categories = [
    for (final category in schema.categories)
      if (category.slug == builtinArmorSlug)
        _attachArmorCategoryRules(category)
      else
        category,
  ];
  return schema.copyWith(categories: categories);
}

/// Applies both armor rule waves to the Armor [category] (see [attachArmorRules]).
EntityCategorySchema _attachArmorCategoryRules(EntityCategorySchema category) {
  // Wave 1: attach the AC rule to the always-present `category_ref` anchor.
  final fields = <FieldSchema>[
    for (final field in category.fields)
      if (field.fieldKey == armorRuleAnchorFieldKey &&
          (field.rules == null || field.rules!.isEmpty))
        field.copyWith(rules: armorRules)
      else
        field,
  ];
  // Wave 2: append the `prereq_clauses` recordList field (idempotent — skip if a
  // re-run / copied built-in already carries it).
  if (!fields.any((f) => f.fieldKey == armorPrereqClausesFieldKey)) {
    final nextOrder = fields.fold<int>(
          0,
          (max, f) => f.orderIndex > max ? f.orderIndex : max,
        ) +
        1;
    fields.add(FieldSchema(
      fieldId: 'fld-armor-$armorPrereqClausesFieldKey',
      categoryId: category.categoryId,
      fieldKey: armorPrereqClausesFieldKey,
      label: 'Equip Prerequisites',
      fieldType: FieldType.recordList,
      typeConfig: armorPrereqClausesTypeConfig,
      rules: armorPrereqClausesRules,
      isBuiltin: true,
      groupId: grpIdentity,
      orderIndex: nextOrder,
      createdAt: builtinDnd5eTemplateTimestamp,
      updatedAt: builtinDnd5eTemplateTimestamp,
    ));
  }
  return category.copyWith(fields: fields);
}

// --- Species/Subspecies grant rule waves (roadmap Phase 3, §4.2) -------------
// Wave 3: `grant_refs` over the entity-ref relation fields ([speciesGrantRefFields]).
// Wave 4: `grant_proficiency` over `granted_skill_proficiencies`.

/// Slugs of the built-in lineage categories that carry the shared grant-shape
/// relation fields (set in `content.dart` `_speciesCategory`/`_subspeciesCategory`).
/// The grant wave walks BOTH because the Subspecies category mirrors the Species
/// grant fields verbatim ("the same grant shape as Species, so CharacterResolver
/// folds them identically") — so one rule table drives both.
const builtinSpeciesGrantSlugs = <String>['species', 'subspecies'];

/// The Species/Subspecies relation list fields that carry a `grant_refs` rule,
/// mapped `fieldKey → target` — the named PC grant bucket the refs collect into
/// (the-template-system §4.2: "target PC list-field key; refs from field value").
///
/// Each is a `relation` (`isList: true`) field that already exists in v2 and is
/// rule-capable (`template_validator.ruleCapableTypes`), so the wave only
/// ATTACHES a rule — it appends no field and migrates no card data (the refs are
/// read from the card's own stored field value, which the built-in lineage cards
/// already populate, so `TemplateRuleResolver._foldGrantRefs` resolves them via
/// the stored-field fallback — no inline `refs`).
///
/// **Deliberately `grant_refs`-only.** The skill-proficiency grant
/// (`granted_skill_proficiencies`) is a different kind (`grant_proficiency`,
/// attached by its own wave — [_speciesGrantProficiencyRule]), the typed
/// `granted_modifiers` DSL folds via `modify_stat`, and the lineage
/// `subspecies_options` is a `choose` preset — each is its own wave. This table
/// is exactly the pure entity-ref grants (traits, senses, languages, the
/// damage/condition resistance-immunity-vulnerability grid, the three action
/// kinds, innate spells + cantrips).
const speciesGrantRefFields = <({String fieldKey, String target})>[
  (fieldKey: 'trait_refs', target: 'traits'),
  (fieldKey: 'granted_senses', target: 'senses'),
  (fieldKey: 'granted_languages', target: 'languages'),
  (fieldKey: 'granted_damage_resistances', target: 'damage_resistances'),
  (fieldKey: 'granted_damage_immunities', target: 'damage_immunities'),
  (fieldKey: 'granted_damage_vulnerabilities', target: 'damage_vulnerabilities'),
  (fieldKey: 'granted_condition_immunities', target: 'condition_immunities'),
  (fieldKey: 'granted_action_refs', target: 'actions'),
  (fieldKey: 'granted_bonus_action_refs', target: 'bonus_actions'),
  (fieldKey: 'granted_reaction_refs', target: 'reactions'),
  (fieldKey: 'granted_spell_refs', target: 'spells'),
  (fieldKey: 'granted_cantrip_refs', target: 'cantrips'),
];

/// Builds the single `grant_refs` rule for a [speciesGrantRefFields] entry on the
/// given category [slug]. The rule carries NO inline `refs` — at fold time
/// `TemplateRuleResolver._foldGrantRefs` reads them from the field's own stored
/// value (`attachment.values[fieldKey]`), i.e. each lineage card's populated
/// relation list. `trigger: when_granted` ≡ always-on once the species/subspecies
/// is attached to the PC (§4.1); `kind: grant_refs` (`RuleKinds.grantRefs`) and
/// the trigger are the canonical wire strings (kept as literals so this
/// entity-layer generator does not import the services-layer resolver; the closed
/// sets are enforced by `validateTemplateCategories`). `ruleId` is namespaced by
/// slug + target so the species and subspecies copies stay distinct and stable.
Map<String, dynamic> _speciesGrantRule(String slug, String target) => {
      'ruleId': '$slug-grant-$target',
      'trigger': 'when_granted',
      'kind': 'grant_refs',
      'target': target,
    };

/// The Species/Subspecies **skill-proficiency** grant field — the FOURTH lineage
/// rule slice (roadmap §3 wave row 3, the-template-system §4.2 `grant_proficiency`).
///
/// It is a separate wave from [speciesGrantRefFields] because a granted skill does
/// not append to a list bucket (as a `grant_refs` ref does) — it sets a
/// proficiency **tier** on a row of the PC `skills` skillTree. The relation field
/// already exists in v2 (`content.dart` `_speciesCategory`/`_subspeciesCategory`,
/// `relation isList:true` over the `skill` catalog) and is rule-capable
/// (`template_validator.ruleCapableTypes`), so the wave only ATTACHES a rule — it
/// appends no field and migrates no card data. The rule carries NO inline `rows`
/// — `TemplateRuleResolver._foldGrantProficiency` reads the affected skill refs
/// from the field's own stored value (`attachment.values[fieldKey]`), i.e. each
/// lineage card's already-populated skill list (e.g. High Elf → Insight, Wood Elf
/// → Stealth, Orc → Intimidation).
const speciesGrantProficiencyFieldKey = 'granted_skill_proficiencies';

/// The PC skillTree field the lineage skill grant writes into: `skills`, the v3
/// rename of the v2 proficiency table ([pcFieldTypeSwaps] — `skills` →
/// [FieldType.skillTree]). `_foldGrantProficiency` records `{skills: {row:
/// tier}}` so the granted skill rows surface as proficient on the character sheet.
const speciesGrantProficiencyTarget = 'skills';

/// The proficiency tier every lineage skill grant confers. All built-in
/// species/subspecies skill grants are base **proficiency** — `expertise` is a
/// class/feat-tier grant, never a lineage one — so the rule fixes the lower tier
/// (`_proficiencyTier` defaults to `proficient`, but it is set explicitly so the
/// exported asset is self-documenting).
const speciesGrantProficiencyTier = 'proficient';

/// Builds the single `grant_proficiency` rule for the lineage
/// [speciesGrantProficiencyFieldKey] on the given category [slug]. The rule
/// carries NO inline `rows` — at fold time `_foldGrantProficiency` reads them from
/// the field's own stored skill refs. `kind`/`trigger`/`tier` are the canonical
/// wire strings (`RuleKinds.grantProficiency` / `RuleTriggers.whenGranted` /
/// `skillTreeTiers`); kept as literals so this entity-layer generator does not
/// import the services-layer resolver (the closed sets are enforced by
/// `validateTemplateCategories`). `ruleId` is slug-namespaced so the species and
/// subspecies copies stay distinct and stable.
Map<String, dynamic> _speciesGrantProficiencyRule(String slug) => {
      'ruleId': '$slug-grant-skill-proficiencies',
      'trigger': 'when_granted',
      'kind': 'grant_proficiency',
      'target': speciesGrantProficiencyTarget,
      'tier': speciesGrantProficiencyTier,
    };

/// Attaches the [speciesGrantRefFields] `grant_refs` rules to every category in
/// [builtinSpeciesGrantSlugs]. Every other category and field is returned
/// untouched — the wave is scoped to the lineage categories. Idempotent and
/// additive: a field is only given a rule if it carries none (a re-run / copied
/// built-in is left as-is), a grant field absent from a category is silently
/// skipped, and no other field property is changed (so the static-field
/// preservation audit and the v2-parity of every untouched field both hold).
WorldSchema attachSpeciesGrantRules(WorldSchema schema) {
  final categories = [
    for (final category in schema.categories)
      if (builtinSpeciesGrantSlugs.contains(category.slug))
        _attachSpeciesGrantRules(category)
      else
        category,
  ];
  return schema.copyWith(categories: categories);
}

/// Applies the lineage grant waves to one [category] (see
/// [attachSpeciesGrantRules]): each [speciesGrantRefFields] target gains its
/// single `grant_refs` rule, and the [speciesGrantProficiencyFieldKey] field
/// gains its `grant_proficiency` rule. Only rule-free fields are touched (a
/// re-run / copied built-in is left as-is); everything else is byte-identical.
EntityCategorySchema _attachSpeciesGrantRules(EntityCategorySchema category) {
  final targetByKey = {
    for (final spec in speciesGrantRefFields) spec.fieldKey: spec.target,
  };
  final fields = <FieldSchema>[
    for (final field in category.fields)
      if (field.rules == null || field.rules!.isEmpty)
        _attachLineageGrantRule(category.slug, field, targetByKey)
      else
        field,
  ];
  return category.copyWith(fields: fields);
}

/// Returns [field] with its lineage grant rule attached, or the field unchanged
/// if it is not a grant field. A [speciesGrantRefFields] field (matched via
/// [targetByKey]) gets a `grant_refs` rule; the [speciesGrantProficiencyFieldKey]
/// field gets a `grant_proficiency` rule. Only ever called on a rule-free field
/// (the caller guards), so this never overwrites an existing rule.
FieldSchema _attachLineageGrantRule(
  String slug,
  FieldSchema field,
  Map<String, String> targetByKey,
) {
  final refTarget = targetByKey[field.fieldKey];
  if (refTarget != null) {
    return field.copyWith(rules: [_speciesGrantRule(slug, refTarget)]);
  }
  if (field.fieldKey == speciesGrantProficiencyFieldKey) {
    return field.copyWith(rules: [_speciesGrantProficiencyRule(slug)]);
  }
  return field;
}

// --- Lineage scalar-modifier `modify_stat` wave (roadmap Phase 3, §4.2) ------
// Wave 5: the Subspecies scalar stat bonuses (speed / flat HP). The legacy
// `granted_modifiers` typed DSL is display-only and non-rule-capable; the v3
// mechanics live on the canonical scalar data fields the converter emits
// (`effect_field_mapper`: `speed_bonus`→`speed_bonus`, `hp_bonus_flat`→`hp_bonus`)
// so the built-in lineage cards and a converted pack's cards drive the SAME rule.

/// Slug of the built-in Subspecies (lineage) category (set in `content.dart`
/// `_subspeciesCategory`). The lineage modifier wave is scoped to this — the only
/// built-in lineage category whose cards carry flat speed / HP grants (Wood Elf
/// +5 ft Speed, Mountain Dwarf +2 HP) — so every appended rule-bearing field is
/// used by ≥1 card (master-roadmap §3 shift 2).
const builtinSubspeciesSlug = 'subspecies';

/// The rule-capable Subspecies field that anchors the modifier `modify_stat`
/// rules. `parent_species_ref` (the required lineage relation) is always present
/// and rule-capable; the scalar bonus fields the rules *read* (`speed_bonus`,
/// `hp_bonus`) are `integer` aspect/value sources only and are never themselves
/// rule-capable (`template_validator.ruleCapableTypes`) — the same anchor
/// discipline as the Armor AC rule on `category_ref`.
const lineageModifierRuleAnchorFieldKey = 'parent_species_ref';

/// The canonical v3 scalar stat-bonus fields APPENDED to the Subspecies category,
/// each `(fieldKey, label, group, target)`. `fieldKey` is the converter's
/// canonical vocabulary ([effectTargetFields]); `target` is the PC aspect the
/// `modify_stat` rule folds into (`speed`, `max_hp` — the `aspect_context`
/// canonical names). `integer` is NOT rule-capable, so these fields only hold the
/// per-card value while the rule lives on the [lineageModifierRuleAnchorFieldKey]
/// anchor and reads them via a `field` value source.
const lineageModifierFields =
    <({String fieldKey, String label, String group, String target})>[
  (fieldKey: 'speed_bonus', label: 'Speed Bonus (ft)', group: grpCombat, target: 'speed'),
  (fieldKey: 'hp_bonus', label: 'HP Bonus', group: grpTraitsActions, target: 'max_hp'),
];

/// Builds the `when_granted modify_stat` rule for a [lineageModifierFields] entry.
/// The value is read from the card's own scalar bonus field via a `field` value
/// source carrying `default: 0` — so the many lineage cards that grant no such
/// bonus fold to a +0 no-op (skipped by `_foldModifyStat`) instead of an
/// unresolved skip. `kind`/`trigger` are the canonical wire strings
/// (`RuleKinds.modifyStat` / `RuleTriggers.whenGranted`); `ruleId` is namespaced
/// by field key so the two rules stay distinct on the shared anchor.
Map<String, dynamic> _lineageModifierRule(String fieldKey, String target) => {
      'ruleId': 'subspecies-$fieldKey',
      'trigger': 'when_granted',
      'kind': 'modify_stat',
      'target': target,
      'value': {'kind': 'field', 'field': fieldKey, 'default': 0},
    };

/// Attaches the lineage scalar-modifier wave to the [builtinSubspeciesSlug]
/// category: it attaches each [lineageModifierFields] `modify_stat` rule to the
/// [lineageModifierRuleAnchorFieldKey] anchor and APPENDS each canonical scalar
/// bonus `integer` field (so the rule has a per-card value to read). Every other
/// category and field is returned untouched. Idempotent and additive: a bonus
/// field is appended only if absent, the anchor only gains a rule it does not
/// already carry (matched by `ruleId`), and no other field property is changed —
/// so the static-field preservation audit and v2-parity both hold.
WorldSchema attachLineageModifierRules(WorldSchema schema) {
  final categories = [
    for (final category in schema.categories)
      if (category.slug == builtinSubspeciesSlug)
        _attachLineageModifierRules(category)
      else
        category,
  ];
  return schema.copyWith(categories: categories);
}

/// Applies the lineage scalar-modifier wave to one [category] (see
/// [attachLineageModifierRules]).
EntityCategorySchema _attachLineageModifierRules(EntityCategorySchema category) {
  // Attach the modifier rules to the anchor, appending to any it already carries
  // (idempotent — a rule whose `ruleId` is already present is not duplicated).
  final fields = <FieldSchema>[
    for (final field in category.fields)
      if (field.fieldKey == lineageModifierRuleAnchorFieldKey)
        field.copyWith(rules: _lineageAnchorRules(field.rules))
      else
        field,
  ];
  // Append each canonical scalar bonus field that is not already present.
  final present = {for (final f in fields) f.fieldKey};
  var nextOrder = fields.fold<int>(
        0,
        (max, f) => f.orderIndex > max ? f.orderIndex : max,
      ) +
      1;
  for (final spec in lineageModifierFields) {
    if (present.contains(spec.fieldKey)) continue;
    fields.add(FieldSchema(
      fieldId: 'fld-subspecies-${spec.fieldKey}',
      categoryId: category.categoryId,
      fieldKey: spec.fieldKey,
      label: spec.label,
      fieldType: FieldType.integer,
      isBuiltin: true,
      groupId: spec.group,
      orderIndex: nextOrder++,
      createdAt: builtinDnd5eTemplateTimestamp,
      updatedAt: builtinDnd5eTemplateTimestamp,
    ));
  }
  return category.copyWith(fields: fields);
}

/// Merges the [lineageModifierFields] `modify_stat` rules into the anchor field's
/// [existing] rule list without duplicating (matched by `ruleId`), preserving any
/// rule already attached. Returns a fresh list.
List<Map<String, dynamic>> _lineageAnchorRules(
  List<Map<String, dynamic>>? existing,
) {
  final rules = <Map<String, dynamic>>[...?existing];
  final haveIds = {for (final r in rules) r['ruleId']};
  for (final spec in lineageModifierFields) {
    if (haveIds.contains('subspecies-${spec.fieldKey}')) continue;
    rules.add(_lineageModifierRule(spec.fieldKey, spec.target));
  }
  return rules;
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
