/// Sealed root for the Tier 2 effect DSL. Populated by 01-domain-model-spec §Effects.
///
/// Intentionally empty here: concrete subclasses (ModifyAttackRoll, GrantCondition,
/// ConditionInteraction, etc.) land with Tier 2 work. Tier 1 catalog classes
/// (Condition, Feat, Background, ...) reference the sealed base so their schemas
/// compile before Tier 2 subclasses exist.
sealed class EffectDescriptor {
  const EffectDescriptor();
}
