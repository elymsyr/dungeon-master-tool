// Source ⟷ asset verifier (offline audit tool, phase **T1**).
//
// The engine; `bin/verify_packs.dart` is the CLI over it. It lives here rather
// than in `bin/` so the judgement matrix can be tested in-process — see
// `test/tool/verify_packs_test.dart`, and the rule-table bugs recorded in its
// header for why that gate is not optional.
//
// Fourth sibling of `audit_packs.dart` (are the fields filled?),
// `dupe_census.dart` (should this entity exist?) and `diff_packs.dart` (what did
// my rebuild change?). This one asks the question none of them can:
// **does the shipped value agree with the fixture it claims to come from?**
//
// `docs/open5e_content_audit.md` §3.4 opens with the reason this exists:
// "`audit_packs` says 100%, so the field is right" does not follow. That tool
// counts *presence* — `0`, `false`, a mapper default and a real reading all
// count as filled, and the `⚠ const` marker only fires when a value is identical
// on **every** row of a category corpus-wide. B2 (2026-07-31) proved the point
// from the other side: it fixed a genuinely broken `description` on the only two
// table-bearing classes and *neither* census tool could see the difference,
// because `description` was 100% "filled" before and after.
//
// ## The four verdicts
//
// For every (entity, rule) pair the tool re-reads the fixture row the entity was
// built from and lands on one of four answers:
//
//   ok          the shipped value is the source's value
//   disagree    both sides have a value and they differ      ← a mapping defect
//   absent      the source has a value, the pack does not    ← a mapping hole
//   unsourced   the pack has a value, the source does not    ← a fabrication
//
// (A fifth outcome, "neither side has anything", is the common case and is not
// reported. A sixth, `unverifiable`, is declared per rule with a reason: the
// mapper derived the value from something other than one column, so agreement
// with a column is not the right question.)
//
// **`unsourced` is the one Stage V is waiting for.** Every ⚠ constant in §5 is
// a mapper default masquerading as coverage — `species.creature_type_ref` is the
// literal string `'Humanoid'`, `magic-item.is_cursed` / `is_sentient` are `false`
// and `activation` is `'None'` with no column behind any of them, and
// `monster.ac` falls back to `10`, `hp_dice` to `'1d4'`, `speed_walk_ft` to `30`.
// `audit_packs` shows all of those as ✅ 100%. Here they are counted, one line
// per field, against the rows that actually carry a source value.
//
// ## Why this is not the mapper checking itself
//
// The rules below are a **hand-written restatement** of the field ⟷ column
// contract, read off the fixtures and the schema, not off the mapper. Nothing in
// this file imports `mappers/`, and no rule calls `Normalizer` — a lookup ref is
// compared by case-folded *name*, which asks "did the source's value land in this
// field?" without re-running the canon that decided how to spell it. Where a
// mapper genuinely computes a value from more than one column (`xp` from the CR
// table, `caster_kind` inferred from feature text when `caster_type` is null),
// the rule says `unverifiable` and names the reason rather than pretending a
// column-level check applies.
//
// ## Scope of the rule table
//
// Parent rows only: the categories that map one fixture record to one entity and
// can therefore be matched back by name — `monster`, `spell`, `magic-item`,
// `feat`, `class`, `subclass`, `species`, `subspecies`, `background`. The child
// categories (`creature-action`, `trait`) are deduped by content hash and
// renamed on collision, so they have no stable name → fixture row mapping; they
// are **T3**'s relational gate, not this tool's. `adventuring-gear` is
// synthesised, not imported — it has no fixture at all (that is **B6**).
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'gate.dart' show builtinNameIndex, nameKey;
import 'loaders.dart';
import 'mappers/item.dart' show baseItemName;
import 'mappers/spell.dart' show classTagsFromV2;
import 'sources.dart';

/// Class names a spell's `class_refs` softRef can land on — the mapper's filter
/// (audit L3), restated from the built-in pack rather than copied from it.
final _knownClasses = () {
  final prefix = nameKey('class', '');
  return {
    for (final key in builtinNameIndex())
      if (key.startsWith(prefix)) key.substring(prefix.length),
  };
}();

/// Base-item names a `magic-item.base_item_ref` softRef can land on — the same
/// filter, over the three categories the schema's relation allows (audit L3).
final _knownBaseItems = {
  for (final slug in const ['weapon', 'armor', 'adventuring-gear'])
    for (final key in builtinNameIndex())
      if (key.startsWith(nameKey(slug, '')))
        key.substring(nameKey(slug, '').length),
};

/// Verify every pack in [packDir] against the fixtures under [dataRoot].
///
/// [only] limits the categories checked, [docs] the source-document slugs.
/// [sample] > 0 checks at most that many matched entities per (pack, category);
/// 0 checks all of them. [examples] caps how many worked examples each finding
/// keeps.
VerifyReport verifyPacks({
  required String dataRoot,
  required String packDir,
  Set<String> only = const {},
  Set<String> docs = const {},
  int sample = 0,
  int examples = 2,
}) {
  final byPackage = <String, SourceDoc>{
    for (final d in sourceDocs(dataRoot)) d.packageName: d,
  };
  if (byPackage.isEmpty) {
    throw StateError('no source documents discovered under $dataRoot/v2');
  }

  final report = VerifyReport(examples);
  final packFiles = Directory(packDir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.pkg.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final f in packFiles) {
    final root = jsonDecode(f.readAsStringSync());
    if (root is! Map) continue;
    final packName = root['package_name'] as String? ??
        f.uri.pathSegments.last.replaceAll('.pkg.json', '');
    final doc = byPackage[packName];
    if (doc == null) {
      report.packsWithoutSource.add(packName);
      continue;
    }
    if (docs.isNotEmpty && !docs.contains(doc.slug)) continue;

    _verifyPack(
      report: report,
      packName: packName,
      doc: doc,
      entitiesById: {
        for (final e in ((root['entities'] as Map?) ?? const {}).entries)
          if (e.value is Map)
            '${e.key}': (e.value as Map).cast<String, dynamic>(),
      },
      only: only,
      sample: sample,
    );
  }
  return report;
}

// ── Per-pack verification ──────────────────────────────────────────────────

/// Category slug → the fixture file its parent rows live in, and (for the two
/// self-parenting files) which half of that file it owns.
class _Category {
  const _Category(this.slug, this.file, {this.parentColumn, this.wantChild});

  final String slug;
  final String file;

  /// `Species.subspecies_of` / `CharacterClass.subclass_of`: one fixture file
  /// feeds two categories, split on whether this column is set.
  final String? parentColumn;
  final bool? wantChild;

  bool owns(Fixture row) {
    if (parentColumn == null) return true;
    final v = row[parentColumn!];
    final isChild = v != null && v.toString().trim().isNotEmpty;
    return isChild == wantChild;
  }
}

const _categories = [
  _Category('monster', 'Creature.json'),
  _Category('spell', 'Spell.json'),
  _Category('magic-item', 'MagicItem.json'),
  _Category('feat', 'Feat.json'),
  _Category('class', 'CharacterClass.json',
      parentColumn: 'subclass_of', wantChild: false),
  _Category('subclass', 'CharacterClass.json',
      parentColumn: 'subclass_of', wantChild: true),
  _Category('species', 'Species.json',
      parentColumn: 'subspecies_of', wantChild: false),
  _Category('subspecies', 'Species.json',
      parentColumn: 'subspecies_of', wantChild: true),
  _Category('background', 'Background.json'),
];

void _verifyPack({
  required VerifyReport report,
  required String packName,
  required SourceDoc doc,
  required Map<String, Map<String, dynamic>> entitiesById,
  required Set<String> only,
  required int sample,
}) {
  // Bucket the pack's entities by category once, and index every entity id to
  // its name: a pack-local Tier-0 row seeded by **B9** (`Titanic`, `Void
  // Speech`) is referenced by resolved uuid rather than by a `{_lookup, name}`
  // placeholder, so a name comparison has to be able to follow the id.
  final bySlug = <String, List<Map<String, dynamic>>>{};
  final idNames = <String, String>{};
  for (final e in entitiesById.entries) {
    final raw = e.value;
    idNames[e.key] = (raw['name'] as String?)?.trim() ?? '';
    final slug = raw['type']?.toString();
    if (slug == null) continue;
    (bySlug[slug] ??= []).add(raw);
  }

  for (final cat in _categories) {
    if (only.isNotEmpty && !only.contains(cat.slug)) continue;
    final ents = bySlug[cat.slug];
    if (ents == null || ents.isEmpty) continue;
    final rules = _rules[cat.slug];
    if (rules == null) continue;

    final rows = loadFixtures(doc.v2File(cat.file)).where(cat.owns).toList();
    final index = _indexByName(rows);

    var matched = 0;
    var checked = 0;
    for (final e in ents) {
      final name = (e['name'] as String?)?.trim() ?? '';
      final row = index[_matchKey(name)];
      if (row == null) {
        report.unmatched(packName, cat.slug, name);
        continue;
      }
      matched++;
      if (sample > 0 && checked >= sample) continue;
      checked++;

      final attrs =
          ((e['attributes'] as Map?) ?? const {}).cast<String, dynamic>();
      for (final rule in rules) {
        report._judge(
          slug: cat.slug,
          rule: rule,
          shipped: (rule.read ?? (a) => a[rule.label])(attrs),
          expect: rule.expect(row),
          label: '$packName/$name',
          idNames: idNames,
        );
      }
    }
    report.coverage(packName, cat.slug, ents.length, matched, checked);
  }
}

/// Fixture rows indexed by match key. Later rows never overwrite earlier ones —
/// a duplicate name inside one document is a `dupe_census` question, and taking
/// the first keeps the mapping deterministic.
Map<String, Fixture> _indexByName(List<Fixture> rows) {
  final out = <String, Fixture>{};
  for (final r in rows) {
    final n = (r['name'] as String?)?.trim() ?? '';
    if (n.isEmpty) continue;
    out.putIfAbsent(_matchKey(n), () => r);
  }
  return out;
}

/// Entity name ⟷ fixture name, folded far enough to survive the two rewrites
/// the importer performs on a *name*: the `"Npc: "` prefix strip and the
/// small-word re-casing that follows it. Deliberately lenient — this decides
/// *which* fixture row to check against, not whether the check passes.
String _matchKey(String raw) {
  var s = raw.trim().toLowerCase();
  s = s.replaceFirst(RegExp(r'^npc\s*:\s*'), '');
  return s.replaceAll(RegExp(r'\s+'), ' ');
}

// ── Expectations ───────────────────────────────────────────────────────────

enum _Shape {
  /// Compare as a JSON-encoded scalar, with `int`/`double` folded together.
  scalar,

  /// Shipped is a `{_lookup|_ref, name}` map; compare its `name` case-folded.
  refName,

  /// As [refName], but the source spelling has more than one legitimate landing
  /// name: an upstream synonym (a5e's `transformation` = Transmutation) or a
  /// plural (`scroll` → the app's "Scrolls" category). Matching any accepted
  /// form is agreement — this asks whether the source's value landed in the
  /// field, not how the canon chose to spell it.
  refNameAny,

  /// Shipped is a list of such maps; compare the name multiset, case-folded.
  refNames,

  /// The mapper does not read one column for this field; say so and why.
  unverifiable,
}

class _Expect {
  const _Expect(this.shape, this.value, {this.reason});

  final _Shape shape;
  final Object? value;
  final String? reason;

  /// The source carries nothing for this field.
  static const nothing = _Expect(_Shape.scalar, null);

  static _Expect scalar(Object? v) => _Expect(_Shape.scalar, v);

  static _Expect refName(Object? raw) => _Expect(_Shape.refName, raw);

  static _Expect refNameAny(Iterable<Object?> raws) => _Expect(
      _Shape.refNameAny,
      raws.where((e) => _str(e).isNotEmpty).toList());

  static _Expect refNames(Iterable<Object?>? raws) => _Expect(
      _Shape.refNames, raws?.where((e) => _str(e).isNotEmpty).toList() ?? const []);

  static _Expect why(String reason) =>
      _Expect(_Shape.unverifiable, null, reason: reason);

  bool get hasValue {
    switch (shape) {
      case _Shape.unverifiable:
        return false;
      case _Shape.scalar:
        return _filled(value);
      case _Shape.refName:
        return _str(value).isNotEmpty;
      case _Shape.refNameAny:
      case _Shape.refNames:
        return (value as List).isNotEmpty;
    }
  }
}

/// One field's contract, restated from the fixture side.
class _Rule {
  const _Rule(this.label, this.columns, this.expect, {this.read});

  /// Report label — the attribute key, or `key.subkey` when [read] digs in.
  final String label;

  /// The fixture column(s) this field is supposed to come from. Reported so a
  /// finding names both sides.
  final List<String> columns;

  final _Expect Function(Fixture row) expect;

  /// Pull the shipped value out of `attributes`. Defaults to `attrs[label]`.
  final Object? Function(Map<String, dynamic> attrs)? read;
}

// ── The rule table ─────────────────────────────────────────────────────────

/// Read a nested map key out of a shipped attribute (`stat_block.STR`).
Object? Function(Map<String, dynamic>) _sub(String key, String inner) =>
    (a) => (a[key] as Map?)?[inner];

/// Read one `senses` entry's range (`[{sense: Darkvision, range_ft: 60}]`).
Object? Function(Map<String, dynamic>) _sense(String sense) => (a) {
      final list = a['senses'];
      if (list is! List) return null;
      for (final s in list) {
        if (s is Map && s['sense'] == sense) return s['range_ft'];
      }
      return null;
    };

/// A positive-int column: the mappers write speeds/senses/ranges only when the
/// source value is `> 0`, so a `0` upstream is an agreed absence, not a hole.
_Expect _positive(Object? v) {
  final n = _num(v);
  return (n == null || n <= 0) ? _Expect.nothing : _Expect.scalar(n.round());
}

_Expect _int(Object? v) {
  final n = _num(v);
  return n == null ? _Expect.nothing : _Expect.scalar(n.round());
}

_Expect _text(Object? v) {
  final s = _str(v);
  return s.isEmpty ? _Expect.nothing : _Expect.scalar(s);
}

const _abilityColumns = {
  'STR': 'ability_score_strength',
  'DEX': 'ability_score_dexterity',
  'CON': 'ability_score_constitution',
  'INT': 'ability_score_intelligence',
  'WIS': 'ability_score_wisdom',
  'CHA': 'ability_score_charisma',
};

const _senseColumns = {
  'Darkvision': 'darkvision_range',
  'Blindsight': 'blindsight_range',
  'Tremorsense': 'tremorsense_range',
  'Truesight': 'truesight_range',
};

final Map<String, List<_Rule>> _rules = {
  'monster': [
    _Rule('ac', ['armor_class'], (r) => _int(r['armor_class'])),
    _Rule('ac_note', ['armor_detail'], (r) => _text(r['armor_detail'])),
    _Rule('hp_average', ['hit_points'], (r) => _int(r['hit_points'])),
    _Rule('hp_dice', ['hit_dice'], (r) => _text(r['hit_dice'])),
    _Rule('speed_walk_ft', ['walk'], (r) => _int(r['walk'])),
    _Rule('speed_burrow_ft', ['burrow'], (r) => _positive(r['burrow'])),
    _Rule('speed_climb_ft', ['climb'], (r) => _positive(r['climb'])),
    _Rule('speed_fly_ft', ['fly'], (r) => _positive(r['fly'])),
    _Rule('speed_swim_ft', ['swim'], (r) => _positive(r['swim'])),
    _Rule('can_hover', ['hover'],
        (r) => r['hover'] == true ? _Expect.scalar(true) : _Expect.nothing),
    _Rule('cr', ['challenge_rating'], (r) => _cr(r['challenge_rating'])),
    // `xp` and `proficiency_bonus` fall back to CR-derived tables when the
    // column is null, so the fallback half is not a column-level question.
    _Rule('xp', ['experience_points_integer'], (r) {
      final v = r['experience_points_integer'];
      return v == null
          ? _Expect.why('derived from the CR→XP table when the column is null')
          : _int(v);
    }),
    _Rule('proficiency_bonus', ['proficiency_bonus'], (r) {
      final v = r['proficiency_bonus'];
      return v == null
          ? _Expect.why('derived from CR when the column is null')
          : _int(v);
    }),
    _Rule('passive_perception', ['passive_perception'], (r) {
      final v = r['passive_perception'];
      return v == null
          ? _Expect.why('derived from WIS when the column is null')
          : _int(v);
    }),
    _Rule('initiative_modifier', ['initiative_bonus'], (r) {
      final v = r['initiative_bonus'];
      return v == null
          ? _Expect.why('derived from DEX when the column is null')
          : _int(v);
    }),
    for (final e in _abilityColumns.entries)
      _Rule('stat_block.${e.key}', [e.value], (r) => _int(r[e.value]),
          read: _sub('stat_block', e.key)),
    _Rule('size_ref', ['size'], (r) => _Expect.refName(r['size'])),
    // "humanoid (elf)" → type `humanoid`, tags_line `(elf)`.
    _Rule('creature_type_ref', ['type'],
        (r) => _Expect.refName(_typeBase(r['type']))),
    _Rule('tags_line', ['type'], (r) => _text(_typeTag(r['type']))),
    _Rule('alignment_ref', ['alignment'],
        (r) => _Expect.refName(r['alignment'])),
    _Rule('telepathy_ft', ['telepathy_range'],
        (r) => _positive(r['telepathy_range'])),
    for (final e in _senseColumns.entries)
      _Rule('senses[${e.key}]', [e.value], (r) => _positive(r[e.value]),
          read: _sense(e.key)),
    _Rule('language_refs', ['languages'],
        (r) => _Expect.refNames(r['languages'] as List?)),
    _Rule('resistance_refs', ['damage_resistances'],
        (r) => _Expect.refNames(r['damage_resistances'] as List?)),
    _Rule('vulnerability_refs', ['damage_vulnerabilities'],
        (r) => _Expect.refNames(r['damage_vulnerabilities'] as List?)),
    _Rule('damage_immunity_refs', ['damage_immunities'],
        (r) => _Expect.refNames(r['damage_immunities'] as List?)),
    _Rule('condition_immunity_refs', ['condition_immunities'],
        (r) => _Expect.refNames(r['condition_immunities'] as List?)),
    _Rule('legendary_action_uses', const [],
        (r) => _Expect.why('Open5e ships no count; the mapper writes the '
            'SRD default of 3 whenever a legendary action exists')),
  ],
  'spell': [
    _Rule('level', ['level'], (r) => _int(r['level'])),
    // a5e calls transmutation "transformation"; both are the same school.
    _Rule('school_ref', ['school'], (r) {
      final s = _str(r['school']).toLowerCase();
      return _Expect.refNameAny(
          [s, if (s == 'transformation') 'transmutation']);
    }),
    _Rule('is_ritual', ['ritual'], (r) => _Expect.scalar(r['ritual'] == true)),
    _Rule('requires_concentration', ['concentration'],
        (r) => _Expect.scalar(r['concentration'] == true)),
    _Rule('save_ability_ref', ['saving_throw_ability'],
        (r) => _Expect.refName(r['saving_throw_ability'])),
    _Rule('damage_type_refs', ['damage_types'],
        (r) => _Expect.refNames(r['damage_types'] as List?)),
    _Rule('material_description', ['material_specified'],
        (r) => _text(r['material_specified'])),
    _Rule('material_consumed', ['material_specified', 'material_consumed'], (r) {
      if (_str(r['material_specified']).isEmpty) return _Expect.nothing;
      return _Expect.scalar(r['material_consumed'] == true);
    }),
    _Rule('material_cost_gp', ['material_cost'], (r) {
      if (_str(r['material_specified']).isEmpty) return _Expect.nothing;
      final n = _num(r['material_cost']);
      return n == null ? _Expect.nothing : _Expect.scalar(n);
    }),
    // Audit **B4**.
    _Rule('area_shape_ref', ['shape_type'],
        (r) => _Expect.refName(r['shape_type'])),
    _Rule('area_size_ft', ['shape_size', 'shape_type'], (r) {
      if (_str(r['shape_type']).isEmpty) return _Expect.nothing;
      return _positive(r['shape_size']);
    }),
    _Rule('reaction_trigger', ['reaction_condition'], (r) {
      final s = _str(r['reaction_condition']);
      return s.isEmpty
          ? _Expect.nothing
          : _Expect.why('the casting-time lead-in is stripped and the '
              'remainder made a sentence, so it is not the column verbatim');
    }),
    _Rule('components', ['verbal', 'somatic', 'material'],
        (r) => _Expect.refNames([
              if (r['verbal'] == true) 'Verbal',
              if (r['somatic'] == true) 'Somatic',
              if (r['material'] == true) 'Material',
            ])),
    _Rule('range_ft', ['range', 'range_unit', 'range_text'], (r) {
      final unit = _str(r['range_unit']).toLowerCase();
      final v = _num(r['range']);
      if (unit == 'feet' || unit == 'ft') {
        return v == null ? _Expect.nothing : _Expect.scalar(v.round());
      }
      if (unit == 'miles' || unit == 'mi') {
        return v == null ? _Expect.nothing : _Expect.scalar((v * 5280).round());
      }
      return _Expect.why('no numeric range column; parsed out of `range_text`');
    }),
    _Rule('casting_time_amount', ['casting_time'], (r) {
      final m = RegExp(r'^(\d+)').firstMatch(_str(r['casting_time']));
      // The mapper's default of 1 for an unprefixed casting time ("action") is
      // the SRD reading, not a column value.
      return m == null
          ? _Expect.why('unprefixed casting time; 1 is implied, not written')
          : _Expect.scalar(int.parse(m.group(1)!));
    }),
    _Rule('attack_type', ['attack_roll'], (r) => r['attack_roll'] == true
        ? _Expect.why('melee/ranged is inferred from the range, not a column')
        : _Expect.nothing),
    // Audit **L3**. Only the built-in classes are emitted as refs — a tag
    // naming a class no pack ships (Artificer, Herald) would dangle — so the
    // expectation is filtered the same way.
    _Rule('class_refs', ['classes'], (r) {
      final cs = (r['classes'] as List?)?.cast<String>() ?? const [];
      if (cs.isEmpty) {
        return _Expect.why('v2 leaves `classes` empty for most 3rd-party '
            'documents; the class list is recovered from the v1 `dnd_class` '
            'column, which this tool does not read');
      }
      return _Expect.refNames(
          classTagsFromV2(cs).where(_knownClasses.contains));
    }),
  ],
  'magic-item': [
    _Rule('rarity_ref', ['rarity'], (r) => _Expect.refName(r['rarity'])),
    // Audit **L3**. Two columns, one link; a base item with no built-in card
    // gets no ref, so the expectation is filtered the same way.
    _Rule('base_item_ref', ['weapon', 'armor'], (r) {
      final base = baseItemName(r['weapon'] ?? r['armor']);
      return base != null && _knownBaseItems.contains(base)
          ? _Expect.refName(base)
          : _Expect.nothing;
    }),
    _Rule('magic_category_ref', ['category'], (r) {
      // Two folds the comparison has to expect: the app's nine categories are
      // coarser than Open5e's (shield→Armor, ammunition→Weapons), and it names
      // them in the plural ("scroll" → "Scrolls").
      final raw = _str(r['category']).toLowerCase();
      const coarse = {'shield': 'armor', 'ammunition': 'weapon'};
      final base = coarse[raw] ?? raw;
      return _Expect.refNameAny([base, '${base}s']);
    }),
    _Rule('requires_attunement', ['requires_attunement'],
        (r) => _Expect.scalar(r['requires_attunement'] == true)),
    _Rule('attunement_prereq', ['attunement_detail'], (r) {
      if (r['requires_attunement'] != true) return _Expect.nothing;
      return _text(r['attunement_detail']);
    }),
    _Rule('cost_gp', ['cost'], (r) => _positive(r['cost'])),
    _Rule('weight_lb', ['weight'], (r) => _positive(r['weight'])),
    _Rule('is_cursed', const [], (r) => _Expect.nothing),
    _Rule('is_sentient', const [], (r) => _Expect.nothing),
    _Rule('activation', const [], (r) => _Expect.nothing),
  ],
  'feat': [
    _Rule('category_ref', ['type'], (r) => _Expect.refName(r['type'])),
    _Rule('prerequisite', ['prerequisite'], (r) {
      final s = _str(r['prerequisite']);
      if (s.isEmpty) return _Expect.nothing;
      // "*N/A*", "N/A", "-", "None" are not gates; the mapper drops them.
      final core = s.replaceAll(RegExp(r'[*\s]'), '').toLowerCase();
      if (const {'n/a', 'na', '-', '—', 'none', ''}.contains(core)) {
        return _Expect.nothing;
      }
      return _Expect.scalar(s);
    }),
    _Rule('repeatable', const [], (r) => _Expect.nothing),
  ],
  'class': [
    _Rule('hit_die', ['hit_dice'], (r) => _hitDie(r['hit_dice'])),
    _Rule('saving_throw_refs', ['saving_throws'],
        (r) => _Expect.refNames(_abilities(r['saving_throws'] as List?))),
    _Rule('primary_ability_ref', ['primary_abilities'], (r) {
      final list = _abilities(r['primary_abilities'] as List?);
      return _Expect.refName(list.isEmpty ? null : list.first);
    }),
    _Rule('caster_kind', ['caster_type'], (r) {
      final s = _str(r['caster_type']);
      return s.isEmpty
          ? _Expect.why('Open5e leaves `caster_type` null for the whole '
              'SRD-2014 set; the mapper infers it from the spellcasting '
              'features instead')
          : _Expect.why('`caster_type` is an enum folded onto the app\'s own '
              'caster-kind names, not copied');
    }),
  ],
  'subclass': [
    _Rule('hit_die', ['hit_dice'], (r) => _hitDie(r['hit_dice'])),
  ],
  'species': [
    _Rule('creature_type_ref', const [], (r) => _Expect.nothing),
    _Rule('size_ref', const [],
        (r) => _Expect.why('Species.json carries no size column; the value is '
            'parsed out of the `Size` trait row (audit B3)')),
    _Rule('speed_ft', const [],
        (r) => _Expect.why('parsed out of the `Speed` trait row (audit B3)')),
  ],
  'subspecies': [
    _Rule('creature_type_ref', const [], (r) => _Expect.nothing),
    _Rule('parent_species_ref', ['subspecies_of'],
        (r) => _Expect.refName(_lastSegment(_str(r['subspecies_of'])))),
  ],
  'background': [],
};

/// `"D10"` / `"1d10"` → `10`. Upstream writes the die capitalised and without a
/// count on every class row in the snapshot.
_Expect _hitDie(Object? raw) {
  final m = RegExp(r'd(\d+)', caseSensitive: false).firstMatch(_str(raw));
  return m == null ? _Expect.nothing : _Expect.scalar(int.parse(m.group(1)!));
}

/// Upstream writes class abilities as three-letter codes (`['wis','con']`).
const _abilityNames = {
  'str': 'Strength',
  'dex': 'Dexterity',
  'con': 'Constitution',
  'int': 'Intelligence',
  'wis': 'Wisdom',
  'cha': 'Charisma',
};

List<String> _abilities(List? raw) => [
      for (final v in raw ?? const [])
        if (_str(v).isNotEmpty)
          _abilityNames[_str(v).toLowerCase()] ?? _str(v),
    ];

/// `"humanoid (elf)"` → `humanoid`.
String _typeBase(Object? raw) {
  final s = _str(raw);
  if (s.isEmpty) return '';
  final m = RegExp(r'^([^(]+?)\s*(\(.*\))?$').firstMatch(s);
  return (m?.group(1) ?? s).trim();
}

/// `"humanoid (elf)"` → `(elf)`.
String _typeTag(Object? raw) {
  final s = _str(raw);
  if (s.isEmpty) return '';
  return RegExp(r'^[^(]+?\s*(\(.*\))$').firstMatch(s)?.group(1) ?? '';
}

/// `"kobold-press_tob_goblin"` / `"srd-2014_elf"` → the trailing segment.
String _lastSegment(String s) {
  final i = s.lastIndexOf('_');
  return i < 0 ? s : s.substring(i + 1);
}

/// `0.5` → `"1/2"`. The app stores CR as the printed fraction.
_Expect _cr(Object? raw) {
  final d = _num(raw);
  if (d == null) return _Expect.nothing;
  if (d == 0) return _Expect.scalar('0');
  if ((d - 0.125).abs() < 0.01) return _Expect.scalar('1/8');
  if ((d - 0.25).abs() < 0.01) return _Expect.scalar('1/4');
  if ((d - 0.5).abs() < 0.01) return _Expect.scalar('1/2');
  return _Expect.scalar(d.round().toString());
}

// ── Judging ────────────────────────────────────────────────────────────────

enum Verdict { ok, disagree, absent, unsourced, unverifiable }

class _Bucket {
  int count = 0;
  final examples = <String>[];

  void record(String example, int limit) {
    count++;
    if (examples.length < limit) examples.add(example);
  }
}

class VerifyReport {
  VerifyReport(this.examples);

  final int examples;

  /// `slug|label|verdict` → bucket.
  final buckets = <String, _Bucket>{};

  /// `slug|label` → the columns the rule names (for the report).
  final columns = <String, List<String>>{};

  /// `slug|label` → why a rule is unverifiable (first reason wins).
  final reasons = <String, String>{};

  final totals = <Verdict, int>{for (final v in Verdict.values) v: 0};

  /// `pack|slug` → (entities, matched, checked).
  final coverageRows = <String, List<int>>{};

  /// `pack|slug` → unmatched entity names (capped).
  final unmatchedNames = <String, List<String>>{};
  final unmatchedCount = <String, int>{};

  final packsWithoutSource = <String>[];

  // ── Queries (the test's view; the printers use the raw maps) ─────────────

  /// How many values landed on [v], optionally narrowed to one category and
  /// field. `ok` is counted but never bucketed, so it is only available in the
  /// unnarrowed form.
  int count(Verdict v, {String? slug, String? field}) {
    if (slug == null && field == null) return totals[v]!;
    var n = 0;
    buckets.forEach((key, b) {
      final p = key.split('|');
      if (p[2] != v.name) return;
      if (slug != null && p[0] != slug) return;
      if (field != null && p[1] != field) return;
      n += b.count;
    });
    return n;
  }

  /// The worked examples recorded for one finding, in encounter order.
  List<String> examplesFor(Verdict v, String slug, String field) =>
      buckets['$slug|$field|${v.name}']?.examples ?? const [];

  /// Why a rule declared itself unverifiable (empty when it never did).
  String reasonFor(String slug, String field) => reasons['$slug|$field'] ?? '';

  /// Entity names in [pack]/[slug] that matched no fixture row (capped at
  /// `examples`); [unmatchedCount] carries the full number.
  List<String> unmatchedIn(String pack, String slug) =>
      unmatchedNames['$pack|$slug'] ?? const [];

  void coverage(String pack, String slug, int total, int matched, int checked) {
    coverageRows['$pack|$slug'] = [total, matched, checked];
  }

  void unmatched(String pack, String slug, String name) {
    final k = '$pack|$slug';
    unmatchedCount[k] = (unmatchedCount[k] ?? 0) + 1;
    final list = unmatchedNames[k] ??= [];
    if (list.length < examples) list.add(name);
  }

  void _judge({
    required String slug,
    required _Rule rule,
    required Object? shipped,
    required _Expect expect,
    required String label,
    required Map<String, String> idNames,
  }) {
    columns['$slug|${rule.label}'] = rule.columns;

    if (expect.shape == _Shape.unverifiable) {
      reasons.putIfAbsent('$slug|${rule.label}', () => expect.reason ?? '');
      _bump(slug, rule.label, Verdict.unverifiable, label, null, null);
      return;
    }

    final hasShipped = _filled(shipped);
    if (!hasShipped && !expect.hasValue) return; // agreed absence — not news.
    if (!hasShipped) {
      _bump(slug, rule.label, Verdict.absent, label, null, expect.value);
      return;
    }
    if (!expect.hasValue) {
      _bump(slug, rule.label, Verdict.unsourced, label, shipped, null);
      return;
    }
    _bump(slug, rule.label, _compare(shipped, expect, idNames), label, shipped,
        expect.value);
  }

  void _bump(String slug, String key, Verdict v, String label, Object? got,
      Object? want) {
    totals[v] = totals[v]! + 1;
    if (v == Verdict.ok) return; // counted, never exemplified
    final b = buckets['$slug|$key|${v.name}'] ??= _Bucket();
    final detail = switch (v) {
      Verdict.absent => _filled(got)
          ? 'pack ${_short(got)} drops part of source ${_short(want)}'
          : 'source ${_short(want)}, pack (absent)',
      Verdict.unsourced => 'pack ${_short(got)}, source (absent)',
      Verdict.disagree => 'pack ${_short(got)} ≠ source ${_short(want)}',
      _ => '',
    };
    b.record(detail.isEmpty ? label : '$label: $detail', examples);
  }

  // ── Output ──────────────────────────────────────────────────────────────

  List<String> _sortedKeys() {
    final keys = buckets.keys.toList();
    keys.sort((a, b) {
      final va = _verdictOf(a).index, vb = _verdictOf(b).index;
      if (va != vb) return va.compareTo(vb);
      final c = buckets[b]!.count.compareTo(buckets[a]!.count);
      return c != 0 ? c : a.compareTo(b);
    });
    return keys;
  }

  Verdict _verdictOf(String key) =>
      Verdict.values.firstWhere((v) => v.name == key.split('|').last);

  void printPlain(String dataRoot, String packDir) {
    print('Source ⟷ asset verification (T1)');
    print('  source: $dataRoot');
    print('  packs:  $packDir');

    print('\n1. Match coverage (entities matched to a fixture row)');
    for (final e in coverageRows.entries) {
      final parts = e.key.split('|');
      final v = e.value;
      final miss = v[0] - v[1];
      final sampled = v[2] < v[1] ? '  [checked ${v[2]}]' : '';
      print('  ${parts[0].padRight(26)} ${parts[1].padRight(12)} '
          '${v[1]}/${v[0]}${miss > 0 ? "   $miss unmatched" : ""}$sampled');
      if (miss > 0) {
        final names = unmatchedNames[e.key] ?? const [];
        if (names.isNotEmpty) print('        e.g. ${names.join(", ")}');
      }
    }
    if (packsWithoutSource.isNotEmpty) {
      print('  packs with no source document (skipped): '
          '${packsWithoutSource.join(", ")}');
    }

    print('\n2. Verdict totals');
    for (final v in Verdict.values) {
      print('  ${v.name.padRight(13)} ${totals[v]}');
    }

    print('\n3. Findings (category | field | verdict → count)');
    if (buckets.isEmpty) {
      print('  none — every checked value agrees with its fixture column.');
    } else {
      for (final key in _sortedKeys()) {
        final b = buckets[key]!;
        final p = key.split('|');
        final cols = columns['${p[0]}|${p[1]}'] ?? const [];
        final from = cols.isEmpty ? 'no column' : cols.join(' + ');
        print('  ${b.count.toString().padLeft(6)}  '
            '${p[2].padRight(12)} ${p[0]} · ${p[1]}   ($from)');
        final why = reasons['${p[0]}|${p[1]}'];
        if (why != null && why.isNotEmpty) {
          print('          — $why');
        }
        for (final ex in b.examples) {
          print('          e.g. $ex');
        }
      }
    }
  }

  void printMarkdown(String dataRoot, String packDir) {
    print('### Source ⟷ asset verification (T1) — `$dataRoot` → `$packDir`\n');
    print('| Verdict | Count |');
    print('|---|--:|');
    for (final v in Verdict.values) {
      print('| `${v.name}` | ${totals[v]} |');
    }
    print('');
    print('| Pack | Category | Matched | Unmatched |');
    print('|---|---|--:|--:|');
    for (final e in coverageRows.entries) {
      final p = e.key.split('|');
      final v = e.value;
      print('| `${p[0]}` | `${p[1]}` | ${v[1]}/${v[0]} | ${v[0] - v[1]} |');
    }
    print('');
    if (buckets.isEmpty) {
      print('No disagreements, holes or unsourced values.\n');
      return;
    }
    print('| Verdict | Category | Field | Source column | Count | Example |');
    print('|---|---|---|---|--:|---|');
    for (final key in _sortedKeys()) {
      final b = buckets[key]!;
      final p = key.split('|');
      final cols = columns['${p[0]}|${p[1]}'] ?? const [];
      final ex = b.examples.isEmpty
          ? (reasons['${p[0]}|${p[1]}'] ?? '')
          : b.examples.first;
      print('| ${p[2]} | `${p[0]}` | `${p[1]}` | '
          '${cols.isEmpty ? "—" : cols.map((c) => "`$c`").join(", ")} | '
          '${b.count} | ${ex.replaceAll("|", "\\|")} |');
    }
    print('');
  }
}

// ── Value comparison ───────────────────────────────────────────────────────

/// Both sides carry a value; decide which of the three non-trivial verdicts
/// applies. A list is the interesting case: the mapper **drops** a member the
/// canon does not know (it lands in `unmapped_report.json`), so a shipped list
/// that is a strict subset of the source's is a hole, not a wrong value — it is
/// reported as `absent`, once, with the missing members named.
Verdict _compare(Object? shipped, _Expect e, Map<String, String> idNames) {
  switch (e.shape) {
    case _Shape.unverifiable:
      return Verdict.ok;
    case _Shape.scalar:
      return _sameScalar(shipped, e.value) ? Verdict.ok : Verdict.disagree;
    case _Shape.refName:
      return _fold(_refName(shipped, idNames)) == _fold(_str(e.value))
          ? Verdict.ok
          : Verdict.disagree;
    case _Shape.refNameAny:
      final got = _fold(_refName(shipped, idNames));
      return (e.value as List).any((v) => _fold(_str(v)) == got)
          ? Verdict.ok
          : Verdict.disagree;
    case _Shape.refNames:
      final got = <String>{
        for (final v in shipped is List ? shipped : const [])
          if (_fold(_refName(v, idNames)).isNotEmpty)
            _fold(_refName(v, idNames)),
      };
      final want = <String>{
        for (final v in e.value as List)
          if (_fold(_str(v)).isNotEmpty) _fold(_str(v)),
      };
      if (got.length == want.length && want.containsAll(got)) return Verdict.ok;
      // Anything the pack ships that the source never listed is a real
      // disagreement; anything only the source has is a dropped value.
      return got.difference(want).isNotEmpty
          ? Verdict.disagree
          : Verdict.absent;
  }
}

bool _sameScalar(Object? a, Object? b) {
  if (a is num && b is num) return (a.toDouble() - b.toDouble()).abs() < 1e-9;
  if (a is String && b is String) return a.trim() == b.trim();
  return jsonEncode(a) == jsonEncode(b);
}

/// The `name` of a `{_lookup|_ref, name}` map, the name behind a resolved
/// in-pack id, or the string itself.
String _refName(Object? v, Map<String, String> idNames) {
  if (v is Map) return _str(v['name']);
  final s = _str(v);
  return idNames[s] ?? s;
}

/// Case-fold a lookup name for comparison: the canon title-cases, turns
/// `_`/`-` into spaces and restores punctuation the slug dropped, so
/// `"neutral good"`/`"Neutral Good"` and `"thieves-cant"`/`"Thieves' Cant"` are
/// each one value.
String _fold(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"['’.,]"), '')
    .replaceAll(RegExp(r'[_\-]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _str(Object? v) => v == null ? '' : v.toString().trim();

num? _num(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  return null;
}

/// Same definition `audit_packs.dart` uses: non-null, not an empty
/// string/list/map. `0` and `false` count as filled — the mapper wrote them.
bool _filled(Object? v) {
  if (v == null) return false;
  if (v is String) return v.trim().isNotEmpty;
  if (v is Iterable) return v.isNotEmpty;
  if (v is Map) return v.isNotEmpty;
  return true;
}

String _short(Object? v) {
  if (v == null) return '(absent)';
  var s = v is String ? v : jsonEncode(v);
  s = s.replaceAll('\n', '⏎');
  return s.length <= 48 ? s : '${s.substring(0, 45)}…';
}
