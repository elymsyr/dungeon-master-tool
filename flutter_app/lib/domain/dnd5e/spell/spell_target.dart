/// Who/what a spell can target. Targets combine with [AreaOfEffect] at cast
/// time; this enum describes the *selection* UI, not the geometry.
enum SpellTarget {
  self,
  oneCreature,
  oneObject,
  oneCreatureOrObject,
  multipleCreatures,
  point,
  aoeOriginPoint,
}
