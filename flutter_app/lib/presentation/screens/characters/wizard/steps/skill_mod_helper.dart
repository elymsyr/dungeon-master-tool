import '../../../../../application/character_creation/character_draft.dart';
import '../../../../../domain/entities/entity.dart';
import '../../../../../domain/entities/schema/dnd5e_constants.dart';

/// Resolves a skill entity's linked ability and returns the draft's current
/// modifier for that ability. Returns null when [entity] isn't a skill, the
/// ability_ref doesn't resolve, or the ability entity is missing its
/// abbreviation. Proficiency bonus is intentionally excluded — the chip is
/// shown next to a not-yet-picked skill, so we only surface the ability mod.
int? skillAbilityModFor(
  Entity entity,
  Map<String, Entity> entities,
  CharacterDraft draft,
) {
  if (entity.categorySlug != 'skill') return null;
  final abilityRef = entity.fields['ability_ref'];
  if (abilityRef is! String || abilityRef.isEmpty) return null;
  final ability = entities[abilityRef];
  if (ability == null) return null;
  final abbr = ability.fields['abbreviation'];
  if (abbr is! String) return null;
  final base = draft.baseAbilities[abbr] ?? 10;
  final racial = draft.racialBonuses[abbr] ?? 0;
  return abilityModifier(base + racial);
}

/// Pretty `+2` / `-1` / `+0` form for the chip suffix.
String formatModifier(int mod) => mod >= 0 ? '+$mod' : '$mod';
