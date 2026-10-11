import '../entities/schema/entity_category_schema.dart';
import '../entities/schema/field_group.dart';
import '../entities/schema/field_schema.dart';
import '../entities/schema/world_schema.dart';

/// Pure edits behind the free template editor (docs/free-template/DESIGN.md
/// §6.6, §7). Each returns a new value; ids and timestamps come from the
/// caller.

/// The simple styles the palette offers (DESIGN §8). Every other
/// [FieldType] in a free template is a kept SRD type (ROADMAP §6).
const simpleFieldTypes = [
  FieldType.text,
  FieldType.textarea,
  FieldType.markdown,
  FieldType.integer,
  FieldType.float_,
  FieldType.boolean_,
  FieldType.enum_,
  FieldType.date,
  FieldType.tagList,
  FieldType.dice,
  FieldType.image,
  FieldType.imagePerEra,
  FieldType.file,
  FieldType.relation,
];

bool isSimpleFieldType(FieldType t) => simpleFieldTypes.contains(t);

/// Simple styles that cannot be a list: a list of yes/no or of era maps
/// means nothing, and tags are a list already.
bool canBeList(FieldType t) =>
    isSimpleFieldType(t) &&
    t != FieldType.boolean_ &&
    t != FieldType.imagePerEra &&
    t != FieldType.tagList;

const _fold = {
  'ç': 'c',
  'ğ': 'g',
  'ı': 'i',
  'ö': 'o',
  'ş': 's',
  'ü': 'u',
  'â': 'a',
  'î': 'i',
  'û': 'u',
  'ä': 'a',
  'ß': 'ss',
  'à': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'ï': 'i',
  'ô': 'o',
  'ù': 'u',
  'ÿ': 'y',
  'œ': 'oe',
  'æ': 'ae',
};

/// A machine name for [label] that is not in [taken]: lowercase ASCII words
/// joined by [separator], `_2`, `_3`… on a clash. A field key is made once,
/// from the label it was created with, and never changes (V3).
String keyFromLabel(
  String label,
  Iterable<String> taken, {
  String separator = '_',
  String fallback = 'field',
}) {
  final folded = label
      .replaceAll('İ', 'i')
      .toLowerCase()
      .split('')
      .map((c) => _fold[c] ?? c)
      .join();
  var base = folded
      .replaceAll(RegExp('[^a-z0-9]+'), separator)
      .replaceAll(
        RegExp(
          '^${RegExp.escape(separator)}+|'
          '${RegExp.escape(separator)}+\$',
        ),
        '',
      );
  if (base.isEmpty) base = fallback;
  final used = taken.toSet();
  if (!used.contains(base)) return base;
  var n = 2;
  while (used.contains('$base$separator$n')) {
    n++;
  }
  return '$base$separator$n';
}

// ---------------------------------------------------------------- fields

/// [cat]'s fields in [groupId] (null = ungrouped, shown as "Properties"),
/// in card order.
List<FieldSchema> fieldsIn(EntityCategorySchema cat, String? groupId) => [
  for (final f in cat.fields)
    if (f.groupId == groupId) f,
]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

List<FieldGroup> sortedGroups(EntityCategorySchema cat) =>
    [...cat.fieldGroups]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

/// Renumbers every field: ungrouped first, then group by group. The card
/// sorts by `orderIndex` inside each group, so only that order matters.
EntityCategorySchema _withBuckets(
  EntityCategorySchema cat,
  Map<String?, List<FieldSchema>> buckets,
) {
  final order = [null, ...sortedGroups(cat).map((g) => g.groupId)];
  final out = <FieldSchema>[];
  for (final g in order) {
    for (final f in buckets[g] ?? const <FieldSchema>[]) {
      out.add(f.copyWith(groupId: g, orderIndex: out.length));
    }
  }
  return cat.copyWith(fields: out);
}

/// Fields per group. A field pointing at a group that does not exist (the
/// card never draws it) lands in the ungrouped bucket.
Map<String?, List<FieldSchema>> _buckets(EntityCategorySchema cat) {
  final ids = {for (final g in cat.fieldGroups) g.groupId};
  final out = <String?, List<FieldSchema>>{
    null: [],
    for (final id in ids) id: [],
  };
  final sorted = [...cat.fields]
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  for (final f in sorted) {
    out[ids.contains(f.groupId) ? f.groupId : null]!.add(f);
  }
  return out;
}

/// Adds a [type] field labelled [label] to [groupId] at [index] (end when
/// null). Its key comes from the label and is unique in [cat].
EntityCategorySchema addField(
  EntityCategorySchema cat, {
  required String id,
  required String label,
  required FieldType type,
  bool isList = false,
  String? groupId,
  int? index,
  required String now,
}) {
  final field = FieldSchema(
    fieldId: id,
    categoryId: cat.categoryId,
    fieldKey: keyFromLabel(label, cat.fields.map((f) => f.fieldKey)),
    label: label,
    fieldType: type,
    isList: isList && canBeList(type),
    groupId: groupId,
    createdAt: now,
    updatedAt: now,
  );
  final buckets = _buckets(cat);
  final list = buckets[groupId] ?? [];
  list.insert((index ?? list.length).clamp(0, list.length), field);
  buckets[groupId] = list;
  return _withBuckets(cat, buckets);
}

/// Moves [fieldId] into [groupId] at [index] (counted without the moved
/// field; end when null).
EntityCategorySchema moveField(
  EntityCategorySchema cat,
  String fieldId, {
  String? groupId,
  int? index,
}) {
  final field = cat.fields.firstWhere((f) => f.fieldId == fieldId);
  final buckets = _buckets(cat);
  for (final list in buckets.values) {
    list.removeWhere((f) => f.fieldId == fieldId);
  }
  final list = buckets[groupId] ?? [];
  list.insert((index ?? list.length).clamp(0, list.length), field);
  buckets[groupId] = list;
  return _withBuckets(cat, buckets);
}

/// Removes [fieldId]. Card data under its key stays in the cards, hidden
/// (D17); the key also leaves the category's filters.
EntityCategorySchema removeField(EntityCategorySchema cat, String fieldId) {
  final key = cat.fields.firstWhere((f) => f.fieldId == fieldId).fieldKey;
  return cat.copyWith(
    fields: [
      for (final f in cat.fields)
        if (f.fieldId != fieldId) f,
    ],
    filterFieldKeys: [
      for (final k in cat.filterFieldKeys)
        if (k != key) k,
    ],
  );
}

EntityCategorySchema replaceField(EntityCategorySchema cat, FieldSchema f) =>
    cat.copyWith(
      fields: [for (final x in cat.fields) x.fieldId == f.fieldId ? f : x],
    );

// ----------------------------------------------------------- type change

enum TypeChange {
  /// Nothing changes.
  same,

  /// Stored values read as they are.
  compatible,

  /// Allowed after a warning: a card link list keeps only its first card.
  lossy,

  /// Allowed after a warning: the old field retires (its data stays hidden)
  /// and a new field with a new key takes its place (V4).
  incompatible,
}

const _textish = {FieldType.text, FieldType.textarea, FieldType.markdown};

/// DESIGN §6.6's compatibility table.
TypeChange typeChangeOf(
  FieldType from,
  bool fromList,
  FieldType to,
  bool toList,
) {
  if (from == to && fromList == toList) return TypeChange.same;
  if (from == to && !fromList && toList) return TypeChange.compatible;
  if (from == FieldType.relation && to == FieldType.relation) {
    return TypeChange.lossy;
  }
  if (fromList != toList) return TypeChange.incompatible;
  if (_textish.contains(from) && _textish.contains(to)) {
    return TypeChange.compatible;
  }
  if (from == FieldType.integer && to == FieldType.float_) {
    return TypeChange.compatible;
  }
  if (from == FieldType.enum_ && to == FieldType.text) {
    return TypeChange.compatible;
  }
  return TypeChange.incompatible;
}

/// Gives [fieldId] the style [to] / [toList]. Compatible and lossy changes
/// keep the field and its key; an incompatible one replaces it with a new
/// field [newId] under a fresh key, in the same place (V4).
EntityCategorySchema changeFieldType(
  EntityCategorySchema cat,
  String fieldId,
  FieldType to,
  bool toList, {
  required String newId,
  required String now,
}) {
  final old = cat.fields.firstWhere((f) => f.fieldId == fieldId);
  final change = typeChangeOf(old.fieldType, old.isList, to, toList);
  if (change == TypeChange.same) return cat;
  if (change != TypeChange.incompatible) {
    return replaceField(
      cat,
      old.copyWith(fieldType: to, isList: toList, updatedAt: now),
    );
  }
  final fresh = old.copyWith(
    fieldId: newId,
    fieldKey: keyFromLabel(old.label, cat.fields.map((f) => f.fieldKey)),
    fieldType: to,
    isList: toList,
    defaultValue: null,
    validation: const FieldValidation(),
    placeholder: '',
    createdAt: now,
    updatedAt: now,
  );
  // removeField also drops the old key from the filters.
  return removeField(cat, fieldId).copyWith(
    fields: [for (final f in cat.fields) f.fieldId == fieldId ? fresh : f],
  );
}

// ---------------------------------------------------------------- groups

EntityCategorySchema addGroup(
  EntityCategorySchema cat, {
  required String id,
  required String name,
}) {
  final groups = sortedGroups(cat);
  return cat.copyWith(
    fieldGroups: [
      for (var i = 0; i < groups.length; i++) groups[i].copyWith(orderIndex: i),
      FieldGroup(groupId: id, name: name, orderIndex: groups.length),
    ],
  );
}

EntityCategorySchema replaceGroup(EntityCategorySchema cat, FieldGroup g) =>
    cat.copyWith(
      fieldGroups: [
        for (final x in cat.fieldGroups) x.groupId == g.groupId ? g : x,
      ],
    );

/// Moves every field of [from] to the end of [to] (null = ungrouped).
EntityCategorySchema moveGroupFields(
  EntityCategorySchema cat,
  String from,
  String? to,
) {
  if (from == to) return cat;
  final buckets = _buckets(cat);
  final moving = buckets[from] ?? [];
  buckets[from] = [];
  buckets[to] = [...?buckets[to], ...moving];
  return _withBuckets(cat, buckets);
}

/// Removes [groupId]; its fields are not deleted, they move to [moveTo]
/// (null = ungrouped "Properties").
EntityCategorySchema removeGroup(
  EntityCategorySchema cat,
  String groupId, {
  String? moveTo,
}) {
  final moved = moveGroupFields(cat, groupId, moveTo);
  final groups = [
    for (final g in sortedGroups(moved))
      if (g.groupId != groupId) g,
  ];
  return moved.copyWith(
    fieldGroups: [
      for (var i = 0; i < groups.length; i++) groups[i].copyWith(orderIndex: i),
    ],
  );
}

/// Moves the group at [oldIndex] to [newIndex] (counted without it, as
/// `ReorderableListView.onReorderItem` gives it).
EntityCategorySchema reorderGroups(
  EntityCategorySchema cat,
  int oldIndex,
  int newIndex,
) {
  final groups = sortedGroups(cat);
  final g = groups.removeAt(oldIndex);
  groups.insert(newIndex.clamp(0, groups.length), g);
  return cat.copyWith(
    fieldGroups: [
      for (var i = 0; i < groups.length; i++) groups[i].copyWith(orderIndex: i),
    ],
  );
}

// ------------------------------------------------------------ categories

/// The player card cannot be removed, only renamed (ROADMAP Faz 2).
bool canRemoveCategory(EntityCategorySchema cat) => cat.isPlayerCard != true;

WorldSchema addCategory(
  WorldSchema schema, {
  required String id,
  required String name,
  required String now,
}) {
  final cat = EntityCategorySchema(
    categoryId: id,
    schemaId: schema.schemaId,
    name: name,
    slug: keyFromLabel(
      name,
      schema.categories.map((c) => c.slug),
      separator: '-',
      fallback: 'category',
    ),
    icon: 'workspaces',
    color: '#42a5f5',
    orderIndex: schema.categories.length,
    allowedInSections: const ['worldmap', 'mindmap', 'projection'],
    createdAt: now,
    updatedAt: now,
  );
  return schema.copyWith(categories: [...schema.categories, cat]);
}

/// Removes [categoryId] unless it is the player card. Its cards stay in the
/// worlds, hidden (V5).
WorldSchema removeCategory(WorldSchema schema, String categoryId) =>
    schema.copyWith(
      categories: [
        for (final c in schema.categories)
          if (c.categoryId != categoryId || !canRemoveCategory(c)) c,
      ],
    );

WorldSchema replaceCategory(WorldSchema schema, EntityCategorySchema cat) =>
    schema.copyWith(
      categories: [
        for (final c in schema.categories)
          c.categoryId == cat.categoryId ? cat : c,
      ],
    );

/// Puts the categories in [orderedIds] order (sidebar order); ids missing
/// from the list keep their place in front.
WorldSchema reorderCategories(WorldSchema schema, List<String> orderedIds) {
  final byId = {for (final c in schema.categories) c.categoryId: c};
  final rest = [
    for (final c in schema.categories)
      if (!orderedIds.contains(c.categoryId)) c,
  ];
  final ordered = [
    ...rest,
    for (final id in orderedIds)
      if (byId[id] != null) byId[id]!,
  ];
  return schema.copyWith(
    categories: [
      for (var i = 0; i < ordered.length; i++)
        ordered[i].copyWith(orderIndex: i),
    ],
  );
}
