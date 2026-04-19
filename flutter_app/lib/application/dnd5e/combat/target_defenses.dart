import '../../../domain/dnd5e/catalog/content_reference.dart';

/// Minimal read-only view a [DamageResolver] needs to compute an outcome.
/// Extracted from `Combatant` so the resolver stays a pure function free of
/// Combatant-case plumbing. `isPlayer` switches the Massive Damage rule on
/// (PCs only per SRD).
class TargetDefenses {
  final int currentHp;
  final int maxHp;
  final int tempHp;
  final Set<String> resistances;
  final Set<String> vulnerabilities;
  final Set<String> damageImmunities;
  final bool isPlayer;

  TargetDefenses._(
    this.currentHp,
    this.maxHp,
    this.tempHp,
    this.resistances,
    this.vulnerabilities,
    this.damageImmunities,
    this.isPlayer,
  );

  factory TargetDefenses({
    required int currentHp,
    required int maxHp,
    int tempHp = 0,
    Set<String> resistances = const {},
    Set<String> vulnerabilities = const {},
    Set<String> damageImmunities = const {},
    bool isPlayer = false,
  }) {
    if (maxHp < 1) {
      throw ArgumentError('TargetDefenses.maxHp must be >= 1, got $maxHp');
    }
    if (currentHp < 0 || currentHp > maxHp) {
      throw ArgumentError(
          'TargetDefenses.currentHp must be in [0, $maxHp], got $currentHp');
    }
    if (tempHp < 0) {
      throw ArgumentError(
          'TargetDefenses.tempHp must be >= 0, got $tempHp');
    }
    for (final id in resistances) {
      validateContentId(id);
    }
    for (final id in vulnerabilities) {
      validateContentId(id);
    }
    for (final id in damageImmunities) {
      validateContentId(id);
    }
    return TargetDefenses._(
      currentHp,
      maxHp,
      tempHp,
      Set.unmodifiable(resistances),
      Set.unmodifiable(vulnerabilities),
      Set.unmodifiable(damageImmunities),
      isPlayer,
    );
  }
}
