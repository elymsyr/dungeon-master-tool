// Self-checking transform verification (no test framework — runs via
// `dart run tool/open5e_import/test/monster_mapper_check.dart`). Builds the
// Tal'Dorei pack in memory and asserts structural + field correctness so a
// regression fails the build loudly.
//
// ignore_for_file: avoid_print
import 'dart:io';

import '../loaders.dart';
import '../mappers/chargen.dart';
import '../mappers/item.dart';
import '../mappers/monster.dart';
import '../mappers/spell.dart';
import '../normalize.dart';
import '../refgraph.dart';
import '../sources.dart';

var _failures = 0;
late Normalizer _norm;

void main() {
  final dataRoot = '${Directory.current.path}/../open5e-api-staging/data';
  final docs = sourceDocs(dataRoot);
  _norm = Normalizer();

  _checkTdcs(docs);
  _checkTob(docs);
  _checkSpells(docs);
  _checkMagicItems(docs);
  _checkChargen(docs);

  if (_failures > 0) {
    print('FAILED: $_failures check(s)');
    exit(1);
  }
  print('All checks passed.');
}

void check(String label, bool ok) {
  if (!ok) {
    _failures++;
    print('  ✗ $label');
  } else {
    print('  ✓ $label');
  }
}

PackBuilder _build(SourceDoc doc) {
  final pack = PackBuilder(doc.packageName);
  mapCreatures(
    pack: pack,
    norm: _norm,
    source: doc.title,
    creatures: loadFixtures(doc.v2File('Creature.json')),
    actions: loadFixtures(doc.v2File('CreatureAction.json')),
    attacks: loadFixtures(doc.v2File('CreatureActionAttack.json')),
    traits: loadFixtures(doc.v2File('CreatureTrait.json')),
  );
  return pack;
}

List<Map> _monsters(PackBuilder p) => p.entities.values
    .where((e) => (e as Map)['type'] == 'monster')
    .cast<Map>()
    .toList();

void _assertCanonicalLookups(PackBuilder pack, String label) {
  final bad = <String>[];
  _walkLookups(pack.entities, (slug, name) {
    if (_norm.canonical(slug, name) == null) bad.add('$slug:$name');
  });
  check('$label: all lookups canonical (${bad.take(5).join(", ")})', bad.isEmpty);
}

// Fields that hold inter-entity `_ref`s (resolve to uuids). Tier-0 lookup
// fields (language_refs, resistance_refs, …) stay as `{_lookup,name}` maps and
// are intentionally excluded.
const _entityRefKeys = {
  'trait_refs',
  'action_refs',
  'bonus_action_refs',
  'reaction_refs',
  'legendary_action_refs',
  'lair_action_refs',
};

void _assertRefsResolved(PackBuilder pack, String label) {
  final dangling = <String>[];
  for (final e in pack.entities.values) {
    final attrs = (e as Map)['attributes'] as Map;
    for (final key in _entityRefKeys) {
      final v = attrs[key];
      if (v is List) {
        for (final item in v) {
          if (item is! String || item.length != 36) {
            dangling.add('${e['name']}.$key');
          }
        }
      }
    }
  }
  check('$label: entity refs resolved to uuids (${dangling.take(3).join(", ")})',
      dangling.isEmpty);
}

void _checkTdcs(List<SourceDoc> docs) {
  print("Tal'Dorei:");
  final pack = _build(docs.firstWhere((d) => d.slug == 'tdcs'));
  final unresolved = pack.resolveRefs();
  check('no unresolved refs (${unresolved.length})', unresolved.isEmpty);
  final monsters = _monsters(pack);
  check('4 monsters mapped', monsters.length == 4);
  _assertCanonicalLookups(pack, 'tdcs');
  _assertRefsResolved(pack, 'tdcs');

  final fa = monsters.firstWhere((m) => m['name'] == 'Firetamer')['attributes'] as Map;
  check('Firetamer ac=17', fa['ac'] == 17);
  check('Firetamer hp=92', fa['hp_average'] == 92);
  check('Firetamer cr=7', fa['cr'] == '7');
  check('Firetamer xp=2900', fa['xp'] == 2900);
  check('Firetamer pb=3', fa['proficiency_bonus'] == 3);
  check('Firetamer STR=8', (fa['stat_block'] as Map)['STR'] == 8);
  check('every monster has action_refs',
      monsters.every((m) => (m['attributes'] as Map)['action_refs'] != null));
}

void _checkTob(List<SourceDoc> docs) {
  print('Tome of Beasts:');
  final pack = _build(docs.firstWhere((d) => d.slug == 'tob'));
  final unresolved = pack.resolveRefs();
  check('no unresolved refs (${unresolved.length})', unresolved.isEmpty);
  final monsters = _monsters(pack);
  check('391 monsters mapped (${monsters.length})', monsters.length == 391);
  _assertCanonicalLookups(pack, 'tob');
  _assertRefsResolved(pack, 'tob');

  // Golden: Adult Cave Dragon (legendary, recharge breath, saves).
  final dragon =
      monsters.firstWhere((m) => m['name'] == 'Adult Cave Dragon')['attributes'] as Map;
  check('Cave Dragon cr=16', dragon['cr'] == '16');
  check('Cave Dragon xp=15000', dragon['xp'] == 15000);
  check('Cave Dragon pb=5', dragon['proficiency_bonus'] == 5);
  check('Cave Dragon hp=243', dragon['hp_average'] == 243);
  check('Cave Dragon legendary_action_uses=3', dragon['legendary_action_uses'] == 3);
  check('Cave Dragon has legendary refs',
      (dragon['legendary_action_refs'] as List?)?.isNotEmpty ?? false);
  check('Cave Dragon Con save proficient, misc=0', () {
    final rows = (dragon['save_bonuses'] as Map)['rows'] as List;
    final con = rows.cast<Map>().firstWhere((r) => r['name'] == 'Constitution');
    return con['proficient'] == true && con['misc'] == 0;
  }());

  // Golden: at least one recharge-on-roll action carries min_roll.
  final rechargeOk = pack.entities.values.any((e) =>
      (e as Map)['type'] == 'creature-action' &&
      (e['attributes'] as Map)['recharge_kind'] == 'Roll' &&
      (e['attributes'] as Map)['recharge_min_roll'] != null);
  check('recharge-on-roll actions carry min_roll', rechargeOk);

  // Golden: attack actions parsed (bonus + dice + kind).
  final attackOk = pack.entities.values.any((e) =>
      (e as Map)['type'] == 'creature-action' &&
      (e['attributes'] as Map)['is_attack'] == true &&
      (e['attributes'] as Map)['attack_bonus'] != null &&
      (e['attributes'] as Map)['damage_dice'] != null);
  check('attack actions carry bonus + dice', attackOk);
}

List<Map> _ofType(PackBuilder p, String type) => p.entities.values
    .where((e) => (e as Map)['type'] == type)
    .cast<Map>()
    .toList();

void _checkSpells(List<SourceDoc> docs) {
  print('Spells (SRD 5.1):');
  final doc = docs.firstWhere((d) => d.slug == 'srd-2014');
  final pack = PackBuilder(doc.packageName);
  mapSpells(
    pack: pack,
    norm: _norm,
    source: doc.title,
    spells: loadFixtures(doc.v2File('Spell.json')),
  );
  check('no unresolved refs (${pack.resolveRefs().length})',
      pack.resolveRefs().isEmpty);
  final spells = _ofType(pack, 'spell');
  check('319 spells mapped (${spells.length})', spells.length == 319);
  _assertCanonicalLookups(pack, 'srd-2014 spells');

  final fb = spells.firstWhere((s) => s['name'] == 'Fireball')['attributes'] as Map;
  check('Fireball level=3', fb['level'] == 3);
  check('Fireball school=Evocation',
      (fb['school_ref'] as Map)['name'] == 'Evocation');
  check('Fireball cast unit=Action',
      (fb['casting_time_unit_ref'] as Map)['name'] == 'Action');
  check('Fireball higher-level appended',
      (fb['description'] as String).contains('**At Higher Levels.**'));
  check('Fireball classes → tags', () {
    final tags = (spells.firstWhere((s) => s['name'] == 'Fireball')['tags']
        as List).cast<String>();
    return tags.contains('Wizard') && tags.contains('Sorcerer');
  }());

  final aa = spells.firstWhere((s) => s['name'] == 'Acid Arrow')['attributes'] as Map;
  check('Acid Arrow range=Ranged 90ft',
      aa['range_type'] == 'Ranged' && aa['range_ft'] == 90);
  check('Acid Arrow V+S+M components',
      (aa['components'] as List).length == 3);
  check('Acid Arrow duration=Instantaneous',
      (aa['duration_unit_ref'] as Map)['name'] == 'Instantaneous');
}

void _checkMagicItems(List<SourceDoc> docs) {
  print('Magic Items (Vault of Magic):');
  final doc = docs.firstWhere((d) => d.slug == 'vom');
  final pack = PackBuilder(doc.packageName);
  mapMagicItems(
    pack: pack,
    norm: _norm,
    source: doc.title,
    items: loadFixtures(doc.v2File('MagicItem.json')),
  );
  check('no unresolved refs (${pack.resolveRefs().length})',
      pack.resolveRefs().isEmpty);
  final items = _ofType(pack, 'magic-item');
  check('1063 magic items mapped (${items.length})', items.length == 1063);
  _assertCanonicalLookups(pack, 'vom items');

  final blade = items.firstWhere((m) => m['name'] == 'Akaasit Blade')['attributes'] as Map;
  check('Akaasit Blade category=Weapons',
      (blade['magic_category_ref'] as Map)['name'] == 'Weapons');
  check('Akaasit Blade rarity=Rare',
      (blade['rarity_ref'] as Map)['name'] == 'Rare');
  check('every item has a category',
      items.every((m) => (m['attributes'] as Map)['magic_category_ref'] != null));
}

void _checkChargen(List<SourceDoc> docs) {
  print('Char-build (SRD 5.1):');
  final doc = docs.firstWhere((d) => d.slug == 'srd-2014');
  final pack = PackBuilder(doc.packageName);
  mapClasses(
    pack: pack,
    norm: _norm,
    source: doc.title,
    classes: loadFixtures(doc.v2File('CharacterClass.json')),
    features: loadFixtures(doc.v2File('ClassFeature.json')),
  );
  mapSpecies(
    pack: pack,
    norm: _norm,
    source: doc.title,
    species: loadFixtures(doc.v2File('Species.json')),
    traits: loadFixtures(doc.v2File('SpeciesTrait.json')),
  );
  mapBackgrounds(
    pack: pack,
    norm: _norm,
    source: doc.title,
    backgrounds: loadFixtures(doc.v2File('Background.json')),
    benefits: loadFixtures(doc.v2File('BackgroundBenefit.json')),
  );
  mapFeats(
    pack: pack,
    norm: _norm,
    source: doc.title,
    feats: loadFixtures(doc.v2File('Feat.json')),
    benefits: loadFixtures(doc.v2File('FeatBenefit.json')),
  );
  check('no unresolved refs (${pack.resolveRefs().length})',
      pack.resolveRefs().isEmpty);
  _assertCanonicalLookups(pack, 'srd-2014 chargen');
  final classes = _ofType(pack, 'class');
  final subs = _ofType(pack, 'subclass');
  check('12 base classes (${classes.length})', classes.length == 12);
  check('12 subclasses (${subs.length})', subs.length == 12);

  // C6: in-pack subclass links to its base class (SRD ships both).
  check('Champion parent_class_ref resolved to a uuid', () {
    final champ = subs.firstWhere((s) => s['name'] == 'Champion')['attributes']
        as Map;
    final r = champ['parent_class_ref'];
    return r is String && r.length == 36;
  }());

  final barb = classes.firstWhere((c) => c['name'] == 'Barbarian')['attributes'] as Map;
  check('Barbarian hit_die=12', barb['hit_die'] == 12);
  check('Barbarian caster_kind=None', barb['caster_kind'] == 'None');
  check('Barbarian saves = Con+Str', () {
    final names = (barb['saving_throw_refs'] as List)
        .map((r) => (r as Map)['name'])
        .toSet();
    return names.containsAll({'Constitution', 'Strength'});
  }());
  check('Barbarian features folded into description',
      (barb['description'] as String).contains('### '));
  // C7: armor/weapon proficiencies parsed from the Proficiencies feature.
  check('Barbarian armor training = Light+Medium+Shield', () {
    final a = ((barb['armor_training_refs'] as List?) ?? const [])
        .map((r) => (r as Map)['name'])
        .toSet();
    return a.containsAll({'Light', 'Medium', 'Shield'});
  }());
  check('Barbarian weapon profs = Simple+Martial', () {
    final w = ((barb['weapon_proficiency_categories'] as List?) ?? const [])
        .map((r) => (r as Map)['name'])
        .toSet();
    return w.containsAll({'Simple', 'Martial'});
  }());

  final grappler = _ofType(pack, 'feat')
      .firstWhere((f) => f['name'] == 'Grappler')['attributes'] as Map;
  check('Grappler prerequisite folded',
      (grappler['description'] as String).contains('**Prerequisite:**'));
  // C1: every feat carries a canonical category_ref mapped from Open5e `type`.
  final feats = _ofType(pack, 'feat');
  check('every feat has category_ref',
      feats.every((f) => (f['attributes'] as Map)['category_ref'] != null));
  check('Grappler category=General',
      (grappler['category_ref'] as Map)['name'] == 'General');

  // C2: species size/speed parsed from trait rows; creature type defaults.
  final dwarf = _ofType(pack, 'species')
      .firstWhere((s) => s['name'] == 'Dwarf')['attributes'] as Map;
  check('Dwarf size=Medium', (dwarf['size_ref'] as Map?)?['name'] == 'Medium');
  check('Dwarf speed=25', dwarf['speed_ft'] == 25);
  check('Dwarf creature_type=Humanoid',
      (dwarf['creature_type_ref'] as Map?)?['name'] == 'Humanoid');
  final gnome = _ofType(pack, 'species')
      .firstWhere((s) => s['name'] == 'Gnome')['attributes'] as Map;
  check('Gnome size=Small', (gnome['size_ref'] as Map?)?['name'] == 'Small');

  // C3: senses + languages parsed from trait rows.
  check('Dwarf granted_senses has Darkvision', () {
    final s = (dwarf['granted_senses'] as List?) ?? const [];
    return s.any((r) => (r as Map)['name'] == 'Darkvision');
  }());
  check('Dwarf languages = Common + Dwarvish', () {
    final l = ((dwarf['granted_languages'] as List?) ?? const [])
        .map((r) => (r as Map)['name'])
        .toSet();
    return l.containsAll({'Common', 'Dwarvish'});
  }());

  // C4: fixed ASI parsed into granted_modifiers.
  check('Dwarf ASI = CON +2', () {
    final m = (dwarf['granted_modifiers'] as List?) ?? const [];
    return m.length == 1 &&
        (m.first as Map)['ability'] == 'CON' &&
        (m.first as Map)['value'] == 2 &&
        (m.first as Map)['kind'] == 'ability_score_bonus';
  }());
  check('Half-Orc ASI = STR+2, CON+1', () {
    final ho = _ofType(pack, 'species')
        .firstWhere((s) => s['name'] == 'Half-Orc')['attributes'] as Map;
    final m = ((ho['granted_modifiers'] as List?) ?? const [])
        .map((e) => '${(e as Map)['ability']}+${e['value']}')
        .toSet();
    return m.containsAll({'STR+2', 'CON+1'});
  }());
  check('Human ASI = all six +1', () {
    final hu = _ofType(pack, 'species')
        .firstWhere((s) => s['name'] == 'Human')['attributes'] as Map;
    final m = (hu['granted_modifiers'] as List?) ?? const [];
    return m.length == 6 && m.every((e) => (e as Map)['value'] == 1);
  }());

  // C5: background skill grants + language count parsed from benefit rows.
  final acolyte = _ofType(pack, 'background')
      .firstWhere((b) => b['name'] == 'Acolyte')['attributes'] as Map;
  check('Acolyte skills = Insight + Religion', () {
    final s = ((acolyte['granted_skill_refs'] as List?) ?? const [])
        .map((r) => (r as Map)['name'])
        .toSet();
    return s.containsAll({'Insight', 'Religion'});
  }());
  check('Acolyte language count = 2', acolyte['granted_language_count'] == 2);

  // ── D-phase goldens ───────────────────────────────────────────────────────

  // D5: every subclass carries a parent_class_ref; SRD ships the base in-pack so
  // it resolves to a uuid here. softRef is the cross-pack path (tested below).
  check('every subclass has parent_class_ref',
      subs.every((s) => (s['attributes'] as Map)['parent_class_ref'] != null));
  check('softRef carries slug/name, no _ref key', () {
    final r = softRef('class', 'Warlock');
    return r['_ref'] == null && r['slug'] == 'class' && r['name'] == 'Warlock';
  }());
  check('resolveRefs leaves a softRef intact (build stays 0-unresolved)', () {
    final p = PackBuilder('softref-test');
    p.add({
      'type': 'subclass',
      'name': 'X',
      'attributes': {'parent_class_ref': softRef('class', 'Warlock')},
    });
    final un = p.resolveRefs();
    final r = (p.entities.values.first as Map)['attributes']['parent_class_ref'];
    return un.isEmpty && r is Map && r['slug'] == 'class' && r['name'] == 'Warlock';
  }());

  // D8: caster_kind inferred from feature rows when Open5e leaves caster_type
  // null (whole SRD-2014 set). Full / Half / Pact / None all exercised.
  Map clsAttrs(String n) =>
      classes.firstWhere((c) => c['name'] == n)['attributes'] as Map;
  check('Wizard caster_kind=Full', clsAttrs('Wizard')['caster_kind'] == 'Full');
  check('Cleric caster_kind=Full', clsAttrs('Cleric')['caster_kind'] == 'Full');
  check('Paladin caster_kind=Half', clsAttrs('Paladin')['caster_kind'] == 'Half');
  check('Ranger caster_kind=Half', clsAttrs('Ranger')['caster_kind'] == 'Half');
  check('Warlock caster_kind=Pact', clsAttrs('Warlock')['caster_kind'] == 'Pact');
  check('Fighter caster_kind=None', clsAttrs('Fighter')['caster_kind'] == 'None');

  // D7: class skill choice parsed from the Proficiencies "**Skills:**" line.
  check('Barbarian skill choice count = 2', barb['skill_proficiency_choice_count'] == 2);
  check('Barbarian skill options include Athletics', () {
    final o = ((barb['skill_proficiency_options'] as List?) ?? const [])
        .map((r) => (r as Map)['name'])
        .toSet();
    return o.containsAll({'Athletics', 'Survival'});
  }());

  // D6: feat prerequisite — raw text kept + structured ability/score gate parsed.
  check('Grappler prerequisite text kept',
      (grappler['prerequisite'] as String?)?.contains('13') ?? false);
  check('Grappler prereq ability=Strength min=13',
      (grappler['prereq_ability_ref'] as Map?)?['name'] == 'Strength' &&
          grappler['prereq_min_score'] == 13);

  // D1 + D3 + D9 on Tiefling (resistance, no skill grant, innate spells).
  final tiefling = _ofType(pack, 'species')
      .firstWhere((s) => s['name'] == 'Tiefling')['attributes'] as Map;
  check('Tiefling damage resistance = Fire', () {
    final r = ((tiefling['granted_damage_resistances'] as List?) ?? const [])
        .map((e) => (e as Map)['name'])
        .toSet();
    return r.contains('Fire');
  }());
  check('Tiefling innate cantrip = Thaumaturgy', () {
    final c = ((tiefling['granted_cantrip_refs'] as List?) ?? const [])
        .map((e) => (e as Map)['name'])
        .toSet();
    return c.contains('Thaumaturgy');
  }());
  check('Tiefling innate spells = Hellish Rebuke + Darkness', () {
    final s = ((tiefling['granted_spell_refs'] as List?) ?? const [])
        .map((e) => (e as Map)['name'])
        .toSet();
    return s.containsAll({'Hellish Rebuke', 'Darkness'});
  }());

  // D3: explicit "proficiency in the X skill" is a grant; the conditional
  // "considered proficient in the History skill" (Dwarf Stonecunning) is NOT.
  final elf = _ofType(pack, 'species')
      .firstWhere((s) => s['name'] == 'Elf')['attributes'] as Map;
  check('Elf skill proficiency = Perception', () {
    final s = ((elf['granted_skill_proficiencies'] as List?) ?? const [])
        .map((e) => (e as Map)['name'])
        .toSet();
    return s.contains('Perception');
  }());
  check('Dwarf gets no false skill proficiency (Stonecunning conditional)',
      dwarf['granted_skill_proficiencies'] == null);
}

void _walkLookups(dynamic value, void Function(String slug, String name) fn) {
  if (value is Map) {
    final slug = value['_lookup'];
    final name = value['name'];
    if (slug is String && name is String) {
      fn(slug, name);
      return;
    }
    for (final v in value.values) {
      _walkLookups(v, fn);
    }
  } else if (value is List) {
    for (final v in value) {
      _walkLookups(v, fn);
    }
  }
}
