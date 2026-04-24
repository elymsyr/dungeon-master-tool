import '../catalog/content_reference.dart';
import '../effect/effect_descriptor.dart';
import 'legendary_action.dart';
import 'monster_action.dart';
import 'monster_spellcasting.dart';
import 'stat_block.dart';

/// Tier 1: immutable monster/NPC definition. Instances in combat wrap this in
/// [MonsterCombatant] (see combat/combatant.dart) with per-instance HP.
///
/// [spellcasting] populates when the monster has a spellcasting trait —
/// standard (prepared list + slots) or innate (fixed-frequency uses).
/// Non-casting monsters leave it null.
class Monster {
  final String id;
  final String name;
  final StatBlock stats;
  final List<EffectDescriptor> traits;
  final List<MonsterAction> actions;
  final List<MonsterAction> bonusActions;
  final List<MonsterAction> reactions;
  final List<LegendaryAction> legendaryActions;
  final int legendaryActionSlots;
  final MonsterSpellcasting? spellcasting;
  final String description;

  Monster._({
    required this.id,
    required this.name,
    required this.stats,
    required this.traits,
    required this.actions,
    required this.bonusActions,
    required this.reactions,
    required this.legendaryActions,
    required this.legendaryActionSlots,
    required this.spellcasting,
    required this.description,
  });

  factory Monster({
    required String id,
    required String name,
    required StatBlock stats,
    List<EffectDescriptor> traits = const [],
    List<MonsterAction> actions = const [],
    List<MonsterAction> bonusActions = const [],
    List<MonsterAction> reactions = const [],
    List<LegendaryAction> legendaryActions = const [],
    int legendaryActionSlots = 0,
    MonsterSpellcasting? spellcasting,
    String description = '',
  }) {
    validateContentId(id);
    if (name.isEmpty) throw ArgumentError('Monster.name must not be empty');
    if (legendaryActionSlots < 0) {
      throw ArgumentError('Monster.legendaryActionSlots must be >= 0');
    }
    if (legendaryActions.isNotEmpty && legendaryActionSlots == 0) {
      throw ArgumentError(
          'Monster has legendaryActions but legendaryActionSlots is 0');
    }
    return Monster._(
      id: id,
      name: name,
      stats: stats,
      traits: List.unmodifiable(traits),
      actions: List.unmodifiable(actions),
      bonusActions: List.unmodifiable(bonusActions),
      reactions: List.unmodifiable(reactions),
      legendaryActions: List.unmodifiable(legendaryActions),
      legendaryActionSlots: legendaryActionSlots,
      spellcasting: spellcasting,
      description: description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Monster && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Monster($id, CR ${stats.cr.canonical})';
}
