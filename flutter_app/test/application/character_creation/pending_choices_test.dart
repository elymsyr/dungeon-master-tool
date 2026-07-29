import 'package:dungeon_master_tool/application/character_creation/pending_choices.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// `player_choices` is the one field a card uses to say "taking this makes the
/// player pick something later". It replaced the `choice_group` effect rows,
/// and unlike every other grant it is *not* applied by `CharacterResolver` —
/// the resolved sheet has nothing to show until the player has picked. These
/// tests cover the reader that does consume it.
///
/// Sibling coverage: `grant_field_isolation_test.dart` asserts the opposite
/// half — that a card carrying only `player_choices` moves nothing on the
/// resolved sheet.

Entity _feat(String id, String name, List<Map<String, dynamic>> choices,
        [Map<String, dynamic> extra = const {}]) =>
    Entity(
      id: id,
      name: name,
      categorySlug: 'feat',
      fields: {'player_choices': choices, ...extra},
    );

void main() {
  group('seedFeatChoicePendings', () {
    test('Skilled queues one pending per unfilled group', () {
      final skilled = _feat('feat-skilled', 'Skilled', [
        {
          'group_id': 'skilled_picks',
          'label': 'Skills or Tools',
          'pick_kind': 'skill_or_tool',
          'pick': 3,
        },
      ]);
      final out = seedFeatChoicePendings(
        feats: [skilled],
        existingFeatChoices: const {},
        level: 1,
      );
      expect(out, hasLength(1));
      expect(out.single.kind, PendingChoiceKind.featChoice);
      expect(out.single.count, 3);
      expect(out.single.featureName, 'Skills or Tools');
      expect(out.single.sourceEntityId, 'feat-skilled');
      expect(out.single.classLabel, 'Skilled');
    });

    test('picks already made shrink the remaining count', () {
      final skilled = _feat('feat-skilled', 'Skilled', [
        {'group_id': 'g', 'label': 'Picks', 'pick_kind': 'skill', 'pick': 3},
      ]);
      final out = seedFeatChoicePendings(
        feats: [skilled],
        existingFeatChoices: const {'feat-skilled:g': 'sk_a,sk_b'},
        level: 1,
      );
      expect(out.single.count, 1);
    });

    test('a fully picked group queues nothing', () {
      final skilled = _feat('feat-skilled', 'Skilled', [
        {'group_id': 'g', 'label': 'Picks', 'pick_kind': 'skill', 'pick': 2},
      ]);
      expect(
        seedFeatChoicePendings(
          feats: [skilled],
          existingFeatChoices: const {'feat-skilled:g': 'sk_a,sk_b'},
          level: 1,
        ),
        isEmpty,
      );
    });

    test('Magic Initiate queues all three of its groups', () {
      final mi = _feat('feat-mi', 'Magic Initiate', [
        {
          'group_id': 'mi_list',
          'label': 'Spell List',
          'pick_kind': 'enum',
          'pick': 1,
          'options': [
            {'id': 'cleric', 'label': 'Cleric'},
            {'id': 'wizard', 'label': 'Wizard'},
          ],
        },
        {
          'group_id': 'mi_cantrips',
          'label': 'Cantrips',
          'pick_kind': 'spell_from_list',
          'pick': 2,
          'list_group_id': 'mi_list',
          'spell_level': 0,
        },
        {
          'group_id': 'mi_spell',
          'label': 'Level 1 Spell',
          'pick_kind': 'spell_from_list',
          'pick': 1,
          'list_group_id': 'mi_list',
          'spell_level': 1,
        },
      ]);
      final out = seedFeatChoicePendings(
        feats: [mi],
        existingFeatChoices: const {},
        level: 1,
      );
      expect(out.map((p) => p.featureName).toList(),
          ['Spell List', 'Cantrips', 'Level 1 Spell']);
      expect(out.map((p) => p.count).toList(), [1, 2, 1]);
    });

    test('an `ability` pick_kind is skipped — feat ASI has its own field', () {
      // `asi_ability_options` / `asi_amount` own that mechanic; queueing it
      // here too would be the same choice offered twice.
      final feat = _feat('feat-tb', 'Tavern Brawler', [
        {'group_id': 'asi', 'label': 'Ability', 'pick_kind': 'ability', 'pick': 1},
      ]);
      expect(
        seedFeatChoicePendings(
          feats: [feat],
          existingFeatChoices: const {},
          level: 1,
        ),
        isEmpty,
      );
    });

    test('a row with no group_id is skipped rather than crashing', () {
      final feat = _feat('feat-x', 'Broken', [
        {'label': 'Nameless', 'pick_kind': 'skill', 'pick': 2},
      ]);
      expect(
        seedFeatChoicePendings(
          feats: [feat],
          existingFeatChoices: const {},
          level: 1,
        ),
        isEmpty,
      );
    });

    test('a feat with no player_choices queues nothing', () {
      const feat = Entity(
        id: 'f',
        name: 'Tough',
        categorySlug: 'feat',
        fields: const {'hp_bonus_per_level': 2},
      );
      expect(
        seedFeatChoicePendings(
          feats: [feat],
          existingFeatChoices: const {},
          level: 1,
        ),
        isEmpty,
      );
    });

    test('choices from several feats are all queued', () {
      final a = _feat('a', 'Skilled', [
        {'group_id': 'g1', 'label': 'A', 'pick_kind': 'skill', 'pick': 1},
      ]);
      final b = _feat('b', 'Magic Initiate', [
        {'group_id': 'g2', 'label': 'B', 'pick_kind': 'enum', 'pick': 1},
      ]);
      final out = seedFeatChoicePendings(
        feats: [a, b],
        existingFeatChoices: const {},
        level: 3,
      );
      expect(out, hasLength(2));
      expect(out.every((p) => p.level == 3), isTrue);
    });
  });

  group('seedFeatFollowOns', () {
    test('bonus pick counts and ASI each queue their own kind', () {
      final feat = _feat(
        'feat-x',
        'Skill Expert',
        [
          {'group_id': 'g', 'label': 'Skill', 'pick_kind': 'skill', 'pick': 1},
        ],
        const {
          'bonus_skill_pick_count': 1,
          'bonus_expertise_pick_count': 1,
          'asi_amount': 1,
        },
      );
      final out = seedFeatFollowOns(
        feat: feat,
        level: 4,
        existingFeatChoices: const {},
      );
      expect(
        out.map((p) => p.kind).toList(),
        [
          PendingChoiceKind.skillProficiency,
          PendingChoiceKind.expertise,
          PendingChoiceKind.featAsi,
          PendingChoiceKind.featChoice,
        ],
      );
      // The ASI pending carries the feat so the dialog can read that feat's
      // `asi_ability_options` / `asi_max_score` instead of guessing.
      final asi =
          out.firstWhere((p) => p.kind == PendingChoiceKind.featAsi);
      expect(asi.sourceEntityId, 'feat-x');
    });

    test('a purely mechanical feat queues nothing', () {
      const feat = Entity(
        id: 'f',
        name: 'Tough',
        categorySlug: 'feat',
        fields: const {'hp_bonus_per_level': 2},
      );
      expect(
        seedFeatFollowOns(
          feat: feat,
          level: 1,
          existingFeatChoices: const {},
        ),
        isEmpty,
      );
    });
  });

  group('PendingChoice wire round-trip', () {
    test('toMap → fromMap preserves every field the panel renders', () {
      final p = newPendingChoice(
        kind: PendingChoiceKind.featChoice,
        level: 4,
        classId: 'cls',
        classLabel: 'Rogue',
        count: 2,
        maxSpellLevel: 3,
        sourceEntityId: 'feat-x',
        featureName: 'Expertise',
      );
      final back = PendingChoice.fromMap(p.toMap())!;
      expect(back.kind, p.kind);
      expect(back.level, 4);
      expect(back.classId, 'cls');
      expect(back.classLabel, 'Rogue');
      expect(back.count, 2);
      expect(back.maxSpellLevel, 3);
      expect(back.sourceEntityId, 'feat-x');
      expect(back.featureName, 'Expertise');
      expect(back.dismissed, isFalse);
    });

    test('an unknown wire kind decodes to null instead of a bogus choice', () {
      expect(
        PendingChoice.fromMap(const {'kind': 'choice_group', 'id': 'x', 'level': 1}),
        isNull,
      );
    });
  });
}
