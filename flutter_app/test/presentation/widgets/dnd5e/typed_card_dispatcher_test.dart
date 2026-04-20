import 'package:dungeon_master_tool/presentation/widgets/dnd5e/cards/action_card.dart';
import 'package:dungeon_master_tool/presentation/widgets/dnd5e/cards/background_card.dart';
import 'package:dungeon_master_tool/presentation/widgets/dnd5e/cards/class_card.dart';
import 'package:dungeon_master_tool/presentation/widgets/dnd5e/cards/condition_card.dart';
import 'package:dungeon_master_tool/presentation/widgets/dnd5e/cards/feat_card.dart';
import 'package:dungeon_master_tool/presentation/widgets/dnd5e/cards/homebrew_placeholder_card.dart';
import 'package:dungeon_master_tool/presentation/widgets/dnd5e/cards/item_card.dart';
import 'package:dungeon_master_tool/presentation/widgets/dnd5e/cards/monster_card.dart';
import 'package:dungeon_master_tool/presentation/widgets/dnd5e/cards/npc_card.dart';
import 'package:dungeon_master_tool/presentation/widgets/dnd5e/cards/player_card.dart';
import 'package:dungeon_master_tool/presentation/widgets/dnd5e/cards/race_card.dart';
import 'package:dungeon_master_tool/presentation/widgets/dnd5e/cards/spell_card.dart';
import 'package:dungeon_master_tool/presentation/widgets/dnd5e/typed_card_dispatcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dispatchTypedCard', () {
    test('returns SpellCard for "spell" slug', () {
      final w = dispatchTypedCard(
        categorySlug: 'spell',
        entityId: 'srd:fireball',
        categoryColor: Colors.red,
      );
      expect(w, isA<SpellCard>());
    });

    test('returns MonsterCard for "monster" slug', () {
      final w = dispatchTypedCard(
        categorySlug: 'monster',
        entityId: 'srd:goblin',
        categoryColor: Colors.red,
      );
      expect(w, isA<MonsterCard>());
    });

    test('returns ItemCard for "item" + "equipment" slugs', () {
      for (final slug in ['item', 'equipment']) {
        final w = dispatchTypedCard(
          categorySlug: slug,
          entityId: 'srd:longsword',
          categoryColor: Colors.red,
        );
        expect(w, isA<ItemCard>(), reason: 'slug=$slug');
      }
    });

    test('returns FeatCard for "feat" slug', () {
      final w = dispatchTypedCard(
        categorySlug: 'feat',
        entityId: 'srd:alert',
        categoryColor: Colors.red,
      );
      expect(w, isA<FeatCard>());
    });

    test('returns BackgroundCard for "background" slug', () {
      final w = dispatchTypedCard(
        categorySlug: 'background',
        entityId: 'srd:acolyte',
        categoryColor: Colors.red,
      );
      expect(w, isA<BackgroundCard>());
    });

    test('returns NpcCard / PlayerCard / ClassCard / RaceCard', () {
      expect(
        dispatchTypedCard(
            categorySlug: 'npc', entityId: 'srd:x', categoryColor: Colors.red),
        isA<NpcCard>(),
      );
      expect(
        dispatchTypedCard(
            categorySlug: 'player',
            entityId: 'hb:p',
            categoryColor: Colors.red),
        isA<PlayerCard>(),
      );
      expect(
        dispatchTypedCard(
            categorySlug: 'class',
            entityId: 'srd:fighter',
            categoryColor: Colors.red),
        isA<ClassCard>(),
      );
      expect(
        dispatchTypedCard(
            categorySlug: 'race',
            entityId: 'srd:elf',
            categoryColor: Colors.red),
        isA<RaceCard>(),
      );
    });

    test('returns ActionCard for action / reaction / trait / legendary-action',
        () {
      for (final slug in [
        'action',
        'reaction',
        'trait',
        'legendary-action',
      ]) {
        expect(
          dispatchTypedCard(
              categorySlug: slug,
              entityId: 'srd:x',
              categoryColor: Colors.red),
          isA<ActionCard>(),
          reason: 'slug=$slug',
        );
      }
    });

    test('returns ConditionCard for "condition" slug', () {
      expect(
        dispatchTypedCard(
            categorySlug: 'condition',
            entityId: 'srd:stunned',
            categoryColor: Colors.red),
        isA<ConditionCard>(),
      );
    });

    test('returns HomebrewPlaceholderCard for world slugs', () {
      for (final slug in ['location', 'quest', 'lore', 'plane',
          'status-effect']) {
        expect(
          dispatchTypedCard(
              categorySlug: slug,
              entityId: 'hb:x',
              categoryColor: Colors.red),
          isA<HomebrewPlaceholderCard>(),
          reason: 'slug=$slug',
        );
      }
    });

    test('returns null only for truly unknown slugs', () {
      expect(
        dispatchTypedCard(
            categorySlug: 'something-new',
            entityId: 'srd:x',
            categoryColor: Colors.red),
        isNull,
      );
    });
  });

  group('isTypedEntityId', () {
    test('true for srd: prefix', () {
      expect(isTypedEntityId('srd:fireball'), isTrue);
    });
    test('true for hb: prefix', () {
      expect(isTypedEntityId('hb:abc-123'), isTrue);
    });
    test('false for bare uuid', () {
      expect(isTypedEntityId('e3f4-uuid'), isFalse);
    });
    test('false for empty', () {
      expect(isTypedEntityId(''), isFalse);
    });
  });
}
