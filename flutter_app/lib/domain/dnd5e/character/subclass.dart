import '../catalog/content_reference.dart';
import 'character_class.dart';

/// Tier 1: a subclass (archetype). Parented to one CharacterClass via
/// [parentClassId]. Subclass features slot into [featureTable] at the class's
/// subclass-feature levels (engine merges parent + subclass rows).
///
/// [bonusSpellIds] are always-prepared spells granted by the subclass at the
/// listed character level — Cleric domain spells, Paladin oath spells,
/// Warlock pact spells. Keyed by the level at which they become prepared.
class Subclass {
  final String id;
  final String name;
  final String parentClassId;
  final List<ClassFeatureRow> featureTable;
  final Map<int, List<ContentReference>> bonusSpellIds;
  final String description;

  Subclass._(this.id, this.name, this.parentClassId, this.featureTable,
      this.bonusSpellIds, this.description);

  factory Subclass({
    required String id,
    required String name,
    required String parentClassId,
    List<ClassFeatureRow> featureTable = const [],
    Map<int, List<ContentReference>> bonusSpellIds = const {},
    String description = '',
  }) {
    validateContentId(id);
    validateContentId(parentClassId);
    if (name.isEmpty) throw ArgumentError('Subclass.name must not be empty');
    for (final entry in bonusSpellIds.entries) {
      if (entry.key < 1 || entry.key > 20) {
        throw ArgumentError(
            'Subclass.bonusSpellIds: level ${entry.key} must be in [1, 20]');
      }
      for (final spellId in entry.value) {
        validateContentId(spellId);
      }
    }
    return Subclass._(
      id,
      name,
      parentClassId,
      List.unmodifiable(featureTable),
      Map.unmodifiable({
        for (final e in bonusSpellIds.entries)
          e.key: List<ContentReference>.unmodifiable(e.value),
      }),
      description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Subclass && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Subclass($id)';
}
