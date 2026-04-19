/// Tier 0 flag vocabulary keyed by [WeaponProperty.flags]. The engine dispatches
/// on these flags (not on the property id), so SRD "srd:finesse" and a homebrew
/// "arcane:graceful" property behave identically if both carry
/// [PropertyFlag.finesse].
enum PropertyFlag {
  finesse,
  heavy,
  light,
  loading,
  range,
  reach,
  thrown,
  twoHanded,
  versatile,
  ammunition,
  appliesToSneakAttack,
  silvered,
  magical,
}
