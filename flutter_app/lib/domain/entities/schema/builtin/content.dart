import 'package:uuid/uuid.dart';

import '../dnd5e_constants.dart';
import '../entity_category_schema.dart';
import '../field_group.dart';
import '../field_schema.dart';
import 'groups.dart';

const _uuid = Uuid();

/// Tier-1 content category slugs, in canonical order.
/// Shape-only — row content (classes, spells, monsters, …) ships via
/// the `srd_core.dnd5e-pkg.json` content pack per design §6.
const tier1Slugs = <String>[
  'class',
  'subclass',
  'species',
  'background',
  'feat',
  'spell',
  'weapon',
  'armor',
  'tool',
  'adventuring-gear',
  'ammunition',
  'pack',
  'mount',
  'vehicle',
  'trinket',
  'magic-item',
  'trait',
  'creature-action',
  'monster',
  'animal',
];

/// Equipment slugs an NPC / monster may carry. Used as the allowed-types
/// list for `equipment_refs` relations.
const equipmentSlugs = <String>[
  'weapon',
  'armor',
  'tool',
  'adventuring-gear',
  'ammunition',
  'pack',
  'mount',
  'vehicle',
  'trinket',
  'magic-item',
];

/// Build every Tier-1 content category.
/// [startOrderIndex] continues the global orderIndex across Tier-0+Tier-1.
List<EntityCategorySchema> buildTier1Content({
  required String schemaId,
  required String now,
  required int startOrderIndex,
}) {
  var i = startOrderIndex;
  return [
    _classCategory(schemaId, now, i++),
    _subclassCategory(schemaId, now, i++),
    _speciesCategory(schemaId, now, i++),
    _backgroundCategory(schemaId, now, i++),
    _featCategory(schemaId, now, i++),
    _spellCategory(schemaId, now, i++),
    _weaponCategory(schemaId, now, i++),
    _armorCategory(schemaId, now, i++),
    _toolCategory(schemaId, now, i++),
    _adventuringGearCategory(schemaId, now, i++),
    _ammunitionCategory(schemaId, now, i++),
    _packCategory(schemaId, now, i++),
    _mountCategory(schemaId, now, i++),
    _vehicleCategory(schemaId, now, i++),
    _trinketCategory(schemaId, now, i++),
    _magicItemCategory(schemaId, now, i++),
    _traitCategory(schemaId, now, i++),
    _creatureActionCategory(schemaId, now, i++),
    _monsterCategory(schemaId, now, i++),
    _animalCategory(schemaId, now, i++),
  ];
}

// ---------------------------------------------------------------------------
// Field helpers
// ---------------------------------------------------------------------------

class _FB {
  final String categoryId;
  final String now;
  int idx = 0;
  final List<FieldSchema> out = [];
  _FB(this.categoryId, this.now);

  FieldSchema _base({
    required String key,
    required String label,
    required FieldType type,
    bool required_ = false,
    String groupId = grpIdentity,
    int gridSpan = 1,
    bool isList = false,
    FieldValidation validation = const FieldValidation(),
    String? helpText,
    dynamic defaultValue,
    List<Map<String, String>> subFields = const [],
  }) {
    final f = FieldSchema(
      fieldId: _uuid.v4(),
      categoryId: categoryId,
      fieldKey: key,
      label: label,
      fieldType: type,
      isRequired: required_,
      isBuiltin: true,
      groupId: groupId,
      gridColumnSpan: gridSpan,
      isList: isList,
      validation: validation,
      helpText: helpText ?? '',
      defaultValue: defaultValue,
      subFields: subFields,
      orderIndex: idx++,
      createdAt: now,
      updatedAt: now,
    );
    out.add(f);
    return f;
  }

  void text(String k, String l, {bool required_ = false, String g = grpIdentity, int span = 1, String? help}) =>
      _base(key: k, label: l, type: FieldType.text, required_: required_, groupId: g, gridSpan: span, helpText: help);

  void textarea(String k, String l, {String g = grpIdentity, int span = 2}) =>
      _base(key: k, label: l, type: FieldType.textarea, groupId: g, gridSpan: span);

  void markdown(String k, String l, {String g = grpRules, int span = 2, bool required_ = false}) =>
      _base(key: k, label: l, type: FieldType.markdown, groupId: g, gridSpan: span, required_: required_);

  void integer(String k, String l,
      {bool required_ = false, int? min, int? max, String g = grpIdentity, String? help, dynamic defaultValue}) =>
      _base(
        key: k,
        label: l,
        type: FieldType.integer,
        required_: required_,
        groupId: g,
        helpText: help,
        defaultValue: defaultValue,
        validation: FieldValidation(
          minValue: min?.toDouble(),
          maxValue: max?.toDouble(),
        ),
      );

  void floatF(String k, String l,
      {bool required_ = false, double? min, double? max, String g = grpIdentity, String? help}) =>
      _base(
        key: k,
        label: l,
        type: FieldType.float_,
        required_: required_,
        groupId: g,
        helpText: help,
        validation: FieldValidation(minValue: min, maxValue: max),
      );

  void boolean(String k, String l, {String g = grpIdentity, bool required_ = false, String? help}) =>
      _base(key: k, label: l, type: FieldType.boolean_, groupId: g, required_: required_, helpText: help);

  void enum_(String k, String l, List<String> vals, {bool required_ = false, String g = grpIdentity}) =>
      _base(
        key: k,
        label: l,
        type: FieldType.enum_,
        required_: required_,
        groupId: g,
        validation: FieldValidation(allowedValues: vals),
      );

  void relation(String k, String l, List<String> allowed,
      {bool isList = false, bool required_ = false, String g = grpIdentity}) =>
      _base(
        key: k,
        label: l,
        type: FieldType.relation,
        isList: isList,
        required_: required_,
        groupId: g,
        validation: FieldValidation(allowedTypes: allowed),
      );

  void dice(String k, String l, {bool required_ = false, String g = grpIdentity}) =>
      _base(key: k, label: l, type: FieldType.dice, required_: required_, groupId: g);

  void levelTable(String k, String l, {String g = grpProgression}) =>
      _base(key: k, label: l, type: FieldType.levelTable, groupId: g, gridSpan: 2);

  void levelTextTable(String k, String l, {String g = grpProgression}) =>
      _base(key: k, label: l, type: FieldType.levelTextTable, groupId: g, gridSpan: 2);

  void classFeatures(String k, String l, {String g = grpFeatures}) =>
      _base(
        key: k,
        label: l,
        type: FieldType.classFeatures,
        groupId: g,
        gridSpan: 2,
        defaultValue: const <Map<String, dynamic>>[],
      );

  void spellEffectList(String k, String l, {String g = grpRules}) =>
      _base(
        key: k,
        label: l,
        type: FieldType.spellEffectList,
        groupId: g,
        gridSpan: 2,
        defaultValue: const <Map<String, dynamic>>[],
      );

  void rangedSenseList(String k, String l, {String g = grpSensesLanguages}) =>
      _base(
        key: k,
        label: l,
        type: FieldType.rangedSenseList,
        groupId: g,
        gridSpan: 2,
        defaultValue: const <Map<String, dynamic>>[],
      );

  void statBlock(String k, String l, {String g = grpAbilityScores}) =>
      _base(
        key: k,
        label: l,
        type: FieldType.statBlock,
        groupId: g,
        gridSpan: 2,
        defaultValue: const {'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10},
      );

  void proficiencyTable(String k, String l, {String g = grpCombat, dynamic defaultValue}) =>
      _base(
        key: k,
        label: l,
        type: FieldType.proficiencyTable,
        groupId: g,
        gridSpan: 2,
        defaultValue: defaultValue,
      );
}

EntityCategorySchema _mk({
  required String schemaId,
  required String categoryId,
  required String name,
  required String slug,
  required String color,
  required String icon,
  required List<FieldSchema> fields,
  required List<FieldGroup> groups,
  required int orderIndex,
  required String now,
  List<String> allowedInSections = const ['mindmap'],
  List<String> filterFieldKeys = const [],
}) {
  return EntityCategorySchema(
    categoryId: categoryId,
    schemaId: schemaId,
    name: name,
    slug: slug,
    icon: icon,
    color: color,
    isBuiltin: true,
    orderIndex: orderIndex,
    fields: fields,
    fieldGroups: groups,
    allowedInSections: allowedInSections,
    filterFieldKeys: filterFieldKeys,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Tier-1 categories
// ---------------------------------------------------------------------------

EntityCategorySchema _classCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('primary_ability_ref', 'Primary Ability', const ['ability'], required_: true);
  fb.relation('secondary_ability_ref', 'Secondary Ability', const ['ability']);
  fb.enum_('hit_die', 'Hit Die', const ['d6', 'd8', 'd10', 'd12'], required_: true);
  fb.relation('saving_throw_refs', 'Saving Throw Proficiencies', const ['ability'], isList: true, required_: true);
  fb.integer('skill_proficiency_choice_count', 'Skill Choice Count', min: 0, max: 4, g: grpProgression);
  fb.relation('skill_proficiency_options', 'Skill Options', const ['skill'], isList: true, g: grpProgression);
  fb.relation('weapon_proficiency_categories', 'Weapon Category Proficiencies', const ['weapon-category'], isList: true, g: grpProgression);
  fb.relation('weapon_proficiency_specifics', 'Specific Weapon Proficiencies', const ['weapon'], isList: true, g: grpProgression);
  fb.integer('tool_proficiency_count', 'Tool Choice Count', min: 0, max: 3, g: grpProgression);
  fb.relation('tool_proficiency_options', 'Tool Options', const ['tool'], isList: true, g: grpProgression);
  fb.relation('armor_training_refs', 'Armor Training', const ['armor-category'], isList: true, g: grpProgression);
  // Typed starting inventory (auto-import to PC.inventory). Markdown options for
  // narrative choice (Option A vs B etc.).
  fb.relation('default_inventory_refs', 'Default Inventory',
      const ['adventuring-gear', 'weapon', 'armor', 'tool', 'pack', 'ammunition'],
      isList: true, g: grpProgression);
  fb.markdown('starting_equipment_options', 'Starting Equipment Options (narrative)', g: grpProgression);
  fb.dice('starting_gold_dice', 'Starting Gold Dice', g: grpProgression);
  fb.enum_('complexity', 'Complexity', const ['Low', 'Average', 'High'], g: grpProgression);
  fb.relation('casting_ability_ref', 'Casting Ability', const ['ability'], g: grpSpellcasting);
  fb.enum_('caster_kind', 'Caster Kind', const ['None', 'Full', 'Half', 'Third', 'Pact', 'Ritual'], required_: true, g: grpSpellcasting);
  fb.relation('spellcasting_focus_ref', 'Spellcasting Focus', const ['arcane-focus', 'druidic-focus', 'holy-symbol'], g: grpSpellcasting);
  fb.classFeatures('features', 'Features by Level', g: grpFeatures);
  fb.levelTable('cantrips_known_by_level', 'Cantrips Known', g: grpSpellcasting);
  fb.levelTable('prepared_spells_by_level', 'Prepared Spells', g: grpSpellcasting);
  fb.levelTable('spell_slots_by_level', 'Spell Slots', g: grpSpellcasting);
  fb.markdown('multiclass_requirements', 'Multiclass Requirements', g: grpProgression);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Class',
    slug: 'class',
    color: '#1976d2',
    icon: 'workspaces',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Core Traits', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpProgression, name: 'Progression', gridColumns: 2, orderIndex: 1),
      FieldGroup(groupId: grpSpellcasting, name: 'Spellcasting', gridColumns: 2, orderIndex: 2),
      FieldGroup(groupId: grpFeatures, name: 'Features', gridColumns: 1, orderIndex: 3),
    ],
    orderIndex: orderIndex,
    now: now,
    filterFieldKeys: const ['caster_kind'],
  );
}

EntityCategorySchema _subclassCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('parent_class_ref', 'Parent Class', const ['class'], required_: true);
  fb.integer('granted_at_level', 'Granted at Level', required_: true, min: 1, max: 20);
  fb.classFeatures('features', 'Features by Level', g: grpFeatures);
  fb.markdown('flavor_description', 'Flavor', g: grpFeatures);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Subclass',
    slug: 'subclass',
    color: '#1565c0',
    icon: 'fork_right',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpFeatures, name: 'Features', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
  );
}

EntityCategorySchema _speciesCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('size_ref', 'Size', const ['size'], required_: true);
  fb.integer('speed_ft', 'Speed (ft)', required_: true, min: 0, max: 120);
  fb.relation('creature_type_ref', 'Creature Type', const ['creature-type'], required_: true);
  fb.markdown('traits', 'Traits', g: grpRules, required_: true);
  fb.relation('granted_languages', 'Granted Languages', const ['language'], isList: true);
  fb.relation('granted_senses', 'Granted Senses', const ['sense'], isList: true);
  fb.relation('granted_damage_resistances', 'Damage Resistances', const ['damage-type'], isList: true);
  fb.relation('granted_skill_proficiencies', 'Skill Proficiencies', const ['skill'], isList: true);
  fb.text('age', 'Typical Lifespan');

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Species',
    slug: 'species',
    color: '#00897b',
    icon: 'diversity_3',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Traits', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
  );
}

EntityCategorySchema _backgroundCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('granted_skill_refs', 'Granted Skills', const ['skill'], isList: true, required_: true);
  fb.relation('granted_tool_refs', 'Granted Tools', const ['tool'], isList: true);
  fb.integer('granted_language_count', 'Granted Language Count', min: 0, max: 5);
  fb.relation('ability_score_options', 'Ability Score Options', const ['ability'], isList: true, required_: true);
  fb.relation('origin_feat_ref', 'Origin Feat', const ['feat'], required_: true);
  // Typed starting equipment (auto-import to PC.inventory). Markdown kept for narrative.
  fb.relation('default_inventory_refs', 'Default Inventory',
      const ['adventuring-gear', 'weapon', 'armor', 'tool', 'pack', 'ammunition'],
      isList: true, g: grpRules);
  fb.markdown('starting_equipment', 'Starting Equipment (narrative)', g: grpRules, required_: true);
  fb.integer('starting_gold_gp', 'Starting Gold (gp)', min: 0);
  fb.integer('gold_alternative_gp', 'Gold Alternative (gp)', min: 0,
      help: 'Choose this gp instead of default_inventory_refs');

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Background',
    slug: 'background',
    color: '#8d6e63',
    icon: 'history_edu',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Grants', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Equipment', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
  );
}

EntityCategorySchema _featCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('category_ref', 'Category', const ['feat-category'], required_: true);
  // Typed prerequisites (gate machinery; freeform `prerequisite_text` for narrative).
  fb.relation('prereq_ability_ref', 'Prereq Ability', const ['ability'], g: grpIdentity);
  fb.integer('prereq_min_score', 'Prereq Min Score', min: 1, max: 30, g: grpIdentity);
  fb.relation('prereq_class_refs', 'Prereq Classes', const ['class'], isList: true, g: grpIdentity);
  fb.relation('prereq_species_refs', 'Prereq Species', const ['species'], isList: true, g: grpIdentity);
  fb.integer('prereq_min_character_level', 'Prereq Min Char Level', min: 1, max: 20, g: grpIdentity);
  fb.boolean('prereq_requires_spellcasting', 'Requires Spellcasting', g: grpIdentity);
  fb.markdown('prerequisite', 'Prerequisite (narrative)', g: grpIdentity, span: 2);
  fb.boolean('repeatable', 'Repeatable', required_: true);
  fb.integer('repeatable_limit', 'Repeat Limit', min: 1, max: 20, help: 'null = unlimited');
  // Typed Ability Score Increase. ASI options + amount (often +1, sometimes +2).
  fb.relation('asi_ability_options', 'ASI Ability Options', const ['ability'], isList: true, g: grpRules);
  fb.integer('asi_amount', 'ASI Amount', min: 0, max: 2, defaultValue: 0, g: grpRules);
  fb.integer('asi_max_score', 'ASI Max Score Cap', min: 1, max: 30, defaultValue: 20, g: grpRules);
  fb.markdown('ability_score_increase', 'Ability Score Increase (narrative)', g: grpRules);
  fb.markdown('benefits', 'Benefits', g: grpRules, required_: true);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Feat',
    slug: 'feat',
    color: '#ff7043',
    icon: 'stars',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Rules Text', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
    filterFieldKeys: const ['category_ref'],
  );
}

EntityCategorySchema _spellCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.integer('level', 'Level', required_: true, min: 0, max: 9);
  fb.relation('school_ref', 'School', const ['spell-school'], required_: true);
  fb.integer('casting_time_amount', 'Casting Time Amount', required_: true, min: 1, defaultValue: 1);
  fb.relation('casting_time_unit_ref', 'Casting Time Unit', const ['casting-time-unit'], required_: true);
  fb.text('reaction_trigger', 'Reaction Trigger', help: 'Only for Reaction casting time');
  fb.boolean('is_ritual', 'Ritual', required_: true);
  fb.enum_('range_type', 'Range Type', const ['Self', 'Touch', 'Ranged', 'Sight', 'Unlimited'], required_: true);
  fb.integer('range_ft', 'Range (ft)', min: 0);
  fb.relation('area_shape_ref', 'Area Shape', const ['area-shape']);
  fb.integer('area_size_ft', 'Area Size (ft)', min: 0);
  fb.relation('components', 'Components', const ['casting-component'], isList: true, required_: true);
  fb.text('material_description', 'Material Description');
  fb.integer('material_cost_gp', 'Material Cost (gp)', min: 0);
  fb.boolean('material_consumed', 'Material Consumed');
  fb.relation('duration_unit_ref', 'Duration Unit', const ['duration-unit'], required_: true);
  fb.integer('duration_amount', 'Duration Amount', min: 0);
  fb.boolean('requires_concentration', 'Concentration', required_: true);
  fb.markdown('description', 'Narrative Description', required_: true, g: grpRules);
  fb.spellEffectList('effects', 'Effects (typed DSL)', g: grpRules);
  fb.levelTextTable('at_higher_levels_text', 'At Higher Levels (narrative)', g: grpRules);
  fb.relation('class_refs', 'Class Spell Lists', const ['class'], isList: true, required_: true);
  fb.relation('damage_type_refs', 'Damage Types', const ['damage-type'], isList: true);
  fb.relation('save_ability_ref', 'Save Ability', const ['ability']);
  fb.enum_('attack_type', 'Attack Type', const ['None', 'Melee', 'Ranged']);
  fb.relation('applied_condition_refs', 'Applied Conditions', const ['condition'], isList: true);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Spell',
    slug: 'spell',
    color: '#7b1fa2',
    icon: 'auto_awesome',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Rules Text', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
    filterFieldKeys: const ['level', 'school_ref'],
  );
}

EntityCategorySchema _weaponCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('category_ref', 'Category', const ['weapon-category'], required_: true);
  fb.boolean('is_melee', 'Melee', required_: true);
  fb.dice('damage_dice', 'Damage Dice', required_: true);
  fb.relation('damage_type_ref', 'Damage Type', const ['damage-type'], required_: true);
  fb.relation('property_refs', 'Properties', const ['weapon-property'], isList: true, g: grpProperties);
  fb.relation('mastery_ref', 'Mastery', const ['weapon-mastery'], required_: true, g: grpProperties);
  fb.integer('normal_range_ft', 'Normal Range (ft)', min: 0, g: grpProperties);
  fb.integer('long_range_ft', 'Long Range (ft)', min: 0, g: grpProperties);
  fb.dice('versatile_damage_dice', 'Versatile Damage', g: grpProperties);
  fb.relation('ammunition_type_ref', 'Ammunition Type', const ['ammunition'], g: grpProperties);
  fb.floatF('cost_gp', 'Cost (gp)', required_: true, min: 0, g: grpCostWeight);
  fb.floatF('weight_lb', 'Weight (lb)', required_: true, min: 0, g: grpCostWeight);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Weapon',
    slug: 'weapon',
    color: '#6d4c41',
    icon: 'colorize',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpProperties, name: 'Properties', gridColumns: 2, orderIndex: 1),
      FieldGroup(groupId: grpCostWeight, name: 'Cost & Weight', gridColumns: 2, orderIndex: 2),
    ],
    orderIndex: orderIndex,
    now: now,
    filterFieldKeys: const ['category_ref', 'damage_type_ref'],
  );
}

EntityCategorySchema _armorCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('category_ref', 'Category', const ['armor-category'], required_: true);
  fb.integer('base_ac', 'Base AC', required_: true, min: 10, max: 20);
  fb.boolean('adds_dex', 'Adds DEX', required_: true);
  fb.integer('dex_cap', 'DEX Cap', min: 0, max: 10);
  fb.integer('strength_requirement', 'STR Requirement', min: 0, max: 30);
  fb.boolean('stealth_disadvantage', 'Stealth Disadvantage', required_: true);
  fb.integer('don_time_minutes', 'Don (min)', required_: true, min: 0);
  fb.integer('doff_time_minutes', 'Doff (min)', required_: true, min: 0);
  fb.floatF('cost_gp', 'Cost (gp)', required_: true, min: 0, g: grpCostWeight);
  fb.floatF('weight_lb', 'Weight (lb)', required_: true, min: 0, g: grpCostWeight);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Armor',
    slug: 'armor',
    color: '#5d4037',
    icon: 'shield',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpCostWeight, name: 'Cost & Weight', gridColumns: 2, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
    filterFieldKeys: const ['category_ref'],
  );
}

EntityCategorySchema _toolCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('category_ref', 'Category', const ['tool-category'], required_: true);
  fb.relation('variant_of_ref', 'Variant Of', const ['tool']);
  fb.relation('ability_ref', 'Ability', const ['ability'], required_: true);
  fb.integer('utilize_check_dc', 'Utilize DC', min: 0, max: 30);
  fb.textarea('utilize_description', 'Utilize Description');
  fb.relation('craftable_items', 'Craftable Items', const ['adventuring-gear'], isList: true);
  fb.floatF('cost_gp', 'Cost (gp)', required_: true, min: 0, g: grpCostWeight);
  fb.floatF('weight_lb', 'Weight (lb)', required_: true, min: 0, g: grpCostWeight);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Tool',
    slug: 'tool',
    color: '#795548',
    icon: 'build',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpCostWeight, name: 'Cost & Weight', gridColumns: 2, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
  );
}

EntityCategorySchema _adventuringGearCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.integer('cost_cp', 'Cost (cp)', required_: true, min: 0);
  fb.floatF('weight_lb', 'Weight (lb)', required_: true, min: 0);
  fb.integer('utilize_check_dc', 'Utilize Check DC', min: 0, max: 30);
  fb.relation('utilize_ability_ref', 'Utilize Ability', const ['ability']);
  fb.markdown('utilize_description', 'Utilize (narrative)');
  fb.boolean('consumable', 'Consumable', required_: true);
  fb.boolean('is_focus', 'Is Spellcasting Focus');
  fb.relation('focus_kind_ref', 'Focus Kind', const ['arcane-focus', 'druidic-focus', 'holy-symbol']);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Adventuring Gear',
    slug: 'adventuring-gear',
    color: '#8d6e63',
    icon: 'inventory_2',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Rules', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
  );
}

EntityCategorySchema _ammunitionCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.text('storage_container', 'Storage Container', help: 'e.g. quiver, pouch, case');
  fb.floatF('cost_gp', 'Cost (gp)', required_: true, min: 0);
  fb.floatF('weight_lb', 'Weight (lb)', required_: true, min: 0);
  fb.integer('bundle_count', 'Bundle Count', required_: true, min: 1, max: 500);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Ammunition',
    slug: 'ammunition',
    color: '#4e342e',
    icon: 'album',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
    ],
    orderIndex: orderIndex,
    now: now,
  );
}

EntityCategorySchema _packCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.integer('cost_gp', 'Cost (gp)', required_: true, min: 0);
  fb.floatF('weight_lb', 'Weight (lb)', min: 0);
  // Typed item refs; quantities listed in narrative markdown until quantity-on-
  // relation is supported (T5 in field_mechanics.md §5).
  fb.relation('content_refs', 'Content Items',
      const ['adventuring-gear', 'weapon', 'armor', 'tool', 'ammunition'],
      isList: true, g: grpRules);
  fb.markdown('contents', 'Contents (narrative w/ qty)', g: grpRules);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Equipment Pack',
    slug: 'pack',
    color: '#6d4c41',
    icon: 'backpack',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Contents', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
  );
}

EntityCategorySchema _mountCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.integer('carrying_capacity_lb', 'Carrying Capacity (lb)', required_: true, min: 0);
  fb.integer('speed_ft', 'Speed (ft)', required_: true, min: 0);
  fb.integer('cost_gp', 'Cost (gp)', required_: true, min: 0);
  fb.boolean('is_trained', 'Trained');

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Mount',
    slug: 'mount',
    color: '#6d4c41',
    icon: 'pets',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
    ],
    orderIndex: orderIndex,
    now: now,
  );
}

EntityCategorySchema _vehicleCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.enum_('vehicle_kind', 'Kind', const ['Land', 'Waterborne', 'Airborne'], required_: true);
  fb.floatF('speed_mph', 'Speed (mph)', min: 0);
  fb.integer('crew', 'Crew', min: 0);
  fb.integer('passengers', 'Passengers', min: 0);
  fb.floatF('cargo_tons', 'Cargo (tons)', min: 0);
  fb.integer('ac', 'AC', min: 0, max: 30);
  fb.integer('hp', 'HP', min: 0);
  fb.integer('damage_threshold', 'Damage Threshold', min: 0);
  fb.integer('cost_gp', 'Cost (gp)', min: 0);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Vehicle',
    slug: 'vehicle',
    color: '#455a64',
    icon: 'directions_boat',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
    ],
    orderIndex: orderIndex,
    now: now,
    filterFieldKeys: const ['vehicle_kind'],
  );
}

EntityCategorySchema _trinketCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.integer('roll_d100', 'd100 Roll', min: 1, max: 100, required_: true);
  fb.markdown('description', 'Description', required_: true, g: grpRules);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Trinket',
    slug: 'trinket',
    color: '#a1887f',
    icon: 'diamond',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Description', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
  );
}

EntityCategorySchema _magicItemCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('magic_category_ref', 'Category', const ['magic-item-category'], required_: true);
  fb.relation('rarity_ref', 'Rarity', const ['rarity'], required_: true);
  fb.boolean('requires_attunement', 'Requires Attunement', required_: true);
  // Typed attunement gates.
  fb.relation('attunement_class_refs', 'Attunement: Classes', const ['class'],
      isList: true, g: grpProperties);
  fb.relation('attunement_species_refs', 'Attunement: Species', const ['species'],
      isList: true, g: grpProperties);
  fb.relation('attunement_alignment_refs', 'Attunement: Alignments',
      const ['alignment'], isList: true, g: grpProperties);
  fb.relation('attunement_min_ability_ref', 'Attunement: Min Ability',
      const ['ability'], g: grpProperties);
  fb.integer('attunement_min_ability_score', 'Attunement: Min Score',
      min: 1, max: 30, g: grpProperties);
  fb.boolean('attunement_spellcaster_only', 'Attunement: Spellcaster Only',
      g: grpProperties);
  fb.markdown('attunement_prereq', 'Attunement Prerequisite (narrative)', g: grpProperties);
  fb.boolean('is_cursed', 'Cursed', required_: true);
  fb.relation('base_item_ref', 'Base Item', const ['weapon', 'armor', 'adventuring-gear']);
  fb.integer('charges_max', 'Max Charges', min: 0);
  fb.text('charge_regain', 'Charge Regain', help: 'e.g. "1d6+4 at dawn"');
  fb.enum_(
    'activation',
    'Activation',
    const ['None', 'Magic Action', 'Bonus Action', 'Reaction', 'Utilize', 'Command Word', 'Consumable'],
    required_: true,
  );
  fb.text('command_word', 'Command Word');
  fb.markdown('effects', 'Effects', required_: true, g: grpRules);
  fb.integer('cost_gp', 'Cost (gp)', min: 0, g: grpCostWeight);
  fb.floatF('weight_lb', 'Weight (lb)', min: 0, g: grpCostWeight);
  fb.boolean('is_sentient', 'Sentient', required_: true);
  fb.integer('sentient_int', 'INT', min: 3, max: 30);
  fb.integer('sentient_wis', 'WIS', min: 3, max: 30);
  fb.integer('sentient_cha', 'CHA', min: 3, max: 30);
  fb.relation('sentient_alignment_ref', 'Sentient Alignment', const ['alignment']);
  fb.text('sentient_communication', 'Communication');
  fb.text('sentient_senses', 'Senses');
  fb.text('sentient_special_purpose', 'Special Purpose');

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Magic Item',
    slug: 'magic-item',
    color: '#8e24aa',
    icon: 'auto_fix_high',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpProperties, name: 'Properties', gridColumns: 2, orderIndex: 1),
      FieldGroup(groupId: grpRules, name: 'Effects', gridColumns: 1, orderIndex: 2),
      FieldGroup(groupId: grpCostWeight, name: 'Cost & Weight', gridColumns: 2, orderIndex: 3),
    ],
    orderIndex: orderIndex,
    now: now,
    filterFieldKeys: const ['rarity_ref', 'magic_category_ref'],
  );
}

EntityCategorySchema _monsterCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('size_ref', 'Size', const ['size'], required_: true);
  fb.relation('creature_type_ref', 'Creature Type', const ['creature-type'], required_: true);
  fb.text('tags_line', 'Tags (e.g. "(goblinoid)")');
  fb.relation('alignment_ref', 'Alignment', const ['alignment']);
  // Combat
  fb.integer('ac', 'AC', required_: true, min: 0, max: 30, g: grpCombat);
  fb.text('ac_note', 'AC Note', g: grpCombat);
  fb.integer('initiative_modifier', 'Init Mod', required_: true, g: grpCombat);
  fb.integer('initiative_score', 'Initiative Score', required_: true, g: grpCombat);
  fb.integer('hp_average', 'HP (avg)', required_: true, min: 0, g: grpCombat);
  fb.dice('hp_dice', 'HP Dice', required_: true, g: grpCombat);
  fb.integer('speed_walk_ft', 'Walk (ft)', required_: true, min: 0, g: grpCombat);
  fb.integer('speed_burrow_ft', 'Burrow (ft)', min: 0, g: grpCombat);
  fb.integer('speed_climb_ft', 'Climb (ft)', min: 0, g: grpCombat);
  fb.integer('speed_fly_ft', 'Fly (ft)', min: 0, g: grpCombat);
  fb.integer('speed_swim_ft', 'Swim (ft)', min: 0, g: grpCombat);
  fb.boolean('can_hover', 'Hover', g: grpCombat);
  // Abilities
  fb.statBlock('stat_block', 'Ability Scores');
  fb.proficiencyTable('save_bonuses', 'Saves',
      g: grpCombat, defaultValue: proficiencyTableDefault(kDnd5eSavingThrows));
  fb.proficiencyTable('skill_bonuses', 'Skills',
      g: grpCombat, defaultValue: proficiencyTableDefault(kDnd5eSkills));
  // Defenses
  fb.relation('resistance_refs', 'Resistances', const ['damage-type'], isList: true, g: grpResistances);
  fb.relation('vulnerability_refs', 'Vulnerabilities', const ['damage-type'], isList: true, g: grpResistances);
  fb.relation('damage_immunity_refs', 'Damage Immunities', const ['damage-type'], isList: true, g: grpResistances);
  fb.relation('condition_immunity_refs', 'Condition Immunities', const ['condition'], isList: true, g: grpResistances);
  // Senses & Languages
  fb.rangedSenseList('senses', 'Senses (sense + range)', g: grpSensesLanguages);
  fb.integer('passive_perception', 'Passive Perception', required_: true, min: 0, max: 30, g: grpSensesLanguages);
  fb.relation('language_refs', 'Languages', const ['language'], isList: true, g: grpSensesLanguages);
  fb.integer('telepathy_ft', 'Telepathy (ft)', min: 0, g: grpSensesLanguages);
  // Meta
  fb.enum_('cr', 'Challenge Rating',
      const ['0', '1/8', '1/4', '1/2', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30'],
      required_: true, g: grpMeta);
  fb.integer('xp', 'XP', required_: true, min: 0, g: grpMeta);
  fb.integer('proficiency_bonus', 'Proficiency Bonus', required_: true, min: 2, max: 9, g: grpMeta);
  // Traits / actions — NPC parite (typed refs)
  fb.relation('trait_refs', 'Traits', const ['trait'], isList: true, g: grpTraitsActions);
  fb.relation('action_refs', 'Actions', const ['creature-action'], isList: true, required_: true, g: grpTraitsActions);
  fb.relation('bonus_action_refs', 'Bonus Actions', const ['creature-action'], isList: true, g: grpTraitsActions);
  fb.relation('reaction_refs', 'Reactions', const ['creature-action'], isList: true, g: grpTraitsActions);
  fb.integer('legendary_action_uses', 'Legendary Action Uses', min: 0, max: 5, g: grpTraitsActions);
  fb.relation('legendary_action_refs', 'Legendary Actions', const ['creature-action'], isList: true, g: grpTraitsActions);
  fb.relation('lair_action_refs', 'Lair Actions', const ['creature-action'], isList: true, g: grpTraitsActions);
  fb.relation('spell_refs', 'Spells', const ['spell'], isList: true, g: grpSpells);
  fb.relation('gear_refs', 'Gear', const ['adventuring-gear', 'weapon', 'armor'], isList: true, g: grpTraitsActions);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Monster',
    slug: 'monster',
    color: '#d32f2f',
    icon: 'coronavirus',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpAbilityScores, name: 'Ability Scores', gridColumns: 1, orderIndex: 1),
      FieldGroup(groupId: grpCombat, name: 'Combat', gridColumns: 2, orderIndex: 2),
      FieldGroup(groupId: grpResistances, name: 'Defenses', gridColumns: 2, orderIndex: 3),
      FieldGroup(groupId: grpSensesLanguages, name: 'Senses & Languages', gridColumns: 2, orderIndex: 4),
      FieldGroup(groupId: grpMeta, name: 'Meta', gridColumns: 2, orderIndex: 5),
      FieldGroup(groupId: grpTraitsActions, name: 'Traits & Actions', gridColumns: 1, orderIndex: 6),
      FieldGroup(groupId: grpSpells, name: 'Spellcasting', gridColumns: 1, orderIndex: 7),
    ],
    orderIndex: orderIndex,
    now: now,
    allowedInSections: const ['encounter', 'mindmap', 'worldmap', 'projection'],
    filterFieldKeys: const ['cr', 'creature_type_ref'],
  );
}

EntityCategorySchema _traitCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.text('source', 'Source', help: 'Origin (race, class, monster name, …)');
  fb.enum_('trait_kind', 'Trait Kind', const [
    'Passive',
    'Sense',
    'Defensive',
    'Movement',
    'Spellcasting',
    'Other',
  ]);
  fb.markdown('description', 'Description', g: grpRules);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Trait',
    slug: 'trait',
    color: '#7e57c2',
    icon: 'auto_awesome',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Rules', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
    filterFieldKeys: const ['trait_kind', 'source'],
  );
}

EntityCategorySchema _creatureActionCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.text('source', 'Source', help: 'Origin (monster, NPC, class, …)');
  fb.enum_('action_type', 'Action Type', const [
    'Action',
    'Bonus Action',
    'Reaction',
    'Legendary Action',
    'Lair Action',
    'Mythic Action',
    'Free',
  ], required_: true);
  fb.text('recharge', 'Recharge', help: 'e.g. "5-6", "Short Rest", "Day"');
  fb.integer('uses_per_day', 'Uses / Day', min: 0);
  fb.boolean('is_attack', 'Is Attack');
  fb.enum_('attack_kind', 'Attack Kind', const [
    'Melee Weapon',
    'Ranged Weapon',
    'Melee Spell',
    'Ranged Spell',
  ]);
  fb.integer('attack_bonus', 'Attack Bonus');
  fb.integer('reach_ft', 'Reach (ft)', min: 0);
  fb.integer('range_normal_ft', 'Range Normal (ft)', min: 0);
  fb.integer('range_long_ft', 'Range Long (ft)', min: 0);
  fb.dice('damage_dice', 'Damage Dice');
  fb.relation('damage_type_ref', 'Damage Type', const ['damage-type']);
  fb.integer('save_dc', 'Save DC', min: 1, max: 30);
  fb.relation('save_ability_ref', 'Save Ability', const ['ability']);
  fb.markdown('description', 'Description', required_: true, g: grpRules);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Action',
    slug: 'creature-action',
    color: '#ef6c00',
    icon: 'flash_on',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Rules', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
    filterFieldKeys: const ['action_type', 'source'],
  );
}

EntityCategorySchema _animalCategory(String schemaId, String now, int orderIndex) {
  // Animal shares Monster's shape (design §5.2 p254-343). Same fields, own slug
  // so the Beast listing on p344 filters cleanly.
  final monster = _monsterCategory(schemaId, now, orderIndex);
  // Rebuild with animal-specific identity, keep field shape identical.
  final catId = _uuid.v4();
  final rebuilt = [
    for (final f in monster.fields)
      f.copyWith(
        fieldId: _uuid.v4(),
        categoryId: catId,
      ),
  ];
  return monster.copyWith(
    categoryId: catId,
    name: 'Animal',
    slug: 'animal',
    color: '#4caf50',
    icon: 'cruelty_free',
    orderIndex: orderIndex,
    fields: rebuilt,
    filterFieldKeys: const ['cr'],
  );
}
