import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/application/character_creation/character_draft.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/presentation/screens/characters/wizard/steps/feats_step.dart';

Entity _feat({
  required String id,
  required String name,
  required List<Map<String, dynamic>> effects,
}) =>
    Entity(
      id: id,
      name: name,
      categorySlug: 'feat',
      source: 'test',
      description: '',
      images: const [],
      imagePath: '',
      tags: const [],
      dmNotes: '',
      pdfs: const [],
      locationId: null,
      fields: {'effects': effects},
    );

Entity _bg({required String id, required String originFeatId}) => Entity(
      id: id,
      name: 'BG',
      categorySlug: 'background',
      source: 'test',
      description: '',
      images: const [],
      imagePath: '',
      tags: const [],
      dmNotes: '',
      pdfs: const [],
      locationId: null,
      fields: {'origin_feat_ref': originFeatId},
    );

Entity _ent(String id, String name, String slug, [Map<String, dynamic>? fx]) =>
    Entity(
      id: id,
      name: name,
      categorySlug: slug,
      source: 'test',
      description: '',
      images: const [],
      imagePath: '',
      tags: const [],
      dmNotes: '',
      pdfs: const [],
      locationId: null,
      fields: fx ?? const {},
    );

void main() {
  group('deriveFeatChoiceContributions', () {
    test('Tavern Brawler ASI bumps the chosen ability', () {
      final feat = _feat(
        id: 'feat-tb',
        name: 'Tavern Brawler',
        effects: [
          {
            'kind': 'choice_group',
            'payload': {
              'group_id': 'asi',
              'pick_kind': 'ability',
              'pick': 1,
              'ability_options': ['STR', 'CON'],
            },
          },
        ],
      );
      final bg = _bg(id: 'bg', originFeatId: 'feat-tb');
      final draft = CharacterDraft(
        backgroundId: 'bg',
        originFeatChoices: {'feat-tb:asi': 'CON'},
      );
      final entities = {'feat-tb': feat, 'bg': bg};

      final out = deriveFeatChoiceContributions(draft, entities);
      expect(out.abilityBumps['CON'], 1);
      expect(out.abilityBumps['STR'], 0);
      expect(out.skillIds, isEmpty);
    });

    test('Skilled routes skill picks vs tool picks by category', () {
      final feat = _feat(
        id: 'feat-skl',
        name: 'Skilled',
        effects: [
          {
            'kind': 'choice_group',
            'payload': {
              'group_id': 'picks',
              'pick_kind': 'skill_or_tool',
              'pick': 3,
            },
          },
        ],
      );
      final bg = _bg(id: 'bg', originFeatId: 'feat-skl');
      final draft = CharacterDraft(
        backgroundId: 'bg',
        originFeatChoices: {'feat-skl:picks': 'sk-1,tl-1,sk-2'},
      );
      final entities = {
        'feat-skl': feat,
        'bg': bg,
        'sk-1': _ent('sk-1', 'Athletics', 'skill'),
        'sk-2': _ent('sk-2', 'Stealth', 'skill'),
        'tl-1': _ent('tl-1', 'Thieves Tools', 'tool'),
      };

      final out = deriveFeatChoiceContributions(draft, entities);
      expect(out.skillIds, ['sk-1', 'sk-2']);
      expect(out.toolIds, ['tl-1']);
    });

    test('Magic Initiate spell picks route by spell_level', () {
      final feat = _feat(
        id: 'feat-mi',
        name: 'Magic Initiate',
        effects: [
          {
            'kind': 'choice_group',
            'payload': {
              'group_id': 'list',
              'pick_kind': 'enum',
              'pick': 1,
              'options': [
                {'id': 'Cleric', 'label': 'Cleric'},
              ],
            },
          },
          {
            'kind': 'choice_group',
            'payload': {
              'group_id': 'cantrips',
              'pick_kind': 'spell_from_list',
              'pick': 2,
              'list_group_id': 'list',
              'spell_level': 0,
            },
          },
          {
            'kind': 'choice_group',
            'payload': {
              'group_id': 'level1',
              'pick_kind': 'spell_from_list',
              'pick': 1,
              'list_group_id': 'list',
              'spell_level': 1,
            },
          },
        ],
      );
      final bg = _bg(id: 'bg', originFeatId: 'feat-mi');
      final draft = CharacterDraft(
        backgroundId: 'bg',
        originFeatChoices: {
          'feat-mi:list': 'Cleric',
          'feat-mi:cantrips': 'sp-c1,sp-c2',
          'feat-mi:level1': 'sp-l1',
        },
      );
      final entities = {
        'feat-mi': feat,
        'bg': bg,
        'sp-c1': _ent('sp-c1', 'Light', 'spell'),
        'sp-c2': _ent('sp-c2', 'Guidance', 'spell'),
        'sp-l1': _ent('sp-l1', 'Cure Wounds', 'spell'),
      };

      final out = deriveFeatChoiceContributions(draft, entities);
      expect(out.cantripIds, ['sp-c1', 'sp-c2']);
      expect(out.preparedSpellIds, ['sp-l1']);
    });

    test('no contributions when no choices made', () {
      final feat = _feat(
        id: 'feat-tb',
        name: 'Tavern Brawler',
        effects: [
          {
            'kind': 'choice_group',
            'payload': {
              'group_id': 'asi',
              'pick_kind': 'ability',
              'pick': 1,
              'ability_options': ['STR', 'CON'],
            },
          },
        ],
      );
      final bg = _bg(id: 'bg', originFeatId: 'feat-tb');
      final draft = CharacterDraft(backgroundId: 'bg');
      final entities = {'feat-tb': feat, 'bg': bg};

      final out = deriveFeatChoiceContributions(draft, entities);
      expect(out.isEmpty, isTrue);
    });
  });

  group('validateFeatsStep', () {
    test('null when no active feats', () {
      expect(validateFeatsStep(const CharacterDraft(), const {}), isNull);
    });

    test('errors when origin feat has unresolved choice', () {
      final feat = _feat(
        id: 'feat-tb',
        name: 'Tavern Brawler',
        effects: [
          {
            'kind': 'choice_group',
            'payload': {
              'group_id': 'asi',
              'label': 'ASI',
              'pick_kind': 'ability',
              'pick': 1,
              'ability_options': ['STR', 'CON'],
            },
          },
        ],
      );
      final bg = _bg(id: 'bg', originFeatId: 'feat-tb');
      final draft = CharacterDraft(backgroundId: 'bg');
      final entities = {'feat-tb': feat, 'bg': bg};
      final err = validateFeatsStep(draft, entities);
      expect(err, isNotNull);
      expect(err, contains('Tavern Brawler'));
    });

    test('passes when chosen', () {
      final feat = _feat(
        id: 'feat-tb',
        name: 'Tavern Brawler',
        effects: [
          {
            'kind': 'choice_group',
            'payload': {
              'group_id': 'asi',
              'label': 'ASI',
              'pick_kind': 'ability',
              'pick': 1,
              'ability_options': ['STR', 'CON'],
            },
          },
        ],
      );
      final bg = _bg(id: 'bg', originFeatId: 'feat-tb');
      final draft = CharacterDraft(
        backgroundId: 'bg',
        originFeatChoices: {'feat-tb:asi': 'STR'},
      );
      final entities = {'feat-tb': feat, 'bg': bg};
      expect(validateFeatsStep(draft, entities), isNull);
    });

    test('skip nested spell_from_list when upstream list unset', () {
      final feat = _feat(
        id: 'feat-mi',
        name: 'Magic Initiate',
        effects: [
          {
            'kind': 'choice_group',
            'payload': {
              'group_id': 'list',
              'label': 'List',
              'pick_kind': 'enum',
              'pick': 1,
              'options': [
                {'id': 'Cleric', 'label': 'Cleric'},
              ],
            },
          },
          {
            'kind': 'choice_group',
            'payload': {
              'group_id': 'cantrips',
              'label': 'Cantrips',
              'pick_kind': 'spell_from_list',
              'pick': 2,
              'list_group_id': 'list',
              'spell_level': 0,
            },
          },
        ],
      );
      final bg = _bg(id: 'bg', originFeatId: 'feat-mi');
      final draft = CharacterDraft(backgroundId: 'bg');
      final entities = {'feat-mi': feat, 'bg': bg};
      final err = validateFeatsStep(draft, entities);
      // Upstream 'list' is unset → surfaces upstream error, not cantrips.
      expect(err, contains('List'));
    });
  });
}
