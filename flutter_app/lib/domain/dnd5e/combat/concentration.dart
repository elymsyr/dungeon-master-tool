import '../catalog/content_reference.dart';
import '../core/spell_level.dart';

/// Tier 0 stateful machine. Non-null = actively concentrating. Snapshot-based
/// so transitions are pure (`withSpell` / `cleared`).
class Concentration {
  final String spellId;
  final SpellLevel castAtLevel;

  Concentration._(this.spellId, this.castAtLevel);

  factory Concentration({
    required ContentReference spellId,
    required SpellLevel castAtLevel,
  }) {
    validateContentId(spellId);
    return Concentration._(spellId, castAtLevel);
  }

  @override
  bool operator ==(Object other) =>
      other is Concentration &&
      other.spellId == spellId &&
      other.castAtLevel == castAtLevel;
  @override
  int get hashCode => Object.hash(spellId, castAtLevel);
  @override
  String toString() => 'Concentration($spellId @ $castAtLevel)';
}
