import '../../../domain/dnd5e/character/spell_slots.dart';
import '../../../domain/dnd5e/combat/concentration.dart';

/// Result of a [SpellCastService.cast] call. Pure value — caller is
/// responsible for persisting the new slot/concentration state if [success].
class CastOutcome {
  /// `null` when the cast succeeded; otherwise the first failed precondition.
  final String? error;

  /// Slot table after the cast. Equal to the input when the cast failed,
  /// when the spell was a cantrip, or when the method was ritual.
  final SpellSlots slots;

  /// Concentration the caster is now committed to. Null when the cast did
  /// not start a concentration spell *and* there was no prior concentration.
  /// When the cast started a new concentration spell, this is that new
  /// concentration; the prior one (if any) is exposed via [droppedConcentration].
  final Concentration? concentration;

  /// Concentration that was broken because a new concentration spell was
  /// started. Null when no concentration was active before, or when the new
  /// spell is not a concentration spell.
  final Concentration? droppedConcentration;

  /// True when a slot was actually expended. False for cantrips, ritual
  /// casts, and failed casts.
  final bool slotConsumed;

  const CastOutcome._({
    this.error,
    required this.slots,
    this.concentration,
    this.droppedConcentration,
    required this.slotConsumed,
  });

  factory CastOutcome.error(String message, SpellSlots slots,
      {Concentration? currentConcentration}) {
    return CastOutcome._(
      error: message,
      slots: slots,
      concentration: currentConcentration,
      slotConsumed: false,
    );
  }

  factory CastOutcome.success({
    required SpellSlots slots,
    Concentration? concentration,
    Concentration? droppedConcentration,
    required bool slotConsumed,
  }) {
    return CastOutcome._(
      slots: slots,
      concentration: concentration,
      droppedConcentration: droppedConcentration,
      slotConsumed: slotConsumed,
    );
  }

  bool get success => error == null;
}
