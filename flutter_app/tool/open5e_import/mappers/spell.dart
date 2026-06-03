// Map v2 Open5e `Spell.json` rows onto the app's `spell` package entity.
//
// Depth = stats + descriptive text (per plan): every typed field the app's
// spell schema carries is filled (level, school, casting time, range,
// components, duration, save, damage types, conditions). The originating class
// list is stored as entity *tags* rather than `class_refs` — a spell package
// ships no class entities of its own, so an inter-entity `_ref` would dangle.
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/_helpers.dart';

import '../loaders.dart';
import '../normalize.dart';
import '../refgraph.dart';

/// v2 `school` slug → canonical app spell-school name. Most title-case 1:1;
/// only the a5e variant "transformation" needs folding.
const _schoolAlias = {'transformation': 'Transmutation'};

/// Map all spells in a document into [pack].
///
/// [v1ClassByName] maps `spellNameLower → v1 dnd_class` string and is used to
/// recover class linkage for spells whose v2 `classes` field is empty (true for
/// most 3rd-party docs — KP/ToH/Warlock/A5E). See `bin/build_packs.dart`.
void mapSpells({
  required PackBuilder pack,
  required Normalizer norm,
  required String source,
  required List<Fixture> spells,
  Map<String, String> v1ClassByName = const {},
}) {
  for (final s in spells) {
    final name = (s['name'] as String?)?.trim();
    if (name == null || name.isEmpty) continue;

    final attrs = <String, dynamic>{
      'level': (s['level'] as num?)?.toInt() ?? 0,
      'is_ritual': s['ritual'] == true,
      'requires_concentration': s['concentration'] == true,
      'description': _description(s),
    };

    // School.
    final schoolRaw = (s['school'] as String?)?.trim() ?? '';
    final school = norm.lookupRef(
        'spell-school', _schoolAlias[schoolRaw.toLowerCase()] ?? schoolRaw,
        context: name);
    if (school != null) attrs['school_ref'] = school;

    // Casting time → amount + unit.
    final ct = _castingTime((s['casting_time'] as String?) ?? 'action');
    attrs['casting_time_amount'] = ct.$1;
    final ctUnit = norm.lookupRef('casting-time-unit', ct.$2, context: name);
    if (ctUnit != null) attrs['casting_time_unit_ref'] = ctUnit;

    // Range.
    final range = _range(s);
    attrs['range_type'] = range.$1;
    if (range.$2 != null) attrs['range_ft'] = range.$2;

    // Components (V/S/M booleans → Tier-0 casting-component rows).
    final comps = <String>[
      if (s['verbal'] == true) 'Verbal',
      if (s['somatic'] == true) 'Somatic',
      if (s['material'] == true) 'Material',
    ];
    attrs['components'] = norm.lookupRefList('casting-component', comps);
    final material = (s['material_specified'] as String?)?.trim();
    if (material != null && material.isNotEmpty) {
      attrs['material_description'] = material;
      final cost = _numOf(s['material_cost']);
      if (cost != null) attrs['material_cost_gp'] = cost;
      attrs['material_consumed'] = s['material_consumed'] == true;
    }

    // Duration → amount + unit.
    final dur = _duration((s['duration'] as String?) ?? '');
    if (dur.$1 != null) attrs['duration_amount'] = dur.$1;
    final durUnit = norm.lookupRef('duration-unit', dur.$2, context: name);
    if (durUnit != null) attrs['duration_unit_ref'] = durUnit;

    // Damage types.
    final dmg = (s['damage_types'] as List?)?.cast<String>() ?? const [];
    if (dmg.isNotEmpty) {
      attrs['damage_type_refs'] =
          norm.lookupRefList('damage-type', dmg, context: name);
    }

    // Save ability.
    final save = (s['saving_throw_ability'] as String?)?.trim() ?? '';
    if (save.isNotEmpty) {
      final ref = norm.lookupRef('ability', save, context: name);
      if (ref != null) attrs['save_ability_ref'] = ref;
    }

    // Spell attack.
    if (s['attack_roll'] == true) {
      attrs['attack_type'] = (range.$2 ?? 0) > 5 ? 'Ranged' : 'Melee';
    }

    // Classes → tags (descriptive; not inter-entity refs). v2 carries the
    // linkage in `classes`; when empty (most 3rd-party docs) fall back to the
    // v1 `dnd_class` string indexed by spell name.
    final v2classes = (s['classes'] as List?)?.cast<String>() ?? const [];
    final tags = v2classes.isNotEmpty
        ? _classTags(v2classes)
        : _classTagsFromV1(v1ClassByName[name.toLowerCase()]);

    pack.add(packEntity(
      slug: 'spell',
      name: name,
      description: attrs['description'] as String,
      source: source,
      tags: tags,
      attributes: attrs,
    ));
  }
}

String _description(Fixture s) {
  final desc = (s['desc'] as String?)?.trim() ?? '';
  final higher = (s['higher_level'] as String?)?.trim() ?? '';
  if (higher.isEmpty) return desc;
  return '$desc\n\n**At Higher Levels.** $higher';
}

/// `'10minutes'` → `(10, 'Minute')`, `'bonus-action'` → `(1, 'Bonus Action')`.
(int, String) _castingTime(String raw) {
  final m = RegExp(r'^(\d+)?\s*([a-z][a-z-]*)$').firstMatch(raw.trim().toLowerCase());
  final amount = int.tryParse(m?.group(1) ?? '') ?? 1;
  final word = m?.group(2) ?? raw.toLowerCase();
  switch (word) {
    case 'action':
      return (amount, 'Action');
    case 'bonus':
    case 'bonus-action':
      return (amount, 'Bonus Action');
    case 'reaction':
      return (amount, 'Reaction');
    case 'minute':
    case 'minutes':
      return (amount, 'Minute');
    case 'hour':
    case 'hours':
      return (amount, 'Hour');
    default:
      return (amount, 'Special');
  }
}

/// Spell range → (`range_type`, `range_ft?`). Prefers the structured
/// `range`/`range_unit` numeric fields; falls back to `range_text` keywords.
(String, int?) _range(Fixture s) {
  final unit = (s['range_unit'] as String?)?.trim().toLowerCase();
  final value = _numOf(s['range']);
  if (unit == 'feet' || unit == 'ft') {
    return ('Ranged', value?.round());
  }
  if (unit == 'miles' || unit == 'mi') {
    return ('Ranged', value == null ? null : (value * 5280).round());
  }
  if (unit == 'any') return ('Unlimited', null);

  final text = (s['range_text'] as String?)?.trim() ?? '';
  final lc = text.toLowerCase();
  if (lc.startsWith('self')) return ('Self', null);
  if (lc.startsWith('touch')) return ('Touch', null);
  if (lc.startsWith('sight')) return ('Sight', null);
  if (lc.startsWith('unlimited') || lc.startsWith('special')) {
    return (lc.startsWith('unlimited') ? 'Unlimited' : 'Ranged', null);
  }
  final n = RegExp(r'(\d+)').firstMatch(text);
  if (n != null) {
    final ft = int.parse(n.group(1)!);
    return ('Ranged', lc.contains('mile') ? ft * 5280 : ft);
  }
  return ('Ranged', null);
}

/// Spell duration → (`amount?`, `unit`). Maps the long tail of free-text
/// 3rd-party durations onto the six canonical duration-unit rows; anything we
/// can't parse becomes "Special" (a canonical row, so never logged as unmapped).
(int?, String) _duration(String raw) {
  final d = raw.trim().toLowerCase();
  if (d.isEmpty) return (null, 'Special');
  if (d.startsWith('instantaneous')) return (null, 'Instantaneous');
  if (d.contains('dispelled')) return (null, 'Until Dispelled');
  if (d.startsWith('permanent')) return (null, 'Until Dispelled');
  final m = RegExp(r'(\d+)\s*(round|minute|hour|day)s?').firstMatch(d);
  if (m != null) {
    final amount = int.parse(m.group(1)!);
    const unit = {
      'round': 'Rounds',
      'minute': 'Minutes',
      'hour': 'Hours',
      'day': 'Days',
    };
    return (amount, unit[m.group(2)]!);
  }
  return (null, 'Special');
}

/// `['srd_wizard', 'kp_cleric']` → `['Wizard', 'Cleric']` (deduped, ordered).
List<String> _classTags(List<String> classes) {
  final seen = <String>{};
  final out = <String>[];
  for (final c in classes) {
    final base = c.contains('_') ? c.substring(c.lastIndexOf('_') + 1) : c;
    final name = titleCase(base);
    if (name.isNotEmpty && seen.add(name)) out.add(name);
  }
  return out;
}

/// Known v1 `dnd_class` misspellings/aliases → canonical class name so the
/// app's class-name match (`spell.tags` ↔ class name) lands.
const _v1ClassFix = {'Sorceror': 'Sorcerer'};

/// `'Druid, Ranger, Sorceror, Wizard'` → `['Druid','Ranger','Sorcerer','Wizard']`
/// (deduped, ordered). Recovers class tags from the v1 comma-string when v2 has
/// none. Non-class tokens (e.g. 'Ritual Caster') pass through harmlessly — they
/// simply match no class.
List<String> _classTagsFromV1(String? dndClass) {
  if (dndClass == null || dndClass.trim().isEmpty) return const [];
  final seen = <String>{};
  final out = <String>[];
  for (final part in dndClass.split(',')) {
    var name = titleCase(part.trim());
    name = _v1ClassFix[name] ?? name;
    if (name.isNotEmpty && seen.add(name)) out.add(name);
  }
  return out;
}

double? _numOf(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}
