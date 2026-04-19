/// How per-level hit points are determined (SRD §16).
enum HpMethod {
  /// Take the class's fixed hit-die average (rounded up), +1 on every level
  /// past 1. Deterministic.
  fixed,

  /// Roll the class's hit die at each level past 1. Level 1 is always the
  /// full hit-die max per SRD.
  rolled,
}
