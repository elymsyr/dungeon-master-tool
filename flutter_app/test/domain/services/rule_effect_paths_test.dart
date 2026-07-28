import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves every SOURCE PATH that can carry a grant block actually feeds
/// `applyGrantsFrom`: chosen feats, auto-granted feats (class walker),
/// species, subspecies (entity + legacy nested option row), traits from
/// species `trait_refs`, and equipped items.

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

const _acGrant = {'ac_bonus': 2};

void main() {
  group('grant-block source paths', () {
    test('chosen feat grants apply', () {
      final feat = _e('feat_x', 'feat', 'Shield Training', _acGrant);
      final eff = CharacterResolver.resolve(
        _pc({'feat_ids': ['feat_x']}),
        {feat.id: feat},
      );
      expect(eff.acBonus, 2);
    });

    test('auto-granted class-feature feat gates on class level', () {
      final cls = _e('cls_x', 'class', 'Fighter');
      final feat = _e('feat_x', 'feat', 'L5 Feature', {
        ..._acGrant,
        'auto_granted_by': [
          {
            'source': 'class',
            'source_ref': 'cls_x',
            'at_level': 5,
          },
        ],
      });
      final at4 = CharacterResolver.resolve(
        _pc({'class_levels': {'cls_x': 4}}),
        {cls.id: cls, feat.id: feat},
      );
      expect(at4.acBonus, 0, reason: 'below the grant level');
      final at5 = CharacterResolver.resolve(
        _pc({'class_levels': {'cls_x': 5}}),
        {cls.id: cls, feat.id: feat},
      );
      expect(at5.acBonus, 2);
    });

    test('species grants apply', () {
      final sp = _e('sp_x', 'species', 'Dwarf', _acGrant);
      final eff = CharacterResolver.resolve(
        _pc({'race_id': 'sp_x'}),
        {sp.id: sp},
      );
      expect(eff.acBonus, 2);
    });

    test('subspecies entity grants apply', () {
      final sp = _e('sp_x', 'species', 'Dwarf');
      final sub = _e('sub_x', 'subspecies', 'Hill Dwarf', {
        'parent_species_ref': 'sp_x',
        'hp_bonus_per_level': 1,
      });
      final eff = CharacterResolver.resolve(
        _pc({'race_id': 'sp_x', 'subspecies_id': 'sub_x'}),
        {sp.id: sp, sub.id: sub},
      );
      expect(eff.hpBonusPerLevel, 1);
    });

    test('legacy nested subspecies_options row still applies', () {
      final sp = _e('sp_x', 'species', 'Dwarf', {
        'subspecies_options': [
          {'name': 'Hill Dwarf', 'hp_bonus_per_level': 1},
        ],
      });
      final eff = CharacterResolver.resolve(
        _pc({'race_id': 'sp_x', 'subspecies_id': 'Hill Dwarf'}),
        {sp.id: sp},
      );
      expect(eff.hpBonusPerLevel, 1);
    });

    test('species trait_refs apply the trait grant block', () {
      final sp = _e('sp_x', 'species', 'Dwarf', {
        'trait_refs': ['trait_x'],
      });
      final trait = _e('trait_x', 'trait', 'Stout', _acGrant);
      final eff = CharacterResolver.resolve(
        _pc({'race_id': 'sp_x'}),
        {sp.id: sp, trait.id: trait},
      );
      expect(eff.autoGrantedTraitIds, contains('trait_x'));
      expect(eff.acBonus, 2);
    });

    test('item grants apply only while equipped', () {
      final item = _e('item_x', 'magic-item', 'Ring of Protection', _acGrant);
      final equipped = CharacterResolver.resolve(
        _pc({
          'inventory': [
            {'id': 'item_x', 'equipped': true},
          ],
        }),
        {item.id: item},
      );
      expect(equipped.acBonus, 2);
      final carried = CharacterResolver.resolve(
        _pc({
          'inventory': [
            {'id': 'item_x', 'equipped': false},
          ],
        }),
        {item.id: item},
      );
      expect(carried.acBonus, 0);
    });

    test('grant refs accept lookup-map envelopes, not just String ids', () {
      // Pack data resolves placeholders at import, but a hand-edited card can
      // still carry {slug,name} envelopes — the shared ref resolver accepts
      // them by name.
      final skill = _e('sk_x', 'skill', 'Arcana');
      final feat = _e('feat_x', 'feat', 'Scholar', {
        'granted_skill_proficiencies': [
          {'slug': 'skill', 'name': 'Arcana'},
        ],
      });
      final eff = CharacterResolver.resolve(
        _pc({'feat_ids': ['feat_x']}),
        {skill.id: skill, feat.id: feat},
      );
      expect(eff.proficiencies.skillIds, contains('sk_x'));
    });
  });
}
