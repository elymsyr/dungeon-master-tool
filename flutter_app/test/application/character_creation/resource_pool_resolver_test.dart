import 'package:dungeon_master_tool/application/character_creation/resource_pool_resolver.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_test/flutter_test.dart';

Entity _class(String name) => Entity(
      id: 'class-${name.toLowerCase()}',
      name: name,
      categorySlug: 'class',
      fields: const {},
    );

Entity _feat({
  required String id,
  required String name,
  required List<Map<String, dynamic>> autoGrantedBy,
  required List<Map<String, dynamic>> effects,
}) =>
    Entity(
      id: id,
      name: name,
      categorySlug: 'feat',
      fields: {
        'auto_granted_by': autoGrantedBy,
        'effects': effects,
      },
    );

Map<String, dynamic> _grantBy(String sourceName, int atLevel) => {
      'source': 'class',
      'source_ref': {'slug': 'class', 'name': sourceName},
      'at_level': atLevel,
    };

Map<String, dynamic> _poolGrant({
  required String pool,
  String recharge = 'long_rest',
  int? count,
  List<List<int>>? scalesTable,
  String? sourceClass,
}) =>
    {
      'kind': 'resource_pool_grant',
      'payload': {
        'pool_ref': {'slug': 'resource-pool', 'name': pool},
        'recharge': recharge,
        if (count != null) 'count': count,
      },
      if (scalesTable != null)
        'scales_with': {
          'kind': 'class_level',
          'class_ref': {'slug': 'class', 'name': sourceClass ?? 'Class'},
          'table': [
            for (final row in scalesTable) {'lvl': row[0], 'v': row[1]},
          ],
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
        autoGrantedBy: [_grantBy('Barbarian', 1)],
        effects: [
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
          classEntity: _class('Barbarian'),
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
        autoGrantedBy: [_grantBy('Barbarian', 1)],
        effects: [
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
      final cls = _class('Barbarian');

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
        autoGrantedBy: [_grantBy('Bard', 1)],
        effects: [_poolGrant(pool: 'pool:flat_thing', count: 7)],
      );
      expect(
        resolveResourcePoolsAt(
          classEntity: _class('Bard'),
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
        autoGrantedBy: [_grantBy('Cleric', 3)],
        effects: [_poolGrant(pool: 'pool:channel_divinity', count: 1)],
      );
      expect(
        resolveResourcePoolsAt(
          classEntity: _class('Cleric'),
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
        autoGrantedBy: [_grantBy('LifeDomain', 2)],
        effects: [_poolGrant(pool: 'pool:divine_strike', count: 1)],
      );
      expect(
        resolveResourcePoolsAt(
          classEntity: _class('Cleric'),
          subclassEntity: _class('LifeDomain'),
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
        autoGrantedBy: [_grantBy('Paladin', 1)],
        effects: const [
          {
            'kind': 'resource_pool_grant',
            'payload': {
              'pool_ref': {
                'slug': 'resource-pool',
                'name': 'pool:lay_on_hands_hp',
              },
              'recharge': 'long_rest',
              'count_formula': 'paladin_level_x5',
            },
          },
        ],
      );
      expect(
        resolveResourcePoolsAt(
          classEntity: _class('Paladin'),
          subclassEntity: null,
          level: 5,
          entities: {feat.id: feat},
        ),
        isEmpty,
      );
    });

    test('keeps the larger value when two effects target the same pool', () {
      final cls = _feat(
        id: 'feat-base',
        name: 'Channel Divinity Base',
        autoGrantedBy: [_grantBy('Cleric', 2)],
        effects: [_poolGrant(pool: 'pool:channel_divinity', count: 1)],
      );
      final sub = _feat(
        id: 'feat-upgrade',
        name: 'Channel Divinity Upgrade',
        autoGrantedBy: [_grantBy('Cleric', 6)],
        effects: [_poolGrant(pool: 'pool:channel_divinity', count: 2)],
      );
      expect(
        resolveResourcePoolsAt(
          classEntity: _class('Cleric'),
          subclassEntity: null,
          level: 6,
          entities: {cls.id: cls, sub.id: sub},
        ),
        {'pool:channel_divinity': 2},
      );
    });
  });
}
