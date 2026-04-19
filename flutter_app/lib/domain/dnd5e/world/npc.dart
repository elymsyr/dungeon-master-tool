import '../catalog/content_reference.dart';

/// Tracked NPC (typed, not a generic Entity). When an NPC is a combatant,
/// wrap the referenced [Monster] via `MonsterCombatant`; this class is
/// for tracking NPC state outside encounters (relations, location, notes).
class Npc {
  final String id;
  final String name;
  final String? monsterId; // optional monster template reference
  final String? currentLocationId;
  final String notes;

  Npc._(this.id, this.name, this.monsterId, this.currentLocationId, this.notes);

  factory Npc({
    required String id,
    required String name,
    ContentReference? monsterId,
    String? currentLocationId,
    String notes = '',
  }) {
    if (id.isEmpty) throw ArgumentError('Npc.id must not be empty');
    if (name.isEmpty) throw ArgumentError('Npc.name must not be empty');
    if (monsterId != null) validateContentId(monsterId);
    return Npc._(id, name, monsterId, currentLocationId, notes);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Npc && other.id == id;
  @override
  int get hashCode => id.hashCode;
  @override
  String toString() => 'Npc($id, $name)';
}
