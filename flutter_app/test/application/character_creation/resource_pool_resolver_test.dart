import 'package:dungeon_master_tool/application/character_creation/resource_pool_resolver.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// A class / subclass card. Its `features` level table is the single place
/// that says which feats arrive at which level — [grants] is `{level: featIds}`.
Entity _class(
  String name, {
  String slug = 'class',
  Map<int, List<String>> grants = const {},
}) =>
    Entity(
      id: 'class-${name.toLowerCase()}',
      name: name,
      categorySlug: slug,
      fields: {
        'features': [
          for (final e in grants.entries)
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
  required List<Map<String, dynamic>> pools,
}) =>
    Entity(
      id: id,
      name: name,
      categorySlug: 'feat',
      fields: {'resource_pool_grants': pools},
    );

Map<String, dynamic> _poolGrant({
  required String pool,
  String recharge = 'long_rest',
  int? count,
  List<List<int>>? scalesTable,
  String? sourceClass,
}) =>
    {
      'pool_ref': {'slug': 'resource-pool', 'name': pool},
      'recharge': recharge,
      'count': ?count,
      if (scalesTable != null)
        'class_ref': {'slug': 'class', 'name': sourceClass ?? 'Class'},
      if (scalesTable != null)
        'count_by_level': {
          for (final row in scalesTable) '${row[0]}': row[1],
        },
    };

void main() {
  group('resolveResourcePoolsAt', () {
    test('returns empty when class is null', () {
      expect(
        resolveResourcePoolsAt(
          classEntity: null,
          subclassEntity: null,
          level: 5,
          entities: const {},
        ),
        isEmpty,
      );
    });

    test('returns empty when level < 1', () {
      final feat = _feat(
        id: 'feat-rage',
        name: 'Rage',
        pools: [
          _poolGrant(
            pool: 'pool:rage_uses',
            scalesTable: [
              [1, 2],
              [3, 3],
            ],
            sourceClass: 'Barbarian',
          ),
        ],
      );
      expect(
        resolveResourcePoolsAt(
          classEntity: _class('Barbarian', grants: const {
            1: ['feat-rage'],
          }),
          subclassEntity: null,
          level: 0,
          entities: {feat.id: feat},
        ),
        isEmpty,
      );
    });

    test('picks the highest lvl ≤ level from the scaling table', () {
      final feat = _feat(
        id: 'feat-rage',
        name: 'Rage',
        pools: [
          _poolGrant(
            pool: 'pool:rage_uses',
            scalesTable: [
              [1, 2],
              [3, 3],
              [6, 4],
              [12, 5],
              [17, 6],
            ],
            sourceClass: 'Barbarian',
          ),
        ],
      );
      final entities = {feat.id: feat};
      final cls = _class('Barbarian', grants: const {
        1: ['feat-rage'],
      });

      expect(
        resolveResourcePoolsAt(
          classEntity: cls,
          subclassEntity: null,
          level: 5,
          entities: entities,
        ),
        {'pool:rage_uses': 3},
      );

      expect(
        resolveResourcePoolsAt(
          classEntity: cls,
          subclassEntity: null,
          level: 12,
          entities: entities,
        ),
        {'pool:rage_uses': 5},
      );
    });

    test('uses literal count when no scaling table present', () {
      final feat = _feat(
        id: 'feat-flat',
        name: 'Flat Pool',
        pools: [_poolGrant(pool: 'pool:flat_thing', count: 7)],
      );
      expect(
        resolveResourcePoolsAt(
          classEntity: _class('Bard', grants: const {
            1: ['feat-flat'],
          }),
          subclassEntity: null,
          level: 3,
          entities: {feat.id: feat},
        ),
        {'pool:flat_thing': 7},
      );
    });

    test('skips feat when at_level > level', () {
      final feat = _feat(
        id: 'feat-l3',
        name: 'Late Grant',
        pools: [_poolGrant(pool: 'pool:channel_divinity', count: 1)],
      );
      expect(
        resolveResourcePoolsAt(
          classEntity: _class('Cleric', grants: const {
            3: ['feat-l3'],
          }),
          subclassEntity: null,
          level: 2,
          entities: {feat.id: feat},
        ),
        isEmpty,
      );
    });

    test('matches via subclass name as well', () {
      final feat = _feat(
        id: 'feat-sub',
        name: 'Subclass Pool',
        pools: [_poolGrant(pool: 'pool:divine_strike', count: 1)],
      );
      expect(
        resolveResourcePoolsAt(
          classEntity: _class('Cleric'),
          subclassEntity: _class('LifeDomain', slug: 'subclass', grants: const {
            2: ['feat-sub'],
          }),
          level: 5,
          entities: {feat.id: feat},
        ),
        {'pool:divine_strike': 1},
      );
    });

    test('ignores feats with count_formula only (unsupported)', () {
      // Skip formula → no scales_with, no count → resolver returns null
      // → effect omitted from output.
      final feat = _feat(
        id: 'feat-formula',
        name: 'Lay on Hands',
        pools: const [
          {
            'pool_ref': {'slug': 'resource-pool', 'name': 'pool:lay_on_hands_hp'},
            'recharge': 'long_rest',
            'count_formula': 'paladin_level_x5',
          },
        ],
      );
      expect(
        resolveResourcePoolsAt(
          classEntity: _class('Paladin', grants: const {
            1: ['feat-formula'],
          }),
          subclassEntity: null,
          level: 5,
          entities: {feat.id: feat},
        ),
        isEmpty,
      );
    });

    test('evaluates paladin_level_x5 when classLevels provided', () {
      final paladin = _class('Paladin', grants: const {
        1: ['feat-loh'],
      });
      final feat = _feat(
        id: 'feat-loh',
        name: 'Lay on Hands',
        pools: const [
          {
            'pool_ref': {'slug': 'resource-pool', 'name': 'pool:lay_on_hands_hp'},
            'recharge': 'long_rest',
            'count_formula': 'paladin_level_x5',
          },
        ],
      );
      expect(
        resolveResourcePoolsAt(
          classEntity: paladin,
          subclassEntity: null,
          level: 5,
          entities: {feat.id: feat, paladin.id: paladin},
          classLevels: {paladin.id: 5},
        ),
        {'pool:lay_on_hands_hp': 25},
      );
    });

    test('evaluates monk_level for Ki / Focus Points', () {
      final monk = _class('Monk', grants: const {
        2: ['feat-ki'],
      });
      final feat = _feat(
        id: 'feat-ki',
        name: 'Focus Points',
        pools: const [
          {
            'pool_ref': {'slug': 'resource-pool', 'name': 'pool:focus_points'},
            'recharge': 'short_rest',
            'count_formula': 'monk_level',
          },
        ],
      );
      expect(
        resolveResourcePoolsAt(
          classEntity: monk,
          subclassEntity: null,
          level: 3,
          entities: {feat.id: feat, monk.id: monk},
          classLevels: {monk.id: 3},
        ),
        {'pool:focus_points': 3},
      );
    });

    test('evaluates cha_mod_min_1 with ability score, clamps at 1', () {
      final cleric = _class('Cleric', grants: const {
        1: ['feat-cd'],
      });
      final feat = _feat(
        id: 'feat-cd',
        name: 'Channel Divinity',
        pools: const [
          {
            'pool_ref': {'slug': 'resource-pool', 'name': 'pool:channel_divinity'},
            'recharge': 'short_rest',
            'count_formula': 'cha_mod_min_1',
          },
        ],
      );
      final entities = {feat.id: feat, cleric.id: cleric};

      expect(
        resolveResourcePoolsAt(
          classEntity: cleric,
          subclassEntity: null,
          level: 1,
          entities: entities,
          abilities: const {'CHA': 16},
          classLevels: {cleric.id: 1},
        ),
        {'pool:channel_divinity': 3},
      );

      expect(
        resolveResourcePoolsAt(
          classEntity: cleric,
          subclassEntity: null,
          level: 1,
          entities: entities,
          abilities: const {'CHA': 10},
          classLevels: {cleric.id: 1},
        ),
        {'pool:channel_divinity': 1},
      );
    });

    test('keeps the larger value when two effects target the same pool', () {
      final cls = _feat(
        id: 'feat-base',
        name: 'Channel Divinity Base',
        pools: [_poolGrant(pool: 'pool:channel_divinity', count: 1)],
      );
      final sub = _feat(
        id: 'feat-upgrade',
        name: 'Channel Divinity Upgrade',
        pools: [_poolGrant(pool: 'pool:channel_divinity', count: 2)],
      );
      expect(
        resolveResourcePoolsAt(
          classEntity: _class('Cleric', grants: const {
            2: ['feat-base'],
            6: ['feat-upgrade'],
          }),
          subclassEntity: null,
          level: 6,
          entities: {cls.id: cls, sub.id: sub},
        ),
        {'pool:channel_divinity': 2},
      );
    });
  });
}
