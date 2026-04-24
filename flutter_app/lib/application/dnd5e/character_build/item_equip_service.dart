import '../../../domain/dnd5e/character/character.dart';
import '../../../domain/dnd5e/character/inventory.dart';
import '../../../domain/dnd5e/character/prepared_spells.dart';
import '../../../domain/dnd5e/item/item.dart';

/// Equips and unequips items on a character. The primary mechanic exposed
/// here: a [MagicItem] carrying [MagicItem.grantsSpellIds] adds those spells
/// to the character's [PreparedSpells] pool tagged with the item id as
/// source, so unequip can revoke them without touching unrelated spells.
///
/// AC bonus + ability-score bonuses are NOT folded into character state by
/// this service; they're read live by combat/sheet code from the currently
/// equipped magic items (same as armor AC is read live from Inventory).
/// This keeps the character's ability scores stable under equip/unequip
/// toggles — otherwise a +2 STR gauntlet would mutate `character.abilities`
/// every time the player swapped gloves mid-combat.
class ItemEquipService {
  const ItemEquipService();

  /// Equips [item] on [character]. If the item is a [MagicItem], grants its
  /// always-on spells to the character's prepared list tagged with the
  /// item's id as source. Returns a new Character with updated inventory +
  /// preparedSpells.
  Character equip(Character character, Item item,
      {EquipSlot slot = EquipSlot.carried, bool attune = false}) {
    final entry = InventoryEntry(
      itemId: item.id,
      equipSlot: slot,
      attuned: attune,
    );
    final newEntries = [
      for (final e in character.inventory.entries)
        if (e.itemId != item.id) e,
      entry,
    ];
    var inventory = character.inventory.copyWith(entries: newEntries);

    var prepared = character.preparedSpells;
    if (item is MagicItem && item.grantsSpellIds.isNotEmpty) {
      for (final spellId in item.grantsSpellIds) {
        prepared = prepared.add(
          PreparedSpellEntry(spellId: spellId, classId: _itemSourceTag(item.id)),
        );
      }
    }

    return character.copyWith(
      inventory: inventory,
      preparedSpells: prepared,
    );
  }

  /// Unequips [item] from [character]. Removes the inventory entry and
  /// revokes any spells granted by a [MagicItem] via [equip].
  Character unequip(Character character, Item item) {
    final newEntries = [
      for (final e in character.inventory.entries)
        if (e.itemId != item.id) e,
    ];
    var inventory = character.inventory.copyWith(entries: newEntries);

    var prepared = character.preparedSpells;
    if (item is MagicItem && item.grantsSpellIds.isNotEmpty) {
      final sourceTag = _itemSourceTag(item.id);
      for (final spellId in item.grantsSpellIds) {
        prepared = prepared.remove(spellId, classId: sourceTag);
      }
    }

    return character.copyWith(
      inventory: inventory,
      preparedSpells: prepared,
    );
  }

  /// Tags item-granted spells in [PreparedSpells.classId] so unequip can
  /// revoke them selectively. The tag collides with a real class id only if
  /// an author names a class `item:<something>` — our content-id validator
  /// forbids namespaced classes with the `item:` package prefix, so safe.
  String _itemSourceTag(String itemId) => 'item:$itemId';
}
