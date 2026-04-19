/// How a [CharacterClass] contributes to the multiclass spell-slot calculator.
///
/// - [none] — non-caster (fighter, barbarian, …).
/// - [full] — contributes levels at fraction 1.0 (wizard, cleric, druid, …).
/// - [half] — contributes at 0.5 (paladin, ranger).
/// - [third] — contributes at 1/3 (eldritch knight, arcane trickster subclasses).
/// - [pact] — excluded from the multiclass sum; uses its own [PactMagicTable].
enum CasterKind { none, full, half, third, pact }
