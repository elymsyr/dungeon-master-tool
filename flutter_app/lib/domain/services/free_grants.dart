import '../entities/entity.dart';
import '../entities/schema/entity_category_schema.dart';
import '../entities/schema/field_schema.dart';
import 'entity_ref.dart';
import 'free_field_styles.dart'
    show RestEffect, RestKind, afterRest, freeFieldValue;

/// The free template's level system (docs/free-template/DESIGN.md §8.4,
/// §8.5, §8.7, §11): Grants, the Level table and the Pool. A card passes
/// what it grants to the **carrier** — a character, or another card — that
/// takes it into a list. Pure and stateless; not the built-in resolver
/// (ROADMAP K4). Nothing here computes a value: cards go into lists,
/// resources and the rest into the Pool (D2).

int? _int(Object? v) => switch (v) {
  int i => i,
  num n => n.toInt(),
  String s => int.tryParse(s.trim()),
  _ => null,
};

List<Map<String, dynamic>> _maps(Object? v) => [
  if (v is List)
    for (final r in v)
      if (r is Map) Map<String, dynamic>.from(r),
];

RestEffect _effect(Object? v, RestEffect fallback) =>
    RestEffect.values.where((e) => e.name == v).firstOrNull ?? fallback;

// ----------------------------------------------------------------- items

enum GrantKind { card, resource, style }

/// The styles a grant item may take besides a card and a resource (V31:
/// never Grants, a Level table, the Pool, Combat stats or the Level).
const grantItemStyles = [
  FieldType.text,
  FieldType.textarea,
  FieldType.markdown,
  FieldType.integer,
  FieldType.float_,
  FieldType.boolean_,
  FieldType.enum_,
  FieldType.tagList,
  FieldType.dice,
  FieldType.table,
  FieldType.statTable,
];

/// One thing a card grants (DESIGN §8.5): a card for one of the carrier's
/// lists, a Pool resource (D39), or an item of another style.
class GrantItem {
  const GrantItem({
    required this.id,
    required this.kind,
    this.card,
    this.targets = const {},
    this.name = '',
    this.max,
    this.short = RestEffect.keep,
    this.long = RestEffect.fill,
    this.style,
    this.label = '',
    this.config,
    this.value,
  });

  factory GrantItem.fromJson(Map<String, dynamic> m) {
    final kind =
        GrantKind.values.where((k) => k.name == m['kind']).firstOrNull ??
        GrantKind.style;
    return GrantItem(
      id: '${m['_id'] ?? ''}',
      kind: kind,
      card: m['card'],
      targets: {
        if (m['targets'] case final Map t)
          for (final MapEntry(:key, :value) in t.entries)
            if (value is String) '$key': value,
      },
      name: '${m['name'] ?? ''}',
      max: _int(m['max']),
      short: _effect(m['short'], RestEffect.keep),
      long: _effect(m['long'], RestEffect.fill),
      style: FieldType.values.where((t) => t.name == m['style']).firstOrNull,
      label: '${m['label'] ?? ''}',
      config: m['config'] is Map
          ? Map<String, dynamic>.from(m['config'] as Map)
          : null,
      value: m['value'],
    );
  }

  final String id;
  final GrantKind kind;

  /// Card: the granted card's ref (an id or a `{slug, name}` soft ref).
  final Object? card;

  /// Card: per carrier category (slug), the list it goes into there (a
  /// field key) — a feat may give a monster's and a player's lists
  /// different homes. A carrier not named takes the first list holding the
  /// card's category; a named list it lacks sends the card to the Pool
  /// (V10).
  final Map<String, String> targets;

  /// Resource: its name — the Pool merges by it (D39).
  final String name;

  /// Resource: null leaves the max to the player (D30).
  final int? max;
  final RestEffect short;
  final RestEffect long;

  /// Another style: which ([grantItemStyles]), its label, settings, value.
  final FieldType? style;
  final String label;
  final Map<String, dynamic>? config;
  final Object? value;

  GrantItem copyWith({
    Object? Function()? card,
    Map<String, String>? targets,
    String? name,
    int? Function()? max,
    RestEffect? short,
    RestEffect? long,
    String? label,
    Map<String, dynamic>? Function()? config,
    Object? Function()? value,
  }) => GrantItem(
    id: id,
    kind: kind,
    card: card == null ? this.card : card(),
    targets: targets ?? this.targets,
    name: name ?? this.name,
    max: max == null ? this.max : max(),
    short: short ?? this.short,
    long: long ?? this.long,
    style: style,
    label: label ?? this.label,
    config: config == null ? this.config : config(),
    value: value == null ? this.value : value(),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'kind': kind.name,
    ...switch (kind) {
      GrantKind.card => {
        'card': card,
        if (targets.isNotEmpty) 'targets': targets,
      },
      GrantKind.resource => {
        'name': name,
        'max': ?max,
        'short': short.name,
        'long': long.name,
      },
      GrantKind.style => {
        'style': style?.name,
        'label': label,
        'config': ?config,
        'value': ?value,
      },
    },
  };

  /// A style item as a field, so the ordinary field widgets draw it.
  FieldSchema asField({String categoryId = ''}) => FieldSchema(
    fieldId: id,
    categoryId: categoryId,
    fieldKey: id,
    label: label,
    fieldType: style ?? FieldType.text,
    styleConfig: config,
    validation: FieldValidation(
      allowedValues: style == FieldType.enum_
          ? [for (final o in (config?['options'] as List?) ?? const []) '$o']
          : null,
    ),
    createdAt: '',
    updatedAt: '',
  );
}

List<GrantItem> grantItemsOf(Object? value) => [
  for (final m in _maps(value)) GrantItem.fromJson(m),
];

/// An item id not used in [items]: `g1`, `g2`…
String nextGrantItemId(List<GrantItem> items) {
  final used = {for (final i in items) i.id};
  var n = items.length + 1;
  while (used.contains('g$n')) {
    n++;
  }
  return 'g$n';
}

// ----------------------------------------------------------- level table

/// One Level table row (DESIGN §8.4): the level, text read once (§11.8),
/// and what the row grants.
class LevelRow {
  const LevelRow({
    required this.id,
    required this.level,
    this.text = '',
    this.items = const [],
  });

  factory LevelRow.fromJson(Map<String, dynamic> m) => LevelRow(
    id: '${m['_id'] ?? ''}',
    level: _int(m['level']) ?? 1,
    text: '${m['text'] ?? ''}',
    items: grantItemsOf(m['items']),
  );

  final String id;
  final int level;
  final String text;
  final List<GrantItem> items;

  Map<String, dynamic> toJson() => {
    '_id': id,
    'level': level,
    if (text.isNotEmpty) 'text': text,
    if (items.isNotEmpty) 'items': [for (final i in items) i.toJson()],
  };
}

/// A card's Level table rows, by level (stable within a level).
List<LevelRow> levelRowsOf(Object? value) {
  final rows = [for (final m in _maps(value)) LevelRow.fromJson(m)];
  return [
    for (final (_, r) in (rows.indexed.toList()
      ..sort(
        (a, b) => a.$2.level != b.$2.level
            ? a.$2.level.compareTo(b.$2.level)
            : a.$1.compareTo(b.$1),
      )))
      r,
  ];
}

// ------------------------------------------------------------- categories

enum LevelMode { separate, together }

LevelMode levelModeOf(EntityCategorySchema c) =>
    c.levelMode == LevelMode.separate.name
    ? LevelMode.separate
    : LevelMode.together;

FieldSchema? _first(EntityCategorySchema c, FieldType t) =>
    c.fields.where((f) => f.fieldType == t).firstOrNull;

/// The category's Level table (at most one, V9).
FieldSchema? levelTableOf(EntityCategorySchema c) =>
    _first(c, FieldType.progressionTable);

/// The category's Pool (at most one, D38).
FieldSchema? poolFieldOf(EntityCategorySchema c) =>
    _first(c, FieldType.autoResources);

/// The category's Level (D25): the player card's, or any other category's
/// that took one (at most one).
FieldSchema? levelFieldOf(EntityCategorySchema c) =>
    _first(c, FieldType.characterLevel);

/// The lists a carrier keeps cards in: its card link lists.
List<FieldSchema> carrierListsOf(EntityCategorySchema c) => [
  for (final f in c.fields)
    if (f.fieldType == FieldType.relation && f.isList) f,
];

/// The links whose cards grant the carrier: its lists and its single card
/// links. Granted cards still only join lists.
List<FieldSchema> carrierLinksOf(EntityCategorySchema c) => [
  for (final f in c.fields)
    if (f.fieldType == FieldType.relation) f,
];

/// Whether [list] takes cards of [slug]: it names it, or names nothing.
bool listTakes(FieldSchema list, String slug) {
  final t = list.validation.allowedTypes;
  return t == null || t.isEmpty || t.contains(slug);
}

/// Whether [list] names [slug] among its targets (an "any" list does not:
/// it would swallow every granted card).
bool listTargets(FieldSchema list, String slug) =>
    list.validation.allowedTypes?.contains(slug) ?? false;

// ---------------------------------------------------------- carrier data

/// The carrier's own card levels in separate categories (DESIGN §10.3).
const cardLevelsKey = '_card_levels';

/// Where each granted card in a list came from (V12): `{card id: {from:
/// giver id, level?: row level}}`.
const grantedKey = '_granted';

typedef GrantLabel = ({String from, int? level});

Map<String, int> cardLevelsOf(Map<String, dynamic> fields) {
  final v = fields[cardLevelsKey];
  return {
    if (v is Map)
      for (final e in v.entries)
        if (_int(e.value) != null) '${e.key}': _int(e.value)!,
  };
}

Map<String, GrantLabel> grantLabelsOf(Map<String, dynamic> fields) {
  final v = fields[grantedKey];
  return {
    if (v is Map)
      for (final e in v.entries)
        if (e.value is Map && (e.value as Map)['from'] != null)
          '${e.key}': (
            from: '${(e.value as Map)['from']}',
            level: _int((e.value as Map)['level']),
          ),
  };
}

/// The main level (D25), or null when the carrier has no Level field — a
/// card carrier (V30), or a player card without one (D34): Level tables
/// are then not read.
int? mainLevelOf(EntityCategorySchema carrier, Map<String, dynamic> fields) {
  final f = levelFieldOf(carrier);
  if (f == null) return null;
  return _int(fields[f.fieldKey]) ?? 1;
}

String? _refId(Object? raw, Map<String, Entity> byId) =>
    resolveEntityRef(raw is Map && raw['id'] != null ? raw['id'] : raw, byId);

/// The card ids in a card link value: a list (`[id]` or `[{id, equipped}]`)
/// or one card; soft refs resolved, unknown cards left out.
List<String> listedIds(Object? value, Map<String, Entity> byId) => [
  for (final r in value is List ? value : [value])
    if (_refId(r, byId) case final String id) id,
];

// ----------------------------------------------------------------- engine

/// What the engine reads besides the carrier's own values.
class GrantContext {
  GrantContext({
    required this.carrier,
    required List<EntityCategorySchema> categories,
    required this.entities,
  }) : _bySlug = {for (final c in categories) c.slug: c};

  /// The carrier's category (the player card for a character).
  final EntityCategorySchema carrier;
  final Map<String, Entity> entities;
  final Map<String, EntityCategorySchema> _bySlug;

  EntityCategorySchema? category(String slug) => _bySlug[slug];
}

/// A card a giver passes into one of the carrier's lists ([listKey]), or
/// into the Pool ([listKey] null).
class CardGrant {
  const CardGrant({
    required this.cardId,
    required this.fromId,
    this.rowLevel,
    this.listKey,
  });

  final String cardId;
  final String fromId;

  /// The Level table row it came from; null = the giver's Grants.
  final int? rowLevel;
  final String? listKey;
}

/// A Pool resource after the merge rules (D39).
class PoolResource {
  const PoolResource({
    required this.name,
    required this.fromId,
    this.max,
    this.short = RestEffect.keep,
    this.long = RestEffect.fill,
  });

  final String name;
  final String fromId;
  final int? max;
  final RestEffect short;
  final RestEffect long;

  RestEffect on(RestKind k) => k == RestKind.short ? short : long;
}

/// Something in the Pool under its giver's name: a style item, or a card
/// no list takes ([cardId]).
class PoolEntry {
  const PoolEntry({required this.fromId, required this.item, this.cardId});

  final String fromId;
  final GrantItem item;
  final String? cardId;
}

/// A reached row's text (read once, DESIGN §11.8).
typedef RowRead = ({String cardId, int level, String text});

/// What a carrier's cards grant it.
class GrantResult {
  const GrantResult({
    this.reached = const {},
    this.cards = const [],
    this.resources = const [],
    this.entries = const [],
    this.reads = const [],
    this.homeless = const [],
  });

  /// Card id → the level its Level table is read to (cards with one).
  final Map<String, int> reached;

  /// Granted cards, one per card (no repeats, §11.6).
  final List<CardGrant> cards;
  final List<PoolResource> resources;
  final List<PoolEntry> entries;
  final List<RowRead> reads;

  /// Granted cards with nowhere to go: no list takes them and the carrier
  /// has no Pool (V10's warning).
  final List<String> homeless;

  bool wants(String cardId) => cards.any((g) => g.cardId == cardId);
}

/// Everything [fields]' cards grant the carrier (DESIGN §8.5, §11.3,
/// §11.6). Roots are the cards in the carrier's card links, lists and
/// single links; a separate-mode card the carrier took itself into a list
/// reads its rows to its own level, every other card to the main level
/// (V11; a single link holds one card). A granted card no list takes goes
/// to the Pool and its own grants still apply (chain). Each card is read
/// once (no loop, no repeats).
GrantResult computeGrants(Map<String, dynamic> fields, GrantContext ctx) {
  final main = mainLevelOf(ctx.carrier, fields);
  final levels = cardLevelsOf(fields);
  final labels = grantLabelsOf(fields);
  final lists = carrierListsOf(ctx.carrier);
  final pool = poolFieldOf(ctx.carrier);
  final hasPool = pool != null;
  final removed = pool == null
      ? const <String>{}
      : poolRemovedOf(fields[pool.fieldKey]);

  final reached = <String, int>{};
  final cards = <CardGrant>[];
  final entries = <PoolEntry>[];
  final reads = <RowRead>[];
  final homeless = <String>[];
  // Per giver, per name: a later one replaces an earlier one (D39).
  final byGiver = <String, Map<String, PoolResource>>{};
  final names = <String>[];

  String? listFor(String? target, String slug) {
    // A chosen list that is gone, or no longer takes the card: the Pool,
    // not a list the owner did not pick (V10).
    if (target != null) {
      final chosen = lists.where((f) => f.fieldKey == target).firstOrNull;
      return chosen != null && listTakes(chosen, slug) ? target : null;
    }
    return lists.where((f) => listTargets(f, slug)).firstOrNull?.fieldKey;
  }

  final queue = <(String, int?)>[];
  for (final f in carrierLinksOf(ctx.carrier)) {
    for (final id in listedIds(fields[f.fieldKey], ctx.entities)) {
      final cat = ctx.category(ctx.entities[id]!.categorySlug);
      int? level;
      if (main != null) {
        final own =
            f.isList &&
            cat != null &&
            levelModeOf(cat) == LevelMode.separate &&
            !labels.containsKey(id);
        level = own ? (levels[id] ?? 1) : main;
      }
      queue.add((id, level));
    }
  }

  final visited = <String>{};
  for (var i = 0; i < queue.length; i++) {
    final (id, level) = queue[i];
    if (!visited.add(id)) continue;
    final card = ctx.entities[id];
    final cat = card == null ? null : ctx.category(card.categorySlug);
    if (card == null || cat == null) continue;

    void emit(GrantItem item, int? row) {
      switch (item.kind) {
        case GrantKind.card:
          final target = _refId(item.card, ctx.entities);
          if (target == null || target == id) return;
          if (cards.any((g) => g.cardId == target)) return;
          final listKey = listFor(
            item.targets[ctx.carrier.slug],
            ctx.entities[target]!.categorySlug,
          );
          if (listKey == null && removed.contains(poolEntryKey(id, item))) {
            return;
          }
          cards.add(
            CardGrant(cardId: target, fromId: id, rowLevel: row, listKey: listKey),
          );
          if (listKey != null) return; // read as a root once it is listed
          if (hasPool) {
            entries.add(PoolEntry(fromId: id, item: item, cardId: target));
          } else {
            homeless.add(target);
          }
          queue.add((target, main));
        case GrantKind.resource:
          if (item.name.trim().isEmpty) return;
          final name = item.name.trim();
          if (removed.contains(name)) return;
          if (!names.contains(name)) names.add(name);
          (byGiver[id] ??= {})[name] = PoolResource(
            name: name,
            fromId: id,
            max: item.max,
            short: item.short,
            long: item.long,
          );
        case GrantKind.style:
          if (item.style == null || !grantItemStyles.contains(item.style)) {
            return;
          }
          if (removed.contains(poolEntryKey(id, item))) return;
          entries.add(PoolEntry(fromId: id, item: item));
      }
    }

    // The card's own Grants count before its rows (D39).
    for (final f in cat.fields) {
      if (f.fieldType != FieldType.grantHolder) continue;
      final value = freeFieldValue(f, card.fields, byId: ctx.entities);
      for (final item in grantItemsOf(value)) {
        emit(item, null);
      }
    }
    final table = levelTableOf(cat);
    if (table != null && level != null) {
      reached[id] = level;
      final rows = freeFieldValue(table, card.fields, byId: ctx.entities);
      for (final row in levelRowsOf(rows)) {
        if (row.level > level) break;
        if (row.text.trim().isNotEmpty) {
          reads.add((cardId: id, level: row.level, text: row.text.trim()));
        }
        for (final item in row.items) {
          emit(item, row.level);
        }
      }
    }
  }

  // Different givers, same name: the larger max wins (D39); a set max
  // beats one left to the player.
  final resources = <PoolResource>[];
  for (final name in names) {
    PoolResource? best;
    for (final g in byGiver.values) {
      final r = g[name];
      if (r == null) continue;
      if (best == null || (r.max ?? -1) > (best.max ?? -1)) best = r;
    }
    resources.add(best!);
  }

  return GrantResult(
    reached: reached,
    cards: cards,
    resources: resources,
    entries: entries,
    reads: reads,
    homeless: homeless,
  );
}

// ------------------------------------------------------------ list edits

/// [fields] with [cards] added to their lists, labelled with their giver.
Map<String, dynamic> withGrantedCards(
  Map<String, dynamic> fields,
  List<CardGrant> cards,
  GrantContext ctx,
) {
  final out = Map<String, dynamic>.from(fields);
  final labels = Map<String, dynamic>.from(
    (fields[grantedKey] as Map?) ?? const {},
  );
  for (final g in cards) {
    final key = g.listKey;
    if (key == null) continue;
    final list = carrierListsOf(ctx.carrier)
        .where((f) => f.fieldKey == key)
        .firstOrNull;
    if (list == null) continue;
    final value = [...((out[key] as List?) ?? const [])];
    value.add(list.hasEquip ? {'id': g.cardId, 'equipped': false} : g.cardId);
    out[key] = value;
    labels[g.cardId] = {'from': g.fromId, 'level': ?g.rowLevel};
  }
  out[grantedKey] = labels;
  return out;
}

/// [fields] with [ids] taken out of every list.
Map<String, dynamic> withoutCards(
  Map<String, dynamic> fields,
  Iterable<String> ids,
  GrantContext ctx,
) {
  final gone = ids.toSet();
  final out = Map<String, dynamic>.from(fields);
  for (final f in carrierListsOf(ctx.carrier)) {
    final v = out[f.fieldKey];
    if (v is! List) continue;
    out[f.fieldKey] = [
      for (final r in v)
        if (!gone.contains(_refId(r, ctx.entities))) r,
    ];
  }
  return _pruned(out, ctx);
}

/// Every card id in the carrier's lists: stored ids as they are, soft refs
/// resolved (a carrier whose world is not loaded keeps its labels).
Set<String> _idsInLists(Map<String, dynamic> fields, GrantContext ctx) => {
  for (final f in carrierListsOf(ctx.carrier))
    if (fields[f.fieldKey] case final List list)
      for (final r in list) ...[
        if (r is String) r,
        if (r is Map && r['id'] is String) r['id'] as String,
        if (_refId(r, ctx.entities) case final String id) id,
      ],
};

/// Labels and card levels of cards no longer in any list go: a card taken
/// again starts afresh (§11.2).
Map<String, dynamic> _pruned(Map<String, dynamic> fields, GrantContext ctx) {
  final inLists = _idsInLists(fields, ctx);
  final out = Map<String, dynamic>.from(fields);
  for (final key in [grantedKey, cardLevelsKey]) {
    final v = fields[key];
    if (v is! Map) continue;
    out[key] = {
      for (final e in v.entries)
        if (inLists.contains('${e.key}')) '${e.key}': e.value,
    };
  }
  return out;
}

// ----------------------------------------------------------------- change

/// A carrier change and what it granted (DESIGN §11.4–§11.7).
class GrantChange {
  const GrantChange({
    required this.fields,
    required this.before,
    required this.after,
    this.added = const [],
    this.stale = const [],
  });

  /// The carrier's values: the change, plus the granted cards it added.
  final Map<String, dynamic> fields;
  final GrantResult before;
  final GrantResult after;

  /// Cards this change put into lists.
  final List<CardGrant> added;

  /// Labelled cards still listed that nothing grants any more (V12): to
  /// offer for removal, never removed unasked.
  final List<String> stale;
}

/// [after] (the carrier's values once the user's change is in: a card
/// added or removed, a level changed) with the cards the change newly
/// grants added to their lists, chains included. A card granted before the
/// change is never added again — the player may have removed it (§11.6).
GrantChange settleGrants(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
  GrantContext ctx,
) {
  final base = computeGrants(before, ctx);
  var fields = _pruned(after, ctx);
  final added = <CardGrant>[];
  // Each round adds at least one card, and a card at most once.
  while (true) {
    final res = computeGrants(fields, ctx);
    final fresh = <CardGrant>[
      for (final g in res.cards)
        if (g.listKey != null &&
            !base.wants(g.cardId) &&
            !added.any((a) => a.cardId == g.cardId) &&
            !listedIds(fields[g.listKey], ctx.entities).contains(g.cardId))
          g,
    ];
    if (fresh.isEmpty) break;
    fields = withGrantedCards(fields, fresh, ctx);
    added.addAll(fresh);
  }
  final result = computeGrants(fields, ctx);
  final inLists = _idsInLists(fields, ctx);
  final stale = [
    for (final id in grantLabelsOf(fields).keys)
      if (inLists.contains(id) && base.wants(id) && !result.wants(id)) id,
  ];
  return GrantChange(
    fields: fields,
    before: base,
    after: result,
    added: added,
    stale: stale,
  );
}

// ---------------------------------------------------------------- summary

/// What a change shows the player (DESIGN §11.4's summary).
class GrantSummary {
  const GrantSummary({
    this.added = const [],
    this.toPool = const [],
    this.reads = const [],
    this.resources = const [],
    this.homeless = const [],
  });

  final List<CardGrant> added;
  final List<PoolEntry> toPool;
  final List<RowRead> reads;

  /// Resources new or with a new max: name, max before (0 when new), after.
  final List<({String name, int? from, int? to})> resources;
  final List<String> homeless;

  bool get isEmpty =>
      added.isEmpty &&
      toPool.isEmpty &&
      reads.isEmpty &&
      resources.isEmpty &&
      homeless.isEmpty;
}

GrantSummary summarize(GrantChange c) {
  bool sameEntry(PoolEntry a, PoolEntry b) =>
      a.fromId == b.fromId && a.item.id == b.item.id && a.cardId == b.cardId;
  return GrantSummary(
    added: c.added,
    toPool: [
      for (final e in c.after.entries)
        if (!c.before.entries.any((b) => sameEntry(b, e))) e,
    ],
    reads: [
      for (final r in c.after.reads)
        if (!c.before.reads.any((b) => b.cardId == r.cardId && b.level == r.level))
          r,
    ],
    resources: [
      for (final r in c.after.resources)
        if (c.before.resources.where((b) => b.name == r.name).firstOrNull
            case final b
            when b == null || b.max != r.max)
          (name: r.name, from: b == null ? 0 : b.max, to: r.max),
    ],
    homeless: [
      for (final id in c.after.homeless)
        if (!c.before.homeless.contains(id)) id,
    ],
  );
}

// --------------------------------------------------------------- level up

/// One separate category at a level up (DESIGN §11.4): its cards the
/// carrier took itself, with their levels, and the list a new one joins.
class LevelUpGroup {
  const LevelUpGroup({
    required this.category,
    required this.listKey,
    required this.cards,
  });

  final EntityCategorySchema category;
  final String listKey;
  final List<({String id, int level})> cards;
}

/// The separate categories a level up asks about: those the carrier holds
/// own cards of (granted cards follow the main level and are not asked,
/// V11; a category without cards is skipped, V13).
List<LevelUpGroup> levelUpGroups(
  Map<String, dynamic> fields,
  GrantContext ctx,
) {
  final levels = cardLevelsOf(fields);
  final labels = grantLabelsOf(fields);
  final groups = <String, LevelUpGroup>{};
  for (final f in carrierListsOf(ctx.carrier)) {
    for (final id in listedIds(fields[f.fieldKey], ctx.entities)) {
      if (labels.containsKey(id)) continue;
      final cat = ctx.category(ctx.entities[id]!.categorySlug);
      if (cat == null ||
          levelTableOf(cat) == null ||
          levelModeOf(cat) != LevelMode.separate) {
        continue;
      }
      final g = groups[cat.slug];
      if (g != null && g.cards.any((c) => c.id == id)) continue;
      groups[cat.slug] = LevelUpGroup(
        category: cat,
        listKey: g?.listKey ?? f.fieldKey,
        cards: [...?g?.cards, (id: id, level: levels[id] ?? 1)],
      );
    }
  }
  return [...groups.values];
}

/// The carrier one level up: main level + 1; per separate category the
/// picked card + 1, or [added] (category slug → new card) joining its list
/// at level 1. Grants are not applied here: run [settleGrants] from the
/// values before.
Map<String, dynamic> levelUp(
  Map<String, dynamic> fields,
  GrantContext ctx, {
  Map<String, String> picked = const {},
  Map<String, String> added = const {},
}) {
  final levelField = levelFieldOf(ctx.carrier);
  if (levelField == null) return fields;
  final out = Map<String, dynamic>.from(fields);
  out[levelField.fieldKey] = (mainLevelOf(ctx.carrier, fields) ?? 0) + 1;
  final levels = cardLevelsOf(fields);
  for (final id in picked.values) {
    levels[id] = (levels[id] ?? 1) + 1;
  }
  final groups = {for (final g in levelUpGroups(fields, ctx)) g.category.slug: g};
  for (final e in added.entries) {
    final listKey =
        groups[e.key]?.listKey ??
        carrierListsOf(ctx.carrier)
            .where((f) => listTargets(f, e.key))
            .firstOrNull
            ?.fieldKey;
    if (listKey == null) continue;
    final list = carrierListsOf(ctx.carrier).firstWhere(
      (f) => f.fieldKey == listKey,
    );
    out[listKey] = [
      ...((out[listKey] as List?) ?? const []),
      list.hasEquip ? {'id': e.value, 'equipped': false} : e.value,
    ];
    levels[e.value] = 1;
  }
  out[cardLevelsKey] = levels;
  return out;
}

// -------------------------------------------------------------------- pool

/// A Pool resource as shown: its max (the item's, else the player's, D30)
/// and current value (new ones start full, a lower max lowers it, V32).
typedef PoolResourceValue = ({
  PoolResource resource,
  int? max,
  int? current,
  bool playerMax,
});

Map<String, dynamic> _stored(Object? v, String name) {
  if (v is! Map) return const {};
  final r = v[name];
  return r is Map ? Map<String, dynamic>.from(r) : const {};
}

PoolResourceValue poolResourceValue(PoolResource r, Object? stored) {
  final s = _stored(stored, r.name);
  final max = r.max ?? _int(s['max']);
  var current = _int(s['current']) ?? max;
  if (current != null && max != null && current > max) current = max;
  return (resource: r, max: max, current: current, playerMax: r.max == null);
}

/// The Pool's stored values with [name] set: only what the player keeps —
/// the current value, and the max where the item leaves it (V29).
Map<String, dynamic> poolStoredWith(
  Object? stored,
  String name, {
  int? current,
  int? max,
}) {
  final out = stored is Map
      ? Map<String, dynamic>.from(stored)
      : <String, dynamic>{};
  out[name] = {
    ..._stored(stored, name),
    'current': ?current,
    'max': ?max,
  };
  return out;
}

/// What the player took out of the Pool: resource names and [poolEntryKey]s,
/// kept in the Pool's value. Taken out, an item is not granted at all — no
/// Pool line, no rest, no chain.
const poolRemovedKey = '_removed';

/// A Pool entry's key: its giver and the item.
String poolEntryKey(String fromId, GrantItem item) => '$fromId/${item.id}';

Set<String> poolRemovedOf(Object? stored) => {
  if (stored is Map && stored[poolRemovedKey] is List)
    for (final k in stored[poolRemovedKey] as List) '$k',
};

/// [stored] with [key] taken out of the Pool; a null [key] puts everything
/// back.
Map<String, dynamic> poolWithRemoved(Object? stored, String? key) {
  final out = stored is Map
      ? Map<String, dynamic>.from(stored)
      : <String, dynamic>{};
  if (key == null) {
    out.remove(poolRemovedKey);
  } else {
    out[poolRemovedKey] = [...poolRemovedOf(stored), key];
  }
  return out;
}

/// The Pool's stored values after a rest (DESIGN §12.3), or null when
/// nothing changes. Values of resources no longer granted stay (V29).
Map<String, dynamic>? poolAfterRest(
  GrantResult r,
  Object? stored,
  RestKind kind,
) {
  Object? out = stored;
  var changed = false;
  for (final res in r.resources) {
    final v = poolResourceValue(res, out);
    final next = afterRest(res.on(kind), v.current, v.max);
    if (next == v.current) continue;
    out = poolStoredWith(out, res.name, current: next);
    changed = true;
  }
  return changed ? out as Map<String, dynamic> : null;
}
