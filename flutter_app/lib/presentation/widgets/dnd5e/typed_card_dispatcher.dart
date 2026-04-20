import 'package:flutter/material.dart';

import 'cards/action_card.dart';
import 'cards/background_card.dart';
import 'cards/class_card.dart';
import 'cards/condition_card.dart';
import 'cards/feat_card.dart';
import 'cards/homebrew_placeholder_card.dart';
import 'cards/item_card.dart';
import 'cards/monster_card.dart';
import 'cards/npc_card.dart';
import 'cards/player_card.dart';
import 'cards/race_card.dart';
import 'cards/spell_card.dart';

/// Maps a category slug to its typed card widget. Returns `null` only for
/// truly unknown slugs — Batches 1-3 cover every SRD category the sidebar
/// can surface. See `docs/engineering/50-typed-ui-migration.md`.
Widget? dispatchTypedCard({
  required String categorySlug,
  required String entityId,
  required Color categoryColor,
}) {
  switch (categorySlug) {
    case 'spell':
      return SpellCard(
        entityId: entityId,
        categoryColor: categoryColor,
        key: ValueKey('spell:$entityId'),
      );
    case 'monster':
      return MonsterCard(
        entityId: entityId,
        categoryColor: categoryColor,
        key: ValueKey('monster:$entityId'),
      );
    case 'equipment':
    case 'item':
      return ItemCard(
        entityId: entityId,
        categoryColor: categoryColor,
        key: ValueKey('item:$entityId'),
      );
    case 'feat':
      return FeatCard(
        entityId: entityId,
        categoryColor: categoryColor,
        key: ValueKey('feat:$entityId'),
      );
    case 'background':
      return BackgroundCard(
        entityId: entityId,
        categoryColor: categoryColor,
        key: ValueKey('background:$entityId'),
      );
    case 'npc':
      return NpcCard(
        entityId: entityId,
        categoryColor: categoryColor,
        key: ValueKey('npc:$entityId'),
      );
    case 'player':
      return PlayerCard(
        entityId: entityId,
        categoryColor: categoryColor,
        key: ValueKey('player:$entityId'),
      );
    case 'class':
      return ClassCard(
        entityId: entityId,
        categoryColor: categoryColor,
        key: ValueKey('class:$entityId'),
      );
    case 'race':
      return RaceCard(
        entityId: entityId,
        categoryColor: categoryColor,
        key: ValueKey('race:$entityId'),
      );
    case 'trait':
    case 'action':
    case 'reaction':
    case 'legendary-action':
      return ActionCard(
        entityId: entityId,
        categoryColor: categoryColor,
        categorySlug: categorySlug,
        key: ValueKey('$categorySlug:$entityId'),
      );
    case 'condition':
      return ConditionCard(
        entityId: entityId,
        categoryColor: categoryColor,
        key: ValueKey('condition:$entityId'),
      );
    case 'location':
    case 'quest':
    case 'lore':
    case 'plane':
    case 'status-effect':
      return HomebrewPlaceholderCard(
        entityId: entityId,
        categoryColor: categoryColor,
        categorySlug: categorySlug,
        key: ValueKey('$categorySlug:$entityId'),
      );
    default:
      return null;
  }
}

/// True when `entityId` starts with a typed-content id prefix (`srd:` or
/// `hb:`). Used to route DatabaseScreen lookups to typed providers first
/// before falling back to the legacy blob.
bool isTypedEntityId(String entityId) =>
    entityId.startsWith('srd:') || entityId.startsWith('hb:');
