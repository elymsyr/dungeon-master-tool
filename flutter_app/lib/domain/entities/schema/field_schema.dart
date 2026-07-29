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
  classFeatures,  // List<{level:int, name, description?, granted_feat_refs[], granted_trait_refs[], granted_action_refs[], granted_bonus_action_refs[], granted_reaction_refs[], granted_senses[], granted_languages[], granted_damage_resistances[], granted_damage_immunities[], granted_condition_immunities[]}> — the class/subclass level table, and the ONLY place a level-gated grant is declared. Resolver Pass 4b walks the rows at or below the character's level in that class and applies each referenced feat/trait exactly like a chosen one. Legacy keys (`kind`, `dice`, `uses`, `recharge`, `feat_ref`, `trait_ref`, `choice_count`, inline `effects`) are tolerated by the parser but not rendered or evaluated.
  spellEffectList,// List<{kind: damage|heal|condition|buff|debuff, dice, type_ref, save_ability_ref, save_effect: none|half|negate|partial, condition_refs[], scaling_dice}>
  rangedSenseList,// List<{sense_ref, range_ft}> — sense ref + range pair listesi (Darkvision 60ft, Truesight 120ft)
  equipmentChoiceGroups, // List<{group_id, label, prompt, options:[{option_id, label, items:[{ref, quantity}], gold_gp?}]}> — class/background starting equipment "Choose A or B" structure.
  resourcePoolGrants, // List<{pool_ref, recharge: short_rest|long_rest, count?, count_formula?, count_by_level?: {lvl: count}, class_ref?}> — per-rest resource pools (Rage, Ki, Sorcery Points, Bardic Inspiration). `count_by_level` wins over `count_formula`, which wins over the flat `count`; `class_ref` scopes the level lookup to that class's level instead of total character level.
  playerChoices,  // List<{group_id, label, prompt, pick_kind: enum|skill|spell_from_list, pick: int, options?: [{id, label}], list_group_id?, spell_level?}> — deferred "pick N of these" decisions a card queues when taken. Read by `pending_choices.dart` and resolved through `pending_choice_resolver_dialog.dart`.
  spellsAtLevel,  // List<{spell_ref, at_level: int, is_cantrip?: bool, uses_per_long_rest?: int}> — innate spells that unlock as the character levels (Drow's Faerie Fire at 3, Darkness at 5). Rows above the character's level are skipped; `uses_per_long_rest` adds a daily counter pool keyed by the spell. The level-gated sibling of `granted_spell_refs`.
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
