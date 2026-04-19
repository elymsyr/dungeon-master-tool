import '../../../domain/dnd5e/character/pact_magic_slots.dart';
import '../../../domain/dnd5e/character/spell_slots.dart';
import '../../../domain/dnd5e/combat/concentration.dart';

/// Result of a [SpellCastService.cast] call. Pure value — caller is
/// responsible for persisting the new slot/concentration state if [success].
class CastOutcome {
  /// `null` when the cast succeeded; otherwise the first failed precondition.
  final String? error;

  /// Slot table after the cast. Equal to the input when the cast failed,
  /// when the spell was a cantrip, when the method was ritual, or when a
  /// pact slot was spent instead.
  final SpellSlots slots;

  /// Pact-magic slots after the cast. Mirrors [slots]: equal to the input
  /// when no pact slot was spent, decremented when one was. Null when the
  /// caster has no pact magic.
  final PactMagicSlots? pactSlots;

  /// Concentration the caster is now committed to. Null when the cast did
  /// not start a concentration spell *and* there was no prior concentration.
  /// When the cast started a new concentration spell, this is that new
  /// concentration; the prior one (if any) is exposed via [droppedConcentration].
  final Concentration? concentration;

  /// Concentration that was broken because a new concentration spell was
  /// started. Null when no concentration was active before, or when the new
  /// spell is not a concentration spell.
  final Concentration? droppedConcentration;

  /// True when a regular spell slot was expended. False for cantrips, ritual
  /// casts, pact-slot casts, and failed casts.
  final bool slotConsumed;

  /// True when a pact-magic slot was expended. Mutually exclusive with
  /// [slotConsumed].
  final bool pactSlotConsumed;

  const CastOutcome._({
    this.error,
    required this.slots,
    this.pactSlots,
    this.concentration,
    this.droppedConcentration,
    required this.slotConsumed,
    required this.pactSlotConsumed,
  });

  factory CastOutcome.error(String message, SpellSlots slots,
      {PactMagicSlots? pactSlots, Concentration? currentConcentration}) {
    return CastOutcome._(
      error: message,
      slots: slots,
      pactSlots: pactSlots,
      concentration: currentConcentration,
      slotConsumed: false,
      pactSlotConsumed: false,
    );
  }

  factory CastOutcome.success({
    required SpellSlots slots,
    PactMagicSlots? pactSlots,
    Concentration? concentration,
    Concentration? droppedConcentration,
    required bool slotConsumed,
    bool pactSlotConsumed = false,
  }) {
    return CastOutcome._(
      slots: slots,
      pactSlots: pactSlots,
      concentration: concentration,
      droppedConcentration: droppedConcentration,
      slotConsumed: slotConsumed,
      pactSlotConsumed: pactSlotConsumed,
    );
  }

  bool get success => error == null;
}
