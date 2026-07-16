import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves every SOURCE PATH that can carry rule effects actually feeds
/// `applyEffect`: the uniform `rule_effects` field on class / subclass /
/// species / background / auto-granted trait / equipped item, class
/// feature-row `effects` with their level gate, and the resolve-time
/// predicates as the predicate editor stores them.

Entity _e(String id, String slug, String name,
        [Map<String, dynamic>? fields]) =>
    Entity(id: id, categorySlug: slug, name: name, fields: fields ?? const {});

Character _pc(Map<String, dynamic> fields) => Character(
      id: 'pc1',
      templateId: 'tpl',
      templateName: 'Tpl',
      entity: Entity(id: 'pc1_e', categorySlug: 'player', fields: fields),
      worldId: 'world',
      createdAt: '0',
      updatedAt: '0',
    );

const _acRow = [
  {'kind': 'ac_bonus', 'value': 2},
];

void main() {
  group('rule_effects source paths', () {
    test('class rule_effects apply while the class is held', () {
      final cls = _e('cls_x', 'class', 'Fighter', {'rule_effects': _acRow});
      final eff = CharacterResolver.resolve(
        _pc({'class_levels': {'cls_x': 1}}),
        {cls.id: cls},
      );
      expect(eff.acBonus, 2);
    });

    test('subclass rule_effects apply', () {
      final cls = _e('cls_x', 'class', 'Cleric');
      final sub = _e('sub_x', 'subclass', 'Life Domain', {
        'parent_class_ref': 'cls_x',
        'granted_at_level': 1,
        'rule_effects': _acRow,
      });
      final eff = CharacterResolver.resolve(
        _pc({'class_levels': {'cls_x': 1}, 'subclass_id': 'sub_x'}),
        {cls.id: cls, sub.id: sub},
      );
      expect(eff.acBonus, 2);
    });

    test('species rule_effects apply', () {
      final sp = _e('sp_x', 'species', 'Dwarf', {'rule_effects': _acRow});
      final eff = CharacterResolver.resolve(
        _pc({'race_id': 'sp_x'}),
        {sp.id: sp},
      );
      expect(eff.acBonus, 2);
    });

    test('background rule_effects apply', () {
      final bg = _e('bg_x', 'background', 'Soldier', {'rule_effects': _acRow});
      final eff = CharacterResolver.resolve(
        _pc({'background_id': 'bg_x'}),
        {bg.id: bg},
      );
      expect(eff.acBonus, 2);
    });

    test('auto-granted trait rule_effects apply', () {
      final cls = _e('cls_x', 'class', 'Druid');
      final trait = _e('trait_x', 'trait', 'Stoneskin', {
        'auto_granted_by': [
          {'source': 'class', 'source_ref': 'cls_x', 'at_level': 1},
        ],
        'rule_effects': _acRow,
      });
      final eff = CharacterResolver.resolve(
        _pc({'class_levels': {'cls_x': 1}}),
        {cls.id: cls, trait.id: trait},
      );
      expect(eff.autoGrantedTraitIds, contains('trait_x'));
      expect(eff.acBonus, 2);
    });

    test('item rule_effects apply only while equipped', () {
      final ring =
          _e('item_ring', 'adventuring-gear', 'Ring of Protection', {
        'rule_effects': _acRow,
      });
      final equipped = CharacterResolver.resolve(
        _pc({
          'inventory': [
            {'id': 'item_ring', 'equipped': true},
          ],
        }),
        {ring.id: ring},
      );
      expect(equipped.acBonus, 2);

      final carried = CharacterResolver.resolve(
        _pc({
          'inventory': [
            {'id': 'item_ring', 'equipped': false},
          ],
        }),
        {ring.id: ring},
      );
      expect(carried.acBonus, 0,
          reason: 'unequipped items must not apply their effects');
    });

    test('class feature-row effects gate on class level', () {
      final cls = _e('cls_x', 'class', 'Monk', {
        'features': [
          {
            'level': 3,
            'description': 'Deflect',
            'effects': _acRow,
          },
        ],
      });
      final below = CharacterResolver.resolve(
        _pc({'class_levels': {'cls_x': 2}}),
        {cls.id: cls},
      );
      expect(below.acBonus, 0);
      final at = CharacterResolver.resolve(
        _pc({'class_levels': {'cls_x': 3}}),
        {cls.id: cls},
      );
      expect(at.acBonus, 2);
    });
  });

  group('scales_with on applied kinds', () {
    test('extra_attack_count honors a class-level scales_with table', () {
      final cls = _e('cls_f', 'class', 'Fighter');
      final feat = _e('feat_ea', 'feat', 'Extra Attack', {
        'effects': [
          {
            'kind': 'extra_attack_count',
            'scales_with': {
              'kind': 'class_level',
              'class_ref': 'cls_f',
              'table': [
                {'lvl': 5, 'v': 2},
                {'lvl': 11, 'v': 3},
              ],
            },
          },
        ],
      });
      int countAt(int lvl) => CharacterResolver.resolve(
            _pc({
              'feat_ids': ['feat_ea'],
              'class_levels': {'cls_f': lvl},
            }),
            {cls.id: cls, feat.id: feat},
          ).extraAttackCount;
      expect(countAt(1), 0, reason: 'below the table, no flat fallback');
      expect(countAt(5), 2);
      expect(countAt(11), 3);
    });
  });

  group('resolve-time predicates (editor-shaped args)', () {
    final lightCat = _e('armorcat_light', 'armor-category', 'Light');
    final shieldCat = _e('armorcat_shield', 'armor-category', 'Shield');
    final leather = _e('armor_leather', 'armor', 'Leather', {
      'category_ref': 'armorcat_light',
    });
    final shield = _e('armor_shield', 'armor', 'Shield', {
      'category_ref': 'armorcat_shield',
    });

    Map<String, Entity> world(Entity feat) => {
          lightCat.id: lightCat,
          shieldCat.id: shieldCat,
          leather.id: leather,
          shield.id: shield,
          feat.id: feat,
        };

    Entity gatedFeat(List<Map<String, dynamic>> predicates) =>
        _e('feat_g', 'feat', 'Gated', {
          'effects': [
            {'kind': 'ac_bonus', 'value': 2, 'predicates': predicates},
          ],
        });

    test("equipped_armor_kind 'none' gates on worn armor", () {
      final feat = gatedFeat([
        {'kind': 'equipped_armor_kind', 'args': {'value': 'none'}},
      ]);
      final bare = CharacterResolver.resolve(
        _pc({'feat_ids': ['feat_g']}),
        world(feat),
      );
      expect(bare.acBonus, 2);

      final armored = CharacterResolver.resolve(
        _pc({
          'feat_ids': ['feat_g'],
          'inventory': [
            {'id': 'armor_leather', 'equipped': true},
          ],
        }),
        world(feat),
      );
      expect(armored.acBonus, 0);
    });

    test("equipped_armor_kind 'light' requires matching worn armor", () {
      final feat = gatedFeat([
        {'kind': 'equipped_armor_kind', 'args': {'value': 'light'}},
      ]);
      final armored = CharacterResolver.resolve(
        _pc({
          'feat_ids': ['feat_g'],
          'inventory': [
            {'id': 'armor_leather', 'equipped': true},
          ],
        }),
        world(feat),
      );
      expect(armored.acBonus, 2);

      final bare = CharacterResolver.resolve(
        _pc({'feat_ids': ['feat_g']}),
        world(feat),
      );
      expect(bare.acBonus, 0);
    });

    test('equipped_shield true/false variants', () {
      final wantsShield = gatedFeat([
        {'kind': 'equipped_shield', 'args': {'value': 'true'}},
      ]);
      final withShield = CharacterResolver.resolve(
        _pc({
          'feat_ids': ['feat_g'],
          'inventory': [
            {'id': 'armor_shield', 'equipped': true},
          ],
        }),
        world(wantsShield),
      );
      expect(withShield.acBonus, 2);

      final without = CharacterResolver.resolve(
        _pc({'feat_ids': ['feat_g']}),
        world(wantsShield),
      );
      expect(without.acBonus, 0);
    });

    test('class_level_at_least with a String class_ref (editor shape)', () {
      final cls = _e('cls_x', 'class', 'Barbarian');
      final feat = gatedFeat([
        {
          'kind': 'class_level_at_least',
          'args': {'class_ref': 'cls_x', 'level': 3},
        },
      ]);
      final low = CharacterResolver.resolve(
        _pc({'feat_ids': ['feat_g'], 'class_levels': {'cls_x': 2}}),
        {cls.id: cls, feat.id: feat},
      );
      expect(low.acBonus, 0);
      final high = CharacterResolver.resolve(
        _pc({'feat_ids': ['feat_g'], 'class_levels': {'cls_x': 3}}),
        {cls.id: cls, feat.id: feat},
      );
      expect(high.acBonus, 2);
    });

    test('not_incapacitated passes at resolve time', () {
      final feat = gatedFeat([
        {'kind': 'not_incapacitated', 'args': <String, dynamic>{}},
      ]);
      final eff = CharacterResolver.resolve(
        _pc({'feat_ids': ['feat_g']}),
        {feat.id: feat},
      );
      expect(eff.acBonus, 2);
    });
  });
}
