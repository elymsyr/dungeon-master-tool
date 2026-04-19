import '../../../domain/dnd5e/character/prepared_spells.dart';
import '../../../domain/dnd5e/character/spell_slots.dart';
import '../../../domain/dnd5e/combat/concentration.dart';
import '../../../domain/dnd5e/core/spell_level.dart';
import '../../../domain/dnd5e/spell/spell.dart';
import '../../../domain/dnd5e/spell/spell_duration.dart';
import 'cast_outcome.dart';
import 'caster_context.dart';
import 'casting_method.dart';
import 'spell_cast_validator.dart';

/// Composes [SpellCastValidator] with the deterministic state transitions
/// that a successful cast triggers: spending a slot and starting/replacing
/// concentration. No effect dispatch and no dice — that lives in the combat
/// services that consume this outcome.
class SpellCastService {
  final SpellCastValidator validator;

  const SpellCastService({this.validator = const SpellCastValidator()});

  CastOutcome cast({
    required Spell spell,
    required int? slotLevelChosen,
    required SpellSlots slots,
    required PreparedSpells prepared,
    Set<String> ritualBookSpellIds = const {},
    required CasterContext context,
    Concentration? currentConcentration,
    CastingMethod method = CastingMethod.normal,
  }) {
    final err = validator.validate(
      spell: spell,
      slotLevelChosen: slotLevelChosen,
      slots: slots,
      prepared: prepared,
      ritualBookSpellIds: ritualBookSpellIds,
      context: context,
      method: method,
    );
    if (err != null) {
      return CastOutcome.error(err, slots,
          currentConcentration: currentConcentration);
    }

    var newSlots = slots;
    var slotConsumed = false;
    if (!spell.isCantrip && method == CastingMethod.normal) {
      newSlots = slots.spend(slotLevelChosen!);
      slotConsumed = true;
    }

    final concentrates = _isConcentrationSpell(spell);
    Concentration? newConc = currentConcentration;
    Concentration? dropped;
    if (concentrates) {
      dropped = currentConcentration;
      final castLevel = method == CastingMethod.normal && !spell.isCantrip
          ? slotLevelChosen!
          : spell.level.value;
      newConc = Concentration(
        spellId: spell.id,
        castAtLevel: SpellLevel(castLevel),
      );
    }

    return CastOutcome.success(
      slots: newSlots,
      concentration: newConc,
      droppedConcentration: dropped,
      slotConsumed: slotConsumed,
    );
  }

  bool _isConcentrationSpell(Spell spell) {
    final d = spell.duration;
    return switch (d) {
      SpellRounds(:final concentration) => concentration,
      SpellMinutes(:final concentration) => concentration,
      SpellHours(:final concentration) => concentration,
      _ => false,
    };
  }
}
