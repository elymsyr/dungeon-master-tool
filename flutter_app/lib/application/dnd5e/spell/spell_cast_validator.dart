import '../../../domain/dnd5e/character/prepared_spells.dart';
import '../../../domain/dnd5e/character/spell_slots.dart';
import '../../../domain/dnd5e/spell/spell.dart';
import '../../../domain/dnd5e/spell/spell_components.dart';
import 'caster_context.dart';
import 'casting_method.dart';

/// Pre-cast checks. Returns `null` when the cast may proceed; otherwise
/// returns a single human-readable error message describing the first
/// failed condition. Pure: no slot is spent, no state mutated.
class SpellCastValidator {
  const SpellCastValidator();

  String? validate({
    required Spell spell,
    required int? slotLevelChosen,
    required SpellSlots slots,
    required PreparedSpells prepared,
    Set<String> ritualBookSpellIds = const {},
    required CasterContext context,
    CastingMethod method = CastingMethod.normal,
  }) {
    if (spell.isCantrip) {
      return _validateComponents(spell, context);
    }

    if (method == CastingMethod.ritual) {
      if (!spell.ritual) return 'Spell is not a ritual';
      final accessible = prepared.contains(spell.id) ||
          ritualBookSpellIds.contains(spell.id);
      if (!accessible) return 'Spell not available for ritual';
      return _validateComponents(spell, context);
    }

    if (slotLevelChosen == null) return 'Slot level must be chosen';
    if (slotLevelChosen < spell.level.value) return 'Slot too low';
    if (slotLevelChosen > 9) return 'Slot level invalid';

    if (!slots.hasAvailable(slotLevelChosen)) {
      return 'No slots remaining at level $slotLevelChosen';
    }

    if (!prepared.contains(spell.id)) return 'Spell not prepared';

    return _validateComponents(spell, context);
  }

  String? _validateComponents(Spell spell, CasterContext ctx) {
    final hasV = spell.components.any((c) => c is VerbalComponent);
    if (hasV && ctx.silenced) {
      return 'Cannot cast Verbal spell while silenced or unable to speak';
    }

    final hasS = spell.components.any((c) => c is SomaticComponent);
    if (hasS && !ctx.hasFreeHand) {
      return 'Cannot cast Somatic spell without a free hand';
    }

    final material = spell.components.whereType<MaterialComponent>().firstOrNull;
    if (material != null) {
      final hasSpecific = ctx.heldMaterialDescriptions.contains(material.description);
      if (material.consumed && !hasSpecific) {
        return 'Missing required material: ${material.description}';
      }
      if (!material.consumed && !(ctx.hasFocus || ctx.hasComponentPouch || hasSpecific)) {
        return 'Need a focus, pouch, or the specific material';
      }
    }

    return null;
  }
}
