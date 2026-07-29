import 'package:dungeon_master_tool/application/character_creation/extra_attack_resolver.dart';
import 'package:dungeon_master_tool/application/character_creation/resource_pool_resolver.dart';
import 'package:dungeon_master_tool/application/character_creation/weapon_mastery_resolver.dart';
import 'package:dungeon_master_tool/application/services/builtin_srd_entities.dart';
import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// **One field, one answer — even with two readers.**
///
/// Three grant fields are read twice: `CharacterResolver` computes them for a
/// character that exists, and a chargen-preview resolver computes them for the
/// wizard and the level-up dialog, before one does. Two implementations of one
/// mechanic is exactly the drift the rule removal was meant to end, so this
/// file walks the real SRD classes level by level and demands the two agree
/// on every one.
///
/// It has already earned its keep: `resolveResourcePoolsAt` only accepted an
/// *unresolved* `pool_ref` placeholder, and shipped packs resolve refs at
/// build time — so the level-up dialog silently showed no pools at all for
/// every class while the sheet showed them correctly.
void main() {
  final entities = buildBuiltinSrdEntities();

  Entity klass(String name) => entities.values.firstWhere(
        (e) => e.categorySlug == 'class' && e.name == name,
        orElse: () => throw StateError('Missing SRD class $name'),
      );

  /// The resolved sheet's pools, re-keyed by pool name so the two readers are
  /// comparable (the sheet keeps entity ids, the preview keeps names).
  Map<String, int> sheetPools(List<Map<String, dynamic>> pools) {
    final out = <String, int>{};
    for (final p in pools) {
      final ref = p['pool_ref'];
      final name = ref is Map
          ? ref['name']?.toString()
          : (ref is String ? entities[ref]?.name : null);
      final max = p['max'];
      if (name == null || max is! int) continue;
      if ((out[name] ?? 0) < max) out[name] = max;
    }
    return out;
  }

  Character pcAt(Entity cls, int level) => Character(
        id: 'pc1',
        templateId: 'tpl',
        templateName: 'Tpl',
        worldId: 'w',
        createdAt: '0',
        updatedAt: '0',
        entity: Entity(id: 'pc1_e', categorySlug: 'player', fields: {
          'class_levels': {cls.id: level},
          'base_abilities': const {
            'STR': 16, 'DEX': 14, 'CON': 14, 'INT': 10, 'WIS': 12, 'CHA': 16, //
          },
        }),
      );

  // Every SRD class that carries at least one of the three fields, plus a
  // couple that carry none — a reader that agrees only where both are empty
  // is not agreeing about anything.
  const classNames = [
    'Barbarian', 'Bard', 'Cleric', 'Druid', 'Fighter', 'Monk',
    'Paladin', 'Ranger', 'Rogue', 'Sorcerer', 'Warlock', 'Wizard', //
  ];
  const levels = [1, 2, 3, 4, 5, 6, 8, 10, 11, 14, 17, 20];

  group('chargen preview agrees with the resolved sheet', () {
    for (final name in classNames) {
      test('$name — extra attacks, mastery slots and pools at every level', () {
        final cls = klass(name);
        for (final level in levels) {
          final where = '$name L$level';
          final eff = CharacterResolver.resolve(pcAt(cls, level), entities);

          expect(
            resolveExtraAttackCountAt(
              classEntity: cls,
              subclassEntity: null,
              level: level,
              entities: entities,
            ),
            eff.extraAttackCount,
            reason: '$where: extra attack count',
          );

          expect(
            resolveWeaponMasteryCountAt(
              classEntity: cls,
              subclassEntity: null,
              level: level,
              entities: entities,
            ),
            eff.weaponMasteryCount,
            reason: '$where: weapon mastery slots',
          );

          expect(
            resolveResourcePoolsAt(
              classEntity: cls,
              subclassEntity: null,
              level: level,
              entities: entities,
              abilities: const {
                'STR': 16, 'DEX': 14, 'CON': 14,
                'INT': 10, 'WIS': 12, 'CHA': 16, //
              },
              classLevels: {cls.id: level},
            ),
            sheetPools(eff.resourcePools),
            reason: '$where: resource pools',
          );
        }
      });
    }

    test('the agreement is not vacuous — the SRD really exercises all three',
        () {
      // Without this, deleting every grant from the content would make every
      // test above pass.
      final fighter = klass('Fighter');
      final fighterL11 =
          CharacterResolver.resolve(pcAt(fighter, 11), entities);
      expect(fighterL11.extraAttackCount, 3);
      expect(fighterL11.weaponMasteryCount, greaterThan(0));
      expect(sheetPools(fighterL11.resourcePools), isNotEmpty);

      final barb = klass('Barbarian');
      final barbL6 = CharacterResolver.resolve(pcAt(barb, 6), entities);
      expect(sheetPools(barbL6.resourcePools)['pool:rage_uses'], 4);
    });
  });

  group('pool refs resolve in both shapes', () {
    // The bug this file caught, pinned directly: the preview must key the same
    // pool whether the card carries an unresolved placeholder or a resolved id.
    Entity pool(String id, String name) =>
        Entity(id: id, categorySlug: 'resource-pool', name: name);

    Entity poolFeat(String id, Object poolRef) => Entity(
          id: id,
          categorySlug: 'feat',
          name: 'Rage',
          fields: {
            'auto_granted_by': [
              {
                'source': 'class',
                'source_ref': {'slug': 'class', 'name': 'Barbarian'},
                'at_level': 1,
              },
            ],
            'resource_pool_grants': [
              {'pool_ref': poolRef, 'recharge': 'long_rest', 'count': 2},
            ],
          },
        );

    const cls = Entity(id: 'c', categorySlug: 'class', name: 'Barbarian');

    test('a resolved entity id keys the pool by its name', () {
      final world = {
        'p1': pool('p1', 'pool:rage_uses'),
        'f1': poolFeat('f1', 'p1'),
      };
      expect(
        resolveResourcePoolsAt(
          classEntity: cls,
          subclassEntity: null,
          level: 1,
          entities: world,
        ),
        {'pool:rage_uses': 2},
      );
    });

    test('an unresolved placeholder keys the same pool', () {
      final world = {
        'f1': poolFeat('f1', {'slug': 'resource-pool', 'name': 'pool:rage_uses'}),
      };
      expect(
        resolveResourcePoolsAt(
          classEntity: cls,
          subclassEntity: null,
          level: 1,
          entities: world,
        ),
        {'pool:rage_uses': 2},
      );
    });

    test('an id pointing at nothing is skipped, not keyed by the raw id', () {
      final world = {'f1': poolFeat('f1', 'missing-id')};
      expect(
        resolveResourcePoolsAt(
          classEntity: cls,
          subclassEntity: null,
          level: 1,
          entities: world,
        ),
        isEmpty,
      );
    });
  });
}
