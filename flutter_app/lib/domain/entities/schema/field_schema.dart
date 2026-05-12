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
  grantedModifiers,// List<{kind, target_kind, target_ref, value, condition_ref, scaling}> — typed bonus DSL: AC/save/skill/HP/speed/proficiency/sense/spell grants. Species traits, feat benefits, magic item effects.
  equipmentChoiceGroups, // List<{group_id, label, prompt, options:[{option_id, label, items:[{ref, quantity}], gold_gp?}]}> — class/background starting equipment "Choose A or B" structure.
  featEffectList, // List<{kind, target_kind?, target_ref?, value?, payload?, predicates?, scales_with?, activation?}> — richer feat/feature effect DSL.
                  // Kinds (existing): class_level_grant, proficiency_grant, language_grant, spell_grant, cantrip_grant, ac_bonus, speed_bonus, hp_bonus_per_level, initiative_bonus, attack_bonus, extra_attack_bump, choice_group.
                  // Kinds (extended for feat/trait mechanic conversion): unarmored_ac_formula, damage_resistance, damage_immunity, damage_vulnerability, condition_immunity_grant, condition_advantage_on_save_grant, crit_range_extend, extra_damage_on_attack, reroll_damage, reroll_d20, attack_bonus_typed, damage_bonus_typed, ignore_cover, ignore_long_range_disadvantage, damage_reduction_flat, swim_speed_equals_speed, climb_speed_equals_speed, fly_speed, sense_grant, truesight_grant, blindsight_grant, walk_on_liquid, advantage_on, disadvantage_on, expertise_grant, half_proficiency_to_unproficient_checks, passive_score_bonus, reliable_talent, min_die_value, state_grant, resource_pool_grant, recovery_grant, slot_recovery_short_rest, spell_always_prepared, spell_cast_from_item, spellcasting_ability_to_damage, cantrip_count_bonus, magical_unarmed_strikes, damage_type_override, concentration_advantage, concentration_immune_to_damage_break, reaction_attack_grant, reaction_damage_reduction, reaction_negate_via_save, opportunity_attack_immunity_when_disengage_redundant, enemy_cant_disengage_oa, oa_stops_movement, weapon_mastery_grant, weapon_mastery_count_bonus, expertise_count, extra_attack_count, hp_max_bonus_total, temp_hp_grant.
                  // Row wrappers: `predicates: [{kind, args}]` AND-combined (closed enum: equipped_armor_kind, equipped_shield, has_state, has_condition, has_proficiency, class_level_at_least, weapon_property, weapon_kind_used, attack_uses_ability, target_has_condition, attack_was_critical, attack_was_miss, dim_or_dark_light, concentration_break_save, not_incapacitated, plus named composites like sneak_attack_eligibility); `scales_with: {kind, class_ref?, table:[{lvl,v}]}`; `activation: {action_type, duration, uses, triggers_state_ref?, end_conditions[]}`.
  autoGrantSources, // List<{source: 'class'|'subclass'|'species'|'background', source_ref, at_level?, choice_required?}> — declared on a Feat or Trait so the resolver can walk class/species/background levels and auto-apply this entity. Inverse edge of class.granted_feat_refs / species.granted_feat_refs.
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
    required String createdAt,
    required String updatedAt,
  }) = _FieldSchema;

  factory FieldSchema.fromJson(Map<String, dynamic> json) =>
      _$FieldSchemaFromJson(json);
}
