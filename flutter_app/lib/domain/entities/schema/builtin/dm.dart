import 'package:uuid/uuid.dart';

import '../dnd5e_constants.dart';
import '../entity_category_schema.dart';
import '../field_group.dart';
import '../field_schema.dart';
import 'groups.dart';

const _uuid = Uuid();

/// Tier-2 DM / campaign category slugs, in canonical order.
/// User-authored content lives here; no SRD rows ship with these.
const tier2Slugs = <String>[
  'npc',
  'player-character',
  'applied-condition',
  'location',
  'scene',
  'quest',
  'encounter',
  'trap',
  'poison',
  'curse',
  'environmental-effect',
  'hireling',
  'service',
];

/// Build every Tier-2 DM/campaign category.
List<EntityCategorySchema> buildTier2Dm({
  required String schemaId,
  required String now,
  required int startOrderIndex,
}) {
  var i = startOrderIndex;
  return [
    _npcCategory(schemaId, now, i++),
    _playerCharacterCategory(schemaId, now, i++),
    _appliedConditionCategory(schemaId, now, i++),
    _locationCategory(schemaId, now, i++),
    _sceneCategory(schemaId, now, i++),
    _questCategory(schemaId, now, i++),
    _encounterCategory(schemaId, now, i++),
    _trapCategory(schemaId, now, i++),
    _poisonCategory(schemaId, now, i++),
    _curseCategory(schemaId, now, i++),
    _environmentalEffectCategory(schemaId, now, i++),
    _hirelingCategory(schemaId, now, i++),
    _serviceCategory(schemaId, now, i++),
  ];
}

// ---------------------------------------------------------------------------
// Hardcoded enum value lists (former Tier-0 lookup categories).
// ---------------------------------------------------------------------------

// PR-2 (2026-04-29): alignment, attitude, illumination, travel-pace,
// weapon-category, armor-category, plane promoted to Tier-0 lookups.
// Consumers reference them via relation fields.

// ---------------------------------------------------------------------------
// Field builder (mirrors content.dart's _FB)
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
    FieldVisibility visibility = FieldVisibility.shared,
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
      visibility: visibility,
      orderIndex: idx++,
      createdAt: now,
      updatedAt: now,
    );
    out.add(f);
    return f;
  }

  void text(String k, String l, {bool required_ = false, String g = grpIdentity, String? help}) =>
      _base(key: k, label: l, type: FieldType.text, required_: required_, groupId: g, helpText: help);
  void textarea(String k, String l, {String g = grpIdentity}) =>
      _base(key: k, label: l, type: FieldType.textarea, groupId: g, gridSpan: 2);
  void markdown(String k, String l, {String g = grpRules, FieldVisibility vis = FieldVisibility.shared}) =>
      _base(key: k, label: l, type: FieldType.markdown, groupId: g, gridSpan: 2, visibility: vis);
  void integer(String k, String l, {bool required_ = false, int? min, int? max, String g = grpIdentity, dynamic defaultValue, String? help}) =>
      _base(
        key: k,
        label: l,
        type: FieldType.integer,
        required_: required_,
        groupId: g,
        defaultValue: defaultValue,
        helpText: help,
        validation: FieldValidation(minValue: min?.toDouble(), maxValue: max?.toDouble()),
      );
  void boolean(String k, String l, {String g = grpIdentity, bool required_ = false, dynamic defaultValue}) =>
      _base(key: k, label: l, type: FieldType.boolean_, groupId: g, required_: required_, defaultValue: defaultValue);
  void enum_(String k, String l, List<String> vals,
          {bool required_ = false, bool isList = false, String g = grpIdentity}) =>
      _base(
        key: k,
        label: l,
        type: FieldType.enum_,
        required_: required_,
        isList: isList,
        groupId: g,
        validation: FieldValidation(allowedValues: vals),
      );
  void relation(String k, String l, List<String> allowed, {bool isList = false, bool required_ = false, String g = grpIdentity}) =>
      _base(
        key: k,
        label: l,
        type: FieldType.relation,
        isList: isList,
        required_: required_,
        groupId: g,
        validation: FieldValidation(allowedTypes: allowed),
      );
  void levelTable(String k, String l, {String g = grpProgression}) =>
      _base(key: k, label: l, type: FieldType.levelTable, groupId: g, gridSpan: 2);
  void slot(String k, String l, {String g = grpSpellcasting}) =>
      _base(key: k, label: l, type: FieldType.slot, groupId: g, gridSpan: 2);
  void dice(String k, String l, {bool required_ = false, String g = grpIdentity}) =>
      _base(key: k, label: l, type: FieldType.dice, required_: required_, groupId: g);
  void proficiencyTable(String k, String l, {String g = grpCombat, dynamic defaultValue}) =>
      _base(
        key: k,
        label: l,
        type: FieldType.proficiencyTable,
        groupId: g,
        gridSpan: 2,
        defaultValue: defaultValue,
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
  void grantedModifiers(String k, String l, {String g = grpRules}) =>
      _base(key: k, label: l, type: FieldType.grantedModifiers, groupId: g, isList: true, gridSpan: 2);
  void combatStats(String k, String l) => _base(
        key: k,
        label: l,
        type: FieldType.combatStats,
        groupId: grpCombat,
        gridSpan: 2,
        defaultValue: const {'hp': '', 'max_hp': '', 'ac': '', 'speed': '', 'cr': '', 'xp': '', 'initiative': '', 'level': ''},
        subFields: const [
          {'key': 'hp', 'label': 'HP', 'type': 'integer'},
          {'key': 'max_hp', 'label': 'Max HP', 'type': 'integer'},
          {'key': 'ac', 'label': 'AC', 'type': 'integer'},
          {'key': 'speed', 'label': 'Speed', 'type': 'text'},
          {'key': 'level', 'label': 'Level', 'type': 'integer'},
          {'key': 'initiative', 'label': 'Initiative', 'type': 'dice'},
          {'key': 'cr', 'label': 'CR', 'type': 'text'},
          {'key': 'xp', 'label': 'XP', 'type': 'integer'},
        ],
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
// Tier-2 categories
// ---------------------------------------------------------------------------

EntityCategorySchema _npcCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('species_ref', 'Species', const ['species']);
  fb.relation('class_refs', 'Classes', const ['class'], isList: true);
  fb.integer('level', 'Level', min: 1, max: 20);
  fb.relation('background_ref', 'Background', const ['background']);
  fb.relation('alignment_ref', 'Alignment', const ['alignment']);
  fb.relation('attitude_ref', 'Attitude', const ['attitude'], required_: true);
  fb.relation('location_ref', 'Location', const ['location']);
  fb.text('faction', 'Faction');
  // Stat block
  fb.statBlock('stat_block', 'Ability Scores');
  fb.combatStats('combat_stats', 'Combat Stats');
  fb.integer('proficiency_bonus', 'Proficiency Bonus', min: 2, max: 9, defaultValue: 2, g: grpCombat);
  fb.integer('initiative_modifier', 'Init Mod', defaultValue: 0, g: grpCombat);
  fb.proficiencyTable('saving_throws', 'Saves',
      defaultValue: proficiencyTableDefault(kDnd5eSavingThrows));
  fb.proficiencyTable('skills', 'Skills',
      defaultValue: proficiencyTableDefault(kDnd5eSkills));
  fb.relation('resistance_refs', 'Resistances', const ['damage-type'], isList: true, g: grpResistances);
  fb.relation('vulnerability_refs', 'Vulnerabilities', const ['damage-type'], isList: true, g: grpResistances);
  fb.relation('damage_immunity_refs', 'Damage Immunities', const ['damage-type'], isList: true, g: grpResistances);
  fb.relation('condition_immunity_refs', 'Condition Immunities', const ['condition'], isList: true, g: grpResistances);
  fb.relation('senses', 'Senses', const ['sense'], isList: true, g: grpSensesLanguages);
  fb.integer('passive_perception', 'Passive Perception', min: 0, max: 30, defaultValue: 10, g: grpSensesLanguages);
  fb.relation('language_refs', 'Languages', const ['language'], isList: true, g: grpSensesLanguages);
  fb.integer('telepathy_ft', 'Telepathy (ft)', min: 0, g: grpSensesLanguages);
  fb.relation('trait_refs', 'Traits', const ['trait'], isList: true, g: grpTraitsActions);
  fb.relation('action_refs', 'Actions', const ['creature-action'], isList: true, g: grpTraitsActions);
  fb.relation('special_action_refs', 'Special Actions', const ['creature-action'], isList: true, g: grpTraitsActions);
  fb.relation('equipment_refs', 'Equipment', const [
    'weapon', 'armor', 'tool', 'adventuring-gear', 'ammunition',
    'pack', 'mount', 'vehicle', 'trinket', 'magic-item',
  ], isList: true, g: grpTraitsActions);
  fb.relation('spell_refs', 'Spells', const ['spell'], isList: true, g: grpSpells);
  fb.markdown('goals', 'Goals', g: grpRules);
  fb.markdown('appearance', 'Appearance', g: grpRules);
  fb.markdown('mannerisms', 'Mannerisms', g: grpRules);
  fb.markdown('secrets', 'Secrets (DM-only)', g: grpRules, vis: FieldVisibility.dmOnly);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'NPC',
    slug: 'npc',
    color: '#ff9800',
    icon: 'person',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpAbilityScores, name: 'Ability Scores', gridColumns: 1, orderIndex: 1),
      FieldGroup(groupId: grpCombat, name: 'Combat', gridColumns: 2, orderIndex: 2),
      FieldGroup(groupId: grpResistances, name: 'Defenses', gridColumns: 2, orderIndex: 3),
      FieldGroup(groupId: grpSensesLanguages, name: 'Senses & Languages', gridColumns: 2, orderIndex: 4),
      FieldGroup(groupId: grpTraitsActions, name: 'Traits & Actions', gridColumns: 1, orderIndex: 5),
      FieldGroup(groupId: grpSpells, name: 'Spells', gridColumns: 1, orderIndex: 6),
      FieldGroup(groupId: grpRules, name: 'DM Notes', gridColumns: 1, orderIndex: 7),
    ],
    orderIndex: orderIndex,
    now: now,
    allowedInSections: const ['encounter', 'mindmap', 'worldmap', 'projection'],
    filterFieldKeys: const ['attitude_ref', 'level'],
  );
}

EntityCategorySchema _playerCharacterCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('species_ref', 'Species', const ['species'], required_: true);
  fb.relation('class_refs', 'Classes', const ['class'], isList: true, required_: true);
  fb.levelTable('class_levels', 'Class Levels', g: grpProgression);
  fb.relation('subclass_refs', 'Subclasses', const ['subclass'], isList: true);
  fb.relation('background_ref', 'Background', const ['background'], required_: true);
  fb.relation('alignment_ref', 'Alignment', const ['alignment']);
  fb.integer('xp', 'XP', required_: true, min: 0, defaultValue: 0);
  fb.integer('proficiency_bonus', 'Proficiency Bonus', required_: true, min: 2, max: 6, defaultValue: 2);
  fb.relation('feats', 'Feats', const ['feat'], isList: true);
  fb.relation('languages', 'Languages', const ['language'], isList: true, required_: true);
  fb.relation('tool_proficiencies', 'Tool Proficiencies', const ['tool'], isList: true);
  fb.relation('weapon_proficiency_categories', 'Weapon Category Proficiencies',
      const ['weapon-category'], isList: true);
  fb.relation('weapon_proficiency_specifics', 'Specific Weapon Proficiencies',
      const ['weapon'], isList: true);
  fb.relation('armor_trainings', 'Armor Trainings', const ['armor-category'], isList: true);
  fb.relation('skill_proficiencies', 'Skill Proficiencies', const ['skill'], isList: true);
  fb.relation('expertise_skills', 'Expertise Skills', const ['skill'], isList: true);
  fb.relation('saving_throw_proficiencies', 'Save Proficiencies', const ['ability'], isList: true, required_: true);
  // Combat
  fb.statBlock('stat_block', 'Ability Scores');
  fb.combatStats('combat_stats', 'Combat Stats');
  fb.integer('temp_hp', 'Temp HP', required_: true, min: 0, defaultValue: 0, g: grpCombat);
  fb.integer('death_saves_successes', 'Death Save Successes', required_: true, min: 0, max: 3, defaultValue: 0, g: grpCombat);
  fb.integer('death_saves_failures', 'Death Save Failures', required_: true, min: 0, max: 3, defaultValue: 0, g: grpCombat);
  fb.boolean('heroic_inspiration', 'Heroic Inspiration', required_: true, defaultValue: false, g: grpCombat);
  fb.proficiencyTable('hit_dice_remaining', 'Hit Dice Remaining', g: grpCombat);
  // Saves & Skills (full preset rows so the card is ready out-of-box)
  fb.proficiencyTable('saving_throws', 'Saving Throws',
      defaultValue: proficiencyTableDefault(kDnd5eSavingThrows));
  fb.proficiencyTable('skills', 'Skills',
      defaultValue: proficiencyTableDefault(kDnd5eSkills));
  // Senses
  fb.relation('senses', 'Senses', const ['sense'], isList: true, g: grpSensesLanguages);
  fb.integer('passive_perception', 'Passive Perception', min: 0, max: 30, defaultValue: 10, g: grpSensesLanguages);
  fb.integer('passive_insight', 'Passive Insight', min: 0, max: 30, defaultValue: 10, g: grpSensesLanguages);
  fb.integer('passive_investigation', 'Passive Investigation', min: 0, max: 30, defaultValue: 10, g: grpSensesLanguages);
  // Inventory & Resources
  fb.relation('inventory', 'Inventory', const ['weapon', 'armor', 'adventuring-gear', 'magic-item'], isList: true, g: grpProperties);
  fb.relation('attuned_items', 'Attuned Items (max 3)', const ['magic-item'], isList: true, g: grpProperties);
  // Equipped state — drives AC, attack, and don/doff actions.
  fb.relation('equipped_armor_ref', 'Equipped Armor', const ['armor', 'magic-item'], g: grpProperties);
  fb.relation('equipped_shield_ref', 'Equipped Shield', const ['armor', 'magic-item'], g: grpProperties);
  fb.relation('held_weapons', 'Held Weapons (max 2)', const ['weapon', 'magic-item'], isList: true, g: grpProperties);
  // Equipped magic items (wearables — head/neck/finger/etc.). Resolver groups
  // by each item's body_slot_ref and enforces body-slot.max_equipped.
  // Armor + shield + held_weapons live in their own dedicated fields.
  fb.relation('equipped_magic_items', 'Equipped Magic Items', const ['magic-item'],
      isList: true, g: grpProperties);
  // Downtime
  fb.relation('current_lifestyle_ref', 'Current Lifestyle', const ['lifestyle'], g: grpProperties);
  // Currency
  fb.integer('cp', 'Copper (cp)', min: 0, defaultValue: 0, g: grpCostWeight);
  fb.integer('sp', 'Silver (sp)', min: 0, defaultValue: 0, g: grpCostWeight);
  fb.integer('ep', 'Electrum (ep)', min: 0, defaultValue: 0, g: grpCostWeight);
  fb.integer('gp', 'Gold (gp)', min: 0, defaultValue: 0, g: grpCostWeight);
  fb.integer('pp', 'Platinum (pp)', min: 0, defaultValue: 0, g: grpCostWeight);
  // Defenses (parallel NPC/Monster — resistance/vulnerability/immunity tracking)
  fb.relation('resistance_refs', 'Resistances', const ['damage-type'], isList: true, g: grpResistances);
  fb.relation('vulnerability_refs', 'Vulnerabilities', const ['damage-type'], isList: true, g: grpResistances);
  fb.relation('damage_immunity_refs', 'Damage Immunities', const ['damage-type'], isList: true, g: grpResistances);
  fb.relation('condition_immunity_refs', 'Condition Immunities', const ['condition'], isList: true, g: grpResistances);
  fb.relation('current_conditions', 'Current Conditions', const ['applied-condition'], isList: true, g: grpResistances);
  // Spells
  fb.relation('casting_ability_ref', 'Casting Ability', const ['ability'], g: grpSpellcasting);
  fb.integer('spell_save_dc', 'Spell Save DC', min: 0, max: 30, g: grpSpellcasting);
  fb.integer('spell_attack_bonus', 'Spell Attack Bonus', g: grpSpellcasting);
  fb.relation('concentration_spell_ref', 'Concentrating On', const ['spell'], g: grpSpellcasting);
  fb.integer('concentration_remaining_rounds', 'Concentration Rounds Left', min: 0, max: 10000, g: grpSpellcasting);
  fb.relation('spells_known', 'Spells Known', const ['spell'], isList: true, g: grpSpells);
  fb.relation('prepared_spells', 'Prepared Spells', const ['spell'], isList: true, g: grpSpells);
  fb.slot('spell_slots', 'Spell Slots', g: grpSpellcasting);
  fb.slot('pact_magic_slots', 'Pact Magic Slots', g: grpSpellcasting);
  fb.proficiencyTable('class_resources', 'Class Resources', g: grpFeatures);
  fb.relation('trinket_ref', 'Trinket', const ['trinket']);
  // Personality (PHB §1)
  fb.markdown('personality_traits', 'Personality Traits', g: grpRules);
  fb.markdown('ideals', 'Ideals', g: grpRules);
  fb.markdown('bonds', 'Bonds', g: grpRules);
  fb.markdown('flaws', 'Flaws', g: grpRules);
  // Physical
  fb.text('age', 'Age', g: grpIdentity);
  fb.text('height', 'Height', g: grpIdentity);
  fb.text('weight', 'Weight', g: grpIdentity);
  fb.text('eyes', 'Eyes', g: grpIdentity);
  fb.text('skin', 'Skin', g: grpIdentity);
  fb.text('hair', 'Hair', g: grpIdentity);
  fb.markdown('appearance', 'Appearance', g: grpRules);
  fb.markdown('backstory', 'Backstory', g: grpRules);
  fb.markdown('allies_organizations', 'Allies & Organizations', g: grpRules);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Player Character',
    slug: 'player-character',
    color: '#4caf50',
    icon: 'person_outline',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpProgression, name: 'Progression', gridColumns: 2, orderIndex: 1),
      FieldGroup(groupId: grpAbilityScores, name: 'Ability Scores', gridColumns: 1, orderIndex: 2),
      FieldGroup(groupId: grpCombat, name: 'Combat', gridColumns: 2, orderIndex: 3),
      FieldGroup(groupId: grpProperties, name: 'Inventory', gridColumns: 1, orderIndex: 4),
      FieldGroup(groupId: grpResistances, name: 'Defenses', gridColumns: 1, orderIndex: 5),
      FieldGroup(groupId: grpSpells, name: 'Spells', gridColumns: 1, orderIndex: 6),
      FieldGroup(groupId: grpSpellcasting, name: 'Slots', gridColumns: 1, orderIndex: 7),
      FieldGroup(groupId: grpFeatures, name: 'Class Resources', gridColumns: 1, orderIndex: 8),
      FieldGroup(groupId: grpRules, name: 'Roleplay', gridColumns: 1, orderIndex: 9),
    ],
    orderIndex: orderIndex,
    now: now,
    allowedInSections: const ['encounter', 'mindmap', 'worldmap', 'projection'],
    filterFieldKeys: const ['xp'],
  );
}

EntityCategorySchema _appliedConditionCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('condition_ref', 'Condition', const ['condition'], required_: true);
  fb.relation('source_entity_ref', 'Source', const ['npc', 'player-character', 'monster', 'animal']);
  fb.integer('duration_rounds', 'Duration (rounds)', min: 0, help: 'null = indefinite');
  fb.integer('save_dc', 'Save DC', min: 1, max: 30);
  fb.relation('save_ability_ref', 'Save Ability', const ['ability']);
  fb.enum_('save_frequency', 'Save Frequency',
      const ['none', 'start-of-turn', 'end-of-turn', 'when-damaged']);
  fb.textarea('notes', 'Notes');

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Applied Condition',
    slug: 'applied-condition',
    color: '#9c27b0',
    icon: 'healing',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
    ],
    orderIndex: orderIndex,
    now: now,
    allowedInSections: const ['encounter'],
  );
}

EntityCategorySchema _locationCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.enum_('danger_level', 'Danger Level', const ['Safe', 'Low', 'Medium', 'High', 'Deadly']);
  fb.text('environment', 'Environment');
  fb.relation('parent_location_ref', 'Parent Location', const ['location']);
  fb.relation('plane_ref', 'Plane', const ['plane']);
  fb.relation('illumination_ref', 'Illumination', const ['illumination']);
  fb.relation('hazard_refs', 'Hazards', const ['hazard'], isList: true);
  fb.markdown('description_long', 'Description', g: grpRules);
  fb.markdown('secrets', 'Secrets (DM-only)', g: grpRules, vis: FieldVisibility.dmOnly);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Location',
    slug: 'location',
    color: '#2e7d32',
    icon: 'place',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Description', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
    allowedInSections: const ['worldmap', 'mindmap'],
    filterFieldKeys: const ['danger_level'],
  );
}

EntityCategorySchema _sceneCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('location_ref', 'Location', const ['location']);
  fb.enum_('status', 'Status', const ['Planned', 'Active', 'Completed', 'Skipped']);
  fb.relation('illumination_ref', 'Illumination', const ['illumination']);
  fb.relation('travel_pace_ref', 'Travel Pace', const ['travel-pace']);
  fb.markdown('beats', 'Beats / Outline', g: grpRules);
  fb.relation('npc_refs', 'NPCs Involved', const ['npc'], isList: true);
  fb.relation('quest_refs', 'Quests Tied', const ['quest'], isList: true);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Scene',
    slug: 'scene',
    color: '#3949ab',
    icon: 'movie',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Outline', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
    allowedInSections: const ['mindmap'],
    filterFieldKeys: const ['status'],
  );
}

EntityCategorySchema _questCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.enum_('status', 'Status', const ['Not Started', 'Active', 'Completed', 'Failed']);
  fb.relation('giver_ref', 'Quest Giver', const ['npc']);
  // Typed reward (auto-grant on completion).
  fb.relation('reward_item_refs', 'Reward Items',
      const ['magic-item', 'adventuring-gear', 'weapon', 'armor', 'trinket'],
      isList: true, g: grpRules);
  fb.integer('reward_xp', 'Reward XP', min: 0, g: grpRules);
  fb.integer('reward_gp', 'Reward Gold (gp)', min: 0, g: grpRules);
  fb.markdown('reward', 'Reward (narrative)', g: grpRules);
  fb.markdown('objective', 'Objective', g: grpRules);
  fb.markdown('secrets', 'Secrets (DM-only)', g: grpRules, vis: FieldVisibility.dmOnly);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Quest',
    slug: 'quest',
    color: '#f57c00',
    icon: 'flag',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Details', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
    allowedInSections: const ['mindmap'],
    filterFieldKeys: const ['status'],
  );
}

EntityCategorySchema _encounterCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('location_ref', 'Location', const ['location']);
  fb.enum_('difficulty', 'Difficulty', const ['Trivial', 'Low', 'Moderate', 'High', 'Deadly']);
  fb.relation('monsters_refs', 'Monsters', const ['monster', 'animal'], isList: true);
  fb.relation('npcs_refs', 'NPCs', const ['npc'], isList: true);
  fb.relation('environmental_effect_refs', 'Environmental Effects', const ['environmental-effect'], isList: true);
  fb.relation('trap_refs', 'Traps', const ['trap'], isList: true);
  fb.markdown('setup', 'Setup', g: grpRules);
  fb.markdown('tactics', 'Tactics (DM-only)', g: grpRules, vis: FieldVisibility.dmOnly);
  fb.integer('xp_budget', 'XP Budget', min: 0);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Encounter',
    slug: 'encounter',
    color: '#c62828',
    icon: 'sports_kabaddi',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Setup', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
    allowedInSections: const ['encounter', 'mindmap'],
    filterFieldKeys: const ['difficulty'],
  );
}

EntityCategorySchema _trapCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.enum_('trigger_kind', 'Trigger Kind',
      const ['Pressure', 'Tripwire', 'Proximity', 'Sound', 'Magical', 'Touch', 'Other'],
      g: grpRules);
  fb.markdown('trigger', 'Trigger (narrative)', g: grpRules);
  fb.integer('save_dc', 'Save DC', min: 1, max: 30);
  fb.relation('save_ability_ref', 'Save Ability', const ['ability']);
  fb.dice('damage_dice', 'Damage Dice');
  fb.relation('damage_type_ref', 'Damage Type', const ['damage-type']);
  fb.relation('applied_condition_refs', 'Applied Conditions',
      const ['condition'], isList: true, g: grpRules);
  fb.integer('detection_dc', 'Detection DC', min: 1, max: 30);
  fb.integer('disable_dc', 'Disable DC', min: 1, max: 30);
  fb.relation('disable_ability_ref', 'Disable Ability', const ['ability'], g: grpRules);
  fb.markdown('countermeasures', 'Countermeasures (narrative)', g: grpRules);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Trap',
    slug: 'trap',
    color: '#bf360c',
    icon: 'gpp_bad',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Mechanics', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
    allowedInSections: const ['encounter', 'mindmap'],
  );
}

EntityCategorySchema _poisonCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.enum_('poison_kind', 'Kind', const ['Contact', 'Ingested', 'Inhaled', 'Injury'], required_: true);
  fb.integer('save_dc', 'Save DC', min: 1, max: 30);
  fb.relation('save_ability_ref', 'Save Ability', const ['ability']);
  fb.dice('damage_dice', 'Damage Dice', g: grpRules);
  fb.relation('damage_type_ref', 'Damage Type', const ['damage-type'], g: grpRules);
  fb.relation('applied_condition_refs', 'Applied Conditions',
      const ['condition'], isList: true, g: grpRules);
  fb.integer('duration_rounds', 'Duration (rounds)', min: 0, g: grpRules);
  fb.markdown('effect', 'Effect (narrative)', g: grpRules, vis: FieldVisibility.shared);
  fb.integer('cost_gp', 'Cost (gp)', min: 0);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Poison',
    slug: 'poison',
    color: '#558b2f',
    icon: 'science',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Effect', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
    filterFieldKeys: const ['poison_kind'],
  );
}

EntityCategorySchema _curseCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.markdown('trigger', 'Trigger (narrative)', g: grpRules);
  fb.relation('applied_condition_refs', 'Applied Conditions',
      const ['condition'], isList: true, g: grpRules);
  fb.relation('removed_by_spell_refs', 'Removed By Spells',
      const ['spell'], isList: true, g: grpRules);
  // Ongoing typed modifiers (e.g. -2 to all attack rolls while cursed).
  fb.grantedModifiers('granted_modifiers', 'Granted Modifiers (typed)', g: grpRules);
  fb.markdown('effect', 'Effect (narrative)', g: grpRules);
  fb.markdown('removed_by', 'Removed By (narrative)', g: grpRules);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Curse',
    slug: 'curse',
    color: '#6a1b9a',
    icon: 'auto_fix_off',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Effect', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
  );
}

EntityCategorySchema _environmentalEffectCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.dice('damage_dice', 'Damage Dice', g: grpRules);
  fb.relation('damage_type_ref', 'Damage Type', const ['damage-type'], g: grpRules);
  fb.relation('applied_condition_refs', 'Applied Conditions',
      const ['condition'], isList: true, g: grpRules);
  // Ongoing typed modifiers (e.g. difficult terrain → speed_bonus -10).
  fb.grantedModifiers('granted_modifiers', 'Granted Modifiers (typed)', g: grpRules);
  fb.markdown('effect', 'Effect (narrative)', g: grpRules);
  fb.integer('save_dc', 'Save DC', min: 1, max: 30);
  fb.relation('save_ability_ref', 'Save Ability', const ['ability']);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Environmental Effect',
    slug: 'environmental-effect',
    color: '#0097a7',
    icon: 'cloud',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
      FieldGroup(groupId: grpRules, name: 'Effect', gridColumns: 1, orderIndex: 1),
    ],
    orderIndex: orderIndex,
    now: now,
  );
}

EntityCategorySchema _hirelingCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.relation('skill_ref', 'Skill', const ['skill']);
  fb.integer('daily_cost_cp', 'Daily Cost (cp)', required_: true, min: 0);
  fb.boolean('skilled', 'Skilled', required_: true);

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Hireling',
    slug: 'hireling',
    color: '#a1887f',
    icon: 'engineering',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
    ],
    orderIndex: orderIndex,
    now: now,
  );
}

EntityCategorySchema _serviceCategory(String schemaId, String now, int orderIndex) {
  final catId = _uuid.v4();
  final fb = _FB(catId, now);
  fb.enum_('kind', 'Kind', const ['Spellcasting', 'Transport', 'Shelter', 'Other'], required_: true);
  fb.integer('cost_cp', 'Cost (cp)', required_: true, min: 0);
  fb.text('availability', 'Availability');

  return _mk(
    schemaId: schemaId,
    categoryId: catId,
    name: 'Service',
    slug: 'service',
    color: '#9e9d24',
    icon: 'storefront',
    fields: fb.out,
    groups: const [
      FieldGroup(groupId: grpIdentity, name: 'Identity', gridColumns: 2, orderIndex: 0),
    ],
    orderIndex: orderIndex,
    now: now,
    filterFieldKeys: const ['kind'],
  );
}
