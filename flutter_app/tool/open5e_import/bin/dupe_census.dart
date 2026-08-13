// Bundled-pack duplication census (offline audit tool).
//
//   dart run tool/open5e_import/bin/dupe_census.dart [--packs assets/open5e_packs]
//                                                    [--only trait,monster,...]
//                                                    [--markdown]
//                                                    [--list <slug>]
//
// Sibling of `audit_packs.dart`. That tool asks "are the fields filled?"; this
// one asks "should this entity exist at all?".
//
// Since 2026-07-29 a package can **link** another package instead of copying
// it (`vault/20-Systems/Package-Links.md`), and the built-in SRD 5.2.1 Core
// pack is in scope for every package, world and character *implicitly* — it is
// overlaid by `packageReferenceOverlayProvider`, linked into every world by
// `SrdCoreBootstrap` and merged by `mergeBuiltinWithPackages`. So an Open5e
// pack that ships its own "Acolyte" or "Fireball" is not adding content, it is
// shadowing content that is already there.
//
// Three censuses, matching the three sections of `docs/open5e_content_audit.md`
// §1.5:
//
//   A. bundled entity ⟷ built-in pack        — collisions that should become
//                                              nothing at all (drop the card;
//                                              the built-in one is in scope)
//   B. bundled entity ⟷ another bundled pack — collisions that should become
//                                              one owner + `metadata.links`
//   C. cross-pack `softRef` targets           — the in-card ref surface: does
//                                              `{slug, name}` actually land on
//                                              a built-in / bundled entity?
//
// ## Fidelity (audit phase L0, 2026-07-30)
//
// **A/B and C ask different questions and therefore use different keys.** L0
// was planned as "match like the runtime everywhere"; measuring it showed that
// would be wrong for A and B, so the tool does this instead:
//
//   * **A and B — identity.** `(slug, lowercased name)`, exact. Case is folded
//     because the importer title-cases and a case variant is still the same
//     card; a **trailing parenthetical is not stripped**, because the qualifier
//     is usually the mechanic ("Legendary Resistance (3/Day)", "Wing Attack
//     (Costs 2 Actions)", `_ensureChild`'s "Scimitar (Firetamer)"). Stripping
//     here would declare 3,501 qualified statblock rows duplicates of built-in
//     cards they do not duplicate.
//   * **C — resolution.** The runtime matcher exactly: `findEntityIdByName`
//     (`lib/domain/services/entity_ref.dart`) is case-**sensitive** and, on a
//     miss, retries once with a trailing parenthetical removed. The delta
//     against the identity key is printed in both directions, so a green
//     "0 dangling" is evidence about the app rather than about the census.
//
// That split is itself a finding: the same qualifier-stripping that makes A/B
// wrong is live in the resolver, so a softRef naming a qualified child can land
// on the generic built-in card (§2.3).
//
// Two further readings the old output could not support:
//
//   * **identical text** — a shared name is not a shared card (§2.5: 90.3% of
//     `creature-action`/`trait` collisions carry different prose). Sections A
//     and B split every collision into same-text and different-text.
//   * **monster-owned children** — a `creature-action` / `trait` row reachable
//     only from one statblock's `action_refs` / `trait_refs` is that monster's
//     property, not library content, and is not a dedup candidate. Those rows
//     are counted on their own line so the headline stops overstating the work
//     by ~4×.
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dungeon_master_tool/domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';

/// `(slug, name)` join key, **case-sensitive** — byte-for-byte what
/// `findEntityIdByName` indexes on, separator included. A slug never contains a
/// space, so [_slugOf] / [_nameOf] split on the *first* one; splitting on the
/// last is what used to make [_nameOf] print only a name's final word.
String _key(String slug, String name) => '$slug\u0000$name';

/// The key this tool used before L0, kept only to measure the difference.
String _looseKey(String slug, String name) =>
    '$slug\u0000${name.toLowerCase()}';

String _loosen(String key) {
  final i = key.indexOf('\u0000');
  return '${key.substring(0, i)}\u0000${key.substring(i + 1).toLowerCase()}';
}

String _slugOf(String key) => key.substring(0, key.indexOf('\u0000'));
String _nameOf(String key) => key.substring(key.indexOf('\u0000') + 1);

/// The runtime's qualifier-tolerant retry, copied from `findEntityIdByName`:
/// on an exact miss, one attempt with a trailing parenthetical removed.
String? _strippedName(String name) {
  final stripped = name.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
  if (stripped.isEmpty || stripped == name) return null;
  return stripped;
}

/// Which key in [index] the app would land on for `(slug, name)`, or null.
String? _resolveKey(Set<String> index, String slug, String name) {
  final exact = _key(slug, name);
  if (index.contains(exact)) return exact;
  final stripped = _strippedName(name);
  if (stripped == null) return null;
  final retry = _key(slug, stripped);
  return index.contains(retry) ? retry : null;
}

/// Comparison form for description prose: whitespace collapsed, ends trimmed,
/// case preserved (a case edit in a rules sentence is a real edit). §2.5's
/// python snippet hashed the raw string, so this reports marginally fewer
/// divergences — reflowed-only copies now count as identical, which is the
/// reading L1/L2 need.
String _normText(String? s) =>
    (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// The five `monster` fields whose targets exist for that one statblock.
const _childRefKeys = <String>[
  'action_refs',
  'bonus_action_refs',
  'reaction_refs',
  'legendary_action_refs',
  'trait_refs',
];

void main(List<String> args) {
  final opts = _parseArgs(args);
  final packDir = opts['packs'] ?? 'assets/open5e_packs';
  final markdown = args.contains('--markdown');
  final only =
      (opts['only'] ?? '').split(',').where((s) => s.isNotEmpty).toSet();
  final listSlug = opts['list'];

  final dir = Directory(packDir);
  if (!dir.existsSync()) {
    stderr.writeln('ERROR: pack dir not found: $packDir');
    exit(2);
  }

  final builtin = _builtinIndex();
  final packs = _loadPacks(dir);
  if (packs.isEmpty) {
    stderr.writeln('ERROR: no *.pkg.json in $packDir');
    exit(2);
  }

  final census = _Census(builtin: builtin, packs: packs, only: only);

  if (listSlug != null) {
    census.printList(listSlug);
    return;
  }
  if (args.contains('--list-shared')) {
    census.printSharedList();
    return;
  }
  if (markdown) {
    census.printMarkdown();
  } else {
    census.printPlain();
  }
}

// ── Inputs ────────────────────────────────────────────────────────────────

/// Every `(slug, name)` the built-in pack puts in scope, mapped to its
/// normalized description so section A can say whether a collision is the same
/// card. Tier-0 seed rows from the schema builder plus the Tier-1 hand-authored
/// SRD catalog; both are pure Dart, so this needs no database and no Flutter
/// binding. First writer wins, matching `_nameIndexFor`.
Map<String, String> _builtinIndex() {
  final out = <String, String>{};
  for (final entry in generateBuiltinDnd5eV2Schema().seedRows.entries) {
    for (final row in entry.value) {
      final name = (row['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      out.putIfAbsent(
        _key(entry.key, name),
        () => _normText(row['description'] as String?),
      );
    }
  }
  for (final value in buildSrdCorePack().entities.values) {
    final row = value as Map;
    final slug = (row['type'] as String?)?.trim() ?? '';
    final name = (row['name'] as String?)?.trim() ?? '';
    if (slug.isEmpty || name.isEmpty) continue;
    out.putIfAbsent(_key(slug, name), () => _textOf(row));
  }
  return out;
}

/// Description as the app would show it: the top-level wire key, falling back
/// to `attributes.description` (the importer writes both; hand-authored SRD
/// cards sometimes only carry one).
String _textOf(Map row) {
  final top = _normText(row['description'] as String?);
  if (top.isNotEmpty) return top;
  final attrs = row['attributes'];
  if (attrs is Map) return _normText(attrs['description'] as String?);
  return '';
}

class _Pack {
  final String name;
  final Map<String, _PackEntity> byId;
  _Pack(this.name, this.byId);
}

class _PackEntity {
  final String id;
  final String slug;
  final String name;
  final String text;
  final Map<String, dynamic> attributes;
  _PackEntity(this.id, this.slug, this.name, this.text, this.attributes);
}

List<_Pack> _loadPacks(Directory dir) {
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.pkg.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final out = <_Pack>[];
  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync());
    if (json is! Map) continue;
    final entities = json['entities'];
    if (entities is! Map) continue;
    final byId = <String, _PackEntity>{};
    entities.forEach((id, value) {
      if (value is! Map) return;
      final slug = (value['type'] as String?)?.trim() ?? '';
      final name = (value['name'] as String?)?.trim() ?? '';
      if (slug.isEmpty || name.isEmpty) return;
      final attrs = value['attributes'];
      byId[id.toString()] = _PackEntity(
        id.toString(),
        slug,
        name,
        _textOf(value),
        attrs is Map ? Map<String, dynamic>.from(attrs) : <String, dynamic>{},
      );
    });
    out.add(_Pack((json['package_name'] ?? file.uri.pathSegments.last).toString(),
        byId));
  }
  return out;
}

// ── The census ────────────────────────────────────────────────────────────

/// One bundled entity plus the pack shipping it.
class _Row {
  final String pack;
  final _PackEntity entity;
  _Row(this.pack, this.entity);
}

class _Census {
  final Map<String, String> builtin;
  final List<_Pack> packs;
  final Set<String> only;

  /// A: `packName -> slug -> count` of entities colliding with the built-in pack.
  final _builtinDupes = <String, Map<String, int>>{};

  /// B: `(slug,name) -> packs that ship it`, only where >1 pack does.
  final _sharedKeys = <String, List<String>>{};

  /// C: softRef targets, bucketed.
  var _softTotal = 0;
  var _softToBuiltin = 0;
  var _softToOtherPack = 0;
  var _softToSelf = 0;
  var _softDangling = 0;
  final _danglingBySlug = <String, int>{};

  /// C fidelity: refs the old lowercased key called resolved and the app drops,
  /// and refs the app resolves (via the parenthetical retry) that it called
  /// dangling.
  var _softLooseOnly = 0;
  var _softRuntimeOnly = 0;

  var _entityTotal = 0;
  var _builtinDupeTotal = 0;

  /// Union of A and B: bundled entities that are a copy of something already
  /// in scope. A name the built-in pack ships makes **every** bundled copy
  /// redundant; a name only bundled packs ship makes all but one redundant.
  /// A and B overlap (a trait can be both), so this is not their sum.
  var _redundantTotal = 0;

  /// (c) — rows reachable only from one statblock's child lists.
  final _ownedIds = <String>{};
  var _ownedTotal = 0;
  var _redundantOwned = 0;

  /// (a) — how much the identity key and the resolver's matcher disagree on A.
  /// [_aCaseOnly] is a collision only a case-folded key sees (the app would
  /// treat the two as distinct entities); [_aStripOnly] is a bundled row that is
  /// *not* a duplicate but whose name the resolver's parenthetical retry lands
  /// on a built-in card anyway — a resolution hazard, not dedup work.
  var _aCaseOnly = 0;
  var _aStripOnly = 0;
  final _stripOnlyExamples = <String>[];
  var _sharedKeysStrict = 0;

  /// (b) — text agreement. `NoText` is its own bucket, not a match: `monster`
  /// ships an empty top-level description in every pack (the statblock lives in
  /// `attributes`), and the synthesised gear stubs have no prose at all, so
  /// counting those as "identical" would manufacture evidence of duplication.
  var _aSameText = 0;
  var _aDiffText = 0;
  var _aNoText = 0;
  var _bNamesSameText = 0;
  var _bNamesDiffText = 0;
  var _bNamesNoText = 0;
  var _bCopiesSameText = 0;

  /// The rows behind [_bNamesSameText], keyed by identity key — L2's candidate
  /// set, printed by `--list-shared`. A name is only a link candidate if no
  /// copy is a statblock's child row (§2.5), so the rows are kept whole and the
  /// ownership call is made at print time.
  final _bSameText = <String, List<_Row>>{};

  /// The no-prose half of the same question (audit **L2**, 2026-08-13): names
  /// whose copies carry no text *and* a byte-identical `attributes` body. §2.5
  /// said this bucket "needs an attributes-level comparison"; this is it.
  var _bNamesSameAttrs = 0;
  final _bSameAttrs = <String, List<_Row>>{};

  /// Every entity id in the corpus → its `slug␀name`. A statblock's child refs
  /// are per-pack uuids, so two byte-identical copies never *encode* the same;
  /// dereferencing the ids to names is what makes [_canonAttrs] compare content
  /// rather than id minting.
  final _idName = <String, String>{};

  /// Identity key → the first name spelling seen for it. The key folds case, so
  /// printing `_nameOf(key)` would show `scoundrel` for `Scoundrel`.
  final _displayName = <String, String>{};

  /// Per-slug text split for the markdown table.
  final _sameTextBySlug = <String, int>{};
  final _diffTextBySlug = <String, int>{};
  final _noTextBySlug = <String, int>{};
  final _ownedBySlug = <String, int>{};

  _Census({required this.builtin, required this.packs, required this.only}) {
    final builtinStrict = builtin.keys.toSet();
    // Identity index for A/B: case-folded, no qualifier stripping.
    final builtinById = <String, String>{};
    builtin.forEach((k, text) => builtinById.putIfAbsent(_loosen(k), () => text));
    final keyToRows = <String, List<_Row>>{};
    final strictKeys = <String>{};
    final allPackKeys = <String>{};

    for (final pack in packs) {
      for (final e in pack.byId.values) {
        _idName[e.id] = _key(e.slug, e.name);
      }
    }
    _collectOwnedIds();

    for (final pack in packs) {
      for (final e in pack.byId.values) {
        if (only.isNotEmpty && !only.contains(e.slug)) continue;
        _entityTotal++;
        final owned = _ownedIds.contains(e.id);
        if (owned) {
          _ownedTotal++;
          _ownedBySlug.update(e.slug, (n) => n + 1, ifAbsent: () => 1);
        }
        final key = _looseKey(e.slug, e.name);
        _displayName.putIfAbsent(key, () => e.name);
        allPackKeys.add(key);
        strictKeys.add(_key(e.slug, e.name));
        keyToRows.putIfAbsent(key, () => <_Row>[]).add(_Row(pack.name, e));

        // A — identity. Plus the two ways the resolver's matcher would differ.
        final builtinText = builtinById[key];
        if (builtinText != null &&
            !builtinStrict.contains(_key(e.slug, e.name))) {
          _aCaseOnly++;
        }
        if (builtinText == null &&
            _resolveKey(builtinStrict, e.slug, e.name) != null) {
          _aStripOnly++;
          if (_stripOnlyExamples.length < 5) {
            _stripOnlyExamples.add('${e.slug} "${e.name}"');
          }
        }
        if (builtinText == null) continue;
        _builtinDupeTotal++;
        (_builtinDupes[pack.name] ??= <String, int>{})
            .update(e.slug, (n) => n + 1, ifAbsent: () => 1);
        if (builtinText.isEmpty && e.text.isEmpty) {
          _aNoText++;
          _noTextBySlug.update(e.slug, (n) => n + 1, ifAbsent: () => 1);
        } else if (builtinText == e.text) {
          _aSameText++;
          _sameTextBySlug.update(e.slug, (n) => n + 1, ifAbsent: () => 1);
        } else {
          _aDiffText++;
          _diffTextBySlug.update(e.slug, (n) => n + 1, ifAbsent: () => 1);
        }
      }
    }
    _sharedKeysStrict = _countStrictShared();

    keyToRows.forEach((key, rows) {
      final distinct = rows.map((r) => r.pack).toSet().toList()..sort();
      final isBuiltinDupe = builtinById.containsKey(key);
      final redundant = isBuiltinDupe ? rows.length : rows.length - 1;
      _redundantTotal += redundant;
      // How many of those redundant copies are a statblock's own child row —
      // i.e. off the table for L1/L2 (§2.5). When the built-in pack ships the
      // name, every copy is redundant; otherwise one copy is kept, and the
      // owned rows are exactly the ones a keep policy would keep.
      final owned = rows.where((r) => _ownedIds.contains(r.entity.id)).length;
      _redundantOwned += isBuiltinDupe ? owned : min(owned, redundant);
      if (distinct.length <= 1) return;
      _sharedKeys[key] = distinct;
      final texts = rows.map((r) => r.entity.text).toSet();
      if (texts.length == 1 && texts.first.isEmpty) {
        _bNamesNoText++;
        // No prose on any copy is not evidence either way (§2.5), so fall
        // through to the card body: canonical JSON of `attributes`, which for a
        // `monster` is the whole statblock. One distinct body = a real
        // duplicate; more = the copies differ and the name is all they share.
        if (rows.map((r) => _canonAttrs(r.entity)).toSet().length == 1) {
          _bNamesSameAttrs++;
          _bSameAttrs[key] = rows;
        }
      } else if (texts.length == 1) {
        _bNamesSameText++;
        _bCopiesSameText += rows.length - 1;
        _bSameText[key] = rows;
      } else {
        _bNamesDiffText++;
      }
    });
    if (_redundantOwned < 0) _redundantOwned = 0;

    // C — every `{slug, name}` softRef reachable from a card's attributes.
    for (final pack in packs) {
      final ownStrict = {
        for (final e in pack.byId.values) _key(e.slug, e.name),
      };
      final ownIdentity = {for (final k in ownStrict) _loosen(k)};
      for (final e in pack.byId.values) {
        if (only.isNotEmpty && !only.contains(e.slug)) continue;
        _walkSoftRefs(e.attributes, (slug, name) {
          _softTotal++;
          // What the pre-L0 census believed: a case-folded exact hit anywhere.
          final id = _looseKey(slug, name);
          final censusLands = builtinById.containsKey(id) ||
              ownIdentity.contains(id) ||
              allPackKeys.contains(id);
          // What the app does: case-sensitive, one parenthetical retry.
          if (_resolveKey(builtinStrict, slug, name) != null) {
            _softToBuiltin++;
          } else if (_resolveKey(ownStrict, slug, name) != null) {
            _softToSelf++;
          } else if (_resolveKey(strictKeys, slug, name) != null) {
            _softToOtherPack++;
          } else {
            _softDangling++;
            _danglingBySlug.update(slug, (n) => n + 1, ifAbsent: () => 1);
            if (censusLands) _softLooseOnly++;
            return;
          }
          if (!censusLands) _softRuntimeOnly++;
        });
      }
    }
  }

  /// Section B's name count under the resolver's **strict** key (case-sensitive,
  /// no qualifier stripping), so the fidelity line can quote both readings.
  int _countStrictShared() {
    final owners = <String, Set<String>>{};
    for (final pack in packs) {
      for (final e in pack.byId.values) {
        if (only.isNotEmpty && !only.contains(e.slug)) continue;
        owners
            .putIfAbsent(_key(e.slug, e.name), () => <String>{})
            .add(pack.name);
      }
    }
    return owners.values.where((s) => s.length > 1).length;
  }

  /// Ids reachable from a `monster`'s five child-list fields. These rows are a
  /// statblock's property: the build resolves them as in-pack hard refs, and
  /// collapsing them by name reassigns another creature's text (§2.5). Not
  /// filtered by `--only`, because the *owner* is what makes a child owned.
  void _collectOwnedIds() {
    for (final pack in packs) {
      for (final e in pack.byId.values) {
        if (e.slug != 'monster') continue;
        for (final key in _childRefKeys) {
          final list = e.attributes[key];
          if (list is! List) continue;
          for (final raw in list) {
            if (raw is String) {
              _ownedIds.add(raw);
            } else if (raw is Map && raw['_ref'] is String) {
              _ownedIds.add(raw['_ref'] as String);
            }
          }
        }
      }
    }
  }

  /// Recursive walk for the `softRef` envelope `{slug, name}`. `{_ref, name}`
  /// and `{_lookup, name}` are deliberately skipped: the first is an in-pack
  /// hard ref the build already gates on, the second is Tier-0 vocabulary
  /// resolved at import.
  void _walkSoftRefs(Object? value, void Function(String, String) onRef) {
    if (value is List) {
      for (final v in value) {
        _walkSoftRefs(v, onRef);
      }
      return;
    }
    if (value is! Map) return;
    final slug = value['slug'];
    final name = value['name'];
    if (slug is String &&
        name is String &&
        slug.isNotEmpty &&
        name.isNotEmpty &&
        !value.containsKey('_ref') &&
        !value.containsKey('_lookup')) {
      onRef(slug, name);
      return;
    }
    for (final v in value.values) {
      _walkSoftRefs(v, onRef);
    }
  }

  int get _sharedRedundantCopies =>
      _sharedKeys.values.fold(0, (sum, owners) => sum + owners.length - 1);

  /// The headline the L/B phases are actually scoped against: redundant copies
  /// that are not one monster's child row.
  int get _actionableRedundant => _redundantTotal - _redundantOwned;

  /// Two built-in rows differ only in case, so the strict row count is 2 higher
  /// than the identity one.
  int get _builtinIdentityRows =>
      {for (final k in builtin.keys) _loosen(k)}.length;

  Map<String, int> get _builtinBySlug {
    final out = <String, int>{};
    for (final m in _builtinDupes.values) {
      m.forEach((slug, n) => out.update(slug, (v) => v + n, ifAbsent: () => n));
    }
    return out;
  }

  Map<String, int> get _sharedBySlug {
    final out = <String, int>{};
    _sharedKeys.forEach((key, owners) {
      out.update(_slugOf(key), (v) => v + owners.length - 1,
          ifAbsent: () => owners.length - 1);
    });
    return out;
  }

  // ── Output ──────────────────────────────────────────────────────────────

  void printPlain() {
    print('Bundled packs: ${packs.length}   entities: $_entityTotal');
    print('Built-in (slug,name) rows in scope: ${builtin.length} '
        '($_builtinIdentityRows after folding case — the key A/B use)');
    print('Redundant (A ∪ B, copies of content already in scope): '
        '$_redundantTotal (${_pct(_redundantTotal, _entityTotal)})');
    print('   of which monster-owned children (not dedup candidates): '
        '$_redundantOwned');
    print('   → actionable redundancy: $_actionableRedundant '
        '(${_pct(_actionableRedundant, _entityTotal)})');
    print('');
    print('Matcher fidelity');
    print('   A/B key on identity: (slug, lowercased name), no qualifier strip.');
    print('   C keys on the resolver: findEntityIdByName — case-sensitive, one');
    print('     trailing-parenthetical retry. The two disagree as follows:');
    print('   A: identity collisions  $_builtinDupeTotal');
    print('      of those, case-only — the app sees two distinct entities  '
        '$_aCaseOnly');
    print('      NOT collisions, but the resolver\'s strip lands them on a '
        'built-in card  $_aStripOnly');
    for (final ex in _stripOnlyExamples) {
      print('        e.g. $ex');
    }
    print('   B: shared names, identity  ${_sharedKeys.length}   '
        'resolver key  $_sharedKeysStrict');
    print('   C: refs the identity key calls resolved, the app drops  '
        '$_softLooseOnly');
    print('      refs the app resolves, the identity key calls dangling  '
        '$_softRuntimeOnly');
    print('   monster-owned child rows in corpus: $_ownedTotal '
        '(${_pct(_ownedTotal, _entityTotal)})');
    print('');
    print('A. Duplicates the built-in pack already ships');
    print('   $_builtinDupeTotal entities '
        '(${_pct(_builtinDupeTotal, _entityTotal)} of the bundled corpus)');
    print('   same text $_aSameText   different text $_aDiffText '
        '(${_pct(_aDiffText, _builtinDupeTotal)} — a shared name is not a '
        'shared card)   no text either side $_aNoText (no evidence)');
    for (final e in _sorted(_builtinBySlug)) {
      print('     ${e.key.padRight(20)} ${e.value.toString().padLeft(5)}'
          '   same ${(_sameTextBySlug[e.key] ?? 0).toString().padLeft(4)}'
          '   diff ${(_diffTextBySlug[e.key] ?? 0).toString().padLeft(4)}'
          '   no-text ${(_noTextBySlug[e.key] ?? 0).toString().padLeft(4)}');
    }
    print('   per pack:');
    final perPack = _builtinDupes.entries.toList()
      ..sort((a, b) => _sum(b.value).compareTo(_sum(a.value)));
    for (final e in perPack) {
      final parts = _sorted(e.value).map((s) => '${s.value} ${s.key}');
      print('     ${e.key.padRight(32)} ${_sum(e.value).toString().padLeft(4)}  '
          '${parts.join(", ")}');
    }
    print('');
    print('B. Shipped by more than one bundled pack');
    print('   ${_sharedKeys.length} name(s), $_sharedRedundantCopies redundant '
        'cop(ies)');
    print('   names whose copies are textually identical  $_bNamesSameText '
        '($_bCopiesSameText cop(ies))');
    print('   names that only share a name                $_bNamesDiffText');
    print('   names with no text on any copy               $_bNamesNoText '
        '(of which identical card body: $_bNamesSameAttrs)');
    for (final e in _sorted(_sharedBySlug)) {
      print('     ${e.key.padRight(20)} ${e.value}');
    }
    print('');
    print('C. Cross-pack softRefs inside cards  (total $_softTotal)');
    print('     -> built-in pack      $_softToBuiltin');
    print('     -> another bundled    $_softToOtherPack   '
        '(needs metadata.links)');
    print('     -> own pack           $_softToSelf   (could be a hard ref)');
    print('     -> nothing installed  $_softDangling');
    for (final e in _sorted(_danglingBySlug)) {
      print('        ${e.key.padRight(18)} ${e.value}');
    }
  }

  void printMarkdown() {
    // The `monster-owned` column is corpus-wide per category, not a subset of
    // the A column — it is the size of the set §2.5 excludes from L1/L2.
    print('| Category | Also in built-in | …same text | …name only | '
        '…no text either side | In >1 bundled pack | monster-owned |');
    print('|---|--:|--:|--:|--:|--:|--:|');
    final slugs = {..._builtinBySlug.keys, ..._sharedBySlug.keys}.toList()
      ..sort();
    for (final slug in slugs) {
      print('| `$slug` | ${_builtinBySlug[slug] ?? 0} | '
          '${_sameTextBySlug[slug] ?? 0} | ${_diffTextBySlug[slug] ?? 0} | '
          '${_noTextBySlug[slug] ?? 0} | '
          '${_sharedBySlug[slug] ?? 0} | ${_ownedBySlug[slug] ?? 0} |');
    }
    print('| **total** | **$_builtinDupeTotal** | **$_aSameText** | '
        '**$_aDiffText** | **$_aNoText** | **$_sharedRedundantCopies** | '
        '**$_ownedTotal** |');
    print('');
    print('Union (A ∪ B): **$_redundantTotal** of $_entityTotal bundled '
        'entities (${_pct(_redundantTotal, _entityTotal)}) are copies of '
        'content already in scope — but $_redundantOwned of those are one '
        "statblock's child rows, so the actionable set is "
        '**$_actionableRedundant** (${_pct(_actionableRedundant, _entityTotal)}).');
    print('');
    print('| Matcher fidelity — identity key (A/B) vs `findEntityIdByName` (C) '
        '| Count |');
    print('|---|--:|');
    print('| A: case-only collision (the app sees two entities) | $_aCaseOnly |');
    print('| A: not a collision, but the resolver\'s parenthetical strip lands '
        'it on a built-in card | $_aStripOnly |');
    print('| B: shared names, identity key / resolver key | '
        '${_sharedKeys.length} / $_sharedKeysStrict |');
    print('| C: called resolved, app drops | $_softLooseOnly |');
    print('| C: called dangling, app resolves | $_softRuntimeOnly |');
    print('');
    print('| Pack | Duplicates built-in | Breakdown |');
    print('|---|--:|---|');
    final perPack = _builtinDupes.entries.toList()
      ..sort((a, b) => _sum(b.value).compareTo(_sum(a.value)));
    for (final e in perPack) {
      final parts = _sorted(e.value).map((s) => '${s.value} `${s.key}`');
      print('| `${e.key}` | ${_sum(e.value)} | ${parts.join(", ")} |');
    }
    print('');
    print('| softRef target | Count |');
    print('|---|--:|');
    print('| built-in pack | $_softToBuiltin |');
    print('| another bundled pack | $_softToOtherPack |');
    print('| own pack | $_softToSelf |');
    print('| nothing installed | $_softDangling |');
    print('| **total** | **$_softTotal** |');
  }

  /// Every colliding name in one category, so a decision can be made per row.
  /// `=` / `≠` is text agreement; `[owned]` marks a monster's own child row,
  /// which §2.5 keeps out of L1/L2 regardless of what the text says.
  /// The card body as content: keys sorted, in-pack uuid refs replaced by the
  /// name they point at.
  String _canonAttrs(_PackEntity e) => jsonEncode(_canon(e.attributes));

  /// How many ids [_canon] actually resolved. Printed by `--list-shared`: if a
  /// bug left this at 0 the statblock comparison would be comparing per-pack
  /// uuids and could only ever report "different", which is the one way this
  /// measurement could be wrong and still look plausible.
  var _derefs = 0;

  Object? _canon(Object? v) {
    if (v is String) {
      final hit = _idName[v];
      if (hit != null) _derefs++;
      return hit ?? v;
    }
    if (v is List) return [for (final x in v) _canon(x)];
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _canon(v[k])};
    }
    return v;
  }

  /// L2's candidate set: every section-B name whose copies are textually
  /// identical, split by whether a statblock owns any copy. Only the unowned
  /// half is link work — an owned child row belongs to its creature (§2.5).
  void printSharedList() {
    final free = <String>[];
    final owned = <String>[];
    _bSameText.forEach((key, rows) {
      final packNames = (rows.map((r) => r.pack).toSet().toList()..sort());
      final line = '  ${_slugOf(key).padRight(18)} '
          '${_displayName[key]}  [${packNames.join(", ")}]';
      (rows.any((r) => _ownedIds.contains(r.entity.id)) ? owned : free)
          .add(line);
    });
    free.sort();
    owned.sort();
    print('# section B, identical text — no statblock owns a copy '
        '(${free.length} name(s))');
    free.forEach(print);
    print('');
    print('# section B, identical text — a statblock owns a copy: not link '
        'work (${owned.length} name(s))');
    owned.forEach(print);
    print('');
    print('# section B, no text on any copy but an identical card body '
        '($_bNamesSameAttrs name(s), $_derefs child ref(s) dereferenced)');
    final byBody = _bSameAttrs.keys.map((key) {
      final packNames = _sharedKeys[key]!;
      return '  ${_slugOf(key).padRight(18)} '
          '${_displayName[key]}  [${packNames.join(", ")}]';
    }).toList()
      ..sort();
    byBody.forEach(print);
  }

  void printList(String slug) {
    final builtinById = <String, String>{};
    builtin.forEach((k, text) => builtinById.putIfAbsent(_loosen(k), () => text));
    print('# $slug — collides with built-in');
    final names = <String>[];
    for (final pack in packs) {
      for (final e in pack.byId.values) {
        if (e.slug != slug) continue;
        final hit = builtinById[_looseKey(e.slug, e.name)];
        if (hit == null) continue;
        final same = hit == e.text ? '=' : '≠';
        final owned = _ownedIds.contains(e.id) ? '  [owned]' : '';
        names.add('$same ${e.name}  [${pack.name}]$owned');
      }
    }
    names.sort();
    for (final n in names) {
      print('  $n');
    }
    print('');
    print('# $slug — shipped by >1 bundled pack');
    final shared = _sharedKeys.entries
        .where((e) => _slugOf(e.key) == slug)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final e in shared) {
      final texts = <String>{};
      var owned = false;
      for (final pack in packs) {
        for (final x in pack.byId.values) {
          if (_looseKey(x.slug, x.name) != e.key) continue;
          texts.add(x.text);
          if (_ownedIds.contains(x.id)) owned = true;
        }
      }
      final mark = texts.length == 1 ? '=' : '≠${texts.length}';
      final shown = _displayName[e.key] ?? _nameOf(e.key);
      print('  ${mark.padRight(4)} $shown  ${e.value.join(", ")}'
          '${owned ? "  [owned]" : ""}');
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

int _sum(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);

List<MapEntry<String, int>> _sorted(Map<String, int> m) =>
    m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

String _pct(int n, int total) =>
    total == 0 ? '0%' : '${(n * 100 / total).toStringAsFixed(1)}%';

Map<String, String> _parseArgs(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) continue;
    final eq = a.indexOf('=');
    if (eq > 0) {
      out[a.substring(2, eq)] = a.substring(eq + 1);
    } else if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      out[a.substring(2)] = args[++i];
    }
  }
  return out;
}
