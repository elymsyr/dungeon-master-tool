import 'package:freezed_annotation/freezed_annotation.dart';

part 'field_schema.freezed.dart';
part 'field_schema.g.dart';

/// Desteklenen alan tipleri — 15 tip.
enum FieldType {
  text,
  textarea,
  markdown,
  integer,
  @JsonValue('float')
  float_,
  @JsonValue('boolean')
  boolean_,
  @JsonValue('enum')
  enum_,
  date,
  image,
  imagePerEra,    // `Map<eraId, assetRef>` — per-era image variants (e.g. location.map_per_era). Widget reads world map era list.
  file,
  pdf,
  relation,       // Tek referans veya liste referans (allowedTypes ile hedef kategori belirlenir)
  tagList,
  statBlock,
  combatStats,
  conditionStats,
  dice,           // Zar notasyonu: "2d6", "1d20+5", "3d8+2"
  slot,           // Dolu/boş checkbox satırı: spell slot, ammo, charges, hit dice
  proficiencyTable, // D&D 5e skills/saving throws — her satır: name, ability, proficient, expertise, misc
  levelTable,     // Map<int,int> — level → value progression tablosu (spell slot count, hit dice, vs.)
  levelTextTable, // Map<int,String> — level → free-form text (e.g. "At Higher Levels", per-level features narrative)
  classFeatures,  // List<{level:int, description?}> — narrative-only level upgrade table. Each row is a per-level summary line shown on the class card. Grants (feats/traits granted on level-up) live on the Feat/Trait entity via `auto_granted_by` and are applied by the resolver's Pass 4b walker independent of this table. Legacy keys (`name`, `kind`, `dice`, `uses`, `recharge`, `feat_ref`, `trait_ref`, `granted_feat_refs`, `granted_trait_refs`, `choice_count`, inline `effects`) are tolerated by the parser but no longer rendered or evaluated.
  spellEffectList,// List<{kind: damage|heal|condition|buff|debuff, dice, type_ref, save_ability_ref, save_effect: none|half|negate|partial, condition_refs[], scaling_dice}>
  rangedSenseList,// List<{sense_ref, range_ft}> — sense ref + range pair listesi (Darkvision 60ft, Truesight 120ft)
  grantedModifiers,// List<{kind, target_kind, target_ref, value, condition_ref, scaling}> — LEGACY typed-bonus DSL (superseded by featEffectList / `rule_effects`). Kept for existing content; the editor now offers only `applied` kinds from the catalog so authored rows can't silently no-op. Canonical kind registry: rules/dnd5e_rule_catalog.dart.
  equipmentChoiceGroups, // List<{group_id, label, prompt, options:[{option_id, label, items:[{ref, quantity}], gold_gp?}]}> — class/background starting equipment "Choose A or B" structure.
  featEffectList, // List<{kind, target_kind?, target_ref?, value?, payload?, predicates?, scales_with?, activation?, trigger?, trigger_args?, clauses?}> — richer feat/feature effect DSL. Also the shape behind the `rule_effects` field on every rule-bearing category.
                  // PR-R2 trigger keys: `trigger` (wire string, see rules/rule_trigger.dart; absent = category default — when_equipped on weapon/armor/magic-item, always_on elsewhere), `trigger_args: {at_level: int, gate: 'class'|'character'}` for when_level_up, `clauses: [...]` (prereqClauses vocabulary) on `kind: prerequisite` rows only.
                  // Canonical kind registry (label, params, target kinds, capability flags, applied|deferred status) lives in rules/dnd5e_rule_catalog.dart and is debug-cross-checked against CharacterResolver.knownEffectKinds (rule_catalog_provider.dart) so the declared and executable surfaces never drift. Do NOT maintain a kind list here.
                  // Row wrappers: `predicates: [{kind, args}]` AND-combined (closed enum: equipped_armor_kind, equipped_shield, has_state, has_condition, has_proficiency, class_level_at_least, weapon_property, weapon_kind_used, attack_uses_ability, target_has_condition, attack_was_critical, attack_was_miss, dim_or_dark_light, concentration_break_save, not_incapacitated, plus named composites like sneak_attack_eligibility); `scales_with: {kind, class_ref?, table:[{lvl,v}]}`; `activation: {action_type, duration, uses, triggers_state_ref?, end_conditions[]}`.
  autoGrantSources, // List<{source: 'class'|'subclass'|'species'|'background', source_ref, at_level?, choice_required?}> — declared on a Feat or Trait so the resolver can walk class/species/background levels and auto-apply this entity. Inverse edge of class.granted_feat_refs / species.granted_feat_refs.
  spellSlotGrid,  // `{max: {spellLevel: count}, remaining: {...}}` — per-spell-level slot pool for PCs. Auto-seeded from class caster_kind + level; tap pips to expend/recover.
  spellSlotProgression, // `Map<level, Map<spellLevel, count>>` — class-level slot progression override. When populated, overrides the SRD `caster_kind` preset at runtime. Stored with string-coerced keys for JSON compatibility.
  subspeciesOptions,    // `List<{name, description, granted_senses, granted_damage_resistances, granted_damage_immunities, granted_damage_vulnerabilities, granted_condition_immunities, granted_languages, granted_skill_proficiencies, granted_action_refs, granted_bonus_action_refs, granted_reaction_refs, granted_trait_refs}>` — species lineage / subspecies option rows. Resolver matches by `name`, folds grants onto the PC.
  crCalculator,         // `{atk_bonus?: int, dpr_avg?: int, save_dc?: int}` — author-supplied inputs. Widget reads `ac` + `hp_average` from sibling fields and renders the SRD §1 / DMG p.273-275 defensive + offensive CR estimate.
  prereqClauses,        // List<{type, ...args}> — typed prerequisite clauses (ALL-of; option lists are OR). Types: character_level {min_level}, ability_min {ability_options[], min_score}, spellcasting, armor_proficiency {category|category_ref}, weapon_proficiency {weapon_class: simple|martial|any}, skill_proficiency {skill_options[]}, class_ref {class_options[], min_level?}, species_ref {species_options[]}, alignment_ref {alignment_options[]}, other (never blocks). Shared interpreter: rules/prereq_evaluator.dart — picker dialogs FILTER on it, CharacterResolver WARN-KEEPs (warning on the sheet, mechanics still apply).

  // ── Template v3 field types (PR-1.2) ────────────────────────────────────
  // Inert until PR-2.3 parameterizes the renderers. The values reuse the old
  // wire-shapes verbatim (checkboxPouch=slot, pouchMatrix=spellSlotGrid,
  // skillTree=proficiencyTable) so the 20k-card value migration is near-zero.
  // Wire strings = these literal names; see docs/new_system/the-template-system.md §2.
  abilityScoreTable, // Parameterized statBlock. typeConfig: {columns[{key,label}], modifierBase, modifierStep, publishAspects}. modifier = floor((score-base)/step). Built-in config reproduces today's (score-10)/2.
  combatStatsTable,  // Parameterized combatStats. typeConfig: {visibleKeys[]}. Canonical keys fixed (hp, max_hp, ac, speed, level, initiative, xp) — structure not creator-editable. Publishes aspects level, ac, max_hp.
  intPouch,          // {current, max} resource pair (rage, ki, charges, granted pouches). typeConfig.maxSource ∈ {fixed, levelTable, formula, manual}. Target of refill/empty/set_pouch_max rules.
  checkboxPouch,     // {count, states[bool]} — BYTE-IDENTICAL wire to `slot` (death saves, hit dice, charges). typeConfig: {countSource, style: pips|checkboxes}. Refill/empty target.
  pouchMatrix,       // {max:{row:n}, remaining:{row:n}} — BYTE-IDENTICAL wire to `spellSlotGrid`. typeConfig: {rowKeys[], rowLabelPrefix?, maxSource}. set_pouch_max target; per-row refill.
  skillTree,         // rows {name, ability, proficient, expertise, misc} — BYTE-IDENTICAL wire to `proficiencyTable`. typeConfig: {abilityFieldKey, proficiencyBonusAspect, rowSeed, tiers[]}. Unifies saving throws AND skills. grant_proficiency target.
  recordList,        // Generic typed table. typeConfig: {columns[{key,label,kind:text|int|float|dice|bool|enum|ref, allowedTypes?, options?}], preset?}. preset keeps a bespoke renderer (spell-effects, equipment-choices, subspecies-options, ranged-senses, prereq-clauses). choose/check_clauses data source.
  levelMatrix,       // Map<level, Map<key,int>> generic level progression (rename target of spellSlotProgression). Feeds set_pouch_max / display.
  levelUpTable,      // rows {level, description, grants[{ref,target}], choices[{choiceId,prompt,pick,optionRefs[],target}]}. typeConfig: {gate: class|character}. Drives level-up grants + pending choices; inverts old auto_granted_by edges into forward grants.
  actionButton,      // level_up / short_rest / long_rest trigger. typeConfig: {action, placement?}. Label = FieldSchema.label (creator-editable); process fixed. Fires on_button rules declared on target pouch fields.
}

/// Alan görünürlüğü — online modda kimin görebileceğini belirler.
enum FieldVisibility {
  shared,
  dmOnly,
  @JsonValue('private')
  private_,
}

/// Tip-spesifik validation kuralları.
@freezed
abstract class FieldValidation with _$FieldValidation {
  const factory FieldValidation({
    double? minValue,
    double? maxValue,
    int? minLength,
    int? maxLength,
    String? pattern,
    List<String>? allowedValues,
    List<String>? allowedTypes,
    List<String>? allowedExtensions,
    String? customMessage,
  }) = _FieldValidation;

  factory FieldValidation.fromJson(Map<String, dynamic> json) =>
      _$FieldValidationFromJson(json);
}

/// Tek bir alanın tanımı.
@freezed
abstract class FieldSchema with _$FieldSchema {
  const factory FieldSchema({
    required String fieldId,
    required String categoryId,
    required String fieldKey,
    required String label,
    required FieldType fieldType,
    @Default(false) bool isRequired,
    @Default(null) dynamic defaultValue,
    @Default('') String placeholder,
    @Default('') String helpText,
    @Default(FieldValidation()) FieldValidation validation,
    @Default(FieldVisibility.shared) FieldVisibility visibility,
    @Default(0) int orderIndex,
    @Default(false) bool isBuiltin,
    @Default(false) bool isList,
    @Default(false) bool hasEquip,
    /// Relation list için "show all sources" filter UI'ını aktive eder.
    /// Varsayılan: sadece equipped itemlar görünür. Açıkken: rule-sourced
    /// itemlar da (class trait vs.) source badge ile görünür.
    @Default(false) bool showSourceFilter,
    @Default([]) List<String> allowedInSections,
    /// combatStats tipi için alt-alan tanımları. Encounter tablosu buradan beslenir.
    /// Her eleman: {key: 'hp', label: 'HP', type: 'text'|'integer'|'dice'}
    @Default([]) List<Map<String, String>> subFields,
    /// Hangi gruba ait (null = grupsuz, üstte render edilir)
    @Default(null) String? groupId,
    /// Grid layout'ta kaç sütun kaplar (1 = normal, 2+ = geniş)
    @Default(1) int gridColumnSpan,
    /// image tipi için per-field upload kind override (`MediaKind.wireName`).
    /// null → upload service mevcut hardcode'a düşer (worldEntityImage /
    /// packageEntityImage). Schema layer'a `MediaKind` import'u sızdırmamak
    /// için string olarak saklanır; resolver `MediaKind.fromWireName` ile çevirir.
    @Default(null) String? mediaKindWire,
    /// Template v3 — per-type parametric payload (replaces ad-hoc
    /// `subFields`/`defaultValue` tricks). Raw map, validated lazily by the
    /// editor/runtime to avoid a freezed explosion across ~10 type shapes.
    /// Shapes per type: docs/new_system/the-template-system.md §2.3.
    /// Absent on most fields; `includeIfNull: false` keeps it out of the
    /// serialized JSON when null so pre-v3 content hashes byte-identically
    /// (PR-1.2 is inert — nothing consumes this yet).
    @JsonKey(includeIfNull: false)
    @Default(null) Map<String, dynamic>? typeConfig,
    /// Template v3 — rule attachments (closed set of 8 kinds × 6 triggers;
    /// docs/new_system/the-template-system.md §4). Raw maps, validated
    /// lazily. Absent/empty on most fields; `includeIfNull: false` keeps a
    /// rule-free field's JSON (and therefore the content hash) inert until
    /// rules actually land in Phase 3. Read as `rules ?? const []`.
    @JsonKey(includeIfNull: false)
    @Default(null) List<Map<String, dynamic>>? rules,
    required String createdAt,
    required String updatedAt,
  }) = _FieldSchema;

  factory FieldSchema.fromJson(Map<String, dynamic> json) =>
      _$FieldSchemaFromJson(json);
}
