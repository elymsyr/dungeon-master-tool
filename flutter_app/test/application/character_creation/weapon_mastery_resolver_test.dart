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
/// `weapon_mastery_resolver_agreement_test.dart` pins the two readers to each
/// other; this file pins the semantics.

Entity _class(String name) => Entity(
      id: 'class-${name.toLowerCase()}',
      name: name,
      categorySlug: 'class',
      fields: const {},
    );

Map<String, dynamic> _grantBy(String sourceName, int atLevel) => {
      'source': 'class',
      'source_ref': {'slug': 'class', 'name': sourceName},
      'at_level': atLevel,
    };

Entity _feat({
  required String id,
  required String name,
  required List<Map<String, dynamic>> autoGrantedBy,
  required Map<String, dynamic> grants,
}) =>
    Entity(
      id: id,
      name: name,
      categorySlug: 'feat',
      fields: {'auto_granted_by': autoGrantedBy, ...grants},
    );

/// SRD §1.7 Fighter shape: 3 slots at L1, then bumps at L4 / L10 / L16.
Map<String, Entity> _fighterMasteryFeats() {
  final feats = [
    _feat(
      id: 'wm-1',
      name: 'Weapon Mastery',
      autoGrantedBy: [_grantBy('Fighter', 1)],
      grants: const {'weapon_mastery_count': 3},
    ),
    _feat(
      id: 'wm-4',
      name: 'Weapon Mastery (4)',
      autoGrantedBy: [_grantBy('Fighter', 4)],
      grants: const {'weapon_mastery_count': 4},
    ),
    _feat(
      id: 'wm-10',
      name: 'Weapon Mastery (5)',
      autoGrantedBy: [_grantBy('Fighter', 10)],
      grants: const {'weapon_mastery_count': 5},
    ),
    _feat(
      id: 'wm-16',
      name: 'Weapon Mastery (6)',
      autoGrantedBy: [_grantBy('Fighter', 16)],
      grants: const {'weapon_mastery_count': 6},
    ),
  ];
  return {for (final f in feats) f.id: f};
}

int _at(int level, {Entity? subclass, Map<String, Entity>? entities}) =>
    resolveWeaponMasteryCountAt(
      classEntity: _class('Fighter'),
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
      // At L16 all four feats match. Summing would give 18.
      expect(_at(16), 6);
    });

    test('a lower-numbered feat granted later does not downgrade', () {
      final entities = {
        ..._fighterMasteryFeats(),
        'wm-late': _feat(
          id: 'wm-late',
          name: 'Odd Card',
          autoGrantedBy: [_grantBy('Fighter', 12)],
          grants: const {'weapon_mastery_count': 2},
        ),
      };
      expect(_at(12, entities: entities), 5);
    });

    test('a subclass grant counts as its own source', () {
      final entities = {
        'wm-sub': _feat(
          id: 'wm-sub',
          name: 'Champion Mastery',
          autoGrantedBy: [
            {
              'source': 'subclass',
              'source_ref': {'slug': 'subclass', 'name': 'Champion'},
              'at_level': 3,
            },
          ],
          grants: const {'weapon_mastery_count': 4},
        ),
      };
      const champion = Entity(
        id: 'sub-champion',
        name: 'Champion',
        categorySlug: 'subclass',
        fields: const {},
      );
      expect(_at(3, subclass: champion, entities: entities), 4);
      expect(_at(2, subclass: champion, entities: entities), 0);
    });

    test('another class\'s mastery feats are ignored', () {
      final entities = {
        'wm-barb': _feat(
          id: 'wm-barb',
          name: 'Barbarian Mastery',
          autoGrantedBy: [_grantBy('Barbarian', 1)],
          grants: const {'weapon_mastery_count': 2},
        ),
      };
      expect(_at(20, entities: entities), 0);
    });

    test('a non-feat card carrying the field is not walked', () {
      // Only feats participate in the auto-grant walk; a species or item with
      // the same field is a resolved-sheet concern, not a chargen preview one.
      final entities = {
        'sp': Entity(
          id: 'sp',
          name: 'Fighter',
          categorySlug: 'species',
          fields: {
            'auto_granted_by': [_grantBy('Fighter', 1)],
            'weapon_mastery_count': 9,
          },
        ),
      };
      expect(_at(5, entities: entities), 0);
    });

    test('a feat with no weapon_mastery_count contributes nothing', () {
      final entities = {
        'plain': _feat(
          id: 'plain',
          name: 'Second Wind',
          autoGrantedBy: [_grantBy('Fighter', 1)],
          grants: const {'resource_pool_grants': <Map<String, dynamic>>[]},
        ),
      };
      expect(_at(5, entities: entities), 0);
    });
  });
}
