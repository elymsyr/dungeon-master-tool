import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/character/effective_character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Every card that can grant, grants the same way.**
///
/// `grant_field_isolation_test.dart` proves each field works when a Feat
/// carries it. This one takes one identical bundle of grants and hangs it off
/// every card type in turn — chosen feat, auto-granted class/subclass/species/
/// background feature, species, subspecies, legacy nested subspecies row,
/// trait, equipped magic item — and demands the resolved sheet come out the
/// same. That is what "one reader for every source" has to mean in practice:
/// no card type may quietly support a smaller subset of the vocabulary.

Entity _e(String id, String slug, String name,
        [Map<String, dynamic>? fields]) =>
    Entity(id: id, categorySlug: slug, name: name, fields: fields ?? const {});

/// One grant of each shape the block supports: a ref list, a scalar, a
/// structured row, a sense row, a speed and a prose note. A source that can
/// carry the block has to carry all of it.
const _bundle = <String, dynamic>{
  'granted_tool_proficiencies': ['tool_x'],
  'granted_skill_proficiencies': ['sk_x'],
  'granted_damage_resistances': ['dt_fire'],
  'ac_bonus': 2,
  'speed_climb_ft': -1,
  'granted_senses': [
    {'sense_ref': 'sense_dv', 'range_ft': 60},
  ],
  'resource_pool_grants': [
    {
      'pool_ref': {'name': 'pool:test_uses'},
      'recharge': 'long_rest',
      'count': 2,
    },
  ],
  'mechanical_notes': 'Roll-time rule the engine cannot compute',
};

final _refs = <String, Entity>{
  'tool_x': _e('tool_x', 'tool', "Thieves' Tools"),
  'sk_x': _e('sk_x', 'skill', 'Stealth'),
  'dt_fire': _e('dt_fire', 'damage-type', 'Fire'),
  'sense_dv': _e('sense_dv', 'sense', 'Darkvision'),
  'cls_a': _e('cls_a', 'class', 'Rogue'),
};

/// The Rogue card with a level table that hands out [ids] at [level]. A class
/// states its grants here and nowhere else, so every "auto-granted" case below
/// builds its source card this way.
Map<String, Entity> _classGranting(
  int level,
  Map<String, List<String>> refsByKey, {
  String id = 'cls_a',
  String slug = 'class',
  String name = 'Rogue',
  Map<String, dynamic> extra = const {},
}) =>
    {
      id: _e(id, slug, name, {
        ...extra,
        'features': [
          {'level': level, 'name': 'Feature', ...refsByKey},
        ],
      }),
    };

Character _pc(Map<String, dynamic> extra) => Character(
      id: 'pc1',
      templateId: 'tpl',
      templateName: 'Tpl',
      worldId: 'w',
      createdAt: '0',
      updatedAt: '0',
      entity: Entity(id: 'pc1_e', categorySlug: 'player', fields: {
        'class_levels': {'cls_a': 5},
        'base_abilities': {
          'STR': 10, 'DEX': 10, 'CON': 10, 'INT': 10, 'WIS': 10, 'CHA': 10, //
        },
        ...extra,
      }),
    );

/// Assert the whole bundle landed, whatever card carried it.
void _expectBundleApplied(EffectiveCharacter eff, {required String from}) {
  expect(eff.proficiencies.toolIds, contains('tool_x'), reason: from);
  expect(eff.proficiencies.skillIds, contains('sk_x'), reason: from);
  expect(eff.damageResistanceIds, contains('dt_fire'), reason: from);
  expect(eff.acBonus, 2, reason: from);
  expect(eff.senseRanges['sense_dv'], 60, reason: from);
  // -1 resolved against the base walking speed of 30.
  expect(eff.extraSpeeds['climb'], 30, reason: from);
  expect(eff.resourcePools.single['max'], 2, reason: from);
  expect(eff.mechanicalNotes,
      contains('Roll-time rule the engine cannot compute'),
      reason: from);
  expect(eff.warnings, isEmpty, reason: from);
}

void main() {
  group('every grant source applies the whole block', () {
    test('a feat the player chose', () {
      final eff = CharacterResolver.resolve(
        _pc({'feat_ids': ['feat_x']}),
        {..._refs, 'feat_x': _e('feat_x', 'feat', 'Skulker', _bundle)},
      );
      _expectBundleApplied(eff, from: 'chosen feat');
    });

    test('a class-feature feat auto-granted at the current level', () {
      final feat = _e('feat_x', 'feat', 'Cunning Action', _bundle);
      _expectBundleApplied(
        CharacterResolver.resolve(_pc(const {}), {
          ..._refs,
          ..._classGranting(2, const {'granted_feat_refs': ['feat_x']}),
          'feat_x': feat,
        }),
        from: 'auto-granted class feature',
      );
    });

    test('a subclass feature feat, gated on the parent class level', () {
      final feat = _e('feat_x', 'feat', 'Second-Story Work', _bundle);
      _expectBundleApplied(
        CharacterResolver.resolve(
          _pc({'subclass_id': 'sub_a'}),
          {
            ..._refs,
            ..._classGranting(
              3,
              const {'granted_feat_refs': ['feat_x']},
              id: 'sub_a',
              slug: 'subclass',
              name: 'Thief',
              extra: const {'parent_class_ref': 'cls_a'},
            ),
            'feat_x': feat,
          },
        ),
        from: 'auto-granted subclass feature',
      );
    });

    test('a species feature feat', () {
      final sp = _e('sp_x', 'species', 'Elf', {
        'granted_feat_refs': ['feat_x'],
      });
      final feat = _e('feat_x', 'feat', 'Fey Ancestry', _bundle);
      _expectBundleApplied(
        CharacterResolver.resolve(
          _pc({'race_id': 'sp_x'}),
          {..._refs, 'sp_x': sp, 'feat_x': feat},
        ),
        from: 'auto-granted species feature',
      );
    });

    test('a background origin feat, once chargen has taken it', () {
      // A Background names its feat on `origin_feat_ref`, but the resolver
      // deliberately does not force-apply it: the wizard writes it into
      // `feat_ids` so the player can swap it. This is that state.
      final bg = _e('bg_x', 'background', 'Criminal', {
        'origin_feat_ref': 'feat_x',
      });
      final feat = _e('feat_x', 'feat', 'Alert', _bundle);
      _expectBundleApplied(
        CharacterResolver.resolve(
          _pc({'background_id': 'bg_x', 'feat_ids': ['feat_x']}),
          {..._refs, 'bg_x': bg, 'feat_x': feat},
        ),
        from: 'background origin feat',
      );
    });

    test('the species card itself', () {
      _expectBundleApplied(
        CharacterResolver.resolve(
          _pc({'race_id': 'sp_x'}),
          {..._refs, 'sp_x': _e('sp_x', 'species', 'Dwarf', _bundle)},
        ),
        from: 'species card',
      );
    });

    test('a subspecies card', () {
      final sp = _e('sp_x', 'species', 'Dwarf');
      final sub = _e('sub_x', 'subspecies', 'Hill Dwarf', {
        ..._bundle,
        'parent_species_ref': 'sp_x',
      });
      _expectBundleApplied(
        CharacterResolver.resolve(
          _pc({'race_id': 'sp_x', 'subspecies_id': 'sub_x'}),
          {..._refs, 'sp_x': sp, 'sub_x': sub},
        ),
        from: 'subspecies card',
      );
    });

    test('a legacy nested subspecies_options row', () {
      // Saves made before subspecies became first-class entities still store
      // the option by name; they must not lose mechanics on load.
      final sp = _e('sp_x', 'species', 'Dwarf', {
        'subspecies_options': [
          {'name': 'Hill Dwarf', ..._bundle},
        ],
      });
      _expectBundleApplied(
        CharacterResolver.resolve(
          _pc({'race_id': 'sp_x', 'subspecies_id': 'Hill Dwarf'}),
          {..._refs, 'sp_x': sp},
        ),
        from: 'legacy subspecies_options row',
      );
    });

    test('a trait pulled in by species trait_refs', () {
      final sp = _e('sp_x', 'species', 'Dwarf', {'trait_refs': ['trait_x']});
      final trait = _e('trait_x', 'trait', 'Dwarven Resilience', _bundle);
      _expectBundleApplied(
        CharacterResolver.resolve(
          _pc({'race_id': 'sp_x'}),
          {..._refs, 'sp_x': sp, 'trait_x': trait},
        ),
        from: 'trait via trait_refs',
      );
    });

    test('a trait named by a class level row', () {
      final trait = _e('trait_x', 'trait', 'Evasion', _bundle);
      _expectBundleApplied(
        CharacterResolver.resolve(_pc(const {}), {
          ..._refs,
          ..._classGranting(5, const {'granted_trait_refs': ['trait_x']}),
          'trait_x': trait,
        }),
        from: 'trait via a class features row',
      );
    });

    test('an equipped magic item', () {
      final item = _e('item_x', 'magic-item', 'Cloak of Elvenkind', _bundle);
      _expectBundleApplied(
        CharacterResolver.resolve(
          _pc({
            'inventory': [
              {'id': 'item_x', 'equipped': true},
            ],
          }),
          {..._refs, 'item_x': item},
        ),
        from: 'equipped magic item',
      );
    });
  });

  group('a grant that should not apply, does not', () {
    test('a level row above the character level stays off the sheet', () {
      final feat = _e('feat_x', 'feat', 'Extra Attack', _bundle);
      final eff = CharacterResolver.resolve(_pc(const {}), {
        ..._refs,
        ..._classGranting(11, const {'granted_feat_refs': ['feat_x']}),
        'feat_x': feat,
      });
      expect(eff.autoGrantedFeatIds, isEmpty);
      expect(eff.proficiencies.toolIds, isEmpty);
      expect(eff.acBonus, 0);
      expect(eff.mechanicalNotes, isEmpty);
    });

    test('an unequipped magic item grants nothing', () {
      final item = _e('item_x', 'magic-item', 'Cloak of Elvenkind', _bundle);
      final eff = CharacterResolver.resolve(
        _pc({
          'inventory': [
            {'id': 'item_x', 'equipped': false},
          ],
        }),
        {..._refs, 'item_x': item},
      );
      expect(eff.proficiencies.toolIds, isEmpty);
      expect(eff.acBonus, 0);
      expect(eff.resourcePools, isEmpty);
      expect(eff.mechanicalNotes, isEmpty);
    });

    test('a subspecies of a different species is not applied', () {
      final sp = _e('sp_x', 'species', 'Dwarf');
      final other = _e('sub_y', 'subspecies', 'High Elf', {
        ..._bundle,
        'parent_species_ref': 'sp_other',
      });
      final eff = CharacterResolver.resolve(
        _pc({'race_id': 'sp_x', 'subspecies_id': 'High Elf'}),
        {..._refs, 'sp_x': sp, 'sub_y': other},
      );
      expect(eff.proficiencies.toolIds, isEmpty);
      expect(eff.acBonus, 0);
    });
  });

  group('class and background grant through their own named fields', () {
    // These two categories deliberately do not carry the grant block: every
    // mechanic they have already had a typed home. The test pins that the
    // typed home actually reaches the sheet — `granted_languages` on a class
    // was authored on Druid and Rogue for months while nothing read it.
    test('class saving throws, tools, languages, weapon and armor training', () {
      final cls = _e('cls_b', 'class', 'Druid', {
        'saving_throw_refs': ['ab_int', 'ab_wis'],
        'granted_tool_refs': ['tool_x'],
        'granted_languages': ['lang_x'],
        'weapon_proficiency_categories': ['wcat_x'],
        'armor_training_refs': ['acat_x'],
      });
      final eff = CharacterResolver.resolve(
        _pc({'class_levels': {'cls_b': 1}}),
        {
          'cls_b': cls,
          'tool_x': _refs['tool_x']!,
          'ab_int': _e('ab_int', 'ability', 'Intelligence'),
          'ab_wis': _e('ab_wis', 'ability', 'Wisdom'),
          'lang_x': _e('lang_x', 'language', 'Druidic'),
          'wcat_x': _e('wcat_x', 'weapon-category', 'Simple'),
          'acat_x': _e('acat_x', 'armor-category', 'Light'),
        },
      );
      expect(eff.proficiencies.savingThrowAbilityIds,
          containsAll(['ab_int', 'ab_wis']));
      expect(eff.proficiencies.toolIds, contains('tool_x'));
      expect(eff.proficiencies.languageIds, contains('lang_x'));
      expect(eff.proficiencies.weaponCategoryIds, contains('wcat_x'));
      expect(eff.proficiencies.armorCategoryIds, contains('acat_x'));
    });

    test('subclass extends the class proficiencies', () {
      final cls = _e('cls_b', 'class', 'Fighter', {
        'saving_throw_refs': ['ab_str'],
      });
      final sub = _e('sub_b', 'subclass', 'Eldritch Knight', {
        'parent_class_ref': 'cls_b',
        'saving_throw_refs': ['ab_int'],
        'armor_training_refs': ['acat_x'],
      });
      final eff = CharacterResolver.resolve(
        _pc({'class_levels': {'cls_b': 3}, 'subclass_id': 'sub_b'}),
        {
          'cls_b': cls,
          'sub_b': sub,
          'ab_str': _e('ab_str', 'ability', 'Strength'),
          'ab_int': _e('ab_int', 'ability', 'Intelligence'),
          'acat_x': _e('acat_x', 'armor-category', 'Heavy'),
        },
      );
      expect(eff.proficiencies.savingThrowAbilityIds,
          containsAll(['ab_str', 'ab_int']));
      expect(eff.proficiencies.armorCategoryIds, contains('acat_x'));
    });

    test('background skills and tools', () {
      final bg = _e('bg_x', 'background', 'Criminal', {
        'granted_skill_refs': ['sk_x'],
        'granted_tool_refs': ['tool_x'],
      });
      final eff = CharacterResolver.resolve(
        _pc({'background_id': 'bg_x'}),
        {..._refs, 'bg_x': bg},
      );
      expect(eff.proficiencies.skillIds, contains('sk_x'));
      expect(eff.proficiencies.toolIds, contains('tool_x'));
    });
  });

  group('grants from several sources combine without clobbering', () {
    test('species + subspecies + feat + item stack into one sheet', () {
      final eff = CharacterResolver.resolve(
        _pc({
          'race_id': 'sp_x',
          'subspecies_id': 'sub_x',
          'feat_ids': ['feat_x'],
          'inventory': [
            {'id': 'item_x', 'equipped': true},
          ],
        }),
        {
          ..._refs,
          'sp_x': _e('sp_x', 'species', 'Dwarf', {
            'granted_tool_proficiencies': ['tool_x'],
            'ac_bonus': 1,
          }),
          'sub_x': _e('sub_x', 'subspecies', 'Hill Dwarf', {
            'parent_species_ref': 'sp_x',
            'granted_skill_proficiencies': ['sk_x'],
            'ac_bonus': 1,
          }),
          'feat_x': _e('feat_x', 'feat', 'Tough', {
            'granted_damage_resistances': ['dt_fire'],
            'ac_bonus': 1,
          }),
          'item_x': _e('item_x', 'magic-item', 'Ring of Protection', {
            'granted_senses': [
              {'sense_ref': 'sense_dv', 'range_ft': 60},
            ],
            'ac_bonus': 1,
          }),
        },
      );
      // Scalars sum across sources…
      expect(eff.acBonus, 4);
      // …and each source's own grant still arrives intact.
      expect(eff.proficiencies.toolIds, contains('tool_x'));
      expect(eff.proficiencies.skillIds, contains('sk_x'));
      expect(eff.damageResistanceIds, contains('dt_fire'));
      expect(eff.senseRanges['sense_dv'], 60);
    });

    test('the same grant from two sources is not double-listed', () {
      final eff = CharacterResolver.resolve(
        _pc({'race_id': 'sp_x', 'feat_ids': ['feat_x']}),
        {
          ..._refs,
          'sp_x': _e('sp_x', 'species', 'Dwarf', {
            'granted_tool_proficiencies': ['tool_x'],
          }),
          'feat_x': _e('feat_x', 'feat', 'Skilled', {
            'granted_tool_proficiencies': ['tool_x'],
          }),
        },
      );
      expect(eff.proficiencies.toolIds, ['tool_x']);
    });

    test('a duplicated defense credits both sources but lists it once', () {
      final eff = CharacterResolver.resolve(
        _pc({'race_id': 'sp_x', 'feat_ids': ['feat_x']}),
        {
          ..._refs,
          'sp_x': _e('sp_x', 'species', 'Dwarf', {
            'granted_damage_resistances': ['dt_fire'],
          }),
          'feat_x': _e('feat_x', 'feat', 'Elemental Adept', {
            'granted_damage_resistances': ['dt_fire'],
          }),
        },
      );
      expect(eff.damageResistanceIds, ['dt_fire']);
      expect(eff.grantSources['dt_fire'],
          containsAll(['Dwarf', 'Elemental Adept']));
    });
  });
}
