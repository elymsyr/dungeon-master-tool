import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration proof against the REAL hand-authored SRD 5.2.1 content, not
/// synthetic fixtures: the class-feature Feat cards, Species and Subspecies
/// rows that were converted from the old `rule_effects` / `granted_modifiers`
/// DSL to plain grant-block fields must still resolve to the same sheet.
///
/// `rule_kinds_e2e_test.dart` proves each grant key works in isolation; this
/// file proves the shipped content actually uses them correctly.
void main() {
  final entities = buildBuiltinSrdEntities();

  Entity find(String slug, String name) => entities.values.firstWhere(
        (e) => e.categorySlug == slug && e.name == name,
        orElse: () => throw StateError('Missing SRD entity $slug/$name'),
      );

  Entity? tryFind(String slug, String name) {
    for (final e in entities.values) {
      if (e.categorySlug == slug && e.name == name) return e;
    }
    return null;
  }

  Character pc(Map<String, dynamic> fields) => Character(
        id: 'pc1',
        templateId: 'tpl',
        templateName: 'Tpl',
        entity: Entity(id: 'pc1_e', categorySlug: 'player', fields: fields),
        worldId: 'w',
        createdAt: '0',
        updatedAt: '0',
      );

  const abilities = {
    'STR': 16, 'DEX': 14, 'CON': 14, 'INT': 10, 'WIS': 10, 'CHA': 10,
  };

  group('SRD content → resolved sheet', () {
    test('Barbarian L1: Unarmored Defense gives AC 10 + DEX + CON', () {
      final barb = find('class', 'Barbarian');
      final eff = CharacterResolver.resolve(
        pc({
          'class_levels': {barb.id: 1},
          'base_abilities': abilities,
        }),
        entities,
      );
      // 10 + DEX(+2) + CON(+2) = 14, beating the plain 10 + DEX = 12.
      expect(eff.unarmoredFormulas, isNotEmpty,
          reason: 'Unarmored Defense must be auto-granted at Barbarian 1');
      expect(eff.armorClass, 14);
    });

    test('Barbarian L1: Rage grants 2 uses per long rest', () {
      final barb = find('class', 'Barbarian');
      final eff = CharacterResolver.resolve(
        pc({
          'class_levels': {barb.id: 1},
          'base_abilities': abilities,
        }),
        entities,
      );
      final rage = eff.resourcePools.firstWhere(
        (p) => (p['pool_ref']?.toString() ?? '').contains(
            find('resource-pool', 'pool:rage_uses').id),
        orElse: () => const <String, dynamic>{},
      );
      expect(rage['max'], 2, reason: 'SRD Rage: 2 uses at level 1');
      expect(rage['recharge'], 'long_rest');
    });

    test('Barbarian L6: the Rage level table scales uses to 4', () {
      final barb = find('class', 'Barbarian');
      final pool = find('resource-pool', 'pool:rage_uses');
      final eff = CharacterResolver.resolve(
        pc({
          'class_levels': {barb.id: 6},
          'base_abilities': abilities,
        }),
        entities,
      );
      final rage = eff.resourcePools.firstWhere(
        (p) => (p['pool_ref']?.toString() ?? '').contains(pool.id),
        orElse: () => const <String, dynamic>{},
      );
      expect(rage['max'], 4);
    });

    test("Barbarian Rage's resistances are state-gated, not always-on", () {
      final barb = find('class', 'Barbarian');
      final slashing = find('damage-type', 'Slashing');
      final eff = CharacterResolver.resolve(
        pc({
          'class_levels': {barb.id: 1},
          'base_abilities': abilities,
        }),
        entities,
      );
      expect(eff.damageResistanceIds, isNot(contains(slashing.id)),
          reason: 'a resting Barbarian has no slashing resistance');
      expect(
        eff.conditionalGrants.any((g) =>
            g['kind'] == 'damage_resistance' &&
            (g['ids'] as List).contains(slashing.id)),
        isTrue,
        reason: 'it must surface as a "while raging" conditional grant',
      );
    });

    test('Fighter L5 / L11 / L20 attack counts come from the level table', () {
      final fighter = find('class', 'Fighter');
      int attacksAt(int level) => CharacterResolver.resolve(
            pc({
              'class_levels': {fighter.id: level},
              'base_abilities': abilities,
            }),
            entities,
          ).extraAttackCount;
      expect(attacksAt(4), 0, reason: 'no Extra Attack before level 5');
      expect(attacksAt(5), 2);
      expect(attacksAt(11), 3);
      expect(attacksAt(20), 4);
    });

    test('Hill Dwarf grants +1 HP per level', () {
      final dwarf = find('species', 'Dwarf');
      final hill = tryFind('subspecies', 'Hill Dwarf');
      if (hill == null) {
        markTestSkipped('Hill Dwarf subspecies not in this pack');
        return;
      }
      final eff = CharacterResolver.resolve(
        pc({
          'race_id': dwarf.id,
          'subspecies_id': hill.id,
          'base_abilities': abilities,
        }),
        entities,
      );
      expect(eff.hpBonusPerLevel, 1);
    });

    test('Mountain Dwarf grants +2 flat max HP', () {
      final dwarf = find('species', 'Dwarf');
      final mountain = tryFind('subspecies', 'Mountain Dwarf');
      if (mountain == null) {
        markTestSkipped('Mountain Dwarf subspecies not in this pack');
        return;
      }
      final eff = CharacterResolver.resolve(
        pc({
          'race_id': dwarf.id,
          'subspecies_id': mountain.id,
          'base_abilities': abilities,
        }),
        entities,
      );
      expect(eff.hpBonusFlat, 2);
    });

    test('Dwarf has Darkvision; Drow upgrades it to 120 ft', () {
      final dwarf = find('species', 'Dwarf');
      final darkvision = find('sense', 'Darkvision');
      final dwarfEff = CharacterResolver.resolve(
        pc({'race_id': dwarf.id, 'base_abilities': abilities}),
        entities,
      );
      expect(dwarfEff.senseEntityIds, contains(darkvision.id));
      expect(dwarfEff.senseRanges[darkvision.id], 60);

      final elf = find('species', 'Elf');
      final drow = tryFind('subspecies', 'Drow');
      if (drow == null) {
        markTestSkipped('Drow subspecies not in this pack');
        return;
      }
      final drowEff = CharacterResolver.resolve(
        pc({
          'race_id': elf.id,
          'subspecies_id': drow.id,
          'base_abilities': abilities,
        }),
        entities,
      );
      expect(drowEff.senseRanges[darkvision.id], 120,
          reason: 'Superior Darkvision overrides the base 60 ft');
    });

    test('Dwarf resists poison damage', () {
      final dwarf = find('species', 'Dwarf');
      final poison = find('damage-type', 'Poison');
      final eff = CharacterResolver.resolve(
        pc({'race_id': dwarf.id, 'base_abilities': abilities}),
        entities,
      );
      expect(eff.damageResistanceIds, contains(poison.id));
    });

    test('Magic Initiate still queues its three player choices', () {
      final feat = find('feat', 'Magic Initiate');
      final rows = feat.fields['player_choices'];
      expect(rows, isA<List>());
      final groups = (rows as List)
          .whereType<Map>()
          .map((r) => r['group_id']?.toString())
          .toSet();
      expect(groups, containsAll(<String>{'list', 'cantrips', 'level1'}));
    });

    test('Monk L1 unarmoured AC uses DEX + WIS and refuses a shield', () {
      final monk = tryFind('class', 'Monk');
      if (monk == null) {
        markTestSkipped('Monk not in this pack');
        return;
      }
      final eff = CharacterResolver.resolve(
        pc({
          'class_levels': {monk.id: 1},
          'base_abilities': const {
            'STR': 10, 'DEX': 16, 'CON': 10,
            'INT': 10, 'WIS': 16, 'CHA': 10,
          },
        }),
        entities,
      );
      expect(eff.unarmoredFormulas, isNotEmpty);
      final payload =
          eff.unarmoredFormulas.first['payload'] as Map<String, dynamic>;
      expect(payload['ability_mods'], containsAll(<String>['DEX', 'WIS']));
      expect(payload['shield_allowed'], isFalse);
      expect(eff.armorClass, 16, reason: '10 + DEX(+3) + WIS(+3)');
    });

    test('no SRD card produces a resolver warning', () {
      final barb = find('class', 'Barbarian');
      final dwarf = find('species', 'Dwarf');
      final eff = CharacterResolver.resolve(
        pc({
          'class_levels': {barb.id: 6},
          'race_id': dwarf.id,
          'base_abilities': abilities,
        }),
        entities,
      );
      expect(eff.warnings, isEmpty);
    });

    test('roll-time rules the engine cannot compute survive as notes', () {
      final barb = find('class', 'Barbarian');
      final eff = CharacterResolver.resolve(
        pc({
          'class_levels': {barb.id: 1},
          'base_abilities': abilities,
        }),
        entities,
      );
      // Rage's Advantage on Strength checks/saves has no resolved-sheet
      // representation; before this change it was silently dropped.
      expect(
        eff.mechanicalNotes.any((n) => n.toLowerCase().contains('advantage')),
        isTrue,
        reason: 'Rage advantage must be visible on the sheet as a note',
      );
    });

    test('Druid knows Druidic and Rogue knows Thieves\' Cant', () {
      // `class.granted_languages` was authored on both classes but nothing
      // read it — the wizard showed the language and the resolved sheet did
      // not. Same field key as the grant block uses elsewhere.
      String? langOf(String className) {
        final cls = find('class', className);
        final eff = CharacterResolver.resolve(
          pc({
            'class_levels': {cls.id: 1},
            'base_abilities': abilities,
          }),
          entities,
        );
        final ids = eff.proficiencies.languageIds;
        return ids.isEmpty ? null : entities[ids.first]?.name;
      }

      expect(langOf('Druid'), 'Druidic');
      expect(langOf('Rogue'), "Thieves' Cant");
    });

    test('Druid is proficient with the Herbalism Kit it grants', () {
      final druid = find('class', 'Druid');
      final eff = CharacterResolver.resolve(
        pc({
          'class_levels': {druid.id: 1},
          'base_abilities': abilities,
        }),
        entities,
      );
      expect(
        eff.proficiencies.toolIds.map((i) => entities[i]?.name),
        contains('Herbalism Kit'),
      );
    });

    test('High Elf innate spells unlock at their authored levels', () {
      // `granted_spells_at_level` — a level-gated grant that the resolver has
      // always read but that had no schema field until now, so nobody could
      // author or even see it.
      final elf = find('species', 'Elf');
      final high = find('subspecies', 'High Elf');
      final wiz = find('class', 'Wizard');

      List<String?> spellsAt(int level) {
        final eff = CharacterResolver.resolve(
          pc({
            'race_id': elf.id,
            'subspecies_id': high.id,
            'class_levels': {wiz.id: level},
            'base_abilities': abilities,
          }),
          entities,
        );
        return eff.grantedSpellIds.map((i) => entities[i]?.name).toList();
      }

      expect(spellsAt(1), isEmpty);
      expect(spellsAt(3), contains('Detect Magic'));
      expect(spellsAt(3), isNot(contains('Misty Step')));
      expect(spellsAt(5), containsAll(['Detect Magic', 'Misty Step']));
    });

    test('a 1/day innate spell brings its own daily counter', () {
      final elf = find('species', 'Elf');
      final high = find('subspecies', 'High Elf');
      final wiz = find('class', 'Wizard');
      final eff = CharacterResolver.resolve(
        pc({
          'race_id': elf.id,
          'subspecies_id': high.id,
          'class_levels': {wiz.id: 5},
          'base_abilities': abilities,
        }),
        entities,
      );
      final detectMagic = find('spell', 'Detect Magic');
      final pool = eff.resourcePools
          .firstWhere((p) => p['pool_ref'] == detectMagic.id, orElse: () => {});
      expect(pool['max'], 1);
      expect(pool['recharge'], 'long_rest');
    });

    test('a pack-shaped pool_ref resolves to the same row as the builtin id',
        () {
      // Built-in içerikte `pool_ref` yüklenirken id'ye dönüyor, `.pkg.json`
      // ve blueprint kaynaklı içerikte `{_lookup, name}` zarfı olarak
      // kalabiliyor. Resolver ikisini de aynı id'ye çevirmezse sayfadaki
      // sayaç, aynı sınıfın nereden geldiğine göre var ya da yok oluyor.
      final bard = find('class', 'Bard');
      final feat = find('feat', 'Bardic Inspiration');
      final poolRow = (feat.fields['resource_pool_grants'] as List).first as Map;
      expect(poolRow['pool_ref'], isA<String>(),
          reason: 'builtin map ships resolved ids');

      final enveloped = <String, Entity>{
        ...entities,
        feat.id: feat.copyWith(fields: {
          ...feat.fields,
          'resource_pool_grants': [
            {
              ...poolRow.cast<String, dynamic>(),
              'pool_ref': const {
                '_lookup': 'resource-pool',
                'name': 'pool:bardic_inspiration',
              },
            },
          ],
        }),
      };

      final choices = {
        'class_levels': {bard.id: 5},
        'base_abilities': abilities,
      };
      final fromBuiltin = CharacterResolver.resolve(pc(choices), entities);
      final fromPack = CharacterResolver.resolve(pc(choices), enveloped);
      expect(fromPack.resourcePools, fromBuiltin.resourcePools);
      expect(
        fromPack.resourcePools.map((p) => p['pool_ref']),
        contains(find('resource-pool', 'pool:bardic_inspiration').id),
      );
    });
  });
}
