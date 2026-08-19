import 'package:dungeon_master_tool/domain/entities/character.dart';
import 'package:dungeon_master_tool/domain/entities/character/effective_character.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/character_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Roadmap phase R5 — the four chargen mechanics get a reader.**
///
/// R5 added the fields; this file is the proof that each one moves a number on
/// a resolved sheet. A field the resolver never reads is exactly the state
/// F-pass0-09 and F-pass0-03 were filed about, only one level further in.
///
///   * F-pass0-09 — `background.granted_languages`, the named half of a line
///     whose free half is already counted by `granted_language_count`.
///   * F-pass0-03 — `background.asi_fixed_ability_ref` +
///     `asi_free_bonus_count`: "+1 Charisma **and** one other".
///   * F-pass0-08 — `always_prepared_spell_refs` on a `features` row, gated by
///     that row's own level like every other level-table grant.
Entity _e(String id, String slug, String name,
        [Map<String, dynamic>? fields]) =>
    Entity(id: id, categorySlug: slug, name: name, fields: fields ?? const {});

final _world = <String, Entity>{
  'cls_rogue': _e('cls_rogue', 'class', 'Rogue'),
  'ab_cha': _e('ab_cha', 'ability', 'Charisma'),
  'ab_str': _e('ab_str', 'ability', 'Strength'),
  'lang_cant': _e('lang_cant', 'language', "Thieves' Cant"),
  'sp_low': _e('sp_low', 'spell', 'False Life'),
  'sp_high': _e('sp_high', 'spell', 'Cloudkill'),
};

EffectiveCharacter _resolve({
  Map<String, dynamic>? background,
  Map<String, dynamic>? subclass,
  Map<String, dynamic>? backgroundAsi,
  int level = 3,
}) {
  final world = <String, Entity>{
    ..._world,
    if (background != null) 'bg': _e('bg', 'background', 'Test BG', background),
    if (subclass != null) 'sub': _e('sub', 'subclass', 'Test Sub', subclass),
  };
  final pc = Character(
    id: 'pc1',
    templateId: 'tpl',
    templateName: 'Tpl',
    worldId: 'w',
    createdAt: '0',
    updatedAt: '0',
    entity: Entity(id: 'pc1_e', categorySlug: 'player', fields: {
      'class_levels': {'cls_rogue': level},
      if (background != null) 'background_id': 'bg',
      if (subclass != null) 'subclass_id': 'sub',
      if (backgroundAsi != null) 'background_asi': backgroundAsi,
      'base_abilities': const {
        'STR': 12, 'DEX': 14, 'CON': 12, 'INT': 10, 'WIS': 10, 'CHA': 10, //
      },
    }),
  );
  return CharacterResolver.resolve(pc, world);
}

void main() {
  group('F-pass0-09 — a background may name the language', () {
    test('the named language lands on the sheet', () {
      final e = _resolve(background: {
        'granted_languages': ['lang_cant'],
      });
      expect(e.proficiencies.languageIds, contains('lang_cant'));
    });

    test('the count half still means "pick this many"', () {
      // The count is a wizard input, not a proficiency — it must not
      // materialise a language on its own.
      final e = _resolve(background: {'granted_language_count': 2});
      expect(e.proficiencies.languageIds, isEmpty);
    });
  });

  group('F-pass0-03 — the mandatory half of the background ASI', () {
    test('the fixed +1 applies with no player choice recorded', () {
      final e = _resolve(background: {'asi_fixed_ability_ref': 'ab_cha'});
      expect(e.effectiveAbilities['CHA'], 11);
      expect(e.effectiveAbilities['STR'], 12);
    });

    test('it is applied once, not twice, when the player recorded it', () {
      // `background_asi: {CHA: 1}` is the wizard's record of this very bump.
      final e = _resolve(
        background: {'asi_fixed_ability_ref': 'ab_cha'},
        backgroundAsi: {'CHA': 1},
      );
      expect(e.effectiveAbilities['CHA'], 11);
    });

    test('the fixed ability is never "outside the options"', () {
      final e = _resolve(
        background: {
          'asi_fixed_ability_ref': 'ab_cha',
          // The free pick chooses among the *other* abilities.
          'ability_score_options': ['ab_str'],
        },
        backgroundAsi: {'CHA': 1, 'STR': 1},
      );
      expect(e.warnings.where((w) => w.contains('ability_score_options')),
          isEmpty);
      expect(e.effectiveAbilities['CHA'], 11);
      expect(e.effectiveAbilities['STR'], 13);
    });

    test('more free points than the card allows is surfaced', () {
      final e = _resolve(
        background: {
          'asi_fixed_ability_ref': 'ab_cha',
          'asi_free_bonus_count': 1,
          'ability_score_options': ['ab_str'],
        },
        backgroundAsi: {'STR': 2},
      );
      expect(e.warnings.any((w) => w.contains('free points')), isTrue);
    });
  });

  group('F-pass0-08 — a domain spell list is level-gated by its row', () {
    Map<String, dynamic> sub() => {
          'parent_class_ref': 'cls_rogue',
          'features': [
            {
              'level': 1,
              'name': 'Test Domain Spells (1st)',
              'always_prepared_spell_refs': ['sp_low'],
            },
            {
              'level': 9,
              'name': 'Test Domain Spells (9th)',
              'always_prepared_spell_refs': ['sp_high'],
            },
          ],
        };

    test('the tier at or below the class level is always prepared', () {
      final e = _resolve(subclass: sub(), level: 3);
      expect(e.alwaysPreparedSpellIds, ['sp_low']);
    });

    test('a higher tier arrives only at its own level', () {
      final e = _resolve(subclass: sub(), level: 9);
      expect(e.alwaysPreparedSpellIds, containsAll(['sp_low', 'sp_high']));
    });
  });
}
