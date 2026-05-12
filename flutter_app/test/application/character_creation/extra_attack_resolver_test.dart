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

Map<String, dynamic> _extra(int value) =>
    {'kind': 'extra_attack_count', 'value': value};

Map<String, Entity> _fighterFeats() {
  final l5 = _feat(
    id: 'feat-extra-5',
    name: 'Extra Attack (Fighter)',
    autoGrantedBy: [_grantBy('Fighter', 5)],
    effects: [_extra(2)],
  );
  final l11 = _feat(
    id: 'feat-extra-11',
    name: 'Two Extra Attacks',
    autoGrantedBy: [_grantBy('Fighter', 11)],
    effects: [_extra(3)],
  );
  final l20 = _feat(
    id: 'feat-extra-20',
    name: 'Three Extra Attacks',
    autoGrantedBy: [_grantBy('Fighter', 20)],
    effects: [_extra(4)],
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

    test('treats extra_attack_bump as equivalent to extra_attack_count', () {
      final feat = _feat(
        id: 'feat-bump',
        name: 'Bump Variant',
        autoGrantedBy: [_grantBy('Barbarian', 5)],
        effects: const [
          {'kind': 'extra_attack_bump', 'value': 2},
        ],
      );
      expect(
        resolveExtraAttackCountAt(
          classEntity: _class('Barbarian'),
          subclassEntity: null,
          level: 5,
          entities: {feat.id: feat},
        ),
        2,
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
