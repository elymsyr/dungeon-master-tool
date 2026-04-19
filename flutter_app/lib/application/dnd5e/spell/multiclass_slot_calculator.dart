import '../../../domain/dnd5e/character/caster_kind.dart';
import '../../../domain/dnd5e/character/character_class.dart';
import '../../../domain/dnd5e/character/character_class_level.dart';
import 'spell_slot_progression.dart';

/// Combines a character's class levels into a single "caster level", then
/// reads [SpellSlotProgression] for the slot array. Pure function — takes a
/// class resolver so tests and production code share the same math.
///
/// Resolver shape matches what a `ContentRegistry` will expose later (Doc 15);
/// for now the calculator accepts any `String → CharacterClass?` mapping.
class MulticlassSlotCalculator {
  final CharacterClass? Function(String classId) resolve;

  const MulticlassSlotCalculator(this.resolve);

  /// Sum `level * casterFraction` over spellcasting classes; floors the total.
  /// Pact classes are excluded — Warlock uses its own table.
  int combinedCasterLevel(List<CharacterClassLevel> levels) {
    double sum = 0;
    for (final lvl in levels) {
      final cls = resolve(lvl.classId);
      if (cls == null) continue;
      if (cls.casterKind == CasterKind.none) continue;
      if (cls.casterKind == CasterKind.pact) continue;
      sum += lvl.level * cls.casterFraction;
    }
    return sum.floor();
  }

  /// Returns 9-element slot array (1..9). Empty list of levels → all zeros.
  List<int> slotsFor(List<CharacterClassLevel> levels) =>
      SpellSlotProgression.slotsForCasterLevel(combinedCasterLevel(levels));
}
