import '../../../domain/dnd5e/combat/combatant.dart';
import '../../../domain/dnd5e/effect/effect_descriptor.dart';

/// Resolves a condition id to its declared list of [EffectDescriptor]s.
/// Implementations typically delegate to the SRD content registry, where each
/// [Condition] carries an `effects` list authored on import.
typedef ConditionEffectsLookup = List<EffectDescriptor> Function(
    String conditionId);

/// Returns the descriptors that ship with a combatant outside of conditions —
/// class features, feats, equipped magic items, racial traits, etc.
typedef InherentEffectsLookup = List<EffectDescriptor> Function(Combatant c);

List<EffectDescriptor> _noInherent(Combatant _) => const [];

/// Pure descriptor collector. Walks a [Combatant]'s active conditions plus an
/// optional inherent-effects callback and returns the concatenated descriptor
/// list. Iteration order: inherent first, then conditions in the order their
/// ids surface from `conditionIds.toList()` — which is the insertion order of
/// the underlying unmodifiable set.
///
/// Stateless. Both callbacks are required to be pure / side-effect-free for
/// the result to be trustworthy in re-rolls.
class CombatantEffectSource {
  final ConditionEffectsLookup conditionEffects;
  final InherentEffectsLookup inherentEffects;

  const CombatantEffectSource({
    required this.conditionEffects,
    this.inherentEffects = _noInherent,
  });

  List<EffectDescriptor> collect(Combatant c) {
    final out = <EffectDescriptor>[];
    out.addAll(inherentEffects(c));
    for (final cid in c.conditionIds) {
      out.addAll(conditionEffects(cid));
    }
    return List.unmodifiable(out);
  }
}
