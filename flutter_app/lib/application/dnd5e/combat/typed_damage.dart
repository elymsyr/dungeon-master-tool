import '../../../domain/dnd5e/catalog/content_reference.dart';

/// One attack's worth of per-type damage. A weapon hit with a Flametongue
/// rider bundles `{srd:slashing: 7, srd:fire: 4}`; Fireball bundles
/// `{srd:fire: 28}`. The multi-type resolver applies resist/vuln/imm per
/// type before summing, then the save-half + temp-HP steps operate on the
/// total.
///
/// `fromSavedThrow` + `savedSucceeded` follow the same pattern as the
/// single-type `DamageInstance`. `sourceSpellId` lets the caller tie the
/// resulting concentration-break notification back to a spell instance.
class TypedDamage {
  final Map<String, int> byType;
  final bool isCritical;
  final bool fromSavedThrow;
  final bool savedSucceeded;
  final String? sourceSpellId;

  TypedDamage._(
    this.byType,
    this.isCritical,
    this.fromSavedThrow,
    this.savedSucceeded,
    this.sourceSpellId,
  );

  factory TypedDamage({
    required Map<String, int> byType,
    bool isCritical = false,
    bool fromSavedThrow = false,
    bool savedSucceeded = false,
    String? sourceSpellId,
  }) {
    if (byType.isEmpty) {
      throw ArgumentError('TypedDamage.byType must not be empty');
    }
    for (final e in byType.entries) {
      validateContentId(e.key);
      if (e.value < 0) {
        throw ArgumentError(
            'TypedDamage.byType["${e.key}"] must be >= 0, got ${e.value}');
      }
    }
    if (!fromSavedThrow && savedSucceeded) {
      throw ArgumentError(
          'TypedDamage.savedSucceeded requires fromSavedThrow=true');
    }
    return TypedDamage._(
      Map.unmodifiable(byType),
      isCritical,
      fromSavedThrow,
      savedSucceeded,
      sourceSpellId,
    );
  }

  int get totalPreMitigation =>
      byType.values.fold<int>(0, (a, b) => a + b);
}
