import 'package:uuid/uuid.dart';

import 'encounter_layout.dart';
import 'entity_category_schema.dart';
import 'field_schema.dart';
import 'world_schema.dart';

const _uuid = Uuid();

/// Mevcut Python ENTITY_SCHEMAS + get_default_entity_structure() yapısından
/// üretilen varsayılan D&D 5e WorldSchema.
/// Yeni kampanya oluşturulduğunda bu schema gömülü olarak kullanılır.
WorldSchema generateDefaultDnd5eSchema() {
  final now = DateTime.now().toUtc().toIso8601String();
  final schemaId = _uuid.v4();

  final categories = <EntityCategorySchema>[];
  var orderIdx = 0;

  for (final def in _categoryDefs) {
    final catId = _uuid.v4();
    final fields = <FieldSchema>[];
    var fieldIdx = 0;

    // Source alanı — tüm kategorilerde ortak
    fields.add(FieldSchema(
      fieldId: _uuid.v4(),
      categoryId: catId,
      fieldKey: 'source',
      label: 'Source',
      fieldType: FieldType.text,
      placeholder: 'e.g. PHB, MM, Custom',
      orderIndex: fieldIdx++,
      isBuiltin: true,
      createdAt: now,
      updatedAt: now,
    ));

    // Tip-spesifik attribute alanları
    for (final f in def.attributes) {
      fields.add(FieldSchema(
        fieldId: _uuid.v4(),
        categoryId: catId,
        fieldKey: f.key,
        label: f.label,
        fieldType: f.type,
        validation: f.validation ?? const FieldValidation(),
        orderIndex: fieldIdx++,
        isBuiltin: true,
        createdAt: now,
        updatedAt: now,
      ));
    }

    // Ortak alanlar (NPC, Monster, Player için)
    if (def.hasStatBlock) {
      fields.add(FieldSchema(
        fieldId: _uuid.v4(),
        categoryId: catId,
        fieldKey: 'stat_block',
        label: 'Ability Scores',
        fieldType: FieldType.statBlock,
        defaultValue: const {'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10},
        orderIndex: fieldIdx++,
        isBuiltin: true,
        createdAt: now,
        updatedAt: now,
      ));
      fields.add(FieldSchema(
        fieldId: _uuid.v4(),
        categoryId: catId,
        fieldKey: 'combat_stats',
        label: 'Combat Stats',
        fieldType: FieldType.combatStats,
        defaultValue: const {'hp': '', 'max_hp': '', 'ac': '', 'speed': '', 'cr': '', 'xp': '', 'initiative': ''},
        orderIndex: fieldIdx++,
        isBuiltin: true,
        createdAt: now,
        updatedAt: now,
      ));
      fields.add(FieldSchema(
        fieldId: _uuid.v4(),
        categoryId: catId,
        fieldKey: 'saving_throws',
        label: 'Saving Throws',
        fieldType: FieldType.text,
        orderIndex: fieldIdx++,
        isBuiltin: true,
        createdAt: now,
        updatedAt: now,
      ));
      fields.add(FieldSchema(
        fieldId: _uuid.v4(),
        categoryId: catId,
        fieldKey: 'skills',
        label: 'Skills',
        fieldType: FieldType.text,
        orderIndex: fieldIdx++,
        isBuiltin: true,
        createdAt: now,
        updatedAt: now,
      ));
      fields.add(FieldSchema(
        fieldId: _uuid.v4(),
        categoryId: catId,
        fieldKey: 'damage_vulnerabilities',
        label: 'Damage Vulnerabilities',
        fieldType: FieldType.text,
        orderIndex: fieldIdx++,
        isBuiltin: true,
        createdAt: now,
        updatedAt: now,
      ));
      fields.add(FieldSchema(
        fieldId: _uuid.v4(),
        categoryId: catId,
        fieldKey: 'damage_resistances',
        label: 'Damage Resistances',
        fieldType: FieldType.text,
        orderIndex: fieldIdx++,
        isBuiltin: true,
        createdAt: now,
        updatedAt: now,
      ));
      fields.add(FieldSchema(
        fieldId: _uuid.v4(),
        categoryId: catId,
        fieldKey: 'damage_immunities',
        label: 'Damage Immunities',
        fieldType: FieldType.text,
        orderIndex: fieldIdx++,
        isBuiltin: true,
        createdAt: now,
        updatedAt: now,
      ));
      fields.add(FieldSchema(
        fieldId: _uuid.v4(),
        categoryId: catId,
        fieldKey: 'condition_immunities',
        label: 'Condition Immunities',
        fieldType: FieldType.text,
        orderIndex: fieldIdx++,
        isBuiltin: true,
        createdAt: now,
        updatedAt: now,
      ));
      fields.add(FieldSchema(
        fieldId: _uuid.v4(),
        categoryId: catId,
        fieldKey: 'proficiency_bonus',
        label: 'Proficiency Bonus',
        fieldType: FieldType.text,
        orderIndex: fieldIdx++,
        isBuiltin: true,
        createdAt: now,
        updatedAt: now,
      ));
      fields.add(FieldSchema(
        fieldId: _uuid.v4(),
        categoryId: catId,
        fieldKey: 'passive_perception',
        label: 'Passive Perception',
        fieldType: FieldType.text,
        orderIndex: fieldIdx++,
        isBuiltin: true,
        createdAt: now,
        updatedAt: now,
      ));
    }

    if (def.hasActions) {
      const actionFields = [
        ('traits', 'Trait List', 'trait'),
        ('actions', 'Action List', 'action'),
        ('reactions', 'Reaction List', 'reaction'),
        ('legendary_actions', 'Legendary Action List', 'legendary-action'),
      ];
      for (final (key, label, targetSlug) in actionFields) {
        fields.add(FieldSchema(
          fieldId: _uuid.v4(),
          categoryId: catId,
          fieldKey: key,
          label: label,
          fieldType: FieldType.relation,
          isList: true,
          validation: FieldValidation(allowedTypes: [targetSlug]),
          orderIndex: fieldIdx++,
          isBuiltin: true,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }

    if (def.hasSpells) {
      fields.add(FieldSchema(
        fieldId: _uuid.v4(),
        categoryId: catId,
        fieldKey: 'spells',
        label: 'Spell List',
        fieldType: FieldType.relation,
        isList: true,
        validation: const FieldValidation(allowedTypes: ['spell']),
        orderIndex: fieldIdx++,
        isBuiltin: true,
        createdAt: now,
        updatedAt: now,
      ));
    }

    categories.add(EntityCategorySchema(
      categoryId: catId,
      schemaId: schemaId,
      name: def.name,
      slug: def.slug,
      icon: 'default_${def.slug}',
      color: def.color,
      isBuiltin: true,
      orderIndex: orderIdx++,
      fields: fields,
      allowedInSections: def.sections,
      filterFieldKeys: def.filters,
      createdAt: now,
      updatedAt: now,
    ));
  }

  return WorldSchema(
    schemaId: schemaId,
    name: 'D&D 5e (Default)',
    version: '1.0.0',
    baseSystem: 'dnd5e',
    description: 'Built-in D&D 5e entity model with 15 categories.',
    categories: categories,
    encounterLayouts: [_defaultEncounterLayout(schemaId)],
    createdAt: now,
    updatedAt: now,
  );
}

EncounterLayout _defaultEncounterLayout(String schemaId) {
  return EncounterLayout(
    layoutId: _uuid.v4(),
    schemaId: schemaId,
    name: 'Standard D&D 5e',
    columns: const [
      EncounterColumn(fieldKey: 'name', displayLabel: 'Name', width: 150),
      EncounterColumn(fieldKey: 'initiative', displayLabel: 'Init', width: 50, isEditable: true),
      EncounterColumn(fieldKey: 'ac', displayLabel: 'AC', width: 50),
      EncounterColumn(fieldKey: 'hp', displayLabel: 'HP', width: 120, isEditable: true, formatTemplate: '{value}/{max_value}'),
      EncounterColumn(fieldKey: 'conditions', displayLabel: 'Conditions', width: 0),
    ],
    sortRules: const [
      SortRule(fieldKey: 'initiative', direction: 'desc', priority: 0),
    ],
  );
}

// ---------------------------------------------------------------------------
// Category Definitions — maps Python ENTITY_SCHEMAS to Dart
// ---------------------------------------------------------------------------

class _FieldDef {
  final String key;
  final String label;
  final FieldType type;
  final FieldValidation? validation;

  const _FieldDef(this.key, this.label, this.type, [this.validation]);
}

class _CategoryDef {
  final String name;
  final String slug;
  final String color;
  final List<_FieldDef> attributes;
  final bool hasStatBlock;
  final bool hasActions;
  final bool hasSpells;
  final List<String> sections;
  final List<String> filters;

  const _CategoryDef(
    this.name,
    this.slug,
    this.color,
    this.attributes, {
    this.hasStatBlock = false,
    this.hasActions = false,
    this.hasSpells = false,
    this.sections = const ['mindmap'],
    this.filters = const [],
  });
}

const _categoryDefs = [
  _CategoryDef('NPC', 'npc', '#ff9800', [
    _FieldDef('race', 'Race', FieldType.relation, FieldValidation(allowedTypes: ['race'])),
    _FieldDef('class_', 'Class', FieldType.relation, FieldValidation(allowedTypes: ['class'])),
    _FieldDef('level', 'Level', FieldType.text),
    _FieldDef('attitude', 'Attitude', FieldType.enum_, FieldValidation(allowedValues: ['Friendly', 'Neutral', 'Hostile'])),
    _FieldDef('location', 'Location', FieldType.relation, FieldValidation(allowedTypes: ['location'])),
  ], hasStatBlock: true, hasActions: true, hasSpells: true,
     sections: ['encounter', 'mindmap', 'worldmap', 'projection'], filters: ['attitude', 'level', 'source']),

  _CategoryDef('Monster', 'monster', '#d32f2f', [
    _FieldDef('cr', 'Challenge Rating', FieldType.text),
    _FieldDef('attack_type', 'Attack Type', FieldType.text),
  ], hasStatBlock: true, hasActions: true, hasSpells: true,
     sections: ['encounter', 'mindmap', 'worldmap', 'projection'], filters: ['cr', 'attack_type', 'source']),

  _CategoryDef('Player', 'player', '#4caf50', [
    _FieldDef('class_', 'Class', FieldType.relation, FieldValidation(allowedTypes: ['class'])),
    _FieldDef('race', 'Race', FieldType.relation, FieldValidation(allowedTypes: ['race'])),
    _FieldDef('level', 'Level', FieldType.text),
  ], hasStatBlock: true, hasActions: true, hasSpells: true,
     sections: ['encounter', 'mindmap', 'worldmap', 'projection'], filters: ['level']),

  _CategoryDef('Spell', 'spell', '#7b1fa2', [
    _FieldDef('level', 'Level', FieldType.enum_, FieldValidation(allowedValues: ['Cantrip', '1', '2', '3', '4', '5', '6', '7', '8', '9'])),
    _FieldDef('school', 'School', FieldType.text),
    _FieldDef('casting_time', 'Casting Time', FieldType.text),
    _FieldDef('range', 'Range', FieldType.text),
    _FieldDef('duration', 'Duration', FieldType.text),
    _FieldDef('components', 'Components', FieldType.text),
  ], sections: ['mindmap'], filters: ['level', 'school', 'source']),

  _CategoryDef('Equipment', 'equipment', '#795548', [
    _FieldDef('category', 'Category', FieldType.text),
    _FieldDef('rarity', 'Rarity', FieldType.text),
    _FieldDef('attunement', 'Attunement', FieldType.text),
    _FieldDef('cost', 'Cost', FieldType.text),
    _FieldDef('weight', 'Weight', FieldType.text),
    _FieldDef('damage_dice', 'Damage Dice', FieldType.text),
    _FieldDef('damage_type', 'Damage Type', FieldType.text),
    _FieldDef('range', 'Range', FieldType.text),
    _FieldDef('ac', 'AC', FieldType.text),
    _FieldDef('requirements', 'Requirements', FieldType.text),
    _FieldDef('properties', 'Properties', FieldType.text),
  ], sections: ['mindmap'], filters: ['category', 'rarity', 'source']),

  _CategoryDef('Class', 'class', '#1976d2', [
    _FieldDef('hit_die', 'Hit Die', FieldType.text),
    _FieldDef('main_stats', 'Main Stats', FieldType.text),
    _FieldDef('proficiencies', 'Proficiencies', FieldType.text),
  ]),

  _CategoryDef('Race', 'race', '#00897b', [
    _FieldDef('speed', 'Speed', FieldType.text),
    _FieldDef('size', 'Size', FieldType.enum_, FieldValidation(allowedValues: ['Small', 'Medium', 'Large'])),
    _FieldDef('alignment', 'Alignment', FieldType.text),
    _FieldDef('language', 'Language', FieldType.text),
  ]),

  _CategoryDef('Location', 'location', '#2e7d32', [
    _FieldDef('danger_level', 'Danger Level', FieldType.enum_, FieldValidation(allowedValues: ['Safe', 'Low', 'Medium', 'High'])),
    _FieldDef('environment', 'Environment', FieldType.text),
  ], sections: ['worldmap', 'mindmap'], filters: ['danger_level']),

  _CategoryDef('Quest', 'quest', '#f57c00', [
    _FieldDef('status', 'Status', FieldType.enum_, FieldValidation(allowedValues: ['Not Started', 'Active', 'Completed'])),
    _FieldDef('giver', 'Quest Giver', FieldType.text),
    _FieldDef('reward', 'Reward', FieldType.text),
  ], sections: ['mindmap'], filters: ['status']),

  _CategoryDef('Lore', 'lore', '#5c6bc0', [
    _FieldDef('category', 'Category', FieldType.enum_, FieldValidation(allowedValues: ['History', 'Geography', 'Religion', 'Culture', 'Other'])),
    _FieldDef('secret_info', 'Secret Info', FieldType.text),
  ], sections: ['mindmap'], filters: ['category']),

  _CategoryDef('Status Effect', 'status-effect', '#e91e63', [
    _FieldDef('duration_turns', 'Duration (Turns)', FieldType.text),
    _FieldDef('effect_type', 'Effect Type', FieldType.enum_, FieldValidation(allowedValues: ['Buff', 'Debuff', 'Condition'])),
    _FieldDef('linked_condition', 'Linked Condition', FieldType.relation, FieldValidation(allowedTypes: ['condition'])),
  ], sections: ['encounter'], filters: ['effect_type']),

  _CategoryDef('Feat', 'feat', '#ff7043', [
    _FieldDef('prerequisite', 'Prerequisite', FieldType.text),
  ]),

  _CategoryDef('Background', 'background', '#8d6e63', [
    _FieldDef('skill_proficiencies', 'Skill Proficiencies', FieldType.text),
    _FieldDef('tool_proficiencies', 'Tool Proficiencies', FieldType.text),
    _FieldDef('languages', 'Languages', FieldType.text),
    _FieldDef('equipment', 'Equipment', FieldType.text),
  ]),

  _CategoryDef('Plane', 'plane', '#26c6da', [
    _FieldDef('type', 'Type', FieldType.text),
  ], sections: ['mindmap', 'worldmap']),

  _CategoryDef('Condition', 'condition', '#ab47bc', [
    _FieldDef('effects', 'Effects', FieldType.text),
  ], sections: ['encounter']),

  // --- Action kategorileri (D&D 5e SRD) ---
  _CategoryDef('Trait', 'trait', '#78909c', [
    _FieldDef('usage', 'Usage', FieldType.text),
  ]),

  _CategoryDef('Action', 'action', '#ef6c00', [
    _FieldDef('attack_bonus', 'Attack Bonus', FieldType.text),
    _FieldDef('damage_dice', 'Damage Dice', FieldType.text),
    _FieldDef('damage_type', 'Damage Type', FieldType.text),
  ]),

  _CategoryDef('Reaction', 'reaction', '#5e35b1', [
    _FieldDef('trigger', 'Trigger', FieldType.text),
  ]),

  _CategoryDef('Legendary Action', 'legendary-action', '#ffd600', [
    _FieldDef('cost', 'Cost', FieldType.enum_, FieldValidation(allowedValues: ['1', '2', '3'])),
  ]),
];
