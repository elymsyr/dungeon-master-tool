import '../entities/entity.dart';
import '../entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../entities/schema/builtin/content.dart' show tier1Slugs;
import '../entities/schema/builtin/lookups.dart'
    show dmAuthoredLookupSlugs, tier0Slugs;
import '../entities/schema/dnd5e_constants.dart' show kDnd5eAbilities;
import '../entities/schema/entity_category_schema.dart';
import '../entities/schema/field_schema.dart';
import '../entities/schema/world_schema.dart';
import '../entities/schema/world_schema_hash.dart';
import 'free_field_styles.dart';
import 'template_edit.dart' show playerCardFieldKey, syncPresets;

/// The one gate between the built-in and the free code paths
/// (docs/free-template/ROADMAP.md K3).
bool isFreeTemplate(WorldSchema schema) => schema.freeRootId != null;

/// True when [schema] descends from the built-in SRD template.
bool isSrdLineage(WorldSchema schema) =>
    schema.freeRootId == builtinDnd5eV2SchemaId;

/// The codex sidebar group the built-in slug lists give [slug] (0 lookups,
/// 1 content, 2 DM; anything else is 2). Same rule as the sidebar's
/// `_tierFor`; a free category's own `tier` wins over it.
int builtinTier(String slug) {
  if (tier0Slugs.contains(slug) && !dmAuthoredLookupSlugs.contains(slug)) {
    return 0;
  }
  return tier1Slugs.contains(slug) ? 1 : 2;
}

/// The SRD copy's Combat stats block (DESIGN §16.2, D36): the built-in
/// `combat_stats` keys, plus Conditions; Speed, CR and the level leave it.
const _srdCombat = CombatStatsSpec(
  values: [
    CombatValue(key: 'ac', label: 'AC'),
    CombatValue(
      key: 'initiative',
      label: 'Initiative',
      type: CombatValueType.dice,
    ),
    CombatValue(key: 'xp', label: 'XP', encounter: false),
    CombatValue(
      key: 'conditions',
      label: 'Conditions',
      type: CombatValueType.cards,
      targets: ['condition'],
    ),
  ],
);

/// Monster and animal cards keep their combat values in flat fields; the
/// copy gives them the block (read from those fields, §16.3) instead.
const _flatCombatSlugs = {'monster', 'animal'};
const _flatCombatKeys = {'ac', 'hp_average', 'initiative_modifier'};

/// A field the SRD copy adds beside [f]: the same group and timestamps.
FieldSchema _added(
  FieldSchema f, {
  required String id,
  required String key,
  required String label,
  required FieldType type,
  Map<String, dynamic>? config,
  int span = 1,
}) => FieldSchema(
  fieldId: id,
  categoryId: f.categoryId,
  fieldKey: key,
  label: label,
  fieldType: type,
  groupId: f.groupId,
  gridColumnSpan: span,
  styleConfig: config,
  createdAt: f.createdAt,
  updatedAt: f.updatedAt,
);

/// [f] as an SRD copy holds it (ROADMAP §6): nothing when it is dropped, a
/// free style for the types converted so far (with the fields that come
/// out of it), else unchanged (a kept SRD type, converted in a later
/// phase). Card data is not touched; the free styles read the SRD shapes
/// as they are (`free_field_styles.dart`).
Iterable<FieldSchema> _srdCopyFields(
  FieldSchema f,
  EntityCategorySchema cat,
) sync* {
  if (_flatCombatSlugs.contains(cat.slug) &&
      _flatCombatKeys.contains(f.fieldKey)) {
    // The block takes the place of the first of them.
    if (f.fieldKey == 'ac') {
      yield _srdCombat.applyTo(
        _added(
          f,
          id: '${cat.categoryId}-combat',
          key: 'combat_stats',
          label: 'Combat Stats',
          type: FieldType.combatStats,
          span: 2,
        ),
      );
    }
    return;
  }
  if (f.fieldType == FieldType.combatStats) {
    yield _srdCombat.applyTo(f.copyWith(defaultValue: null));
    // Out of the block, as numbers (D36).
    yield _added(
      f,
      id: '${f.fieldId}-speed',
      key: 'speed',
      label: 'Speed',
      type: FieldType.integer,
      config: const {srdReadKey: 'speed'},
    );
    if (cat.slug == 'npc') {
      yield _added(
        f,
        id: '${f.fieldId}-cr',
        key: 'cr',
        label: 'CR',
        type: FieldType.float_,
        config: const {srdReadKey: 'cr'},
      );
    }
    return;
  }
  final one = _srdCopyField(f, cat);
  if (one != null) yield one;
}

FieldSchema? _srdCopyField(FieldSchema f, EntityCategorySchema cat) {
  FieldSchema table(List<TableColumn> columns) => f.copyWith(
    fieldType: FieldType.table,
    styleConfig: TableSpec(columns: columns).toConfig(),
  );
  const level = TableColumn(
    key: 'level',
    label: 'Level',
    type: TableColumnType.number,
  );
  return switch (f.fieldType) {
    FieldType.crCalculator => null,
    FieldType.statBlock => f.copyWith(
      fieldType: FieldType.statTable,
      styleConfig: StatTableSpec(
        stats: [for (final a in kDnd5eAbilities) (key: a, label: a)],
        // Species / feat bonuses are plain values (DESIGN §16.2).
        showModifier: f.fieldKey != 'ability_bonuses',
      ).toConfig(),
    ),
    FieldType.proficiencyTable => f.copyWith(
      fieldType: FieldType.skillTable,
      defaultValue: null,
      styleConfig: _skillSpec(f, cat).toConfig(),
    ),
    // The player card's class levels give way to the main level (§16.1).
    FieldType.levelTable when f.fieldKey == 'class_levels' => f.copyWith(
      fieldType: FieldType.characterLevel,
      fieldKey: playerCardFieldKey(FieldType.characterLevel),
      label: 'Level',
      gridColumnSpan: 1,
    ),
    // The slot grid's slots arrive in the Pool (D38); the class's Level
    // table grants them (Faz 7b).
    FieldType.spellSlotGrid => f.copyWith(
      fieldType: FieldType.autoResources,
      fieldKey: playerCardFieldKey(FieldType.autoResources),
      label: 'Pool',
    ),
    FieldType.slot => f.copyWith(
      fieldType: FieldType.resource,
      styleConfig: const ResourceSpec(boxes: true).toConfig(),
    ),
    FieldType.levelTable => table(const [
      level,
      TableColumn(key: 'value', label: 'Value', type: TableColumnType.number),
    ]),
    FieldType.levelTextTable => table(const [
      level,
      TableColumn(key: 'value', label: 'Text'),
    ]),
    FieldType.rangedSenseList => table(const [
      TableColumn(
        key: 'sense_ref',
        label: 'Sense',
        type: TableColumnType.relation,
        targets: ['sense'],
      ),
      TableColumn(
        key: 'range_ft',
        label: 'Range (ft)',
        type: TableColumnType.number,
      ),
    ]),
    FieldType.spellEffectList => table(const [
      TableColumn(
        key: 'kind',
        label: 'Kind',
        type: TableColumnType.choice,
        options: ['damage', 'heal', 'condition', 'buff', 'debuff'],
      ),
      TableColumn(key: 'dice', label: 'Dice', type: TableColumnType.dice),
      TableColumn(
        key: 'type_ref',
        label: 'Damage Type',
        type: TableColumnType.relation,
        targets: ['damage-type'],
      ),
      TableColumn(
        key: 'save_ability_ref',
        label: 'Save',
        type: TableColumnType.relation,
        targets: ['ability'],
      ),
      TableColumn(
        key: 'save_effect',
        label: 'Save Effect',
        type: TableColumnType.choice,
        options: ['none', 'half', 'negate', 'partial'],
      ),
    ]),
    FieldType.equipmentChoiceGroups ||
    FieldType.playerChoices ||
    FieldType.subspeciesOptions => f.copyWith(
      fieldType: FieldType.markdown,
      defaultValue: null,
    ),
    _ => f,
  };
}

/// An SRD skill / save table as a Skill table: the template holds the
/// names and their default stat, read from the category's stat table; a
/// mark adds the card's proficiency bonus (D32).
SkillTableSpec _skillSpec(FieldSchema f, EntityCategorySchema cat) =>
    SkillTableSpec(
      rows: [
        for (final r in storedTableRows(f.defaultValue))
          {tableRowId: r['name'], 'name': r['name'], 'ability': r['ability']},
      ],
      stat: cat.fields
          .where((x) => x.fieldType == FieldType.statBlock)
          .firstOrNull
          ?.fieldKey,
      bonus: cat.fields.any((x) => x.fieldKey == 'proficiency_bonus')
          ? 'proficiency_bonus'
          : null,
    );

/// The SRD copy's presets (DESIGN §16.1): skills, saving throws and ability
/// scores, each built from the first such field (the player card's first)
/// and bound to every such field. The fields keep their SRD keys (a
/// monster's `skill_bonuses`), so SRD cards read as they are.
WorldSchema _withSrdPresets(WorldSchema schema, String now) {
  String? kindOf(FieldSchema f) => switch (f.fieldType) {
    FieldType.skillTable => f.fieldKey.startsWith('sav') ? 'saves' : 'skills',
    FieldType.statTable when f.fieldKey == 'stat_block' => 'stats',
    FieldType.combatStats => 'combat',
    _ => null,
  };
  final presets = <String, FieldSchema>{};
  for (final c in [
    ...schema.categories.where((c) => c.isPlayerCard == true),
    ...schema.categories.where((c) => c.isPlayerCard != true),
  ]) {
    for (final f in c.fields) {
      final kind = kindOf(f);
      if (kind == null) continue;
      presets.putIfAbsent(
        kind,
        () => f.copyWith(
          fieldId: '${schema.schemaId}-preset-$kind',
          categoryId: '',
          groupId: null,
          orderIndex: 0,
          gridColumnSpan: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }
  return syncPresets(
    schema.copyWith(
      presets: [...presets.values],
      categories: [
        for (final c in schema.categories)
          c.copyWith(
            fields: [
              for (final f in c.fields)
                switch (kindOf(f)) {
                  final kind? => f.copyWith(presetId: presets[kind]!.fieldId),
                  null => f,
                },
            ],
          ),
      ],
    ),
  );
}

/// [cat]'s fields in the SRD copy, numbered in card order (the copy adds
/// fields beside the ones it converts).
List<FieldSchema> _srdCopyCategoryFields(EntityCategorySchema cat) {
  final sorted = [...cat.fields]
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  final out = [for (final f in sorted) ..._srdCopyFields(f, cat)];
  return [for (final (i, f) in out.indexed) f.copyWith(orderIndex: i)];
}

/// [source] copied as a new free template [id] named [name]. Works for the
/// built-in template (SRD copy, DESIGN §16) and for a free one (the lineage
/// root is kept). Category and field ids are kept: they are scoped to the
/// schema. The original hash is frozen here, at creation.
WorldSchema copyAsFreeTemplate(
  WorldSchema source, {
  required String id,
  required String name,
  required String now,
}) {
  final fromBuiltin = !isFreeTemplate(source);
  final copy = source.copyWith(
    schemaId: id,
    name: name,
    freeRootId: source.freeRootId ?? source.schemaId,
    createdAt: now,
    updatedAt: now,
    originalHash: null,
    categories: [
      for (final c in source.categories)
        c.copyWith(
          schemaId: id,
          isPlayerCard: fromBuiltin
              ? (c.slug == 'player-character' ? true : null)
              : c.isPlayerCard,
          tier: fromBuiltin ? builtinTier(c.slug) : c.tier,
          fields: fromBuiltin ? _srdCopyCategoryFields(c) : c.fields,
          summaryChips: fromBuiltin && c.slug == 'player-character'
              ? _srdChips
              : c.summaryChips,
        ),
    ],
  );
  final out = fromBuiltin ? _withSrdPresets(copy, now) : copy;
  return out.copyWith(originalHash: computeWorldSchemaContentHash(out));
}

/// The SRD copy's summary chips: the built-in character card's.
const List<Map<String, dynamic>> _srdChips = [
  {'field': 'combat_stats', 'icon': 'favorite'},
  {'field': 'species_ref', 'icon': 'pets'},
  {'field': 'class_refs', 'icon': 'shield_moon_outlined'},
  {'field': 'level', 'icon': 'trending_up'},
  {'field': 'combat_stats', 'sub': 'ac', 'icon': 'security'},
  {'field': ownerChipField, 'icon': 'person_outline'},
];

/// Content hash for the free template update check (ROADMAP Faz 3): the usual
/// content hash minus the Templates tab's tags and cover, so a new cover
/// doesn't ask every world to update.
String freeTemplateContentHash(WorldSchema schema) =>
    computeWorldSchemaContentHash(
      schema.copyWith(
        metadata: {
          for (final e in schema.metadata.entries)
            if (e.key != 'tags' && e.key != 'cover_image_path') e.key: e.value,
        },
      ),
    );

/// The template [world] should be offered as an update, or null: the world
/// isn't free (B2), prompts are muted, its template is gone (V2), or the
/// template already matches the world or the version the user ignored.
WorldSchema? pendingTemplateUpdate(
  WorldSchema world,
  List<WorldSchema> templates, {
  String? dismissedHash,
  bool muted = false,
}) {
  if (!isFreeTemplate(world) || muted) return null;
  final template = templates
      .where((t) => t.schemaId == world.schemaId)
      .firstOrNull;
  if (template == null) return null;
  final hash = freeTemplateContentHash(template);
  if (hash == dismissedHash || hash == freeTemplateContentHash(world)) {
    return null;
  }
  return template;
}

/// V5: in a free world the cards of a deleted category stay stored but are
/// not shown; adding the category back brings them back. Built-in worlds
/// pass through untouched.
Map<String, Entity> withoutDeletedCategories(
  Map<String, Entity> all,
  WorldSchema schema,
) {
  if (!isFreeTemplate(schema)) return all;
  final slugs = {for (final c in schema.categories) c.slug};
  return {
    for (final e in all.entries)
      if (slugs.contains(e.value.categorySlug)) e.key: e.value,
  };
}

/// A new free template holding only the player card (V1), with its two
/// ready fields: Level and Pool (DESIGN §10.1, D38).
WorldSchema emptyFreeTemplate({
  required String id,
  required String name,
  required String playerCardName,
  String levelLabel = 'Level',
  String poolLabel = 'Pool',
  required String now,
}) {
  FieldSchema own(FieldType type, String label, int order) => FieldSchema(
    fieldId: '$id-${playerCardFieldKey(type)}',
    categoryId: '$id-player',
    fieldKey: playerCardFieldKey(type),
    label: label,
    fieldType: type,
    orderIndex: order,
    createdAt: now,
    updatedAt: now,
  );
  final schema = WorldSchema(
    schemaId: id,
    name: name,
    freeRootId: id,
    createdAt: now,
    updatedAt: now,
    categories: [
      EntityCategorySchema(
        categoryId: '$id-player',
        schemaId: id,
        name: playerCardName,
        slug: 'player-character',
        icon: 'person_outline',
        color: '#4caf50',
        isPlayerCard: true,
        fields: [
          own(FieldType.characterLevel, levelLabel, 0),
          own(FieldType.autoResources, poolLabel, 1),
        ],
        summaryChips: [
          {
            'field': playerCardFieldKey(FieldType.characterLevel),
            'icon': 'trending_up',
          },
          {'field': ownerChipField, 'icon': 'person_outline'},
        ],
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
  return schema.copyWith(originalHash: computeWorldSchemaContentHash(schema));
}

/// A new free character's values (D35): level 1, and an empty Combat stats
/// block (not the built-in default map).
Map<String, dynamic> freeCharacterSeed(EntityCategorySchema playerCard) => {
  for (final f in playerCard.fields)
    if (f.fieldType == FieldType.characterLevel)
      f.fieldKey: 1
    else if (isCombatBlock(f))
      f.fieldKey: <String, dynamic>{},
};

/// The character's main level, or null when the player card has no Level
/// field (the sheet then shows none, D34).
int? characterLevelOf(EntityCategorySchema playerCard, Entity character) {
  final f = playerCard.fields
      .where((f) => f.fieldType == FieldType.characterLevel)
      .firstOrNull;
  if (f == null) return null;
  final v = character.fields[f.fieldKey];
  return v is num ? v.toInt() : int.tryParse('${v ?? ''}');
}

/// A free template's player card (DESIGN §10.1).
EntityCategorySchema? freePlayerCard(WorldSchema schema) =>
    schema.categories.where((c) => c.isPlayerCard == true).firstOrNull;

// ---------------------------------------------------------- summary chips

/// A summary chip showing the character's user (the built-in "User" chip).
const ownerChipField = '_owner';

/// One of the player card's summary chips: a field, one value of its Combat
/// stats block ([sub]; HP when null), or the user ([ownerChipField]).
typedef SheetChip = ({String field, String? sub, String icon});

Map<String, dynamic> sheetChipJson(SheetChip c) => {
  'field': c.field,
  'sub': ?c.sub,
  'icon': c.icon,
};

/// Field types a summary chip can show: short values.
const chipFieldTypes = {
  FieldType.text,
  FieldType.integer,
  FieldType.float_,
  FieldType.boolean_,
  FieldType.enum_,
  FieldType.dice,
  FieldType.tagList,
  FieldType.relation,
  FieldType.resource,
  FieldType.characterLevel,
  FieldType.combatStats,
};

/// [card]'s summary chips whose field is still there.
List<SheetChip> sheetChipsOf(EntityCategorySchema card) => [
  for (final m in card.summaryChips ?? const <Map<String, dynamic>>[])
    if (m['field'] case final String field
        when field == ownerChipField ||
            card.fields.any((f) => f.fieldKey == field))
      (field: field, sub: m['sub'] as String?, icon: '${m['icon'] ?? ''}'),
];

/// Every chip [card] can show, by label (a block's HP and each value apart).
List<({SheetChip chip, String label})> sheetChipChoices(
  EntityCategorySchema card,
) {
  final out = <({SheetChip chip, String label})>[];
  final fields = [...card.fields]
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  for (final f in fields) {
    if (!chipFieldTypes.contains(f.fieldType)) continue;
    SheetChip chip([String? sub]) => (field: f.fieldKey, sub: sub, icon: '');
    if (isCombatBlock(f)) {
      final spec = CombatStatsSpec.of(f);
      out.add((chip: chip(), label: '${f.label} › ${spec.hpLabel}'));
      for (final v in spec.values) {
        out.add((chip: chip(v.key), label: '${f.label} › ${v.label}'));
      }
    } else if (f.fieldType != FieldType.combatStats) {
      out.add((chip: chip(), label: f.label));
    }
  }
  return out;
}

/// [chip]'s label and what it shows on [fields]; [name] gives a card's
/// name for a ref (null: unknown). Null for the user chip and a field gone.
({String label, String value})? sheetChipValue(
  EntityCategorySchema card,
  SheetChip chip,
  Map<String, dynamic> fields,
  String? Function(Object? ref) name,
) {
  final f = card.fields.where((f) => f.fieldKey == chip.field).firstOrNull;
  if (f == null) return null;
  final v = freeFieldValue(f, fields);
  String text(Object? v, {bool cards = false}) => switch (v) {
    null || '' => '—',
    bool b => b ? '✓' : '—',
    List l when cards => _orDash(l.map(name).nonNulls.join(', ')),
    List l => _orDash(l.join(', ')),
    _ when cards => name(v) ?? '—',
    _ => '$v',
  };
  if (isCombatBlock(f)) {
    final m = v is Map ? v : const {};
    final spec = CombatStatsSpec.of(f);
    final sub = spec.values.where((x) => x.key == chip.sub).firstOrNull;
    if (sub == null) {
      final hp = combatNumber(m[combatHpKey]);
      final max = combatNumber(m[combatMaxHpKey]);
      return (
        label: spec.hpLabel,
        value: max == null ? text(hp) : '${hp ?? '—'} / $max',
      );
    }
    return (
      label: sub.label,
      value: text(m[sub.key], cards: sub.type == CombatValueType.cards),
    );
  }
  if (f.fieldType == FieldType.resource) {
    final r = resourceValue(v);
    return (
      label: f.label,
      value: r.max == null ? text(r.current) : '${r.current ?? '—'} / ${r.max}',
    );
  }
  return (
    label: f.label,
    value: text(v, cards: f.fieldType == FieldType.relation),
  );
}

String _orDash(String s) => s.isEmpty ? '—' : s;
