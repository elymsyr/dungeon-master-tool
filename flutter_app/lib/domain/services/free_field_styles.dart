import '../entities/entity.dart';
import '../entities/schema/field_schema.dart';
import 'free_srd_levels.dart';
import 'template_edit.dart' show keyFromLabel;

/// The free template's combined styles: Table (docs/free-template/DESIGN.md
/// §8.1), Stat table (§8.2), Skill table (D32), Resource (§8.3) and Combat
/// stats (§8.6), the rests (§12.3), plus the readers that
/// show SRD data in them without changing it (§16.3). Pure; the stored
/// shapes are documented on [FieldType.table], [FieldType.statTable] and
/// [FieldType.skillTable].

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

// ------------------------------------------------------------ stat table

typedef StatEntry = ({String key, String label});

class StatTableSpec {
  const StatTableSpec({
    this.stats = const [],
    this.base = 10,
    this.step = 2,
    this.showModifier = true,
  });

  factory StatTableSpec.of(FieldSchema f) {
    final c = f.styleConfig ?? const {};
    return StatTableSpec(
      stats: [
        for (final s in _maps(c['stats']))
          (key: '${s['key']}', label: '${s['label'] ?? s['key']}'),
      ],
      base: _int(c['base']) ?? 10,
      step: _int(c['step']) ?? 2,
      showModifier: c['showModifier'] != false,
    );
  }

  final List<StatEntry> stats;
  final int base;

  /// Points per ±1; below 1 reads as 1.
  final int step;
  final bool showModifier;

  int modifier(int value) => statModifier(value, base: base, step: step);

  StatTableSpec copyWith({
    List<StatEntry>? stats,
    int? base,
    int? step,
    bool? showModifier,
  }) => StatTableSpec(
    stats: stats ?? this.stats,
    base: base ?? this.base,
    step: step ?? this.step,
    showModifier: showModifier ?? this.showModifier,
  );

  Map<String, dynamic> toConfig() => {
    'stats': [
      for (final s in stats) {'key': s.key, 'label': s.label},
    ],
    'base': base,
    'step': step,
    'showModifier': showModifier,
  };
}

/// DESIGN §8.2: ⌊(value − base) ÷ step⌋, always rounded down (9 → −1 in
/// D&D; the built-in stat block's truncation is not copied, Y7).
int statModifier(int value, {int base = 10, int step = 2}) =>
    ((value - base) / (step < 1 ? 1 : step)).floor();

// ----------------------------------------------------------------- table

enum TableColumnType { text, number, check, choice, dice, relation }

class TableColumn {
  const TableColumn({
    required this.key,
    required this.label,
    this.type = TableColumnType.text,
    this.options = const [],
    this.targets = const [],
    this.locked = false,
  });

  factory TableColumn.fromJson(Map<String, dynamic> m) => TableColumn(
    key: '${m['key']}',
    label: '${m['label'] ?? m['key']}',
    type:
        TableColumnType.values.where((t) => t.name == m['type']).firstOrNull ??
        TableColumnType.text,
    options: [for (final o in (m['options'] as List?) ?? const []) '$o'],
    targets: [for (final o in (m['targets'] as List?) ?? const []) '$o'],
    locked: m['locked'] == true,
  );

  final String key;
  final String label;
  final TableColumnType type;

  /// [TableColumnType.choice]'s options.
  final List<String> options;

  /// [TableColumnType.relation]'s target category slugs (empty = any).
  final List<String> targets;

  /// Fixed rows: the cell is the template's, read-only on cards.
  final bool locked;

  TableColumn copyWith({
    String? label,
    TableColumnType? type,
    List<String>? options,
    List<String>? targets,
    bool? locked,
  }) => TableColumn(
    key: key,
    label: label ?? this.label,
    type: type ?? this.type,
    options: options ?? this.options,
    targets: targets ?? this.targets,
    locked: locked ?? this.locked,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'type': type.name,
    if (options.isNotEmpty) 'options': options,
    if (targets.isNotEmpty) 'targets': targets,
    if (locked) 'locked': true,
  };
}

/// The row id key of a fixed row (template and card).
const tableRowId = '_id';

class TableSpec {
  const TableSpec({
    this.columns = const [],
    this.fixedRows = false,
    this.rows = const [],
  });

  factory TableSpec.of(FieldSchema f) {
    final c = f.styleConfig ?? const {};
    return TableSpec(
      columns: [for (final m in _maps(c['columns'])) TableColumn.fromJson(m)],
      fixedRows: c['fixedRows'] == true,
      rows: _maps(c['rows']),
    );
  }

  final List<TableColumn> columns;
  final bool fixedRows;

  /// The template's rows (used when [fixedRows]), each with a [tableRowId].
  final List<Map<String, dynamic>> rows;

  TableSpec copyWith({
    List<TableColumn>? columns,
    bool? fixedRows,
    List<Map<String, dynamic>>? rows,
  }) => TableSpec(
    columns: columns ?? this.columns,
    fixedRows: fixedRows ?? this.fixedRows,
    rows: rows ?? this.rows,
  );

  Map<String, dynamic> toConfig() => {
    'columns': [for (final c in columns) c.toJson()],
    'fixedRows': fixedRows,
    'rows': rows,
  };
}

/// A row id not used in [rows]: `r1`, `r2`…
String nextTableRowId(List<Map<String, dynamic>> rows) {
  final used = {for (final r in rows) r[tableRowId]};
  var n = rows.length + 1;
  while (used.contains('r$n')) {
    n++;
  }
  return 'r$n';
}

/// A table value's stored rows, in whichever shape it was written: card
/// rows, the SRD proficiency table's `{rows: [...]}`, or a level table's
/// `{level: value}` map (→ `{level, value}` rows, by level).
List<Map<String, dynamic>> storedTableRows(Object? value) {
  if (value is Map && value['rows'] is List) return _maps(value['rows']);
  if (value is List) return _maps(value);
  if (value is Map) {
    final byLevel = [
      for (final e in value.entries)
        if (_int(e.key) != null) (_int(e.key)!, e.value),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return [
      for (final (level, v) in byLevel) {'level': level, 'value': v},
    ];
  }
  return [];
}

/// A stored row is the template row [t]'s by id or, for SRD data that has
/// none, by equal locked cells (a skill's name) — or by that name being
/// [t]'s id: the SRD copy ids each row by its SRD name, so a row renamed in
/// the template still finds its SRD data.
bool _sameRow(TableSpec spec, Map<String, dynamic> t, Map<String, dynamic> s) {
  final id = s[tableRowId];
  if (id != null) return id == t[tableRowId];
  final locked = spec.columns.where((c) => c.locked);
  return locked.isNotEmpty &&
      (locked.every((c) => t[c.key] != null && t[c.key] == s[c.key]) ||
          locked.any((c) => s[c.key] != null && s[c.key] == t[tableRowId]));
}

/// The rows a card shows. Free rows: as stored. Fixed rows: the template's,
/// each overlaid with the card's values for it; locked cells always the
/// template's.
List<Map<String, dynamic>> tableRows(TableSpec spec, Object? value) {
  final stored = storedTableRows(value);
  if (!spec.fixedRows) return stored;
  return [
    for (final t in spec.rows)
      {
        ...t,
        ...?stored.where((s) => _sameRow(spec, t, s)).firstOrNull,
        for (final c in spec.columns)
          if (c.locked) c.key: t[c.key],
        tableRowId: t[tableRowId],
      },
  ];
}

bool _blank(Object? v) => v == null || v == false || v == '';

/// What to store after a card changed [rows] (as [tableRows] gave them).
/// A fixed row keeps only what differs from the template, so a template
/// default still reaches cards that never changed it; stored rows of a
/// template row that is gone stay in the card, hidden (D17).
List<Map<String, dynamic>> tableValue(
  TableSpec spec,
  List<Map<String, dynamic>> rows, {
  Object? previous,
}) {
  if (!spec.fixedRows) return rows;
  final locked = {
    for (final c in spec.columns)
      if (c.locked) c.key,
  };
  final out = <Map<String, dynamic>>[];
  for (final r in rows) {
    final t = spec.rows
        .where((t) => t[tableRowId] == r[tableRowId])
        .firstOrNull;
    if (t == null) continue;
    final diff = {
      for (final e in r.entries)
        if (e.key != tableRowId &&
            !locked.contains(e.key) &&
            !(_blank(e.value) && _blank(t[e.key])) &&
            e.value != t[e.key])
          e.key: e.value,
    };
    if (diff.isNotEmpty) out.add({tableRowId: t[tableRowId], ...diff});
  }
  return [
    ...out,
    for (final s in storedTableRows(previous))
      if (!spec.rows.any((t) => _sameRow(spec, t, s))) s,
  ];
}

// ----------------------------------------------------------- skill table

/// A skill table's card row: the template's name, the row's stat (the
/// template's default, a card may pick another), the two marks and a
/// number — the SRD proficiency table's row keys, so SRD rows read as they
/// are. Stored like a fixed-row [TableSpec] (only what differs).
const _skillColumns = [
  TableColumn(key: 'name', label: 'name', locked: true),
  TableColumn(key: 'ability', label: 'ability'),
  TableColumn(key: 'proficient', label: '', type: TableColumnType.check),
  TableColumn(key: 'expertise', label: '', type: TableColumnType.check),
  TableColumn(key: 'misc', label: '', type: TableColumnType.number),
];

class SkillTableSpec {
  const SkillTableSpec({
    this.rows = const [],
    this.stat,
    this.bonus,
    this.nameEditable = false,
    this.statEditable = true,
  });

  factory SkillTableSpec.of(FieldSchema f) {
    final c = f.styleConfig ?? const {};
    return SkillTableSpec(
      rows: _maps(c['rows']),
      stat: c['stat'] as String?,
      bonus: c['bonus'] as String?,
      nameEditable: c['name_editable'] == true,
      statEditable: c['stat_editable'] != false,
    );
  }

  /// The template's rows: `{_id, name, ability}`.
  final List<Map<String, dynamic>> rows;

  /// The stat table the rows read (null = the category's first).
  final String? stat;

  /// The number field a proficient / expertise mark adds (D&D: the
  /// proficiency bonus); null = none.
  final String? bonus;

  /// Whether a card may rename a row (stored as the row's `label`; the
  /// template's name still matches the row).
  final bool nameEditable;

  /// Whether a card may pick another stat for a row.
  final bool statEditable;

  /// The card rows as a fixed-row table.
  TableSpec get table =>
      TableSpec(columns: _skillColumns, fixedRows: true, rows: rows);

  SkillTableSpec copyWith({
    List<Map<String, dynamic>>? rows,
    String? Function()? stat,
    String? Function()? bonus,
    bool? nameEditable,
    bool? statEditable,
  }) => SkillTableSpec(
    rows: rows ?? this.rows,
    stat: stat == null ? this.stat : stat(),
    bonus: bonus == null ? this.bonus : bonus(),
    nameEditable: nameEditable ?? this.nameEditable,
    statEditable: statEditable ?? this.statEditable,
  );

  Map<String, dynamic> toConfig() => {
    'rows': rows,
    'stat': ?stat,
    'bonus': ?bonus,
    if (nameEditable) 'name_editable': true,
    if (!statEditable) 'stat_editable': false,
  };
}

/// The stat table [spec] reads: its own choice, else the first stat table
/// among [fields] (the card's category).
FieldSchema? skillStatField(SkillTableSpec spec, List<FieldSchema> fields) {
  final tables = fields.where((f) => f.fieldType == FieldType.statTable);
  return spec.stat == null
      ? tables.firstOrNull
      : tables.where((f) => f.fieldKey == spec.stat).firstOrNull;
}

/// The card's bonus for [spec] (0 when none is set or the card left it
/// blank).
int skillBonus(SkillTableSpec spec, Map<String, dynamic> card) =>
    spec.bonus == null ? 0 : _int(card[spec.bonus]) ?? 0;

/// A skill row's total, as the SRD's skill table adds it (D32): the stat's
/// modifier from the card's stat table + the bonus per mark (proficient,
/// expertise) + misc. A row with no stat, or no score for it, adds 0 for
/// the stat.
int skillTotal(
  SkillTableSpec spec,
  Map<String, dynamic> row, {
  required Map<String, dynamic> card,
  required List<FieldSchema> fields,
}) {
  final st = skillStatField(spec, fields);
  final scores = st == null ? null : card[st.fieldKey];
  final score = scores is Map ? _int(scores[row['ability']]) : null;
  final bonus = skillBonus(spec, card);
  return (score == null ? 0 : StatTableSpec.of(st!).modifier(score)) +
      (row['proficient'] == true ? bonus : 0) +
      (row['expertise'] == true ? bonus : 0) +
      (_int(row['misc']) ?? 0);
}

// ------------------------------------------------------- SRD as markdown

/// SRD structured lists a free template shows as markdown (DESIGN §16.2:
/// starting equipment, player choices, subspecies options): a bold title
/// and its prompt, then one bullet per option. [nameOf] names a card ref
/// for an option that has no label of its own.
String structuredListAsMarkdown(
  List<Object?> rows,
  String Function(Object? ref) nameOf,
) {
  final blocks = <String>[];
  for (final r in rows.whereType<Map>()) {
    if (r['name'] != null) {
      blocks.add(
        [
          '**${r['name']}**',
          if ('${r['description'] ?? ''}'.trim().isNotEmpty)
            '${r['description']}'.trim(),
        ].join('\n\n'),
      );
      continue;
    }
    final title = '${r['label'] ?? ''}'.trim();
    final prompt = '${r['prompt'] ?? ''}'.trim();
    final lines = [
      [
        if (title.isNotEmpty) '**$title**',
        if (prompt.isNotEmpty) prompt,
      ].join(' — '),
      for (final o in _maps(r['options'])) '- ${_optionLine(o, nameOf)}',
    ];
    blocks.add(lines.where((l) => l.isNotEmpty).join('\n'));
  }
  return blocks.where((b) => b.isNotEmpty).join('\n\n');
}

String _optionLine(Map<String, dynamic> o, String Function(Object?) nameOf) {
  var text = '${o['label'] ?? ''}'.trim();
  if (text.isEmpty) {
    text = [
      for (final it in _maps(o['items']))
        (_int(it['quantity']) ?? 1) > 1
            ? '${it['quantity']}× ${nameOf(it['ref'])}'
            : nameOf(it['ref']),
      if (o['gold_gp'] != null) '${o['gold_gp']} GP',
    ].join(', ');
  }
  final id = o['option_id'];
  return id == null ? text : '**$id:** $text';
}

// -------------------------------------------------------------- resource

/// What a rest does to a counter (DESIGN §8.3).
enum RestEffect { fill, empty, keep }

enum RestKind { short, long }

RestEffect _effect(Object? v, RestEffect fallback) =>
    RestEffect.values.where((e) => e.name == v).firstOrNull ?? fallback;

/// Resource (DESIGN §8.3): number or boxes, and each rest's effect.
class ResourceSpec {
  const ResourceSpec({
    this.boxes = false,
    this.short = RestEffect.keep,
    this.long = RestEffect.fill,
  });

  factory ResourceSpec.of(FieldSchema f) {
    final c = f.styleConfig ?? const {};
    return ResourceSpec(
      boxes: c['display'] == 'boxes',
      short: _effect(c['short'], RestEffect.keep),
      long: _effect(c['long'], RestEffect.fill),
    );
  }

  final bool boxes;
  final RestEffect short;
  final RestEffect long;

  RestEffect on(RestKind k) => k == RestKind.short ? short : long;

  ResourceSpec copyWith({bool? boxes, RestEffect? short, RestEffect? long}) =>
      ResourceSpec(
        boxes: boxes ?? this.boxes,
        short: short ?? this.short,
        long: long ?? this.long,
      );

  Map<String, dynamic> toConfig() => {
    'display': boxes ? 'boxes' : 'number',
    'short': short.name,
    'long': long.name,
  };
}

typedef ResourceValue = ({int? current, int? max});

/// A resource's card value: `{current, max}`, or the SRD slot's
/// `{count, states}` / `{count, filled}` (count = max, filled = current).
ResourceValue resourceValue(Object? v) {
  if (v is! Map) return (current: null, max: null);
  if (v.containsKey('count')) {
    final states = v['states'];
    return (
      current: states is List
          ? states.where((s) => s == true).length
          : _int(v['filled']),
      max: _int(v['count']),
    );
  }
  return (current: _int(v['current']), max: _int(v['max']));
}

Map<String, dynamic> resourceJson(ResourceValue v) => {
  'current': ?v.current,
  'max': ?v.max,
};

/// A counter after [effect]: fill → max (nothing without one), empty → 0.
int? afterRest(RestEffect effect, int? current, int? max) => switch (effect) {
  RestEffect.fill => max ?? current,
  RestEffect.empty => 0,
  RestEffect.keep => current,
};

// --------------------------------------------------------- combat stats

/// The Combat stats block's keys for HP (DESIGN §8.6): the SRD's, so the
/// encounter keeps reading them (ROADMAP Y5).
const combatHpKey = 'hp';
const combatMaxHpKey = 'max_hp';

enum CombatValueType { number, dice, cards }

/// One value of the block besides HP (DESIGN §8.6).
class CombatValue {
  const CombatValue({
    required this.key,
    required this.label,
    this.type = CombatValueType.number,
    this.encounter = true,
    this.width,
    this.editable = true,
    this.targets = const [],
  });

  factory CombatValue.fromJson(Map<String, dynamic> m) => CombatValue(
    key: '${m['key']}',
    label: '${m['label'] ?? m['key']}',
    type:
        CombatValueType.values.where((t) => t.name == m['type']).firstOrNull ??
        CombatValueType.number,
    encounter: m['encounter'] != false,
    width: _int(m['width']),
    editable: m['editable'] != false,
    targets: [for (final t in (m['targets'] as List?) ?? const []) '$t'],
  );

  final String key;
  final String label;
  final CombatValueType type;

  /// Shown as an encounter column (read in Faz 9).
  final bool encounter;

  /// The encounter column's width; null = the default.
  final int? width;

  /// Number only: the card may change it.
  final bool editable;

  /// Card list only: the target category slugs (empty = any).
  final List<String> targets;

  CombatValue copyWith({
    String? label,
    CombatValueType? type,
    bool? encounter,
    int? Function()? width,
    bool? editable,
    List<String>? targets,
  }) => CombatValue(
    key: key,
    label: label ?? this.label,
    type: type ?? this.type,
    encounter: encounter ?? this.encounter,
    width: width == null ? this.width : width(),
    editable: editable ?? this.editable,
    targets: targets ?? this.targets,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'type': type.name,
    if (!encounter) 'encounter': false,
    'width': ?width,
    if (!editable) 'editable': false,
    if (targets.isNotEmpty) 'targets': targets,
  };
}

/// Combat stats (DESIGN §8.6, D36): HP / Max HP — the one part that cannot
/// go, resting like a resource — and the values the template adds.
class CombatStatsSpec {
  const CombatStatsSpec({
    this.hpLabel = 'HP',
    this.short = RestEffect.keep,
    this.long = RestEffect.fill,
    this.values = const [],
  });

  factory CombatStatsSpec.of(FieldSchema f) {
    final c = f.styleConfig ?? const {};
    return CombatStatsSpec(
      hpLabel: '${c['hp_label'] ?? 'HP'}',
      short: _effect(c['short'], RestEffect.keep),
      long: _effect(c['long'], RestEffect.fill),
      values: [for (final m in _maps(c['values'])) CombatValue.fromJson(m)],
    );
  }

  final String hpLabel;
  final RestEffect short;
  final RestEffect long;
  final List<CombatValue> values;

  RestEffect on(RestKind k) => k == RestKind.short ? short : long;

  /// At most one card list (it feeds the encounter's Conditions).
  bool get hasCards => values.any((v) => v.type == CombatValueType.cards);

  /// A key for a value labelled [label]: never HP's, never a taken one (V3).
  String keyFor(String label) => keyFromLabel(label, [
    combatHpKey,
    combatMaxHpKey,
    ...values.map((v) => v.key),
  ]);

  CombatStatsSpec copyWith({
    String? hpLabel,
    RestEffect? short,
    RestEffect? long,
    List<CombatValue>? values,
  }) => CombatStatsSpec(
    hpLabel: hpLabel ?? this.hpLabel,
    short: short ?? this.short,
    long: long ?? this.long,
    values: values ?? this.values,
  );

  Map<String, dynamic> toConfig() => {
    'hp_label': hpLabel,
    'short': short.name,
    'long': long.name,
    'values': [for (final v in values) v.toJson()],
  };

  /// The built-in `subFields` the encounter reads until Faz 9.
  List<Map<String, String>> get subFields => [
    {'key': combatHpKey, 'label': hpLabel, 'type': 'integer'},
    {'key': combatMaxHpKey, 'label': 'Max $hpLabel', 'type': 'integer'},
    for (final v in values)
      {
        'key': v.key,
        'label': v.label,
        'type': switch (v.type) {
          CombatValueType.number => 'integer',
          CombatValueType.dice => 'dice',
          CombatValueType.cards => 'cards',
        },
      },
  ];

  /// [f] with this spec, `subFields` in step.
  FieldSchema applyTo(FieldSchema f) =>
      f.copyWith(styleConfig: toConfig(), subFields: subFields);
}

/// The free Combat stats block (built-in `combatStats` has no settings).
bool isCombatBlock(FieldSchema f) =>
    f.fieldType == FieldType.combatStats && f.styleConfig != null;

bool _blankValue(Object? v) => v == null || (v is String && v.trim().isEmpty);

/// The block's values on [card] (DESIGN §16.3): as stored, a value the
/// block lacks read from the SRD monster's flat fields — `hp_average` → HP
/// and Max HP, `ac` → AC, `initiative_modifier` → `1d20+N`.
Map<String, dynamic> combatStatsValue(Object? stored, Map<String, dynamic> card) {
  final out = stored is Map
      ? Map<String, dynamic>.from(stored)
      : <String, dynamic>{};
  void fill(String key, Object? v) {
    if (_blankValue(out[key]) && !_blankValue(v)) out[key] = v;
  }

  final hp = _int(card['hp_average']);
  fill(combatHpKey, hp);
  fill(combatMaxHpKey, hp);
  fill('ac', _int(card['ac']));
  final init = _int(card['initiative_modifier']);
  if (init != null) fill('initiative', init < 0 ? '1d20$init' : '1d20+$init');
  return out;
}

/// The number a value of the block holds (stored as int or, after the
/// encounter wrote it, as text).
int? combatNumber(Object? v) => _int(v);

// ------------------------------------------------------------ SRD reads

/// An SRD copy's Speed / CR field reads the built-in `combat_stats` text
/// it came from (DESIGN §16.3): `styleConfig: {srd_read: speed|cr}`.
const srdReadKey = 'srd_read';

/// The leading number of "30 ft." → 30; a CR's "1/2" → 0.5; else null.
num? srdNumber(Object? v) {
  if (v is num) return v;
  final s = '${v ?? ''}'.trim();
  final frac = RegExp(r'^(\d+)\s*/\s*(\d+)').firstMatch(s);
  if (frac != null) {
    final d = int.parse(frac[2]!);
    return d == 0 ? null : int.parse(frac[1]!) / d;
  }
  final n = RegExp(r'^-?\d+(\.\d+)?').firstMatch(s);
  return n == null ? null : num.parse(n[0]!);
}

/// What a free field shows for [card]: the stored value, or what the SRD
/// shape it replaced holds (the combat block's flat fields, Speed / CR's
/// text, a class's features as a Level table — that one reads other cards
/// from [byId]). Fields without settings (the built-in schema) read as
/// stored.
Object? freeFieldValue(
  FieldSchema f,
  Map<String, dynamic> card, {
  Map<String, Entity> byId = const {},
}) {
  final v = card[f.fieldKey];
  final c = f.styleConfig;
  if (c == null) return v;
  if (f.fieldType == FieldType.combatStats) return combatStatsValue(v, card);
  final from = c[srdReadKey];
  if (from is String && srdLevelReads.contains(from)) {
    return isSrdLevelShape(v) ? srdLevelValue(from, v, card, byId) : v;
  }
  if (from is String && _blankValue(v)) {
    final cs = card['combat_stats'];
    final n = cs is Map ? srdNumber(cs[from]) : null;
    if (n == null) return v;
    return f.fieldType == FieldType.integer ? n.toInt() : n.toDouble();
  }
  return v;
}

// ------------------------------------------------------------------ rest

/// What a Short / Long rest writes (DESIGN §12.3): each resource field and
/// the combat block's HP take the rest's effect; nothing else changes.
/// Only changed values are returned.
Map<String, dynamic> restPatch(
  List<FieldSchema> fields,
  Map<String, dynamic> card,
  RestKind kind,
) {
  final out = <String, dynamic>{};
  for (final f in fields) {
    if (f.fieldType == FieldType.resource) {
      final v = resourceValue(card[f.fieldKey]);
      final next = afterRest(ResourceSpec.of(f).on(kind), v.current, v.max);
      if (next != v.current) {
        out[f.fieldKey] = resourceJson((current: next, max: v.max));
      }
    } else if (isCombatBlock(f)) {
      final stats = combatStatsValue(card[f.fieldKey], card);
      final hp = _int(stats[combatHpKey]);
      final next = afterRest(
        CombatStatsSpec.of(f).on(kind),
        hp,
        _int(stats[combatMaxHpKey]),
      );
      if (next != hp) out[f.fieldKey] = {...stats, combatHpKey: next};
    }
  }
  return out;
}
