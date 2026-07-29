import 'package:dungeon_master_tool/application/character_creation/weapon_mastery_resolver.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// `weapon_mastery_count` is the single field for "how many weapon masteries
/// does this character get". Two things read it: `CharacterResolver` (for the
/// resolved sheet) and this chargen-preview resolver (for the wizard, before a
/// character exists). Both must take the **maximum** across matching grants —
/// Fighter's L1 three and its L4/L10/L16 bumps are separate feats, and a sum
/// would hand out ten slots by L16.
///
/// Which feats a class hands out, and when, is stated once — on the class
/// card's `features` rows. `_class` below is what that looks like.
///
/// `weapon_mastery_resolver_agreement_test.dart` pins the two readers to each
/// other; this file pins the semantics.

/// A class card whose level table grants [byLevel]'s feat ids.
Entity _class(
  String name, {
  String slug = 'class',
  Map<int, List<String>> byLevel = const {},
}) =>
    Entity(
      id: '$slug-${name.toLowerCase()}',
      name: name,
      categorySlug: slug,
      fields: {
        'features': [
          for (final e in byLevel.entries)
            {
              'level': e.key,
              'name': '$name L${e.key}',
              'granted_feat_refs': e.value,
            },
        ],
      },
    );

Entity _feat({
  required String id,
  required String name,
  required Map<String, dynamic> grants,
}) =>
    Entity(id: id, name: name, categorySlug: 'feat', fields: grants);

/// SRD §1.7 Fighter shape: 3 slots at L1, then bumps at L4 / L10 / L16.
Map<String, Entity> _fighterMasteryFeats() {
  final feats = [
    _feat(
        id: 'wm-1',
        name: 'Weapon Mastery',
        grants: const {'weapon_mastery_count': 3}),
    _feat(
        id: 'wm-4',
        name: 'Weapon Mastery (4)',
        grants: const {'weapon_mastery_count': 4}),
    _feat(
        id: 'wm-10',
        name: 'Weapon Mastery (5)',
        grants: const {'weapon_mastery_count': 5}),
    _feat(
        id: 'wm-16',
        name: 'Weapon Mastery (6)',
        grants: const {'weapon_mastery_count': 6}),
  ];
  return {for (final f in feats) f.id: f};
}

Entity _fighter([Map<int, List<String>>? byLevel]) => _class(
      'Fighter',
      byLevel: byLevel ??
          const {
            1: ['wm-1'],
            4: ['wm-4'],
            10: ['wm-10'],
            16: ['wm-16'],
          },
    );

int _at(
  int level, {
  Entity? cls,
  Entity? subclass,
  Map<String, Entity>? entities,
}) =>
    resolveWeaponMasteryCountAt(
      classEntity: cls ?? _fighter(),
      subclassEntity: subclass,
      level: level,
      entities: entities ?? _fighterMasteryFeats(),
    );

void main() {
  group('resolveWeaponMasteryCountAt', () {
    test('returns 0 with no class', () {
      expect(
        resolveWeaponMasteryCountAt(
          classEntity: null,
          subclassEntity: null,
          level: 5,
          entities: _fighterMasteryFeats(),
        ),
        0,
      );
    });

    test('returns 0 below level 1', () {
      expect(_at(0), 0);
    });

    test('returns 0 with no entities to walk', () {
      expect(_at(5, entities: const {}), 0);
    });

    test('Fighter progression 1/4/10/16 → 3/4/5/6', () {
      expect(_at(1), 3);
      expect(_at(3), 3);
      expect(_at(4), 4);
      expect(_at(9), 4);
      expect(_at(10), 5);
      expect(_at(15), 5);
      expect(_at(16), 6);
      expect(_at(20), 6);
    });

    test('bumps take the max, never the sum', () {
      // At L16 all four rows are in range. Summing would give 18.
      expect(_at(16), 6);
    });

    test('a lower-numbered feat granted later does not downgrade', () {
      final entities = {
        ..._fighterMasteryFeats(),
        'wm-late': _feat(
            id: 'wm-late',
            name: 'Odd Card',
            grants: const {'weapon_mastery_count': 2}),
      };
      final cls = _fighter(const {
        1: ['wm-1'],
        4: ['wm-4'],
        10: ['wm-10'],
        12: ['wm-late'],
        16: ['wm-16'],
      });
      expect(_at(12, cls: cls, entities: entities), 5);
    });

    test('a subclass grant counts as its own source', () {
      final entities = {
        'wm-sub': _feat(
            id: 'wm-sub',
            name: 'Champion Mastery',
            grants: const {'weapon_mastery_count': 4}),
      };
      final champion = _class('Champion', slug: 'subclass', byLevel: const {
        3: ['wm-sub'],
      });
      // The class card grants nothing here, so anything found came from the
      // subclass table.
      final bare = _class('Fighter');
      expect(_at(3, cls: bare, subclass: champion, entities: entities), 4);
      expect(_at(2, cls: bare, subclass: champion, entities: entities), 0);
    });

    test("another class's mastery feats are ignored", () {
      // The Barbarian card is not the one being resolved, so its table is
      // never walked even though the feat sits in the same world.
      final entities = {
        'wm-barb': _feat(
            id: 'wm-barb',
            name: 'Barbarian Mastery',
            grants: const {'weapon_mastery_count': 2}),
      };
      expect(_at(20, cls: _class('Fighter'), entities: entities), 0);
    });

    test('a row naming a non-feat card is skipped', () {
      // Only feats participate; a species id sitting in `granted_feat_refs`
      // is bad data, not a grant.
      final entities = {
        'sp': const Entity(
          id: 'sp',
          name: 'Fighter',
          categorySlug: 'species',
          fields: {'weapon_mastery_count': 9},
        ),
      };
      final cls = _fighter(const {
        1: ['sp'],
      });
      expect(_at(5, cls: cls, entities: entities), 0);
    });

    test('a feat with no weapon_mastery_count contributes nothing', () {
      final entities = {
        'plain': _feat(
          id: 'plain',
          name: 'Second Wind',
          grants: const {'resource_pool_grants': <Map<String, dynamic>>[]},
        ),
      };
      final cls = _fighter(const {
        1: ['plain'],
      });
      expect(_at(5, cls: cls, entities: entities), 0);
    });
  });
}
