/// How a spell is being cast. Drives validator branching.
enum CastingMethod {
  /// Standard slot-consuming cast. Requires the spell to be prepared and a
  /// slot of sufficient level to be available.
  normal,

  /// Ritual cast (10-minute extension; no slot expended). Requires
  /// `Spell.ritual == true` and the spell either prepared or in a ritual book.
  ritual,
}
