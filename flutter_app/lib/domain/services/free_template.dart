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
import 'template_edit.dart' show syncPresets;

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

/// [f] as an SRD copy holds it (ROADMAP §6): null when it is dropped, a
/// free style for the types converted so far, else unchanged (a kept SRD
/// type, converted in a later phase). Card data is not touched; the free
/// styles read the SRD shapes as they are (`free_field_styles.dart`).
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
    // The player card's class levels leave in Faz 6 (ROADMAP §6).
    FieldType.levelTable when f.fieldKey != 'class_levels' => table(const [
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
          fields: fromBuiltin
              ? [
                  for (final f in c.fields) ?_srdCopyField(f, c),
                ]
              : c.fields,
        ),
    ],
  );
  final out = fromBuiltin ? _withSrdPresets(copy, now) : copy;
  return out.copyWith(originalHash: computeWorldSchemaContentHash(out));
}

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

/// A new free template holding only the player card (V1). Its fixed fields
/// (level, automatic resources) arrive in Faz 6.
WorldSchema emptyFreeTemplate({
  required String id,
  required String name,
  required String playerCardName,
  required String now,
}) {
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
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
  return schema.copyWith(originalHash: computeWorldSchemaContentHash(schema));
}
