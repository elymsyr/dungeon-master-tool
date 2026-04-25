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
  'size',
  'creature-type',
  'alignment',
  'language',
  'weapon-category',
  'weapon-property',
  'weapon-mastery',
  'armor-category',
  'tool-category',
  'spell-school',
  'magic-item-category',
  'rarity',
  'speed-type',
  'sense',
  'action',
  'area-shape',
  'attitude',
  'cover',
  'illumination',
  'hazard',
  'feat-category',
  'lifestyle',
  'coin',
  'tier-of-play',
  'travel-pace',
  'arcane-focus',
  'druidic-focus',
  'holy-symbol',
  'plane',
  'casting-component',
  'casting-time-unit',
  'duration-unit',
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
    _sizeCategory(schemaId, now),
    _creatureTypeCategory(schemaId, now),
    _alignmentCategory(schemaId, now),
    _languageCategory(schemaId, now),
    _weaponCategoryCategory(schemaId, now),
    _weaponPropertyCategory(schemaId, now),
    _weaponMasteryCategory(schemaId, now),
    _armorCategoryCategory(schemaId, now),
    _toolCategoryCategory(schemaId, now),
    _spellSchoolCategory(schemaId, now),
    _magicItemCategoryCategory(schemaId, now),
    _rarityCategory(schemaId, now),
    _speedTypeCategory(schemaId, now),
    _senseCategory(schemaId, now),
    _actionCategory(schemaId, now),
    _areaShapeCategory(schemaId, now),
    _attitudeCategory(schemaId, now),
    _coverCategory(schemaId, now),
    _illuminationCategory(schemaId, now),
    _hazardCategory(schemaId, now),
    _featCategoryCategory(schemaId, now),
    _lifestyleCategory(schemaId, now),
    _coinCategory(schemaId, now),
    _tierOfPlayCategory(schemaId, now),
    _travelPaceCategory(schemaId, now),
    _arcaneFocusCategory(schemaId, now),
    _druidicFocusCategory(schemaId, now),
    _holySymbolCategory(schemaId, now),
    _planeCategory(schemaId, now),
    _castingComponentCategory(schemaId, now),
    _castingTimeUnitCategory(schemaId, now),
    _durationUnitCategory(schemaId, now),
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
}) {
  return FieldSchema(
    fieldId: _uuid.v4(),
    categoryId: categoryId,
    fieldKey: key,
    label: label,
    fieldType: FieldType.float_,
    helpText: helpText ?? '',
    validation: FieldValidation(minValue: minValue, maxValue: maxValue),
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
  ]);
  const rows = [
    {'name': 'Acid', 'examples': 'Corrosive liquids, digestive enzymes', 'physical': false},
    {'name': 'Bludgeoning', 'examples': 'Blunt force — falling, crushing, clubs', 'physical': true},
    {'name': 'Cold', 'examples': 'Icy blasts, frost', 'physical': false},
    {'name': 'Fire', 'examples': 'Flames, intense heat', 'physical': false},
    {'name': 'Force', 'examples': 'Pure magical energy', 'physical': false},
    {'name': 'Lightning', 'examples': 'Electricity', 'physical': false},
    {'name': 'Necrotic', 'examples': 'Draining life force', 'physical': false},
    {'name': 'Piercing', 'examples': 'Puncturing — spears, arrows, bites', 'physical': true},
    {'name': 'Poison', 'examples': 'Toxins, venom', 'physical': false},
    {'name': 'Psychic', 'examples': 'Mental energy', 'physical': false},
    {'name': 'Radiant', 'examples': 'Divine radiance, positive energy', 'physical': false},
    {'name': 'Slashing', 'examples': 'Cuts and slices — swords, claws', 'physical': true},
    {'name': 'Thunder', 'examples': 'Concussive sound', 'physical': false},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {
              'example_sources': r['examples'],
              'is_physical': r['physical'],
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
          helpText: 'Diameter of the creature\'s space',
        ),
    (o) => _floatField(
          categoryId: catId,
          now: now,
          key: 'squares',
          label: 'Squares',
          order: o,
        ),
    (o) => _enumField(
          categoryId: catId,
          now: now,
          key: 'hit_die_size',
          label: 'Hit Die',
          order: o,
          values: ['d4', 'd6', 'd8', 'd10', 'd12', 'd20'],
        ),
  ]);
  const rows = [
    {'name': 'Tiny', 'space_ft': 2.5, 'squares': 0.25, 'hit_die_size': 'd4'},
    {'name': 'Small', 'space_ft': 5.0, 'squares': 1.0, 'hit_die_size': 'd6'},
    {'name': 'Medium', 'space_ft': 5.0, 'squares': 1.0, 'hit_die_size': 'd8'},
    {'name': 'Large', 'space_ft': 10.0, 'squares': 4.0, 'hit_die_size': 'd10'},
    {'name': 'Huge', 'space_ft': 15.0, 'squares': 9.0, 'hit_die_size': 'd12'},
    {'name': 'Gargantuan', 'space_ft': 20.0, 'squares': 16.0, 'hit_die_size': 'd20'},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {
              'space_ft': r['space_ft'],
              'squares': r['squares'],
              'hit_die_size': r['hit_die_size'],
            },
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Size',
      slug: 'size',
      color: '#8d6e63',
      icon: 'aspect_ratio',
      fields: fields,
      orderIndex: 4,
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
      orderIndex: 5,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _alignmentCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _enumField(
          categoryId: catId,
          now: now,
          key: 'morality',
          label: 'Morality',
          order: o,
          values: ['Good', 'Neutral', 'Evil'],
        ),
    (o) => _enumField(
          categoryId: catId,
          now: now,
          key: 'order',
          label: 'Order',
          order: o,
          values: ['Lawful', 'Neutral', 'Chaotic'],
        ),
  ]);
  const rows = [
    {'name': 'Lawful Good', 'abbr': 'LG', 'order': 'Lawful', 'morality': 'Good'},
    {'name': 'Neutral Good', 'abbr': 'NG', 'order': 'Neutral', 'morality': 'Good'},
    {'name': 'Chaotic Good', 'abbr': 'CG', 'order': 'Chaotic', 'morality': 'Good'},
    {'name': 'Lawful Neutral', 'abbr': 'LN', 'order': 'Lawful', 'morality': 'Neutral'},
    {'name': 'Neutral', 'abbr': 'N', 'order': 'Neutral', 'morality': 'Neutral'},
    {'name': 'Chaotic Neutral', 'abbr': 'CN', 'order': 'Chaotic', 'morality': 'Neutral'},
    {'name': 'Lawful Evil', 'abbr': 'LE', 'order': 'Lawful', 'morality': 'Evil'},
    {'name': 'Neutral Evil', 'abbr': 'NE', 'order': 'Neutral', 'morality': 'Evil'},
    {'name': 'Chaotic Evil', 'abbr': 'CE', 'order': 'Chaotic', 'morality': 'Evil'},
    {'name': 'Unaligned', 'abbr': '—', 'order': 'Neutral', 'morality': 'Neutral'},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {
              'abbreviation': r['abbr'],
              'morality': r['morality'],
              'order': r['order'],
            },
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Alignment',
      slug: 'alignment',
      color: '#607d8b',
      icon: 'balance',
      fields: fields,
      orderIndex: 6,
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
      orderIndex: 7,
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

Tier0CategoryBuild _weaponCategoryCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'weapon-category',
      name: 'Weapon Category',
      color: '#455a64',
      icon: 'category',
      orderIndex: 8,
      rowNames: const ['Simple', 'Martial'],
    );

Tier0CategoryBuild _weaponPropertyCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'weapon-property',
      name: 'Weapon Property',
      color: '#455a64',
      icon: 'handyman',
      orderIndex: 9,
      rowNames: const [
        'Ammunition', 'Finesse', 'Heavy', 'Light', 'Loading',
        'Range', 'Reach', 'Thrown', 'Two-Handed', 'Versatile', 'Improvised',
      ],
    );

Tier0CategoryBuild _weaponMasteryCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'weapon-mastery',
      name: 'Weapon Mastery',
      color: '#37474f',
      icon: 'military_tech',
      orderIndex: 10,
      rowNames: const ['Cleave', 'Graze', 'Nick', 'Push', 'Sap', 'Slow', 'Topple', 'Vex'],
    );

Tier0CategoryBuild _armorCategoryCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'armor-category',
      name: 'Armor Category',
      color: '#5d4037',
      icon: 'shield',
      orderIndex: 11,
      rowNames: const ['Light', 'Medium', 'Heavy', 'Shield'],
    );

Tier0CategoryBuild _toolCategoryCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'tool-category',
      name: 'Tool Category',
      color: '#795548',
      icon: 'build',
      orderIndex: 12,
      rowNames: const ['Artisan\'s Tools', 'Other Tools', 'Gaming Set', 'Musical Instrument'],
    );

Tier0CategoryBuild _spellSchoolCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'spell-school',
      name: 'Spell School',
      color: '#7b1fa2',
      icon: 'auto_awesome',
      orderIndex: 13,
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
      orderIndex: 14,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _rarityCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _integerField(
          categoryId: catId,
          now: now,
          key: 'value_gp',
          label: 'Value (gp)',
          order: o,
          minValue: 0,
        ),
    (o) => _integerField(
          categoryId: catId,
          now: now,
          key: 'crafting_time_days',
          label: 'Crafting Time (days)',
          order: o,
          minValue: 0,
        ),
    (o) => _integerField(
          categoryId: catId,
          now: now,
          key: 'crafting_cost_gp',
          label: 'Crafting Cost (gp)',
          order: o,
          minValue: 0,
        ),
  ]);
  const rows = [
    {'name': 'Common', 'value_gp': 100, 'days': 5, 'cost_gp': 50},
    {'name': 'Uncommon', 'value_gp': 400, 'days': 10, 'cost_gp': 200},
    {'name': 'Rare', 'value_gp': 4000, 'days': 50, 'cost_gp': 2000},
    {'name': 'Very Rare', 'value_gp': 40000, 'days': 125, 'cost_gp': 20000},
    {'name': 'Legendary', 'value_gp': 200000, 'days': 250, 'cost_gp': 100000},
    {'name': 'Artifact', 'value_gp': 0, 'days': 0, 'cost_gp': 0},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {
              'value_gp': r['value_gp'],
              'crafting_time_days': r['days'],
              'crafting_cost_gp': r['cost_gp'],
            },
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Rarity',
      slug: 'rarity',
      color: '#d81b60',
      icon: 'workspace_premium',
      fields: fields,
      orderIndex: 15,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _speedTypeCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'speed-type',
      name: 'Speed Type',
      color: '#0097a7',
      icon: 'directions_run',
      orderIndex: 16,
      rowNames: const ['Walking', 'Burrow', 'Climb', 'Fly', 'Swim'],
    );

Tier0CategoryBuild _senseCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'sense',
      name: 'Sense',
      color: '#00838f',
      icon: 'visibility',
      orderIndex: 17,
      rowNames: const ['Blindsight', 'Darkvision', 'Tremorsense', 'Truesight'],
    );

Tier0CategoryBuild _actionCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'action',
      name: 'Action',
      color: '#ef6c00',
      icon: 'flash_on',
      orderIndex: 18,
      rowNames: const [
        'Attack', 'Dash', 'Disengage', 'Dodge', 'Help',
        'Hide', 'Influence', 'Magic', 'Ready', 'Search', 'Study', 'Utilize',
      ],
    );

Tier0CategoryBuild _areaShapeCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _textField(
          categoryId: catId,
          now: now,
          key: 'origin_behavior',
          label: 'Origin Behavior',
          order: o,
          helpText: 'e.g. cube: face, cone: tip, sphere: center',
        ),
  ]);
  const rows = [
    {'name': 'Cone', 'origin': 'Tip of cone at a point you can see'},
    {'name': 'Cube', 'origin': 'Face of cube at origin point'},
    {'name': 'Cylinder', 'origin': 'Center of flat face'},
    {'name': 'Emanation', 'origin': 'Around the creature'},
    {'name': 'Line', 'origin': 'Path from origin point'},
    {'name': 'Sphere', 'origin': 'Center point'},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {'origin_behavior': r['origin']},
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Area of Effect Shape',
      slug: 'area-shape',
      color: '#00acc1',
      icon: 'crop_free',
      fields: fields,
      orderIndex: 19,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _attitudeCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'attitude',
      name: 'Attitude',
      color: '#fdd835',
      icon: 'mood',
      orderIndex: 20,
      rowNames: const ['Friendly', 'Indifferent', 'Hostile'],
    );

Tier0CategoryBuild _coverCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'cover',
      name: 'Cover',
      color: '#546e7a',
      icon: 'grid_on',
      orderIndex: 21,
      rowNames: const ['Half Cover', 'Three-Quarters Cover', 'Total Cover'],
    );

Tier0CategoryBuild _illuminationCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'illumination',
      name: 'Illumination',
      color: '#fbc02d',
      icon: 'lightbulb',
      orderIndex: 22,
      rowNames: const ['Bright Light', 'Dim Light', 'Darkness'],
    );

Tier0CategoryBuild _hazardCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'hazard',
      name: 'Hazard',
      color: '#c62828',
      icon: 'warning',
      orderIndex: 23,
      rowNames: const ['Burning', 'Dehydration', 'Falling', 'Malnutrition', 'Suffocation'],
    );

Tier0CategoryBuild _featCategoryCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'feat-category',
      name: 'Feat Category',
      color: '#ff7043',
      icon: 'stars',
      orderIndex: 24,
      rowNames: const ['Origin', 'General', 'Fighting Style', 'Epic Boon'],
    );

Tier0CategoryBuild _lifestyleCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _floatField(
          categoryId: catId,
          now: now,
          key: 'cost_per_day_gp',
          label: 'Cost / Day (gp)',
          order: o,
          minValue: 0,
        ),
  ]);
  const rows = [
    {'name': 'Wretched', 'cost': 0.0},
    {'name': 'Squalid', 'cost': 0.1},
    {'name': 'Poor', 'cost': 0.2},
    {'name': 'Modest', 'cost': 1.0},
    {'name': 'Comfortable', 'cost': 2.0},
    {'name': 'Wealthy', 'cost': 4.0},
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
      color: '#8d6e63',
      icon: 'home',
      fields: fields,
      orderIndex: 25,
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
        ),
  ]);
  const rows = [
    {'name': 'Copper Piece', 'abbr': 'CP', 'gp': 0.01},
    {'name': 'Silver Piece', 'abbr': 'SP', 'gp': 0.1},
    {'name': 'Electrum Piece', 'abbr': 'EP', 'gp': 0.5},
    {'name': 'Gold Piece', 'abbr': 'GP', 'gp': 1.0},
    {'name': 'Platinum Piece', 'abbr': 'PP', 'gp': 10.0},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {
              'abbreviation': r['abbr'],
              'value_in_gp': r['gp'],
            },
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Coin',
      slug: 'coin',
      color: '#fdd835',
      icon: 'monetization_on',
      fields: fields,
      orderIndex: 26,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _tierOfPlayCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _integerField(
          categoryId: catId,
          now: now,
          key: 'min_level',
          label: 'Min Level',
          order: o,
          minValue: 1,
          maxValue: 20,
        ),
    (o) => _integerField(
          categoryId: catId,
          now: now,
          key: 'max_level',
          label: 'Max Level',
          order: o,
          minValue: 1,
          maxValue: 20,
        ),
  ]);
  const rows = [
    {'name': 'Tier 1', 'min': 1, 'max': 4},
    {'name': 'Tier 2', 'min': 5, 'max': 10},
    {'name': 'Tier 3', 'min': 11, 'max': 16},
    {'name': 'Tier 4', 'min': 17, 'max': 20},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {'min_level': r['min'], 'max_level': r['max']},
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Tier of Play',
      slug: 'tier-of-play',
      color: '#3949ab',
      icon: 'emoji_events',
      fields: fields,
      orderIndex: 27,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _travelPaceCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'travel-pace',
      name: 'Travel Pace',
      color: '#43a047',
      icon: 'directions_walk',
      orderIndex: 28,
      rowNames: const ['Fast', 'Normal', 'Slow'],
    );

Tier0CategoryBuild _arcaneFocusCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'arcane-focus',
      name: 'Arcane Focus',
      color: '#5e35b1',
      icon: 'casino',
      orderIndex: 29,
      rowNames: const ['Crystal', 'Orb', 'Rod', 'Staff', 'Wand'],
    );

Tier0CategoryBuild _druidicFocusCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'druidic-focus',
      name: 'Druidic Focus',
      color: '#388e3c',
      icon: 'park',
      orderIndex: 30,
      rowNames: const ['Sprig of Mistletoe', 'Wooden Staff', 'Yew Wand'],
    );

Tier0CategoryBuild _holySymbolCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'holy-symbol',
      name: 'Holy Symbol',
      color: '#fbc02d',
      icon: 'auto_awesome',
      orderIndex: 31,
      rowNames: const ['Amulet', 'Emblem', 'Reliquary'],
    );

Tier0CategoryBuild _planeCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _enumField(
          categoryId: catId,
          now: now,
          key: 'group',
          label: 'Group',
          order: o,
          values: ['Material', 'Transitive', 'Inner', 'Outer-Upper', 'Outer-Lower'],
        ),
  ]);
  const rows = [
    {'name': 'Material Plane', 'group': 'Material'},
    {'name': 'Astral Plane', 'group': 'Transitive'},
    {'name': 'Ethereal Plane', 'group': 'Transitive'},
    {'name': 'Feywild', 'group': 'Transitive'},
    {'name': 'Shadowfell', 'group': 'Transitive'},
    // Inner (Elemental)
    {'name': 'Plane of Air', 'group': 'Inner'},
    {'name': 'Plane of Earth', 'group': 'Inner'},
    {'name': 'Plane of Fire', 'group': 'Inner'},
    {'name': 'Plane of Water', 'group': 'Inner'},
    // Outer upper (Good-leaning)
    {'name': 'Mount Celestia', 'group': 'Outer-Upper'},
    {'name': 'Bytopia', 'group': 'Outer-Upper'},
    {'name': 'Elysium', 'group': 'Outer-Upper'},
    {'name': 'The Beastlands', 'group': 'Outer-Upper'},
    {'name': 'Arborea', 'group': 'Outer-Upper'},
    {'name': 'Ysgard', 'group': 'Outer-Upper'},
    {'name': 'Limbo', 'group': 'Outer-Upper'},
    {'name': 'Pandemonium', 'group': 'Outer-Lower'},
    {'name': 'The Abyss', 'group': 'Outer-Lower'},
    {'name': 'Carceri', 'group': 'Outer-Lower'},
    {'name': 'Hades', 'group': 'Outer-Lower'},
    {'name': 'Gehenna', 'group': 'Outer-Lower'},
    {'name': 'The Nine Hells', 'group': 'Outer-Lower'},
    {'name': 'Acheron', 'group': 'Outer-Lower'},
    {'name': 'Mechanus', 'group': 'Outer-Upper'},
    {'name': 'Arcadia', 'group': 'Outer-Upper'},
  ];
  final seed = rows
      .map((r) => {
            'name': r['name'],
            'fields': {'group': r['group']},
          })
      .toList();
  return Tier0CategoryBuild(
    _makeCategory(
      schemaId: schemaId,
      categoryId: catId,
      name: 'Plane',
      slug: 'plane',
      color: '#26c6da',
      icon: 'public',
      fields: fields,
      orderIndex: 32,
      now: now,
    ),
    seed,
  );
}

Tier0CategoryBuild _castingComponentCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'casting-component',
      name: 'Casting Component',
      color: '#9c27b0',
      icon: 'record_voice_over',
      orderIndex: 33,
      rowNames: const ['Verbal', 'Somatic', 'Material'],
    );

Tier0CategoryBuild _castingTimeUnitCategory(String schemaId, String now) => _simpleLookup(
      schemaId: schemaId,
      now: now,
      slug: 'casting-time-unit',
      name: 'Casting Time Unit',
      color: '#6a1b9a',
      icon: 'schedule',
      orderIndex: 34,
      rowNames: const [
        'Action', 'Bonus Action', 'Reaction',
        'Minute', 'Hour', 'Ritual', 'Special',
      ],
    );

Tier0CategoryBuild _durationUnitCategory(String schemaId, String now) {
  final catId = _uuid.v4();
  final common = _commonLookupFields(categoryId: catId, now: now);
  final fields = _withExtras(common, [
    (o) => _boolField(
          categoryId: catId,
          now: now,
          key: 'is_concentration_compatible',
          label: 'Concentration Compatible',
          order: o,
        ),
  ]);
  const rows = [
    {'name': 'Instantaneous', 'conc': false},
    {'name': 'Rounds', 'conc': true},
    {'name': 'Minutes', 'conc': true},
    {'name': 'Hours', 'conc': true},
    {'name': 'Days', 'conc': true},
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
      color: '#ad1457',
      icon: 'hourglass_bottom',
      fields: fields,
      orderIndex: 35,
      now: now,
    ),
    seed,
  );
}
