// Map a v2 Open5e Creature (+ its CreatureAction / CreatureActionAttack /
// CreatureTrait child rows) onto the app's `monster` + `creature-action` +
// `trait` package entities.
//
// Depth = stats + descriptive text (per plan): every stat field we can derive
// is filled; mechanical effect/grant DSL is NOT attempted. Actions/traits are
// minted as separate entities the monster references by name (resolved to ids
// in PackBuilder pass 2), exactly like the SRD core pack.
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/_helpers.dart';
import 'package:dungeon_master_tool/domain/entities/schema/dnd5e_constants.dart';

import '../loaders.dart';
import '../normalize.dart';
import '../refgraph.dart';

/// v1 statblock fallback for creature actions (audit **B8**): lowercased
/// monster name → `action_type` bucket → the raw `{name, desc}` rows upstream's
/// v1 `Monster.*_json` columns carry. Built by `build_packs`.
typedef V1ActionIndex = Map<String, Map<String, List<Map<String, String>>>>;

/// Map all creatures in a document into [pack]. Child actions/traits are
/// deduped within the package by content so shared rows are authored once.
///
/// [v1Actions] backfills a bucket the v2 fixtures leave **completely empty** for
/// a creature; it can never override a bucket v2 populated. See B8 below.
///
/// [v1Subtypes] (`lowercased name → subtype`) is the same kind of backfill for
/// `tags_line`: v2's `Creature.type` is a bare enum and the subtype column was
/// dropped in the v2 conversion. See `_creatureType`.
void mapCreatures({
  required PackBuilder pack,
  required Normalizer norm,
  required String source,
  required List<Fixture> creatures,
  required List<Fixture> actions,
  required List<Fixture> attacks,
  required List<Fixture> traits,
  V1ActionIndex v1Actions = const {},
  Map<String, String> v1Subtypes = const {},
  Map<String, int> v1LegendaryUses = const {},
  Map<String, String> v1Senses = const {},
}) {
  final actionsByCreature = groupBy(actions, 'parent');
  final traitsByCreature = groupBy(traits, 'parent');
  final attacksByAction = groupBy(attacks, 'parent');

  // **R2 / F-pass0-26.** Upstream left `alignment` unfilled in two documents
  // and the placeholder it left is not harmless: `a5e-mm` and `bfrd` say
  // "chaotic evil" on 946 of 946 rows, so Pixie and Unicorn ship as chaotic
  // evil. A column that collapsed to a single value over a whole document is
  // not a statement about any creature in it — write nothing instead.
  final alignmentIsCollapsed = _collapsedColumn(creatures, 'alignment');

  // Dedup child entities (action/trait) across creatures: content-hash → name.
  final childNameByHash = <String, String>{};

  for (final c in creatures) {
    final pk = c['_pk'].toString();
    final rawName = (c['name'] as String?)?.trim() ?? 'Unknown';
    final cname = _cleanMonsterName(rawName);

    // v1's rows for this creature, flattened by name — the repair source for a
    // v2 row that upstream truncated (F-tob-2023-01) and the recovery source
    // for a row v2 never converted (F-pass0-24).
    final v1 = v1Actions[rawName.toLowerCase()];
    final v1DescByName = <String, String>{};
    for (final rows in (v1 ?? const {}).values) {
      for (final r in rows) {
        final n = (r['name'] ?? '').trim().toLowerCase();
        final d = (r['desc'] ?? '').trim();
        if (n.isEmpty || d.isEmpty) continue;
        if ((v1DescByName[n]?.length ?? 0) < d.length) v1DescByName[n] = d;
      }
    }

    // ── Build child trait entities + collect refs ──
    final traitRefs = <Map<String, String>>[];
    for (final raw in traitsByCreature[pk] ?? const <Fixture>[]) {
      final t = _repairRow(raw, null);
      final cleaned = _childName(t, 'Trait', 'trait');
      if (cleaned == null) continue; // spurious mis-segmented row → drop, no ref.
      final name = _ensureChild(
        pack: pack,
        childNameByHash: childNameByHash,
        baseName: cleaned,
        creatureName: cname,
        row: _traitRow(t, source),
      );
      traitRefs.add(ref('trait', name));
    }

    // ── Build child creature-action entities, split by action_type ──
    final actionRefs = <Map<String, String>>[];
    final bonusRefs = <Map<String, String>>[];
    final reactionRefs = <Map<String, String>>[];
    final legendaryRefs = <Map<String, String>>[];
    final lairRefs = <Map<String, String>>[];
    final rawActions = actionsByCreature[pk] ?? const <Fixture>[];
    // **R2 / F-pass0-22.** Upstream writes 114 legendary actions a second time
    // as plain actions, named "… (Costs 2 Actions)". Published as-is the card
    // offers a legendary action at will, which is the rule inverted — drop the
    // copy, the legendary bucket already carries it.
    final legendaryDescs = {
      for (final a in rawActions)
        if ((a['action_type'] as String?)?.toUpperCase() == 'LEGENDARY_ACTION')
          (a['desc'] as String?)?.trim() ?? '',
    };
    final published = <String>{}; // repaired descs, for the v1 recovery below.
    for (final raw in rawActions) {
      final apk = raw['_pk'].toString();
      final attack =
          (attacksByAction[apk] ?? const <Fixture>[]).cast<Fixture?>().firstWhere(
                (x) => true,
                orElse: () => null,
              );
      final rawDesc = (raw['desc'] as String?)?.trim() ?? '';
      if (_costsActionsName((raw['name'] as String?) ?? '') &&
          (raw['action_type'] as String?)?.toUpperCase() != 'LEGENDARY_ACTION' &&
          legendaryDescs.contains(rawDesc)) {
        continue;
      }
      final a = _repairRow(
          raw, v1DescByName[((raw['name'] as String?) ?? '').trim().toLowerCase()]);
      final cleaned = _childName(a, 'Action', 'creature-action');
      if (cleaned == null) continue; // spurious mis-segmented row → drop, no ref.
      published..add(rawDesc)..add((a['desc'] as String?)?.trim() ?? '');
      final row = _actionRow(a, attack, source, norm);
      final name = _ensureChild(
        pack: pack,
        childNameByHash: childNameByHash,
        baseName: cleaned,
        creatureName: cname,
        row: row,
      );
      final r = ref('creature-action', name);
      switch ((a['action_type'] as String?)?.toUpperCase()) {
        case 'BONUS_ACTION':
          bonusRefs.add(r);
          break;
        case 'REACTION':
          reactionRefs.add(r);
          break;
        case 'LEGENDARY_ACTION':
          legendaryRefs.add(r);
          break;
        case 'LAIR_ACTION':
          lairRefs.add(r);
          break;
        default:
          actionRefs.add(r);
      }
    }

    // ── B8 + R2/F-pass0-24: recover rows upstream's v2 conversion dropped ──
    // Tome of Beasts 3 ships 309 CreatureAction rows for 397 creatures and
    // exactly 2 of them are ACTION, while v1's `actions_json` holds 1,373 —
    // this is a partial upstream conversion, not a mapping bug. B8 only filled
    // a bucket v2 had left *entirely* empty, which measured the cost wrong:
    // a half-converted bucket silently dropped v1's extra rows, 11 actions on
    // 10 creatures across three documents. The test is now per row and by
    // text, not by bucket and not by name (names are unreliable, F-pass0-17):
    // a v1 row whose text no child of this creature carries is published.
    // v1 rows are prose only — there is no v1 equivalent of
    // CreatureActionAttack — so a recovered action carries name + text and no
    // structured attack, which is what tob3 would have shipped anyway.
    if (v1 != null) {
      final buckets = <String, List<Map<String, String>>>{
        'ACTION': actionRefs,
        'BONUS_ACTION': bonusRefs,
        'REACTION': reactionRefs,
        'LEGENDARY_ACTION': legendaryRefs,
      };
      for (final b in buckets.entries) {
        for (final row in v1[b.key] ?? const <Map<String, String>>[]) {
          final desc = _fixEscapes(row['desc']?.trim() ?? '');
          if (desc.isEmpty || published.any((p) => _samePublishedText(p, desc))) {
            continue;
          }
          final cleaned = _cleanChildName(
              _fixEscapes(row['name']?.trim() ?? 'Action'), desc, 'creature-action');
          if (cleaned == null) continue;
          published.add(desc);
          final name = _ensureChild(
            pack: pack,
            childNameByHash: childNameByHash,
            baseName: cleaned,
            creatureName: cname,
            row: _v1ActionRow(cleaned, desc, b.key, source),
          );
          b.value.add(ref('creature-action', name));
        }
      }
    }

    pack.add(_monsterRow(
      c: c,
      source: source,
      norm: norm,
      traitRefs: traitRefs,
      actionRefs: actionRefs,
      bonusRefs: bonusRefs,
      reactionRefs: reactionRefs,
      legendaryRefs: legendaryRefs,
      lairRefs: lairRefs,
      v1Subtype: v1Subtypes[rawName.toLowerCase()],
      alignmentIsCollapsed: alignmentIsCollapsed,
      v1LegendaryUses: v1LegendaryUses[rawName.toLowerCase()],
      v1Senses: v1Senses[rawName.toLowerCase()],
    ));
  }
}

/// **R2 / F-pass0-27.** Upstream's v2 conversion half-resolved some unicode
/// escapes: the escape marker collapsed to `æ` (U+00E6) and the code point it
/// named was left behind as literal text, so `Vættir` shipped as
/// `Væ00e6ttir`, `Colláis` as `Collæ00e1is` and `2× damage` as `2æ00d7 damage`.
/// Every one of the corpus's 13 occurrences has that exact shape — marker plus
/// four hex digits — so restore the character the digits name. v1 has the same
/// rows clean, which is how the reading was confirmed.
final _escapeResidue = RegExp(r'æ(00[0-9a-fA-F]{2})');

String _fixEscapes(String s) => s.contains('æ')
    ? s.replaceAllMapped(_escapeResidue,
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
    : s;

/// Normalize a child row before anything reads it: repair upstream's mangled
/// escapes (F-pass0-27), take v1's copy of the text when v2's is a truncation
/// of it (F-tob-2023-01), and move a rule written into `name` down into `desc`
/// (F-a5e-mm-01). Rows repaired by that last rule are flagged so `_childName`
/// knows it may shorten a sentence into a title instead of dropping the row.
Fixture _repairRow(Fixture r, String? v1Desc) {
  final name = _fixEscapes((r['name'] as String?)?.trim() ?? '');
  var desc = _fixEscapes((r['desc'] as String?)?.trim() ?? '');
  // v2 truncated `Reconfiguring Curse` at 333 of 1,030 characters, dropping
  // four named curses. Only a strict prefix that is markedly longer wins, so
  // an edited (not truncated) v1 row can never overwrite v2's text.
  if (v1Desc != null &&
      v1Desc.length > desc.length * 1.3 &&
      v1Desc.startsWith(desc)) {
    desc = v1Desc;
  }
  var fromName = false;
  // `a5e-mm`'s parser inverted 30 rows: the rule sits in `name` and `desc` is
  // empty, so the row was dropped as a sentence fragment and its text lost.
  if (desc.isEmpty && name.length >= 40) {
    desc = name;
    fromName = true;
  }
  return {...r, 'name': name, 'desc': desc, if (fromName) '_fromName': true};
}

/// The published name for a repaired child row, or null when the row is
/// spurious. A row whose rule text was recovered out of `name` keeps a
/// shortened form of that sentence as its title rather than being dropped.
String? _childName(Fixture r, String fallback, String type) {
  final raw = (r['name'] as String?)?.trim() ?? fallback;
  final cleaned =
      _cleanChildName(raw, (r['desc'] as String?)?.trim() ?? '', type);
  if (cleaned != null) return cleaned;
  return r['_fromName'] == true ? _shortTitle(raw) : null;
}

/// First clause of a sentence, as a card title: "If a swallowed creature deals
/// 30 or more damage…". Truncation is marked, never hidden.
String _shortTitle(String sentence) {
  final head = sentence.split(RegExp(r'[.,;:]')).first.trim();
  if (head.isNotEmpty && head.length <= 48) return head;
  final words = (head.isEmpty ? sentence : head).split(RegExp(r'\s+'));
  final sb = StringBuffer();
  for (final w in words) {
    if (sb.length + w.length + 1 > 48) break;
    if (sb.isNotEmpty) sb.write(' ');
    sb.write(w);
  }
  return '${sb.isEmpty ? words.first : sb}…';
}

final _costsActions =
    RegExp(r'\(costs\s+\d+\s+actions?\)\s*$', caseSensitive: false);

bool _costsActionsName(String name) => _costsActions.hasMatch(name.trim());

/// Same statblock text, allowing for markdown and the form qualifier R2 adds.
/// Used to decide whether a v1 row is genuinely missing from the card; a short
/// text must match outright, so one-line "Multiattack" rows can't collide.
bool _samePublishedText(String a, String b) {
  String n(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[*_`]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final x = n(a), y = n(b);
  if (x == y) return true;
  final shorter = x.length < y.length ? x : y;
  final longer = x.length < y.length ? y : x;
  return shorter.length >= 40 && longer.contains(shorter);
}

/// True when [column] carries one single value across a whole document's rows
/// (and there are enough rows for that to mean something). See F-pass0-26.
bool _collapsedColumn(List<Fixture> rows, String column) {
  final seen = <String>{};
  var filled = 0;
  for (final r in rows) {
    final v = (r[column] as String?)?.trim() ?? '';
    if (v.isEmpty) continue;
    filled++;
    seen.add(v.toLowerCase());
    if (seen.length > 1) return false;
  }
  return seen.length == 1 && filled > 20;
}

/// Register a child (trait/creature-action) entity, deduping by content. Returns
/// the unique name the parent should reference. When two different children
/// share a base name, the later one is suffixed with the creature name (SRD
/// convention, e.g. "Scimitar (Firetamer)").
String _ensureChild({
  required PackBuilder pack,
  required Map<String, String> childNameByHash,
  required String baseName,
  required String creatureName,
  required Map<String, dynamic> row,
}) {
  final slug = row['type'] as String;
  // **R2 / F-pass0-17.** The name is part of the identity: two different
  // weapons whose statblock text is byte-identical ("Mining Pick" and "Bite")
  // used to merge into one entity and the first name won, so a creature's card
  // showed another creature's attack. Same text + same name still merges.
  final hash = '$baseName|${_contentHash(row)}';
  final existing = childNameByHash[hash];
  if (existing != null) return existing; // identical child already authored.

  var name = baseName;
  if (pack.has(slug, name)) {
    // Name taken by different content → disambiguate with creature name.
    name = '$baseName ($creatureName)';
    var n = 2;
    while (pack.has(slug, name)) {
      name = '$baseName ($creatureName $n)';
      n++;
    }
  }
  row['name'] = name;
  pack.add(row);
  childNameByHash[hash] = name;
  return name;
}

String _contentHash(Map<String, dynamic> row) {
  // Cheap stable signature: type + description + sorted attribute entries.
  final attrs = (row['attributes'] as Map?) ?? const {};
  final keys = attrs.keys.map((k) => k.toString()).toList()..sort();
  final sb = StringBuffer(row['type']);
  sb.write('|');
  sb.write(row['description']);
  for (final k in keys) {
    if (k == 'description') continue;
    sb..write('|')..write(k)..write('=')..write(attrs[k]);
  }
  return sb.toString();
}

// ── Name sanitization ──────────────────────────────────────────────────────
// Open5e's upstream scraper mis-segments some creature stat blocks: numbered
// option lists, roll tables, tiered effects, and flavor paragraphs become
// separate CreatureAction/CreatureTrait rows whose `name` is junk (e.g. "1",
// "1-4: Arm", "9 Tentacle Arms Melee Weapon Attack: …", "Second Roar: <effect>",
// "An acolyte is a priest in training…"). We copy names verbatim, so the junk
// surfaces as nonsensical entity-card titles. These helpers salvage a clean
// title where possible and drop the truly-spurious phantom rows.

/// Words kept lowercase mid-title when re-casing an Npc monster name.
const _smallWords = {
  'a', 'an', 'and', 'as', 'at', 'by', 'for', 'from',
  'in', 'of', 'on', 'or', 'the', 'to', 'with',
};

/// Clean a `monster` name. Strips the upstream "Npc: " prefix and lowercases
/// title small-words ("Npc: Warlock Of The Genie Lord" → "Warlock of the Genie
/// Lord"); preserves hyphens and existing casing ("Npc: Frost-Afflicted" →
/// "Frost-Afflicted"). Non-Npc names pass through unchanged.
String _cleanMonsterName(String raw) {
  final n = raw.trim();
  final m = RegExp(r'^npc\s*:\s*(.+)$', caseSensitive: false).firstMatch(n);
  if (m == null) return n;
  final words = m.group(1)!.trim().split(RegExp(r'\s+'));
  return [
    for (var i = 0; i < words.length; i++)
      (i > 0 && _smallWords.contains(words[i].toLowerCase()))
          ? words[i].toLowerCase()
          : words[i],
  ].join(' ');
}

/// Sanitize a monster child (trait / creature-action) name. Returns the cleaned
/// name, or `null` meaning "drop this row" — the caller then skips adding a ref
/// so no orphan ships. [desc] salvages a title for purely-numeric names.
String? _cleanChildName(String baseName, String desc, String type) {
  var n = baseName.trim();
  if (n.isEmpty) return null;

  // 0. Drop a single trailing sentence period ("Multiattack." → "Multiattack").
  if (n.endsWith('.') && !n.endsWith('..')) {
    n = n.substring(0, n.length - 1).trimRight();
  }

  // 1. Roll-table range row: "1-4: Arm" / "5-6: Head" → "Arm" / "Head".
  final range = RegExp(r'^\d+\s*[-–]\s*\d+\s*:\s*(.+)$').firstMatch(n);
  if (range != null) n = range.group(1)!.trim();

  // 2. Purely-numeric name ("1", "2", …): recover the bold label from the desc
  //    ("Charm Hex. The target…" → "Charm Hex"); drop if nothing recoverable.
  if (RegExp(r'^\d+$').hasMatch(n)) return _leadingLabel(desc);

  // 3. Leading list-count: "1 Bat Head", "9 Tentacle Arms Melee Weapon Attack:…"
  //    → strip the count, then cut any stat-block attack clause that leaked in.
  final count = RegExp(r'^\d+\s+(\S.*)$').firstMatch(n);
  if (count != null) n = _truncateAtAttackClause(count.group(1)!.trim());

  // 4. "Label: effect sentence" → "Label" (gated; leaves "Curse: Mummy Rot",
  //    "Variant: …", "Relentless (Recharge: …)" untouched).
  n = _maybeColonLabel(n) ?? n;

  // 5. Spurious full-sentence fragment (flavor / preamble / orphaned rule) → drop.
  if (_looksLikeSentenceFragment(n)) return null;

  return n;
}

/// First sentence of [desc] when it reads like a bold label ("Charm Hex.",
/// "Blood Choke Curse."). Null when there's no short title to recover.
String? _leadingLabel(String desc) {
  final d = desc.trim();
  if (d.isEmpty) return null;
  final dot = d.indexOf('.');
  final label = (dot >= 0 ? d.substring(0, dot) : d).trim();
  if (label.isEmpty || label.length > 40) return null;
  if (label.split(RegExp(r'\s+')).length > 6) return null;
  return label;
}

final _attackClause = RegExp(
    r'\s+(?:Melee|Ranged)\s+(?:Weapon|Spell)\s+Attack:.*$',
    caseSensitive: false);

/// "Tentacle Arms Melee Weapon Attack: +5 to hit…" → "Tentacle Arms".
String _truncateAtAttackClause(String s) =>
    s.replaceAll(_attackClause, '').trim();

final _colonBody = RegExp(
    r'\b(the|a|an|is|are|takes|creature|target|fails|saving|becomes|regains|cannot)\b',
    caseSensitive: false);

/// When [n] is "Label: effect sentence", return "Label"; otherwise null
/// (leave the name as-is). Only a top-level colon (before any "(") counts, the
/// label must be a short title, and the body must read like an effect sentence —
/// so "Curse: Mummy Rot" and "Variant: Devil Summoning" are left untouched.
String? _maybeColonLabel(String n) {
  final paren = n.indexOf('(');
  final colon = n.indexOf(':');
  if (colon < 0) return null;
  if (paren >= 0 && colon > paren) return null; // colon lives inside parens
  final label = n.substring(0, colon).trim();
  final body = n.substring(colon + 1).trim();
  if (label.isEmpty || label.length > 32) return null;
  if (label.split(RegExp(r'\s+')).length > 5) return null;
  if (RegExp(r'^(the|a|an|if|while|when)\b', caseSensitive: false)
      .hasMatch(label)) {
    return null;
  }
  final bodyIsSentence = body.length >= 20 && _colonBody.hasMatch(body);
  return bodyIsSentence ? label : null;
}

/// True only for clearly-spurious full-sentence names (mis-split flavor,
/// legendary-action preamble, or orphaned rule continuations). Conservative:
/// real titles like "Scholar of the Ages", "Versatility of the Elder
/// Elementals", "Keen Hearing and Smell" have ≤2 lowercase-initial words and
/// pass through. A title's only lowercase words are articles/prepositions; a
/// mis-split sentence carries ≥4 lowercase-initial words.
bool _looksLikeSentenceFragment(String n) {
  final core = n.replaceAll(RegExp(r'\s*\([^()]*\)\s*$'), '').trim();
  if (RegExp(r'\blegendary actions?\b', caseSensitive: false).hasMatch(core)) {
    return true; // "The aboleth can take 2 legendary actions" preamble.
  }
  if (RegExp(r'[.!?]\s+\S').hasMatch(core)) return true; // multiple sentences.
  final words = core.split(RegExp(r'\s+'));
  final lower = words.where((w) => RegExp(r'^[a-z]').hasMatch(w)).length;
  if (lower >= 4) return true;
  if (core.length > 45 && words.length >= 7) return true;
  return false;
}

Map<String, dynamic> _traitRow(Fixture t, String source) {
  final desc = (t['desc'] as String?)?.trim() ?? '';
  return packEntity(
    slug: 'trait',
    name: (t['name'] as String?)?.trim() ?? 'Trait',
    description: desc,
    source: source,
    attributes: {
      'source': source,
      'trait_kind': 'Other',
      'description': desc,
    },
  );
}

Map<String, dynamic> _actionRow(
    Fixture a, Fixture? attack, String source, Normalizer norm) {
  final desc = _formQualified(a, (a['desc'] as String?)?.trim() ?? '');
  final usesType = (a['uses_type'] as String?)?.toUpperCase();
  final usesParam = _int(a['uses_param']);
  final attrs = <String, dynamic>{
    'source': source,
    'action_type': _actionType(a['action_type'] as String?),
    'description': desc,
    'is_attack': attack != null || _descIsAttack(desc),
    'recharge_kind': _rechargeKind(usesType),
  };
  if (usesType == 'RECHARGE_ON_ROLL' && usesParam != null) {
    attrs['recharge_min_roll'] = usesParam; // "Recharge 5–6" → 5.
  } else if (usesType == 'PER_DAY' && usesParam != null) {
    attrs['uses_per_day'] = usesParam;
  }
  // **R3 / F-pass0-28.** A legendary action can spend more than one of the
  // creature's per-round legendary actions. 1 is the rule's default and needs
  // no field; anything above it is a mechanic that was reaching the card only
  // by accident, when the v1 recovery happened to carry it inside the name.
  final legendaryCost = _int(a['legendary_action_cost']);
  if (legendaryCost != null && legendaryCost > 1) {
    attrs['legendary_action_cost'] = legendaryCost.clamp(1, 5);
  }

  if (attack != null) {
    final toHit = attack['to_hit_mod'];
    if (toHit is int) attrs['attack_bonus'] = toHit;
    final reach = attack['reach'];
    final range = attack['range'];
    final isWeapon =
        (attack['attack_type'] as String?)?.toUpperCase() == 'WEAPON';
    final melee = reach != null && range == null;
    attrs['attack_kind'] = (isWeapon
            ? (melee ? 'Melee Weapon' : 'Ranged Weapon')
            : (melee ? 'Melee Spell' : 'Ranged Spell'));
    if (reach is num) attrs['reach_ft'] = reach.round();
    if (range is num) attrs['range_normal_ft'] = range.round();
    final long = attack['long_range'];
    if (long is num) attrs['range_long_ft'] = long.round();

    final dice = _attackDamageDice(attack);
    if (dice != null) attrs['damage_dice'] = dice;
    final dtype = _primaryDamageType(attack);
    if (dtype != null) {
      final r = norm.lookupRef('damage-type', dtype, context: 'creature-action');
      if (r != null) attrs['damage_type_ref'] = r;
    }
  }

  return packEntity(
    slug: 'creature-action',
    name: (a['name'] as String?)?.trim() ?? 'Action',
    description: desc,
    source: source,
    attributes: attrs,
  );
}

/// A `creature-action` recovered from a v1 `Monster.*_json` column (audit
/// **B8**). v1 carries only a name and the statblock prose, so the structured
/// attack attributes `_actionRow` derives from CreatureActionAttack are simply
/// absent — the row is deliberately not reverse-engineered out of the text.
Map<String, dynamic> _v1ActionRow(
        String name, String desc, String bucket, String source) =>
    packEntity(
      slug: 'creature-action',
      name: name,
      description: desc,
      source: source,
      attributes: <String, dynamic>{
        'source': source,
        'action_type': _actionType(bucket),
        'description': desc,
        'is_attack': _descIsAttack(desc),
        'recharge_kind': 'None',
      },
    );

/// **R2 / F-pass0-25.** `is_attack` used to mean "a CreatureActionAttack row
/// exists", which is not what the source says: `tob3` ships no attack fixture
/// at all, so all 1,577 of its actions claimed *not* to be attacks — 681 rows
/// corpus-wide whose own text opens with "Melee Weapon Attack:". The schema
/// field is a bool with no "unknown", so read the text the source did write.
final _attackOpener = RegExp(
    r'^\**\s*(?:Melee|Ranged)(?:\s+or\s+(?:Melee|Ranged))?\s+'
    r'(?:Weapon|Spell)\s+Attack\s*:',
    caseSensitive: false);

bool _descIsAttack(String desc) => _attackOpener.hasMatch(desc.trimLeft());

/// **R2 / F-pass0-21.** `limited_to_form` ("Skunk Form Only") is filled on 262
/// rows and the schema has no home for it, so a shapechanger's card showed a
/// form-locked attack as unconditional. Upstream's own second convention is a
/// parenthesized prefix on the text — 13 rows already ship that way — so write
/// the qualifier there rather than growing the schema.
String _formQualified(Fixture a, String desc) {
  final form = (a['limited_to_form'] as String?)?.trim() ?? '';
  if (form.isEmpty || desc.contains(form)) return desc;
  return desc.isEmpty ? '($form)' : '($form) $desc';
}

/// **R2 / F-pass0-18.** `damage_type` is filled only in the two skipped WotC
/// documents; every third-party document carries the *primary* type in
/// `extra_damage_type` instead — but that column is overloaded, holding the
/// *secondary* type on the 828 rows that really do have extra damage. The
/// filled-ness of `extra_damage_die_type` separates the two cases exactly.
String? _primaryDamageType(Fixture attack) {
  final dtype = attack['damage_type'];
  if (dtype is String && dtype.isNotEmpty) return dtype;
  final extraDie = (attack['extra_damage_die_type'] as String?)?.trim() ?? '';
  if (extraDie.isNotEmpty) return null; // genuine second damage, not the primary
  final extra = attack['extra_damage_type'];
  return (extra is String && extra.isNotEmpty) ? extra : null;
}

/// Build "XdY+Z" from a CreatureActionAttack's primary damage fields.
String? _attackDamageDice(Fixture attack) {
  final count = attack['damage_die_count'];
  final die = attack['damage_die_type']; // "D6"
  if (count is! int || die is! String || die.isEmpty) return null;
  final faces = die.replaceAll(RegExp(r'[^0-9]'), '');
  if (faces.isEmpty) return null;
  final bonus = attack['damage_bonus'];
  final b = (bonus is int && bonus != 0)
      ? (bonus > 0 ? '+$bonus' : '$bonus')
      : '';
  return '${count}d$faces$b';
}

Map<String, dynamic> _monsterRow({
  required Fixture c,
  required String source,
  required Normalizer norm,
  required List<Map<String, String>> traitRefs,
  required List<Map<String, String>> actionRefs,
  required List<Map<String, String>> bonusRefs,
  required List<Map<String, String>> reactionRefs,
  required List<Map<String, String>> legendaryRefs,
  required List<Map<String, String>> lairRefs,
  String? v1Subtype,
  bool alignmentIsCollapsed = false,
  int? v1LegendaryUses,
  String? v1Senses,
}) {
  final name = _cleanMonsterName((c['name'] as String?)?.trim() ?? 'Unknown');
  final stats = {
    'STR': _int(c['ability_score_strength']) ?? 10,
    'DEX': _int(c['ability_score_dexterity']) ?? 10,
    'CON': _int(c['ability_score_constitution']) ?? 10,
    'INT': _int(c['ability_score_intelligence']) ?? 10,
    'WIS': _int(c['ability_score_wisdom']) ?? 10,
    'CHA': _int(c['ability_score_charisma']) ?? 10,
  };
  final dexMod = abilityModifier(stats['DEX']!);
  final cr = _crString(c['challenge_rating']);
  final pb = _int(c['proficiency_bonus']) ?? _profForCr(cr);

  final attrs = <String, dynamic>{
    'ac': _int(c['armor_class']) ?? 10,
    'initiative_modifier': _int(c['initiative_bonus']) ?? dexMod,
    'initiative_score': 10 + (_int(c['initiative_bonus']) ?? dexMod),
    'hp_average': _int(c['hit_points']) ?? 1,
    'speed_walk_ft': _int(c['walk']) ?? 30,
    'stat_block': stats,
    'cr': cr,
    'xp': _int(c['experience_points_integer']) ?? _xpForCr(cr),
    'proficiency_bonus': pb,
    'passive_perception': _int(c['passive_perception']) ?? (10 + abilityModifier(stats['WIS']!)),
    'action_refs': actionRefs,
  };

  // B11: `hit_dice` is null on every row of some documents (all 360 of bfrd's).
  // No die pool is truer than a fabricated one — omit rather than default.
  final hitDice = (c['hit_dice'] as String?)?.trim();
  if (hitDice != null && hitDice.isNotEmpty) attrs['hp_dice'] = hitDice;

  // Identity refs (skip silently-unknown → logged in sink).
  final size = norm.lookupRef('size', (c['size'] as String?) ?? '', context: name);
  if (size != null) attrs['size_ref'] = size;
  _creatureType(c['type'] as String?, name, norm, attrs, v1Subtype: v1Subtype);
  if (!alignmentIsCollapsed) {
    _alignment(c['alignment'] as String?, name, norm, attrs);
  }
  final acDetail = (c['armor_detail'] as String?)?.trim();
  if (acDetail != null && acDetail.isNotEmpty) attrs['ac_note'] = acDetail;

  // Extra speeds.
  _speed(c['burrow'], 'speed_burrow_ft', attrs);
  _speed(c['climb'], 'speed_climb_ft', attrs);
  _speed(c['fly'], 'speed_fly_ft', attrs);
  _speed(c['swim'], 'speed_swim_ft', attrs);
  if (c['hover'] == true) attrs['can_hover'] = true;

  // Senses (sense + range).
  final senses = <Map<String, dynamic>>[];
  _sense(norm, c['darkvision_range'], 'Darkvision', senses);
  _sense(norm, c['blindsight_range'], 'Blindsight', senses);
  _sense(norm, c['tremorsense_range'], 'Tremorsense', senses);
  _sense(norm, c['truesight_range'], 'Truesight', senses);
  _v1Senses(norm, v1Senses, senses);
  if (senses.isNotEmpty) attrs['senses'] = senses;
  final tele = _int(c['telepathy_range']);
  if (tele != null && tele > 0) attrs['telepathy_ft'] = tele;

  // Languages.
  final langs = (c['languages'] as List?)?.cast<dynamic>() ?? const [];
  final langRefs = norm.lookupRefList(
      'language', langs.map((e) => e.toString()), context: name);
  if (langRefs.isNotEmpty) attrs['language_refs'] = langRefs;
  final langNote = _languageNote(c['languages_desc'] as String?, langRefs);
  if (langNote != null) attrs['language_note'] = langNote;

  // Defenses (damage / condition).
  _dmgList(c['damage_resistances'], 'resistance_refs', norm, name, attrs);
  _dmgList(c['damage_vulnerabilities'], 'vulnerability_refs', norm, name, attrs);
  _dmgList(c['damage_immunities'], 'damage_immunity_refs', norm, name, attrs);
  _qualifierNote(c, 'nonmagical_attack_resistance',
      'damage_resistances_display', 'resistance_note', attrs);
  _qualifierNote(c, 'nonmagical_attack_immunity', 'damage_immunities_display',
      'immunity_note', attrs);
  final condImm = (c['condition_immunities'] as List?)?.cast<dynamic>() ?? const [];
  final condRefs = norm.lookupRefList(
      'condition', condImm.map((e) => e.toString()), context: name);
  if (condRefs.isNotEmpty) attrs['condition_immunity_refs'] = condRefs;

  // Saves / skills (proficiency tables) — only when the creature has any.
  final saves = _saveTable(c, stats, pb);
  if (saves != null) attrs['save_bonuses'] = saves;
  final skills = _skillTable(c, stats, pb);
  if (skills != null) attrs['skill_bonuses'] = skills;

  // Action-economy refs.
  if (traitRefs.isNotEmpty) attrs['trait_refs'] = traitRefs;
  if (bonusRefs.isNotEmpty) attrs['bonus_action_refs'] = bonusRefs;
  if (reactionRefs.isNotEmpty) attrs['reaction_refs'] = reactionRefs;
  if (legendaryRefs.isNotEmpty) {
    attrs['legendary_action_refs'] = legendaryRefs;
    // **R2 / F-tob-01.** v2 has no column for the count, but v1's
    // `legendary_desc` prose states it ("can take 1 legendary action") and the
    // pipeline already reads that file for `tags_line`. Where the source is
    // silent the SRD default of 3 still stands.
    attrs['legendary_action_uses'] = v1LegendaryUses ?? 3;
  }
  if (lairRefs.isNotEmpty) attrs['lair_action_refs'] = lairRefs;

  // 'action_refs' is required by the schema; guarantee at least an empty list
  // (handled above by always assigning, even if empty).

  return packEntity(
    slug: 'monster',
    name: name,
    description: '',
    source: source,
    attributes: attrs,
  );
}

void _creatureType(
    String? raw, String name, Normalizer norm, Map<String, dynamic> attrs,
    {String? v1Subtype}) {
  if (raw == null || raw.trim().isEmpty) return;
  // "humanoid (elf)" → type "humanoid", tags "(elf)".
  final m = RegExp(r'^([^(]+?)\s*(\(.*\))?$').firstMatch(raw.trim());
  final base = (m?.group(1) ?? raw).trim();
  final tag = m?.group(2);
  final r = norm.lookupRef('creature-type', base, context: name);
  if (r != null) attrs['creature_type_ref'] = r;
  // The parenthesised form never occurs in v2 — measured 0 of 3,541 rows: the
  // v2 conversion moved the subtype into its own column and then dropped it.
  // v1's `Monster.subtype` still has it, so `tags_line` is a v1 backfill for
  // the same reason B8's actions are (audit B5).
  final sub = (tag != null && tag.isNotEmpty)
      ? tag
      : (v1Subtype != null && v1Subtype.trim().isNotEmpty)
          ? '(${v1Subtype.trim()})'
          : null;
  if (sub != null) attrs['tags_line'] = sub;
}

/// Audit **B10**. `Creature.alignment` is free text and only some of it is one
/// of the nine canonical alignments. Three outcomes, in order:
///
/// * canonical (`"neutral good"`) → `alignment_ref`;
/// * an alignment *expression* — wildcards (`"any evil alignment"`), compounds
///   (`"chaotic neutral or chaotic evil"`), weights (`"neutral evil (50%) …"`) →
///   `alignment_note` prose with **no** ref. A single relation cannot hold
///   "any chaotic", and coercing one would be B11's fabrication again;
/// * neither → dropped and logged. This is only the three rows corrupt in
///   `Creature.json` itself (`"Titan)"`, `"Shapechanger)"`), which are not
///   alignments at all and must not be shipped as prose.
void _alignment(
    String? raw, String name, Normalizer norm, Map<String, dynamic> attrs) {
  final v = raw?.trim() ?? '';
  if (v.isEmpty) return;
  if (norm.canonical('alignment', v) != null) {
    final r = norm.lookupRef('alignment', v, context: name);
    if (r != null) attrs['alignment_ref'] = r;
    return;
  }
  if (_alignmentWords.hasMatch(v)) {
    attrs['alignment_note'] = v;
    return;
  }
  norm.unmapped.add('alignment', v, context: name);
}

/// Any word that only appears in an alignment expression: the axis names plus
/// `any`, which is what every wildcard form opens with (`"any non-lawful"`).
final _alignmentWords =
    RegExp(r'\b(any|lawful|chaotic|neutral|good|evil|unaligned)\b',
        caseSensitive: false);

void _speed(dynamic v, String key, Map<String, dynamic> attrs) {
  final n = _int(v);
  if (n != null && n > 0) attrs[key] = n;
}

/// **R3.** `rangedSenseList` rows are `{sense_ref, range_ft}` — the shape
/// `species.granted_senses` has used since B3 and the only one
/// `RangedSenseListFieldWidget` reads. Monsters were writing a bare
/// `{sense: 'Darkvision'}` string, so every sense row on every monster card
/// rendered with an empty sense picker.
void _sense(Normalizer norm, dynamic range, String sense,
    List<Map<String, dynamic>> out) {
  final n = _int(range);
  if (n == null || n <= 0) return;
  final r = _senseRef(norm, sense);
  if (r != null) out.add({'sense_ref': r, 'range_ft': n});
}

/// A `sense` ref from the built-in Tier-0 canon, or — for a sense only a
/// third-party document has — a row minted **inside the pack** (F-pass0-23,
/// the `Void Speech` pattern). The SRD vocabulary never grows a keensense.
Map<String, String>? _senseRef(Normalizer norm, String name) {
  final canonical = norm.canonical('sense', name);
  if (canonical != null) return lookup('sense', canonical);
  return norm.tier0Seeder?.call('sense', titleCaseName(name));
}

/// Clauses of the v1 `senses` prose that are not a sense name: the four v2
/// already has a column for, and `or …` — a continuation of the clause before
/// it ("blindsight 30 ft., or 10 ft. while deafened"), never a sense of its own.
const _v1KnownSenses = [
  'darkvision', 'blindsight', 'truesight', 'tremorsense', 'passive perception',
  'or ',
];

/// `"keensense 60 ft. (can't sense beyond this radius)"` → a `senses` row.
///
/// **R3 / F-pass0-23.** Black Flag replaces darkvision with **keensense**, and
/// v2 has no column for it: `darkvision_range` does not exist in that document
/// at all, so 41 of its creatures ship senseless. The name and the range are
/// both in v1's `senses` prose, which the pipeline already loads for
/// `tags_line`. A range is required — a sense with no distance is not a
/// statblock row, and guessing one would be inventing rules.
void _v1Senses(Normalizer norm, String? prose,
    List<Map<String, dynamic>> out) {
  if (prose == null || prose.trim().isEmpty) return;
  final have = {
    for (final r in out)
      ((r['sense_ref'] as Map?)?['name'] as String? ?? '').toLowerCase(),
  };
  for (final part in prose.split(',')) {
    final low = part.trim().toLowerCase();
    if (low.isEmpty || _v1KnownSenses.any(low.startsWith)) continue;
    final m = RegExp(r"^([a-z][a-z' ]*[a-z])\s+(\d+)\s*(?:ft|feet)").firstMatch(low);
    if (m == null) continue;
    final sense = m.group(1)!.trim();
    if (!have.add(sense)) continue;
    final r = _senseRef(norm, sense);
    if (r != null) {
      out.add({'sense_ref': r, 'range_ft': int.parse(m.group(2)!)});
    }
  }
}

/// **R3 / F-pass0-19.** The qualifier lives in a boolean beside the list:
/// `damage_resistances` says `[bludgeoning, piercing, slashing]` while
/// `nonmagical_attack_resistance` says those three only apply to non-magical
/// attacks. Published without it the card claims resistance to a +1 sword —
/// a wrong value, not a missing one. The source's own display sentence is the
/// note, so nothing is paraphrased.
void _qualifierNote(Fixture c, String flagKey, String displayKey, String noteKey,
    Map<String, dynamic> attrs) {
  if (c[flagKey] != true) return;
  final display = (c[displayKey] as String?)?.trim() ?? '';
  if (display.isEmpty) return;
  attrs[noteKey] = display;
}

/// **R3 / F-pass0-20.** `languages_desc` carries the sentence the M2M list
/// cannot: *"understands Common but can't speak"*, *"all, telepathy 120 ft."*,
/// *"the languages it knew in life"*. Written only when the prose says
/// something the resolved refs (plus the separate `telepathy_ft` column) do
/// not already state, so a creature whose list is complete gains no noise.
String? _languageNote(String? prose, List<Map<String, String>> refs) {
  final desc = (prose ?? '').trim();
  if (desc.isEmpty || desc == '-') return null;
  final known = {for (final r in refs) (r['name'] ?? '').toLowerCase()};
  for (final part in desc.split(RegExp(r'[,;]'))) {
    final low = part.replaceAll(RegExp(r'\([^)]*\)'), '').trim().toLowerCase();
    if (low.isEmpty || low == '-' || low.startsWith('telepathy')) continue;
    if (!known.contains(low)) return desc;
  }
  return null;
}

void _dmgList(dynamic raw, String key, Normalizer norm, String ctx,
    Map<String, dynamic> attrs) {
  final list = (raw as List?)?.cast<dynamic>() ?? const [];
  final refs =
      norm.lookupRefList('damage-type', list.map((e) => e.toString()), context: ctx);
  if (refs.isNotEmpty) attrs[key] = refs;
}

/// Build a proficiencyTable for saving throws, or null if none are set.
Map<String, dynamic>? _saveTable(Fixture c, Map<String, int> stats, int pb) {
  const map = {
    'Strength': ['saving_throw_strength', 'STR'],
    'Dexterity': ['saving_throw_dexterity', 'DEX'],
    'Constitution': ['saving_throw_constitution', 'CON'],
    'Intelligence': ['saving_throw_intelligence', 'INT'],
    'Wisdom': ['saving_throw_wisdom', 'WIS'],
    'Charisma': ['saving_throw_charisma', 'CHA'],
  };
  final base = proficiencyTableDefault(kDnd5eSavingThrows);
  var any = false;
  for (final row in (base['rows'] as List).cast<Map<String, dynamic>>()) {
    final spec = map[row['name']]!;
    final bonus = _int(c[spec[0]]);
    if (bonus == null) continue;
    any = true;
    final mod = abilityModifier(stats[spec[1]]!);
    row['proficient'] = true;
    row['misc'] = bonus - mod - pb;
  }
  return any ? base : null;
}

/// Build a proficiencyTable for skills, or null if none are set.
Map<String, dynamic>? _skillTable(Fixture c, Map<String, int> stats, int pb) {
  // skill name → (fixture key, ability) from kDnd5eSkills presets.
  final base = proficiencyTableDefault(kDnd5eSkills);
  var any = false;
  for (final row in (base['rows'] as List).cast<Map<String, dynamic>>()) {
    final skill = row['name'] as String;
    final key = 'skill_bonus_${skill.toLowerCase().replaceAll(' ', '_')}';
    final bonus = _int(c[key]);
    if (bonus == null) continue;
    any = true;
    final mod = abilityModifier(stats[row['ability']]!);
    row['proficient'] = true;
    row['misc'] = bonus - mod - pb;
  }
  return any ? base : null;
}

int? _int(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is num) return v.round();
  if (v is String) {
    final d = double.tryParse(v);
    return d?.round();
  }
  return null;
}

String _actionType(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'BONUS_ACTION':
      return 'Bonus Action';
    case 'REACTION':
      return 'Reaction';
    case 'LEGENDARY_ACTION':
      return 'Legendary Action';
    case 'LAIR_ACTION':
      return 'Lair Action';
    default:
      return 'Action';
  }
}

String _rechargeKind(String? usesType) {
  switch (usesType?.toUpperCase()) {
    case 'RECHARGE_ON_ROLL':
      return 'Roll';
    case 'RECHARGE_AFTER_REST':
      return 'Short Rest';
    default:
      return 'None';
  }
}

/// "7.000" → "7", "0.250" → "1/4", "0.125" → "1/8", "0.500" → "1/2".
String _crString(dynamic raw) {
  final d = (raw is num) ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
  if (d == null) return '0';
  if (d == 0) return '0';
  if ((d - 0.125).abs() < 0.01) return '1/8';
  if ((d - 0.25).abs() < 0.01) return '1/4';
  if ((d - 0.5).abs() < 0.01) return '1/2';
  return d.round().toString();
}

int _profForCr(String cr) {
  final n = _crNumeric(cr);
  if (n <= 4) return 2;
  if (n <= 8) return 3;
  if (n <= 12) return 4;
  if (n <= 16) return 5;
  if (n <= 20) return 6;
  if (n <= 24) return 7;
  if (n <= 28) return 8;
  return 9;
}

double _crNumeric(String cr) {
  switch (cr) {
    case '1/8':
      return 0.125;
    case '1/4':
      return 0.25;
    case '1/2':
      return 0.5;
    default:
      return double.tryParse(cr) ?? 0;
  }
}

const _xpByCr = <String, int>{
  '0': 10, '1/8': 25, '1/4': 50, '1/2': 100, '1': 200, '2': 450, '3': 700,
  '4': 1100, '5': 1800, '6': 2300, '7': 2900, '8': 3900, '9': 5000,
  '10': 5900, '11': 7200, '12': 8400, '13': 10000, '14': 11500, '15': 13000,
  '16': 15000, '17': 18000, '18': 20000, '19': 22000, '20': 25000, '21': 33000,
  '22': 41000, '23': 50000, '24': 62000, '25': 75000, '26': 90000, '27': 105000,
  '28': 120000, '29': 135000, '30': 155000,
};

int _xpForCr(String cr) => _xpByCr[cr] ?? 0;
