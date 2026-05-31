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
  featEffectList, // List<{kind, target_kind?, target_ref?, value?, payload?, predicates?, scales_with?, activation?}> — richer feat/feature effect DSL. Also the shape behind the `rule_effects` field on every rule-bearing category.
                  // Canonical kind registry (label, params, target kinds, capability flags, applied|deferred status) lives in rules/dnd5e_rule_catalog.dart and is debug-cross-checked against CharacterResolver.knownEffectKinds (rule_catalog_provider.dart) so the declared and executable surfaces never drift. Do NOT maintain a kind list here.
                  // Row wrappers: `predicates: [{kind, args}]` AND-combined (closed enum: equipped_armor_kind, equipped_shield, has_state, has_condition, has_proficiency, class_level_at_least, weapon_property, weapon_kind_used, attack_uses_ability, target_has_condition, attack_was_critical, attack_was_miss, dim_or_dark_light, concentration_break_save, not_incapacitated, plus named composites like sneak_attack_eligibility); `scales_with: {kind, class_ref?, table:[{lvl,v}]}`; `activation: {action_type, duration, uses, triggers_state_ref?, end_conditions[]}`.
  autoGrantSources, // List<{source: 'class'|'subclass'|'species'|'background', source_ref, at_level?, choice_required?}> — declared on a Feat or Trait so the resolver can walk class/species/background levels and auto-apply this entity. Inverse edge of class.granted_feat_refs / species.granted_feat_refs.
  spellSlotGrid,  // `{max: {spellLevel: count}, remaining: {...}}` — per-spell-level slot pool for PCs. Auto-seeded from class caster_kind + level; tap pips to expend/recover.
  spellSlotProgression, // `Map<level, Map<spellLevel, count>>` — class-level slot progression override. When populated, overrides the SRD `caster_kind` preset at runtime. Stored with string-coerced keys for JSON compatibility.
  subspeciesOptions,    // `List<{name, description, granted_senses, granted_damage_resistances, granted_damage_immunities, granted_damage_vulnerabilities, granted_condition_immunities, granted_languages, granted_skill_proficiencies, granted_action_refs, granted_bonus_action_refs, granted_reaction_refs, granted_trait_refs}>` — species lineage / subspecies option rows. Resolver matches by `name`, folds grants onto the PC.
  crCalculator,         // `{atk_bonus?: int, dpr_avg?: int, save_dc?: int}` — author-supplied inputs. Widget reads `ac` + `hp_average` from sibling fields and renders the SRD §1 / DMG p.273-275 defensive + offensive CR estimate.
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
    required String createdAt,
    required String updatedAt,
  }) = _FieldSchema;

  factory FieldSchema.fromJson(Map<String, dynamic> json) =>
      _$FieldSchemaFromJson(json);
}
