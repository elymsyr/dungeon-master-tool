import '../catalog/content_reference.dart';
import '../core/ability.dart';

/// How often an innate-spellcasting monster may cast a given spell.
/// Per SRD: at-will, X/day each, or via slots (standard spellcasting).
enum InnateFrequency {
  atWill,
  oncePerDay,
  twicePerDay,
  thricePerDay,
}

/// One entry in a monster's innate-spellcasting block. Innate casters get
/// free uses of a spell at a fixed frequency — no slots consumed.
class InnateSpellUse {
  final ContentReference spellId;
  final InnateFrequency frequency;

  InnateSpellUse({required this.spellId, required this.frequency}) {
    validateContentId(spellId);
  }

  @override
  bool operator ==(Object other) =>
      other is InnateSpellUse &&
      other.spellId == spellId &&
      other.frequency == frequency;

  @override
  int get hashCode => Object.hash(spellId, frequency);
}

/// Structured spellcasting block for a monster. Covers both standard
/// spellcasting (prepared list + slot table) and innate spellcasting
/// (fixed-frequency uses). A monster can have one or the other, rarely both.
///
/// [preparedSpellIds] is a flat list; slot-table lookups happen on the
/// runtime side via [spellSlots] keyed by spell level.
class MonsterSpellcasting {
  final Ability spellcastingAbility;
  final int spellSaveDc;
  final int spellAttackBonus;
  final List<ContentReference> preparedSpellIds;
  final Map<int, int> spellSlots;
  final List<InnateSpellUse> innateSpells;

  MonsterSpellcasting._(
    this.spellcastingAbility,
    this.spellSaveDc,
    this.spellAttackBonus,
    this.preparedSpellIds,
    this.spellSlots,
    this.innateSpells,
  );

  factory MonsterSpellcasting({
    required Ability spellcastingAbility,
    required int spellSaveDc,
    required int spellAttackBonus,
    List<ContentReference> preparedSpellIds = const [],
    Map<int, int> spellSlots = const {},
    List<InnateSpellUse> innateSpells = const [],
  }) {
    if (spellSaveDc < 0) {
      throw ArgumentError('MonsterSpellcasting.spellSaveDc must be >= 0');
    }
    for (final id in preparedSpellIds) {
      validateContentId(id);
    }
    for (final entry in spellSlots.entries) {
      if (entry.key < 0 || entry.key > 9) {
        throw ArgumentError(
            'MonsterSpellcasting.spellSlots: level ${entry.key} must be in [0, 9]');
      }
      if (entry.value < 0) {
        throw ArgumentError(
            'MonsterSpellcasting.spellSlots[${entry.key}] must be >= 0');
      }
    }
    return MonsterSpellcasting._(
      spellcastingAbility,
      spellSaveDc,
      spellAttackBonus,
      List.unmodifiable(preparedSpellIds),
      Map.unmodifiable(spellSlots),
      List.unmodifiable(innateSpells),
    );
  }
}
