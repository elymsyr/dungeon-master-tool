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

/// Map all creatures in a document into [pack]. Child actions/traits are
/// deduped within the package by content so shared rows are authored once.
void mapCreatures({
  required PackBuilder pack,
  required Normalizer norm,
  required String source,
  required List<Fixture> creatures,
  required List<Fixture> actions,
  required List<Fixture> attacks,
  required List<Fixture> traits,
}) {
  final actionsByCreature = groupBy(actions, 'parent');
  final traitsByCreature = groupBy(traits, 'parent');
  final attacksByAction = groupBy(attacks, 'parent');

  // Dedup child entities (action/trait) across creatures: content-hash → name.
  final childNameByHash = <String, String>{};

  for (final c in creatures) {
    final pk = c['_pk'].toString();
    final cname = _cleanMonsterName((c['name'] as String?)?.trim() ?? 'Unknown');

    // ── Build child trait entities + collect refs ──
    final traitRefs = <Map<String, String>>[];
    for (final t in traitsByCreature[pk] ?? const <Fixture>[]) {
      final cleaned = _cleanChildName(
        (t['name'] as String?)?.trim() ?? 'Trait',
        (t['desc'] as String?)?.trim() ?? '',
        'trait',
      );
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
    for (final a in actionsByCreature[pk] ?? const <Fixture>[]) {
      final apk = a['_pk'].toString();
      final attack =
          (attacksByAction[apk] ?? const <Fixture>[]).cast<Fixture?>().firstWhere(
                (x) => true,
                orElse: () => null,
              );
      final cleaned = _cleanChildName(
        (a['name'] as String?)?.trim() ?? 'Action',
        (a['desc'] as String?)?.trim() ?? '',
        'creature-action',
      );
      if (cleaned == null) continue; // spurious mis-segmented row → drop, no ref.
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
    ));
  }
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
  final hash = _contentHash(row);
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
  final desc = (a['desc'] as String?)?.trim() ?? '';
  final usesType = (a['uses_type'] as String?)?.toUpperCase();
  final usesParam = _int(a['uses_param']);
  final attrs = <String, dynamic>{
    'source': source,
    'action_type': _actionType(a['action_type'] as String?),
    'description': desc,
    'is_attack': attack != null,
    'recharge_kind': _rechargeKind(usesType),
  };
  if (usesType == 'RECHARGE_ON_ROLL' && usesParam != null) {
    attrs['recharge_min_roll'] = usesParam; // "Recharge 5–6" → 5.
  } else if (usesType == 'PER_DAY' && usesParam != null) {
    attrs['uses_per_day'] = usesParam;
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
    final dtype = attack['damage_type'];
    if (dtype is String && dtype.isNotEmpty) {
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
    'hp_dice': (c['hit_dice'] as String?)?.trim() ?? '1d4',
    'speed_walk_ft': _int(c['walk']) ?? 30,
    'stat_block': stats,
    'cr': cr,
    'xp': _int(c['experience_points_integer']) ?? _xpForCr(cr),
    'proficiency_bonus': pb,
    'passive_perception': _int(c['passive_perception']) ?? (10 + abilityModifier(stats['WIS']!)),
    'action_refs': actionRefs,
  };

  // Identity refs (skip silently-unknown → logged in sink).
  final size = norm.lookupRef('size', (c['size'] as String?) ?? '', context: name);
  if (size != null) attrs['size_ref'] = size;
  _creatureType(c['type'] as String?, name, norm, attrs);
  final align = c['alignment'] as String?;
  if (align != null && align.trim().isNotEmpty) {
    final r = norm.lookupRef('alignment', align, context: name);
    if (r != null) attrs['alignment_ref'] = r;
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
  _sense(c['darkvision_range'], 'Darkvision', senses);
  _sense(c['blindsight_range'], 'Blindsight', senses);
  _sense(c['tremorsense_range'], 'Tremorsense', senses);
  _sense(c['truesight_range'], 'Truesight', senses);
  if (senses.isNotEmpty) attrs['senses'] = senses;
  final tele = _int(c['telepathy_range']);
  if (tele != null && tele > 0) attrs['telepathy_ft'] = tele;

  // Languages.
  final langs = (c['languages'] as List?)?.cast<dynamic>() ?? const [];
  final langRefs = norm.lookupRefList(
      'language', langs.map((e) => e.toString()), context: name);
  if (langRefs.isNotEmpty) attrs['language_refs'] = langRefs;

  // Defenses (damage / condition).
  _dmgList(c['damage_resistances'], 'resistance_refs', norm, name, attrs);
  _dmgList(c['damage_vulnerabilities'], 'vulnerability_refs', norm, name, attrs);
  _dmgList(c['damage_immunities'], 'damage_immunity_refs', norm, name, attrs);
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
    attrs['legendary_action_uses'] = 3; // Open5e omits the count; SRD default.
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
    String? raw, String name, Normalizer norm, Map<String, dynamic> attrs) {
  if (raw == null || raw.trim().isEmpty) return;
  // "humanoid (elf)" → type "humanoid", tags "(elf)".
  final m = RegExp(r'^([^(]+?)\s*(\(.*\))?$').firstMatch(raw.trim());
  final base = (m?.group(1) ?? raw).trim();
  final tag = m?.group(2);
  final r = norm.lookupRef('creature-type', base, context: name);
  if (r != null) attrs['creature_type_ref'] = r;
  if (tag != null && tag.isNotEmpty) attrs['tags_line'] = tag;
}

void _speed(dynamic v, String key, Map<String, dynamic> attrs) {
  final n = _int(v);
  if (n != null && n > 0) attrs[key] = n;
}

void _sense(dynamic range, String sense, List<Map<String, dynamic>> out) {
  final n = _int(range);
  if (n != null && n > 0) out.add({'sense': sense, 'range_ft': n});
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
