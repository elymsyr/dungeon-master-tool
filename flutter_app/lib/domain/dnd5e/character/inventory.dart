import '../catalog/content_reference.dart';

/// Where an inventory entry is placed relative to the character.
enum EquipSlot {
  none,
  mainHand,
  offHand,
  twoHanded,
  armor,
  shield,
  worn,
  carried,
  stashed,
}

/// One line in a character's inventory. [itemId] resolves against the Item
/// registry. [equipSlot] = [EquipSlot.none] means stashed in pack.
class InventoryEntry {
  final String itemId;
  final int quantity;
  final EquipSlot equipSlot;
  final bool attuned;

  const InventoryEntry._(
      this.itemId, this.quantity, this.equipSlot, this.attuned);

  factory InventoryEntry({
    required String itemId,
    int quantity = 1,
    EquipSlot equipSlot = EquipSlot.none,
    bool attuned = false,
  }) {
    validateContentId(itemId);
    if (quantity <= 0) {
      throw ArgumentError('InventoryEntry.quantity must be > 0');
    }
    return InventoryEntry._(itemId, quantity, equipSlot, attuned);
  }

  InventoryEntry copyWith({
    String? itemId,
    int? quantity,
    EquipSlot? equipSlot,
    bool? attuned,
  }) =>
      InventoryEntry(
        itemId: itemId ?? this.itemId,
        quantity: quantity ?? this.quantity,
        equipSlot: equipSlot ?? this.equipSlot,
        attuned: attuned ?? this.attuned,
      );

  @override
  bool operator ==(Object other) =>
      other is InventoryEntry &&
      other.itemId == itemId &&
      other.quantity == quantity &&
      other.equipSlot == equipSlot &&
      other.attuned == attuned;

  @override
  int get hashCode => Object.hash(itemId, quantity, equipSlot, attuned);

  @override
  String toString() =>
      'InventoryEntry($itemId ×$quantity @$equipSlot${attuned ? ' attuned' : ''})';
}

class Inventory {
  final List<InventoryEntry> entries;
  final int copper;

  Inventory._(this.entries, this.copper);

  factory Inventory({
    List<InventoryEntry> entries = const [],
    int copper = 0,
  }) {
    if (copper < 0) throw ArgumentError('Inventory.copper must be >= 0');
    final max3 =
        entries.where((e) => e.attuned).length;
    if (max3 > 3) {
      throw ArgumentError(
          'Inventory exceeds SRD attunement cap of 3 items (found $max3)');
    }
    return Inventory._(List.unmodifiable(entries), copper);
  }

  factory Inventory.empty() => Inventory();

  int get attunedCount => entries.where((e) => e.attuned).length;

  Inventory copyWith({List<InventoryEntry>? entries, int? copper}) =>
      Inventory(
        entries: entries ?? this.entries,
        copper: copper ?? this.copper,
      );
}
