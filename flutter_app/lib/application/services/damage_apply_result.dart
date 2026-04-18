/// Damage pipeline sonucu — caller entity mutation'ını bu spec'e göre yapar.
class DamageApplyResult {
  const DamageApplyResult({
    required this.rawAmount,
    required this.multipliedAmount,
    required this.appliedAmount,
    required this.absorbedByTempHp,
    required this.newHp,
    required this.newTempHp,
    required this.hpZero,
    required this.damageType,
    required this.wasImmune,
    required this.wasResistant,
    required this.wasVulnerable,
    required this.wasCritical,
    this.concentrationSaveDc,
  });

  /// Ham damage (crit double + vulnerability çarpımı uygulanmadan).
  final int rawAmount;

  /// Crit double + vulnerability × uygulandıktan sonraki tutar.
  final int multipliedAmount;

  /// Resistance/immunity sonrası gerçek uygulanan.
  final int appliedAmount;

  /// Temp HP tarafından soğurulan.
  final int absorbedByTempHp;

  final int newHp;
  final int newTempHp;
  final bool hpZero;
  final String damageType;

  final bool wasImmune;
  final bool wasResistant;
  final bool wasVulnerable;
  final bool wasCritical;

  /// Concentration için save DC (damage >= 10 ? damage / 2 : 10). Target
  /// concentration sürüyorsa caller bu DC ile onConcentrationBroken akışını
  /// tetikler; yoksa null.
  final int? concentrationSaveDc;
}
