import 'package:uuid/uuid.dart';

import '../entity_category_schema.dart';
import '../field_schema.dart';
import 'groups.dart';

const _uuid = Uuid();

/// All Tier-0 lookup category slugs, in canonical order.
/// Relation fields across Tier-1 content reference these slugs via
/// [FieldValidation.allowedTypes].
const tier0Slugs = <String>[
  'ability',
  'skill',
  'damage-type',
  'condition',
  'creature-type',
  'language',
  'weapon-property',
  'weapon-mastery',
  'spell-school',
  'magic-item-category',
  'sense',
  'hazard',
  'arcane-focus',
  'druidic-focus',
  'holy-symbol',
  'size',
  'rarity',
  'coin',
  'lifestyle',
  'duration-unit',
  'body-slot',
  'alignment',
  'weapon-category',
  'armor-category',
  'tool-category',
  'feat-category',
  'action',
  'area-shape',
  'attitude',
  'illumination',
  'travel-pace',
  'plane',
  'casting-component',
  'casting-time-unit',
  'speed-type',
  'cover',
  'tier-of-play',
];

/// One row of the Tier-0 category output: the category schema plus its
/// canonical seed rows (already-flattened `fields` maps).
class Tier0CategoryBuild {
  final EntityCategorySchema category;
  final List<Map<String, dynamic>> seedRows;
  const Tier0CategoryBuild(this.category, this.seedRows);
}

/// Build every Tier-0 lookup category for the given [schemaId].
/// Deterministic order matches [tier0Slugs].
List<Tier0CategoryBuild> buildTier0Lookups({
  required String schemaId,
  required String now,
}) {
  return [
    _abilityCategory(schemaId, now),
    _skillCategory(schemaId, now),
    _damageTypeCategory(schemaId, now),
    _conditionCategory(schemaId, now),
    _creatureTypeCategory(schemaId, now),
    _languageCategory(schemaId, now),
    _weaponPropertyCategory(schemaId, now),
    _weaponMasteryCategory(schemaId, now),
    _spellSchoolCategory(schemaId, now),
    _magicItemCategoryCategory(schemaId, now),
    _senseCategory(schemaId, now),
    _hazardCategory(schemaId, now),
    _arcaneFocusCategory(schemaId, now),
    _druidicFocusCategory(schemaId, now),
    _holySymbolCategory(schemaId, now),
    _sizeCategory(schemaId, now),
    _rarityCategory(schemaId, now),
    _coinCategory(schemaId, now),
    _lifestyleCategory(schemaId, now),
    _durationUnitCategory(schemaId, now),
    _bodySlotCategory(schemaId, now),
    _alignmentCategory(schemaId, now),
    _weaponCategoryCategory(schemaId, now),
    _armorCategoryCategory(schemaId, now),
    _toolCategoryCategory(schemaId, now),
    _featCategoryCategory(schemaId, now),
    _actionCategory(schemaId, now),
    _areaShapeCategory(schemaId, now),
    _attitudeCategory(schemaId, now),
    _illuminationCategory(schemaId, now),
    _travelPaceCategory(schemaId, now),
    _planeCategory(schemaId, now),
    _castingComponentCategory(schemaId, now),
    _castingTimeUnitCategory(schemaId, now),
    _speedTypeCategory(schemaId, now),
    _coverCategory(schemaId, now),
    _tierOfPlayCategory(schemaId, now),
  ];
}

// ---------------------------------------------------------------------------
// Shared builders
// ---------------------------------------------------------------------------

/// Build the common fields every Tier-0 row carries.
/// Extra category-specific fields are appended in order after these.
List<FieldSchema> _commonLookupFields({
  required String categoryId,
  required String now,
  bool includeAbbreviation = true,
  bool includeEffects = true,
}) {
  final fields = <FieldSchema>[];
  var idx = 0;

  if (includeAbbreviation) {
    fields.add(FieldSchema(
      fieldId: _uuid.v4(),
      categoryId: categoryId,
      fieldKey: 'abbreviation',
      label: 'Abbreviation',
      fieldType: FieldType.text,
      helpText: 'Short code (e.g. "STR", "GP", "LG")',
      orderIndex: idx++,
      isBuiltin: true,
      groupId: grpIdentity,
      createdAt: now,
      updatedAt: now,
    ));
  }

  fields.add(FieldSchema(
    fieldId: _uuid.v4(),
    categoryId: categoryId,
    fieldKey: 'summary',
    label: 'Summary',
    fieldType: FieldType.textarea,
    helpText: 'One-line glossary definition',
    orderIndex: idx++,
    isBuiltin: true,
    groupId: grpIdentity,
    gridColumnSpan: 2,
    createdAt: now,
    updatedAt: now,
  ));

  if (includeEffects) {
    fields.add(FieldSchema(
      fieldId: _uuid.v4(),
      categoryId: categoryId,
      fieldKey: 'effects',
      label: 'Effects',
      fieldType: FieldType.markdown,
      helpText: 'Full glossary body',
      orderIndex: idx++,
      isBuiltin: true,
      groupId: grpLookupMeta,
      gridColumnSpan: 2,
      createdAt: now,
      updatedAt: now,
    ));
  }

  fields.add(FieldSchema(
    fieldId: _uuid.v4(),
    categoryId: categoryId,
    fieldKey: 'icon_name',
    label: 'Icon',
    fieldType: FieldType.text,
    helpText: 'Material Icons name',
    orderIndex: idx++,
    isBuiltin: true,
    groupId: grpLookupMeta,
    createdAt: now,
    updatedAt: now,
  ));

  fields.add(FieldSchema(
    fieldId: _uuid.v4(),
    categoryId: categoryId,
    fieldKey: 'color',
    label: 'Color',
    fieldType: FieldType.text,
    helpText: 'Hex color',
    orderIndex: idx++,
    isBuiltin: true,
    groupId: grpLookupMeta,
    createdAt: now,
    updatedAt: now,
  ));

  return fields;
}

/// Helper to append category-specific fields after the common block,
/// continuing the orderIndex sequence.
List<FieldSchema> _withExtras(List<FieldSchema> common, List<FieldSchema Function(int)> extras) {
  final out = List<FieldSchema>.from(common);
  for (final extra in extras) {
    out.add(extra(out.length));
  }
  return out;
}

FieldSchema _textField({
  required String categoryId,
  required String now,
  required String key,
  required String label,
  required int order,
  String? helpText,
  String? groupId,
  bool isRequired = false,
  FieldValidation validation = const FieldValidation(),
}) {
  return FieldSchema(
    fieldId: _uuid.v4(),
    categoryId: categoryId,
    fieldKey: key,
    label: label,
    fieldType: FieldType.text,
    helpText: helpText ?? '',
    orderIndex: order,
    isBuiltin: true,
    isRequired: isRequired,
    validation: validation,
    groupId: groupId ?? grpLookupMeta,
    createdAt: now,
    updatedAt: now,
  );
}

FieldSchema _textareaField({
  required String categoryId,
  required String now,
  required String key,
  required String label,
  required int order,
  String? helpText,
  String? groupId,
}) {
  return FieldSchema(
    fieldId: _uuid.v4(),
    categoryId: categoryId,
    fieldKey: key,
    label: label,
    fieldType: FieldType.textarea,
    helpText: helpText ?? '',
    orderIndex: order,
    isBuiltin: true,
    groupId: groupId ?? grpLookupMeta,
    gridColumnSpan: 2,
    createdAt: now,
    updatedAt: now,
  );
}

FieldSchema _integerField({
  required String categoryId,
  required String now,
  required String key,
  required String label,
  required int order,
  int? minValue,
  int? maxValue,
  String? helpText,
  String? groupId,
  bool isRequired = false,
}) {
  return FieldSchema(
    fieldId: _uuid.v4(),
    categoryId: categoryId,
    fieldKey: key,
    label: label,
    fieldType: FieldType.integer,
    helpText: helpText ?? '',
    isRequired: isRequired,
    validation: FieldValidation(
      minValue: minValue?.toDouble(),
      maxValue: maxValue?.toDouble(),
    ),
    orderIndex: order,
    isBuiltin: true,
    groupId: groupId ?? grpLookupMeta,
    createdAt: now,
    updatedAt: now,
  );
}


FieldSchema _intField({
  required String categoryId,
  required String now,
  required String key,
  required String label,
  required int order,
  int? minValue,
  int? maxValue,
  String? helpText,
  String? groupId,
}) {
  return FieldSchema(
    fieldId: _uuid.v4(),
    categoryId: categoryId,
    fieldKey: key,
    label: label,
    fieldType: FieldType.integer,
    helpText: helpText ?? '',
    validation: FieldValidation(
      minValue: minValue?.toDouble(),
      maxValue: maxValue?.toDouble(),
    ),
    orderIndex: order,
    isBuiltin: true,
    groupId: groupId ?? grpLookupMeta,
    createdAt: now,
    updatedAt: now,
  );
}

FieldSchema _boolField({
  required String categoryId,
  required String now,
  required String key,
  required String label,
  required int order,
  String? helpText,
  String? groupId,
}) {
  return FieldSchema(
    fieldId: _uuid.v4(),
    categoryId: categoryId,
    fieldKey: key,
    label: label,
    fieldType: FieldType.boolean_,
    helpText: helpText ?? '',
    orderIndex: order,
    isBuiltin: true,
    groupId: groupId ?? grpLookupMeta,
    createdAt: now,
    updatedAt: now,
  );
}

FieldSchema _floatField({
  required String categoryId,
  required String now,
  required String key,
  required String label,
  required int order,
  double? minValue,
  double? maxValue,
  String? helpText,
  String? groupId,
  bool isRequired = false,
}) {
  return FieldSchema(
    fieldId: _uuid.v4(),
    categoryId: categoryId,
    fieldKey: key,
    label: label,
    fieldType: FieldType.float_,
    helpText: helpText ?? '',
    isRequired: isRequired,
    validation: FieldValidation(minValue: minValue, maxValue: maxValue),
    orderIndex: order,
    isBuiltin: true,
    groupId: groupId ?? grpLookupMeta,
    createdAt: now,
    updatedAt: now,
  );
}

FieldSchema _enumField({
  required String categoryId,
  required String now,
  required String key,
  required String label,
  required int order,
  required List<String> values,
  String? helpText,
  String? groupId,
  bool isRequired = false,
}) {
  return FieldSchema(
    fieldId: _uuid.v4(),
    categoryId: categoryId,
    fieldKey: key,
    label: label,
    fieldType: FieldType.enum_,
    helpText: helpText ?? '',
    isRequired: isRequired,
    validation: FieldValidation(allowedValues: values),
    orderIndex: order,
    isBuiltin: true,
    groupId: groupId ?? grpLookupMeta,
    createdAt: now,
    updatedAt: now,
  );
}

FieldSchema _relationField({
  required String categoryId,
  required String now,
  required String key,
  required String label,
  required int order,
  required List<String> allowedTypes,
  bool isList = false,
  bool isRequired = false,
  String? groupId,
}) {
  return FieldSchema(
    fieldId: _uuid.v4(),
    categoryId: categoryId,
    fieldKey: key,
    label: label,
    fieldType: FieldType.relation,
    isList: isList,
    isRequired: isRequired,
    validation: FieldValidation(allowedTypes: allowedTypes),
    orderIndex: order,
    isBuiltin: true,
    groupId: groupId ?? grpLookupMeta,
    createdAt: now,
    updatedAt: now,
  );
}

EntityCategorySchema _makeCategory({
  required String schemaId,
  required String categoryId,
  required String name,
  required String slug,
  required String color,
  required String icon,
  required List<FieldSchema> fields,
  required int orderIndex,
  required String now,
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
    fieldGroups: lookupGroups(),
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Tier-0 categories
// Each function returns the shape plus its canonical seed rows.
// Seed rows use slug-stable keys inside `fields`; the Entity's `name` is
// surfaced separately so bootstrap can set it on the base Entity record.
// ---------------------------------------------------------------------------

Tier0CategoryBuild _abilityCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _integerField(
          categoryId: catId,
          now: now,
          key: 'order_index',
          label: 'Order',
          order: o,
          minValue: 0,
          maxValue: 5,
          helpText: '0 = STR, 5 = CHA',
        ),
  ]);
  const rows = [
    {'name': 'Strength', 'fields': {'abbreviation': 'STR', 'summary': 'Physical power applied directly.', 'order_index': 0}},
    {'name': 'Dexterity', 'fields': {'abbreviation': 'DEX', 'summary': 'Agility, reflexes, and balance.', 'order_index': 1}},
    {'name': 'Constitution', 'fields': {'abbreviation': 'CON', 'summary': 'Health, stamina, and vital force.', 'order_index': 2}},
    {'name': 'Intelligence', 'fields': {'abbreviation': 'INT', 'summary': 'Reasoning and memory.', 'order_index': 3}},
    {'name': 'Wisdom', 'fields': {'abbreviation': 'WIS', 'summary': 'Perception and insight.', 'order_index': 4}},
    {'name': 'Charisma', 'fields': {'abbreviation': 'CHA', 'summary': 'Force of personality.', 'order_index': 5}},
  ];
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Ability',
      slug: 'ability',
      color: '#1e88e5',
      icon: 'fitness_center',
      fields: fields,
      orderIndex: 0,
      now: now,
    ),
    rows,
  );
}

Tier0CategoryBuild _skillCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _relationField(
          categoryId: catId,
          now: now,
          key: 'ability_ref',
          label: 'Ability',
          order: o,
          allowedTypes: ['ability'],
          isRequired: true,
        ),
    (o) => _textareaField(
          categoryId: catId,
          now: now,
          key: 'examples',
          label: 'Examples',
          order: o,
        ),
  ]);
  const rows = [
    {'name': 'Acrobatics', 'ability': 'Dexterity', 'summary': 'Stay on your feet in tricky situations.'},
    {'name': 'Animal Handling', 'ability': 'Wisdom', 'summary': 'Calm or train animals.'},
    {'name': 'Arcana', 'ability': 'Intelligence', 'summary': 'Recall lore about spells and magical traditions.'},
    {'name': 'Athletics', 'ability': 'Strength', 'summary': 'Climb, jump, swim, grapple.'},
    {'name': 'Deception', 'ability': 'Charisma', 'summary': 'Convincingly hide the truth.'},
    {'name': 'History', 'ability': 'Intelligence', 'summary': 'Recall historical facts.'},
    {'name': 'Insight', 'ability': 'Wisdom', 'summary': 'Read a creature\'s intentions.'},
    {'name': 'Intimidation', 'ability': 'Charisma', 'summary': 'Influence through threats.'},
    {'name': 'Investigation', 'ability': 'Intelligence', 'summary': 'Deduce from clues.'},
    {'name': 'Medicine', 'ability': 'Wisdom', 'summary': 'Stabilize the dying and diagnose illness.'},
    {'name': 'Nature', 'ability': 'Intelligence', 'summary': 'Recall lore about the natural world.'},
    {'name': 'Perception', 'ability': 'Wisdom', 'summary': 'Notice what\'s around you.'},
    {'name': 'Performance', 'ability': 'Charisma', 'summary': 'Entertain an audience.'},
    {'name': 'Persuasion', 'ability': 'Charisma', 'summary': 'Influence through reason or charm.'},
    {'name': 'Religion', 'ability': 'Intelligence', 'summary': 'Recall lore about gods and religious rites.'},
    {'name': 'Sleight of Hand', 'ability': 'Dexterity', 'summary': 'Pick pockets, plant items, conceal objects.'},
    {'name': 'Stealth', 'ability': 'Dexterity', 'summary': 'Move unseen and unheard.'},
    {'name': 'Survival', 'ability': 'Wisdom', 'summary': 'Track, hunt, and navigate the wilderness.'},
  ];
  // ability_ref will be resolved at bootstrap time by looking up the Ability
  // row whose name matches the 'ability' key here.
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {
              'summary': r['summary'],
              '_ability_name_': r['ability'], // bootstrap resolves to entityId
            },
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Skill',
      slug: 'skill',
      color: '#26a69a',
      icon: 'school',
      fields: fields,
      orderIndex: 1,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _damageTypeCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _textareaField(
          categoryId: catId,
          now: now,
          key: 'example_sources',
          label: 'Example Sources',
          order: o,
        ),
    (o) => _boolField(
          categoryId: catId,
          now: now,
          key: 'is_physical',
          label: 'Physical (B/P/S)',
          order: o,
        ),
    (o) => _boolField(
          categoryId: catId,
          now: now,
          key: 'bypassable_by_magical',
          label: 'Bypassable by Magical Weapons',
          order: o,
          helpText: 'Physical types: nonmagical resistance bypassed by magical/silvered/adamantine.',
        ),
  ]);
  const rows = [
    {'name': 'Acid', 'examples': 'Corrosive liquids, digestive enzymes', 'physical': false, 'bypass': false},
    {'name': 'Bludgeoning', 'examples': 'Blunt force — falling, crushing, clubs', 'physical': true, 'bypass': true},
    {'name': 'Cold', 'examples': 'Icy blasts, frost', 'physical': false, 'bypass': false},
    {'name': 'Fire', 'examples': 'Flames, intense heat', 'physical': false, 'bypass': false},
    {'name': 'Force', 'examples': 'Pure magical energy', 'physical': false, 'bypass': false},
    {'name': 'Lightning', 'examples': 'Electricity', 'physical': false, 'bypass': false},
    {'name': 'Necrotic', 'examples': 'Draining life force', 'physical': false, 'bypass': false},
    {'name': 'Piercing', 'examples': 'Puncturing — spears, arrows, bites', 'physical': true, 'bypass': true},
    {'name': 'Poison', 'examples': 'Toxins, venom', 'physical': false, 'bypass': false},
    {'name': 'Psychic', 'examples': 'Mental energy', 'physical': false, 'bypass': false},
    {'name': 'Radiant', 'examples': 'Divine radiance, positive energy', 'physical': false, 'bypass': false},
    {'name': 'Slashing', 'examples': 'Cuts and slices — swords, claws', 'physical': true, 'bypass': true},
    {'name': 'Thunder', 'examples': 'Concussive sound', 'physical': false, 'bypass': false},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {
              'example_sources': r['examples'],
              'is_physical': r['physical'],
              'bypassable_by_magical': r['bypass'],
            },
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Damage Type',
      slug: 'damage-type',
      color: '#e53935',
      icon: 'local_fire_department',
      fields: fields,
      orderIndex: 2,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _conditionCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _boolField(
          categoryId: catId,
          now: now,
          key: 'stacks',
          label: 'Stacks',
          order: o,
          helpText: 'True only for Exhaustion',
        ),
    (o) => _textareaField(
          categoryId: catId,
          now: now,
          key: 'ends_on',
          label: 'Ends On',
          order: o,
        ),
    (o) => _boolField(
          categoryId: catId,
          now: now,
          key: 'grants_incapacitated',
          label: 'Grants Incapacitated',
          order: o,
        ),
  ]);
  const names = [
    'Blinded', 'Charmed', 'Deafened', 'Exhaustion', 'Frightened',
    'Grappled', 'Incapacitated', 'Invisible', 'Paralyzed', 'Petrified',
    'Poisoned', 'Prone', 'Restrained', 'Stunned', 'Unconscious',
  ];
  final seed = [
    for (final n in names)
      {
        'name': n,
        'fields': {
          'stacks': n == 'Exhaustion',
          'grants_incapacitated': n == 'Paralyzed' || n == 'Petrified' || n == 'Stunned' || n == 'Unconscious',
        },
      },
  ];
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Condition',
      slug: 'condition',
      color: '#ab47bc',
      icon: 'healing',
      fields: fields,
      orderIndex: 3,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _creatureTypeCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _textareaField(
          categoryId: catId,
          now: now,
          key: 'default_skills_note',
          label: 'Default Skills Note',
          order: o,
        ),
  ]);
  const names = [
    'Aberration', 'Beast', 'Celestial', 'Construct', 'Dragon',
    'Elemental', 'Fey', 'Fiend', 'Giant', 'Humanoid',
    'Monstrosity', 'Ooze', 'Plant', 'Undead',
  ];
  final seed = [for (final n in names) {'name': n, 'fields': <String, dynamic>{}}];
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Creature Type',
      slug: 'creature-type',
      color: '#6d4c41',
      icon: 'pets',
      fields: fields,
      orderIndex: 4,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _languageCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _enumField(
          categoryId: catId,
          now: now,
          key: 'tier',
          label: 'Tier',
          order: o,
          values: ['Standard', 'Rare'],
          isRequired: true,
        ),
    (o) => _textareaField(
          categoryId: catId,
          now: now,
          key: 'typical_speakers',
          label: 'Typical Speakers',
          order: o,
        ),
    (o) => _textField(
          categoryId: catId,
          now: now,
          key: 'script',
          label: 'Script',
          order: o,
        ),
  ]);
  const standards = ['Common', 'Common Sign Language', 'Draconic', 'Dwarvish', 'Elvish', 'Giant', 'Gnomish', 'Goblin', 'Halfling', 'Orc'];
  const rares = ['Abyssal', 'Celestial', 'Deep Speech', 'Druidic', 'Infernal', 'Primordial', 'Sylvan', 'Thieves\' Cant', 'Undercommon'];
  final seed = [
    for (final n in standards) {'name': n, 'fields': {'tier': 'Standard'}},
    for (final n in rares) {'name': n, 'fields': {'tier': 'Rare'}},
  ];
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Language',
      slug: 'language',
      color: '#5c6bc0',
      icon: 'translate',
      fields: fields,
      orderIndex: 5,
      now: now,
    ),
    seed,
  );
}

// ---------------------------------------------------------------------------
// Small summary/effects-only categories (no extra fields beyond common)
// ---------------------------------------------------------------------------

Tier0CategoryBuild _simpleLookup({
  required String schemaId,
  required String now,
  required String slug,
  required String name,
  required String color,
  required String icon,
  required int orderIndex,
  required List<String> rowNames,
}) {
  final catId = _uuid.v4();
  final fields = _commonLookupFields(categoryId: catId, now: now);
  final seed = [for (final n in rowNames) {'name': n, 'fields': <String, dynamic>{}}];
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: name,
      slug: slug,
      color: color,
      icon: icon,
      fields: fields,
      orderIndex: orderIndex,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _weaponPropertyCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _enumField(
          categoryId: catId,
          now: now,
          key: 'mechanic_kind',
          label: 'Mechanic Kind',
          order: o,
          values: const [
            'ammunition_required', // Ammunition: must consume ammo per attack
            'ability_choice_str_dex', // Finesse: choose STR or DEX for attack/damage
            'small_creature_disadv',  // Heavy: Small creatures have disadv
            'two_weapon_fighting',    // Light: eligible for off-hand TWF
            'one_attack_per_turn',    // Loading: 1 attack/turn cap
            'has_range',              // Range: ranged attack with normal/long
            'extended_reach',         // Reach: +5ft reach
            'thrown_attack',          // Thrown: ranged via STR (or DEX if Finesse)
            'two_handed',             // Two-Handed: requires 2 hands
            'versatile_damage',       // Versatile: alt damage die when 2H
            'improvised',             // Improvised: not designed as weapon
          ],
        ),
  ]);
  const rows = [
    {'name': 'Ammunition', 'mk': 'ammunition_required'},
    {'name': 'Finesse',    'mk': 'ability_choice_str_dex'},
    {'name': 'Heavy',      'mk': 'small_creature_disadv'},
    {'name': 'Light',      'mk': 'two_weapon_fighting'},
    {'name': 'Loading',    'mk': 'one_attack_per_turn'},
    {'name': 'Range',      'mk': 'has_range'},
    {'name': 'Reach',      'mk': 'extended_reach'},
    {'name': 'Thrown',     'mk': 'thrown_attack'},
    {'name': 'Two-Handed', 'mk': 'two_handed'},
    {'name': 'Versatile',  'mk': 'versatile_damage'},
    {'name': 'Improvised', 'mk': 'improvised'},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {'mechanic_kind': r['mk']},
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Weapon Property',
      slug: 'weapon-property',
      color: '#455a64',
      icon: 'handyman',
      fields: fields,
      orderIndex: 6,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _weaponMasteryCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _enumField(
          categoryId: catId,
          now: now,
          key: 'effect_kind',
          label: 'Effect Kind',
          order: o,
          values: const [
            'extra_damage_attack', // Cleave: hit second creature within 5ft
            'damage_on_miss',      // Graze: ability mod damage on miss
            'extra_attack_light',  // Nick: light off-hand free
            'forced_move',         // Push: 10ft away on hit
            'attack_disadv_next',  // Sap: target disadv on next attack
            'speed_reduce',        // Slow: −10ft until start of next turn
            'save_or_prone',       // Topple: CON save or knocked prone
            'attack_advantage_next', // Vex: adv on next attack vs same target
          ],
        ),
    (o) => _intField(
          categoryId: catId,
          now: now,
          key: 'effect_value',
          label: 'Effect Value',
          order: o,
          helpText: 'Damage/distance/speed (ft or dice). Push=10, Slow=10, Cleave/Graze use weapon damage.',
        ),
    (o) => _enumField(
          categoryId: catId,
          now: now,
          key: 'save_ability',
          label: 'Save Ability',
          order: o,
          values: const ['', 'STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'],
          helpText: 'For Topple = STR or CON (target choice). Empty if no save.',
        ),
  ]);
  const rows = [
    {'name': 'Cleave',  'effect_kind': 'extra_damage_attack',   'effect_value': 0,  'save_ability': ''},
    {'name': 'Graze',   'effect_kind': 'damage_on_miss',         'effect_value': 0,  'save_ability': ''},
    {'name': 'Nick',    'effect_kind': 'extra_attack_light',     'effect_value': 0,  'save_ability': ''},
    {'name': 'Push',    'effect_kind': 'forced_move',            'effect_value': 10, 'save_ability': ''},
    {'name': 'Sap',     'effect_kind': 'attack_disadv_next',     'effect_value': 0,  'save_ability': ''},
    {'name': 'Slow',    'effect_kind': 'speed_reduce',           'effect_value': 10, 'save_ability': ''},
    {'name': 'Topple',  'effect_kind': 'save_or_prone',          'effect_value': 0,  'save_ability': 'CON'},
    {'name': 'Vex',     'effect_kind': 'attack_advantage_next',  'effect_value': 0,  'save_ability': ''},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {
              'effect_kind': r['effect_kind'],
              'effect_value': r['effect_value'],
              'save_ability': r['save_ability'],
            },
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Weapon Mastery',
      slug: 'weapon-mastery',
      color: '#37474f',
      icon: 'military_tech',
      fields: fields,
      orderIndex: 7,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _spellSchoolCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'spell-school',
      name: 'Spell School',
      color: '#7b1fa2',
      icon: 'auto_awesome',
      orderIndex: 8,
      rowNames: const [
        'Abjuration', 'Conjuration', 'Divination', 'Enchantment',
        'Evocation', 'Illusion', 'Necromancy', 'Transmutation',
      ],
    );

Tier0CategoryBuild _magicItemCategoryCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _relationField(
          categoryId: catId,
          now: now,
          key: 'crafting_tool_ref',
          label: 'Crafting Tool',
          order: o,
          allowedTypes: ['tool'],
        ),
  ]);
  const names = ['Armor', 'Potions', 'Rings', 'Rods', 'Scrolls', 'Staffs', 'Wands', 'Weapons', 'Wondrous Items'];
  final seed = [for (final n in names) {'name': n, 'fields': <String, dynamic>{}}];
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Magic Item Category',
      slug: 'magic-item-category',
      color: '#8e24aa',
      icon: 'auto_fix_high',
      fields: fields,
      orderIndex: 9,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _senseCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _integerField(
          categoryId: catId,
          now: now,
          key: 'default_range_ft',
          label: 'Default Range (ft)',
          order: o,
          minValue: 0,
          maxValue: 1000,
          helpText: 'SRD typical: Darkvision 60, Truesight 120, Blindsight 30',
        ),
  ]);
  const rows = [
    {'name': 'Blindsight', 'range': 30},
    {'name': 'Darkvision', 'range': 60},
    {'name': 'Tremorsense', 'range': 60},
    {'name': 'Truesight', 'range': 120},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {'default_range_ft': r['range']},
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Sense',
      slug: 'sense',
      color: '#00838f',
      icon: 'visibility',
      fields: fields,
      orderIndex: 10,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _hazardCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'hazard',
      name: 'Hazard',
      color: '#c62828',
      icon: 'warning',
      orderIndex: 11,
      rowNames: const ['Burning', 'Dehydration', 'Falling', 'Malnutrition', 'Suffocation'],
    );

Tier0CategoryBuild _arcaneFocusCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'arcane-focus',
      name: 'Arcane Focus',
      color: '#5e35b1',
      icon: 'casino',
      orderIndex: 12,
      rowNames: const ['Crystal', 'Orb', 'Rod', 'Staff', 'Wand'],
    );

Tier0CategoryBuild _druidicFocusCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'druidic-focus',
      name: 'Druidic Focus',
      color: '#388e3c',
      icon: 'park',
      orderIndex: 13,
      rowNames: const ['Sprig of Mistletoe', 'Wooden Staff', 'Yew Wand'],
    );

Tier0CategoryBuild _holySymbolCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'holy-symbol',
      name: 'Holy Symbol',
      color: '#fbc02d',
      icon: 'auto_awesome',
      orderIndex: 14,
      rowNames: const ['Amulet', 'Emblem', 'Reliquary'],
    );

Tier0CategoryBuild _sizeCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _floatField(
          categoryId: catId,
          now: now,
          key: 'space_ft',
          label: 'Space (ft)',
          order: o,
          minValue: 0,
          maxValue: 100,
          helpText: 'Square side. Tiny 2.5, S/M 5, L 10, H 15, G 20.',
          isRequired: true,
        ),
    (o) => _intField(
          categoryId: catId,
          now: now,
          key: 'hit_die_size',
          label: 'Monster Hit Die',
          order: o,
          minValue: 4,
          maxValue: 20,
          helpText: 'DMG: Tiny d4, Small d6, Medium d8, Large d10, Huge d12, Gargantuan d20.',
        ),
    (o) => _floatField(
          categoryId: catId,
          now: now,
          key: 'carrying_multiplier',
          label: 'Carry Multiplier',
          order: o,
          minValue: 0,
          maxValue: 16,
          helpText: 'Multiply STR×15 for carry capacity. Tiny 0.5, S/M 1, L 2, H 4, G 8.',
          isRequired: true,
        ),
  ]);
  const rows = [
    {'name': 'Tiny',       'space': 2.5, 'hd': 4,  'mult': 0.5},
    {'name': 'Small',      'space': 5.0, 'hd': 6,  'mult': 1.0},
    {'name': 'Medium',     'space': 5.0, 'hd': 8,  'mult': 1.0},
    {'name': 'Large',      'space': 10.0,'hd': 10, 'mult': 2.0},
    {'name': 'Huge',       'space': 15.0,'hd': 12, 'mult': 4.0},
    {'name': 'Gargantuan', 'space': 20.0,'hd': 20, 'mult': 8.0},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {
              'space_ft': r['space'],
              'hit_die_size': r['hd'],
              'carrying_multiplier': r['mult'],
            },
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Size',
      slug: 'size',
      color: '#546e7a',
      icon: 'aspect_ratio',
      fields: fields,
      orderIndex: 15,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _rarityCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _intField(
          categoryId: catId,
          now: now,
          key: 'value_gp',
          label: 'Sale Value (gp)',
          order: o,
          minValue: 0,
          maxValue: 1000000,
          helpText: 'DMG magic-item base value. Artifact = 0 (priceless).',
        ),
    (o) => _intField(
          categoryId: catId,
          now: now,
          key: 'crafting_time_days',
          label: 'Craft Time (days)',
          order: o,
          minValue: 0,
          maxValue: 100000,
        ),
    (o) => _intField(
          categoryId: catId,
          now: now,
          key: 'crafting_cost_gp',
          label: 'Craft Cost (gp)',
          order: o,
          minValue: 0,
          maxValue: 1000000,
          helpText: 'Half of sale value (DMG default).',
        ),
  ]);
  const rows = [
    {'name': 'Common',    'value': 100,    'days': 4,    'cost': 50},
    {'name': 'Uncommon',  'value': 400,    'days': 8,    'cost': 200},
    {'name': 'Rare',      'value': 4000,   'days': 80,   'cost': 2000},
    {'name': 'Very Rare', 'value': 40000,  'days': 800,  'cost': 20000},
    {'name': 'Legendary', 'value': 200000, 'days': 4000, 'cost': 100000},
    {'name': 'Artifact',  'value': 0,      'days': 0,    'cost': 0},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {
              'value_gp': r['value'],
              'crafting_time_days': r['days'],
              'crafting_cost_gp': r['cost'],
            },
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Rarity',
      slug: 'rarity',
      color: '#ab47bc',
      icon: 'star',
      fields: fields,
      orderIndex: 16,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _coinCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _floatField(
          categoryId: catId,
          now: now,
          key: 'value_in_gp',
          label: 'Value (gp)',
          order: o,
          minValue: 0,
          maxValue: 100,
          helpText: 'cp 0.01, sp 0.1, ep 0.5, gp 1, pp 10.',
          isRequired: true,
        ),
  ]);
  const rows = [
    {'name': 'Copper',   'v': 0.01},
    {'name': 'Silver',   'v': 0.1},
    {'name': 'Electrum', 'v': 0.5},
    {'name': 'Gold',     'v': 1.0},
    {'name': 'Platinum', 'v': 10.0},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {'value_in_gp': r['v']},
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Coin',
      slug: 'coin',
      color: '#ffb300',
      icon: 'monetization_on',
      fields: fields,
      orderIndex: 17,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _lifestyleCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _floatField(
          categoryId: catId,
          now: now,
          key: 'cost_per_day_gp',
          label: 'Cost/Day (gp)',
          order: o,
          minValue: 0,
          maxValue: 1000,
          helpText: 'PHB lifestyle expense. Aristocratic ≥10 gp/day.',
          isRequired: true,
        ),
  ]);
  const rows = [
    {'name': 'Wretched',     'cost': 0.0},
    {'name': 'Squalid',      'cost': 0.1},
    {'name': 'Poor',         'cost': 0.2},
    {'name': 'Modest',       'cost': 1.0},
    {'name': 'Comfortable',  'cost': 2.0},
    {'name': 'Wealthy',      'cost': 4.0},
    {'name': 'Aristocratic', 'cost': 10.0},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {'cost_per_day_gp': r['cost']},
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Lifestyle',
      slug: 'lifestyle',
      color: '#26a69a',
      icon: 'home',
      fields: fields,
      orderIndex: 18,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _bodySlotCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _intField(
          categoryId: catId,
          now: now,
          key: 'max_equipped',
          label: 'Max Equipped',
          order: o,
          minValue: 1,
          maxValue: 10,
          helpText: 'Most slots allow 1; finger allows 2.',
        ),
  ]);
  const rows = [
    {'name': 'Head',      'max': 1},
    {'name': 'Eyes',      'max': 1},
    {'name': 'Neck',      'max': 1},
    {'name': 'Shoulders', 'max': 1},
    {'name': 'Body',      'max': 1},
    {'name': 'Arms',      'max': 1},
    {'name': 'Hands',     'max': 1},
    {'name': 'Finger',    'max': 2},
    {'name': 'Waist',     'max': 1},
    {'name': 'Feet',      'max': 1},
    {'name': 'None',      'max': 1},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {'max_equipped': r['max']},
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Body Slot',
      slug: 'body-slot',
      color: '#6d4c41',
      icon: 'checkroom',
      fields: fields,
      orderIndex: 20,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _durationUnitCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _boolField(
          categoryId: catId,
          now: now,
          key: 'is_concentration_compatible',
          label: 'Concentration-Compatible',
          order: o,
          helpText: 'True for Round/Minute/Hour/Day. False for Instantaneous, Special, Until Dispelled.',
        ),
  ]);
  const rows = [
    {'name': 'Instantaneous',   'conc': false},
    {'name': 'Rounds',          'conc': true},
    {'name': 'Minutes',         'conc': true},
    {'name': 'Hours',           'conc': true},
    {'name': 'Days',            'conc': true},
    {'name': 'Special',         'conc': false},
    {'name': 'Until Dispelled', 'conc': false},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {'is_concentration_compatible': r['conc']},
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Duration Unit',
      slug: 'duration-unit',
      color: '#5e35b1',
      icon: 'schedule',
      fields: fields,
      orderIndex: 19,
      now: now,
    ),
    seed,
  );
}

// ---------------------------------------------------------------------------
// PR-2: Identifier-only Tier-0 lookups (no extra mechanic fields).
// Replace former hardcoded enum lists with relation targets so users can
// homebrew rows (e.g. custom alignment, weapon-category) and consumers
// reference them via [FieldValidation.allowedTypes].
// ---------------------------------------------------------------------------

Tier0CategoryBuild _identifierLookup({
  required String schemaId,
  required String now,
  required String name,
  required String slug,
  required String color,
  required String icon,
  required int orderIndex,
  required List<String> rows,
}) {
  final catId = _uuid.v4();
  final fields = _commonLookupFields(categoryId: catId, now: now);
  final seed = [for (final r in rows) {'name': r, 'fields': <String, dynamic>{}}];
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: name,
      slug: slug,
      color: color,
      icon: icon,
      fields: fields,
      orderIndex: orderIndex,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _alignmentCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Alignment', slug: 'alignment',
      color: '#8e24aa', icon: 'balance', orderIndex: 21,
      rows: const [
        'Lawful Good', 'Neutral Good', 'Chaotic Good',
        'Lawful Neutral', 'Neutral', 'Chaotic Neutral',
        'Lawful Evil', 'Neutral Evil', 'Chaotic Evil',
        'Unaligned',
      ],
    );

Tier0CategoryBuild _weaponCategoryCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Weapon Category', slug: 'weapon-category',
      color: '#c62828', icon: 'sports_kabaddi', orderIndex: 22,
      rows: const [
        'Simple', 'Martial',
        'Simple Melee', 'Simple Ranged', 'Martial Melee', 'Martial Ranged',
      ],
    );

Tier0CategoryBuild _armorCategoryCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Armor Category', slug: 'armor-category',
      color: '#37474f', icon: 'shield', orderIndex: 23,
      rows: const ['Light', 'Medium', 'Heavy', 'Shield'],
    );

Tier0CategoryBuild _toolCategoryCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Tool Category', slug: 'tool-category',
      color: '#6d4c41', icon: 'handyman', orderIndex: 24,
      rows: const ["Artisan's Tools", 'Gaming Set', 'Musical Instrument', 'Other Tools'],
    );

Tier0CategoryBuild _featCategoryCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Feat Category', slug: 'feat-category',
      color: '#558b2f', icon: 'military_tech', orderIndex: 25,
      rows: const ['Origin', 'General', 'Fighting Style', 'Epic Boon'],
    );

Tier0CategoryBuild _actionCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Action', slug: 'action',
      color: '#ef6c00', icon: 'bolt', orderIndex: 26,
      rows: const [
        'Action', 'Bonus Action', 'Reaction', 'Free Action',
        'Magic Action', 'Attack Action', 'Dash', 'Dodge',
        'Disengage', 'Help', 'Hide', 'Ready', 'Search',
        'Influence', 'Study', 'Utilize',
      ],
    );

Tier0CategoryBuild _areaShapeCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Area Shape', slug: 'area-shape',
      color: '#3949ab', icon: 'category', orderIndex: 27,
      rows: const ['Cone', 'Cube', 'Cylinder', 'Line', 'Sphere', 'Emanation'],
    );

Tier0CategoryBuild _attitudeCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Attitude', slug: 'attitude',
      color: '#00838f', icon: 'mood', orderIndex: 28,
      rows: const ['Friendly', 'Indifferent', 'Hostile'],
    );

Tier0CategoryBuild _illuminationCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Illumination', slug: 'illumination',
      color: '#fbc02d', icon: 'wb_sunny', orderIndex: 29,
      rows: const ['Bright', 'Dim', 'Darkness'],
    );

Tier0CategoryBuild _travelPaceCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Travel Pace', slug: 'travel-pace',
      color: '#43a047', icon: 'directions_walk', orderIndex: 30,
      rows: const ['Slow', 'Normal', 'Fast'],
    );

Tier0CategoryBuild _planeCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Plane', slug: 'plane',
      color: '#5e35b1', icon: 'public', orderIndex: 31,
      rows: const [
        'Material Plane', 'Astral Plane', 'Ethereal Plane',
        'Feywild', 'Shadowfell',
        'Plane of Air', 'Plane of Earth', 'Plane of Fire', 'Plane of Water',
        'Mount Celestia', 'Bytopia', 'Elysium', 'Beastlands', 'Arborea',
        'Ysgard', 'Limbo', 'Pandemonium', 'Abyss', 'Carceri', 'Hades',
        'Gehenna', 'Nine Hells', 'Acheron', 'Mechanus', 'Arcadia', 'Outlands',
      ],
    );

Tier0CategoryBuild _castingComponentCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Casting Component', slug: 'casting-component',
      color: '#7e57c2', icon: 'auto_awesome', orderIndex: 32,
      rows: const ['Verbal', 'Somatic', 'Material'],
    );

Tier0CategoryBuild _castingTimeUnitCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Casting Time Unit', slug: 'casting-time-unit',
      color: '#7e57c2', icon: 'timer', orderIndex: 33,
      rows: const ['Action', 'Bonus Action', 'Reaction', 'Minute', 'Hour', 'Ritual', 'Special'],
    );

Tier0CategoryBuild _speedTypeCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Speed Type', slug: 'speed-type',
      color: '#26a69a', icon: 'speed', orderIndex: 34,
      rows: const ['Walk', 'Burrow', 'Climb', 'Fly', 'Swim'],
    );

Tier0CategoryBuild _coverCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Cover', slug: 'cover',
      color: '#455a64', icon: 'crop_square', orderIndex: 35,
      rows: const ['Half Cover', 'Three-Quarters Cover', 'Total Cover'],
    );

Tier0CategoryBuild _tierOfPlayCategory(String schemaId, String now) =>
    _identifierLookup(
      schemaId: schemaId, now: now,
      name: 'Tier of Play', slug: 'tier-of-play',
      color: '#9e9d24', icon: 'leaderboard', orderIndex: 36,
      rows: const [
        'Local Heroes',
        'Heroes of the Realm',
        'Masters of the Realm',
        'Masters of the World',
      ],
    );

