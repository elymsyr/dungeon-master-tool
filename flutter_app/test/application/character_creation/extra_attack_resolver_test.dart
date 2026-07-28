import 'package:dungeon_master_tool/application/character_creation/extra_attack_resolver.dart';
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
  required Map<String, dynamic> grants,
}) =>
    Entity(
      id: id,
      name: name,
      categorySlug: 'feat',
      fields: {
        'auto_granted_by': autoGrantedBy,
        ...grants,
      },
    );

Map<String, dynamic> _grantBy(String sourceName, int atLevel) => {
      'source': 'class',
      'source_ref': {'slug': 'class', 'name': sourceName},
      'at_level': atLevel,
    };

Map<String, dynamic> _extra(int value) => {'extra_attack_count': value};

Map<String, Entity> _fighterFeats() {
  final l5 = _feat(
    id: 'feat-extra-5',
    name: 'Extra Attack (Fighter)',
    autoGrantedBy: [_grantBy('Fighter', 5)],
    grants: _extra(2),
  );
  final l11 = _feat(
    id: 'feat-extra-11',
    name: 'Two Extra Attacks',
    autoGrantedBy: [_grantBy('Fighter', 11)],
    grants: _extra(3),
  );
  final l20 = _feat(
    id: 'feat-extra-20',
    name: 'Three Extra Attacks',
    autoGrantedBy: [_grantBy('Fighter', 20)],
    grants: _extra(4),
  );
  return {l5.id: l5, l11.id: l11, l20.id: l20};
}

void main() {
  group('resolveExtraAttackCountAt', () {
    test('returns 0 when class is null', () {
      expect(
        resolveExtraAttackCountAt(
          classEntity: null,
          subclassEntity: null,
          level: 5,
          entities: const {},
        ),
        0,
      );
    });

    test('returns 0 when level < 1', () {
      expect(
        resolveExtraAttackCountAt(
          classEntity: _class('Fighter'),
          subclassEntity: null,
          level: 0,
          entities: _fighterFeats(),
        ),
        0,
      );
    });

    test('returns 0 for Fighter L4 (below threshold)', () {
      expect(
        resolveExtraAttackCountAt(
          classEntity: _class('Fighter'),
          subclassEntity: null,
          level: 4,
          entities: _fighterFeats(),
        ),
        0,
      );
    });

    test('returns 2 for Fighter L5', () {
      expect(
        resolveExtraAttackCountAt(
          classEntity: _class('Fighter'),
          subclassEntity: null,
          level: 5,
          entities: _fighterFeats(),
        ),
        2,
      );
    });

    test('returns 3 for Fighter L11', () {
      expect(
        resolveExtraAttackCountAt(
          classEntity: _class('Fighter'),
          subclassEntity: null,
          level: 11,
          entities: _fighterFeats(),
        ),
        3,
      );
    });

    test('returns 4 for Fighter L20', () {
      expect(
        resolveExtraAttackCountAt(
          classEntity: _class('Fighter'),
          subclassEntity: null,
          level: 20,
          entities: _fighterFeats(),
        ),
        4,
      );
    });

    test('takes max across multiple matching effects', () {
      final feats = _fighterFeats();
      expect(
        resolveExtraAttackCountAt(
          classEntity: _class('Fighter'),
          subclassEntity: null,
          level: 15,
          entities: feats,
        ),
        3, // L11 grant active, L20 not yet
      );
    });

    test('a class-level table wins over the flat count', () {
      // Fighter's Extra Attack authored as one card with a level table
      // instead of three separate cards.
      final feat = _feat(
        id: 'feat-table',
        name: 'Extra Attack (table)',
        autoGrantedBy: [_grantBy('Fighter', 5)],
        grants: const {
          'extra_attack_count': 2,
          'extra_attack_count_by_level': {'5': 2, '11': 3, '20': 4},
        },
      );
      final entities = {feat.id: feat};
      expect(
        resolveExtraAttackCountAt(
          classEntity: _class('Fighter'),
          subclassEntity: null,
          level: 11,
          entities: entities,
        ),
        3,
      );
      expect(
        resolveExtraAttackCountAt(
          classEntity: _class('Fighter'),
          subclassEntity: null,
          level: 20,
          entities: entities,
        ),
        4,
      );
    });

    test('ignores feats not auto-granted by the active class', () {
      final feats = _fighterFeats();
      expect(
        resolveExtraAttackCountAt(
          classEntity: _class('Wizard'),
          subclassEntity: null,
          level: 20,
          entities: feats,
        ),
        0,
      );
    });
  });
}
