import 'package:dungeon_master_tool/application/dnd5e/character_build/item_equip_service.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/character_class_level.dart';
import 'package:dungeon_master_tool/domain/dnd5e/character/prepared_spells.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/ability_scores.dart';
import 'package:dungeon_master_tool/domain/dnd5e/core/hit_points.dart';
import 'package:dungeon_master_tool/domain/dnd5e/item/item.dart';
import 'package:flutter_test/flutter_test.dart';

Character _seed() => Character(
      id: 'char-1',
      name: 'Test',
      classLevels: [CharacterClassLevel(classId: 'srd:wizard', level: 5)],
      speciesId: 'srd:human',
      backgroundId: 'srd:sage',
      alignmentId: 'srd:neutral',
      abilities: AbilityScores.allTens(),
      hp: HitPoints(current: 24, max: 24),
    );

void main() {
  group('ItemEquipService', () {
    const svc = ItemEquipService();

    test('equipping a non-magic Gear only updates inventory', () {
      final gear = Gear(
        id: 'srd:torch',
        name: 'Torch',
        rarityId: 'srd:common',
      );
      final c = svc.equip(_seed(), gear);
      expect(c.inventory.entries.map((e) => e.itemId), contains('srd:torch'));
      expect(c.preparedSpells.entries, isEmpty);
    });

    test('equipping a MagicItem adds granted spells to preparedSpells', () {
      final wand = MagicItem(
        id: 'srd:wand-of-fireballs',
        name: 'Wand of Fireballs',
        rarityId: 'srd:rare',
        grantsSpellIds: ['srd:fireball'],
      );
      final c = svc.equip(_seed(), wand);
      expect(c.inventory.entries.map((e) => e.itemId),
          contains('srd:wand-of-fireballs'));
      expect(c.preparedSpells.contains('srd:fireball'), true);
    });

    test('unequipping a MagicItem removes granted spells + inventory entry',
        () {
      final wand = MagicItem(
        id: 'srd:wand-of-fireballs',
        name: 'Wand of Fireballs',
        rarityId: 'srd:rare',
        grantsSpellIds: ['srd:fireball'],
      );
      final after = svc.unequip(svc.equip(_seed(), wand), wand);
      expect(after.inventory.entries.map((e) => e.itemId),
          isNot(contains('srd:wand-of-fireballs')));
      expect(after.preparedSpells.contains('srd:fireball'), false);
    });

    test('unequipping does not remove spells granted by other sources', () {
      final wand = MagicItem(
        id: 'srd:wand-of-fireballs',
        name: 'Wand of Fireballs',
        rarityId: 'srd:rare',
        grantsSpellIds: ['srd:fireball'],
      );
      // Seed has Fireball from class, tagged with "srd:wizard".
      final wizardPrep = _seed().preparedSpells.add(
            // ignore: avoid_redundant_argument_values
            PreparedSpellEntry(spellId: 'srd:fireball', classId: 'srd:wizard'),
          );
      final seedWithWizardFireball =
          _seed().copyWith(preparedSpells: wizardPrep);
      final equipped = svc.equip(seedWithWizardFireball, wand);
      final after = svc.unequip(equipped, wand);
      // Fireball from wizard class should persist; only item-tagged copy
      // removed.
      expect(after.preparedSpells.contains('srd:fireball'), true);
    });

    test('equipping item with multiple granted spells adds all', () {
      final ring = MagicItem(
        id: 'srd:ring-of-spell-storing',
        name: 'Ring of Spell Storing',
        rarityId: 'srd:rare',
        grantsSpellIds: ['srd:magic-missile', 'srd:shield'],
      );
      final c = svc.equip(_seed(), ring);
      expect(c.preparedSpells.contains('srd:magic-missile'), true);
      expect(c.preparedSpells.contains('srd:shield'), true);
    });
  });
}
