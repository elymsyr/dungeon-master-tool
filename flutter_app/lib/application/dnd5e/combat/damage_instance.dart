import '../../../domain/dnd5e/catalog/content_reference.dart';

/// One hit's worth of incoming damage. `amount` is the already-rolled total;
/// the resolver applies the target's resistance/vuln/immunity/temp-HP after.
///
/// `fromSavedThrow` + `savedSucceeded` cooperate to halve post-resistance
/// damage on a successful save-for-half effect — the resolver does the halving
/// so callers don't pre-halve incorrectly when the target also resists.
class DamageInstance {
  final int amount;
  final String typeId;
  final bool isCritical;
  final bool fromSavedThrow;
  final bool savedSucceeded;
  final String? sourceSpellId;

  DamageInstance._(
    this.amount,
    this.typeId,
    this.isCritical,
    this.fromSavedThrow,
    this.savedSucceeded,
    this.sourceSpellId,
  );

  factory DamageInstance({
    required int amount,
    required String typeId,
    bool isCritical = false,
    bool fromSavedThrow = false,
    bool savedSucceeded = false,
    String? sourceSpellId,
  }) {
    if (amount < 0) {
      throw ArgumentError('DamageInstance.amount must be >= 0, got $amount');
    }
    validateContentId(typeId);
    if (!fromSavedThrow && savedSucceeded) {
      throw ArgumentError(
          'DamageInstance.savedSucceeded requires fromSavedThrow=true');
    }
    return DamageInstance._(amount, typeId, isCritical, fromSavedThrow,
        savedSucceeded, sourceSpellId);
  }
}
