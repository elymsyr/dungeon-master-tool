/// Transient caster state the spell-cast validator inspects to evaluate
/// component requirements. Decoupled from `Combatant`/`Inventory` so it can
/// be assembled by either combat services or pre-combat preview UI.
class CasterContext {
  /// True when the caster is silenced or otherwise unable to speak — blocks
  /// Verbal components.
  final bool silenced;

  /// True when the caster has at least one hand free for somatic gestures.
  /// Casters wielding a focus that doubles as a weapon (e.g. component-pouch
  /// in off-hand) should pass `true`.
  final bool hasFreeHand;

  /// Caster wields a spellcasting focus appropriate for their class.
  final bool hasFocus;

  /// Caster carries a component pouch.
  final bool hasComponentPouch;

  /// Description strings of specific material components currently in the
  /// caster's possession. Matched verbatim against `MaterialComponent.description`.
  /// Used both for consumed components (must be present) and for non-pouch
  /// non-focus fallbacks.
  final Set<String> heldMaterialDescriptions;

  const CasterContext({
    this.silenced = false,
    this.hasFreeHand = true,
    this.hasFocus = false,
    this.hasComponentPouch = false,
    this.heldMaterialDescriptions = const {},
  });
}
