import '../../domain/entities/schema/event_kind.dart';

/// D20 test çıktısı.
///
/// [d20Roll] — advantage/disadvantage sonrası seçilmiş zar değeri.
/// [rawRolls] — atılan 1 veya 2 zarın tümü (UI göstermek için).
/// [total] — d20 + tüm bonus'lar (ability mod + PB + misc + rule bonus).
/// [critical] — d20 >= criticalRangeMin.
/// [success] — DC null ise null; aksi halde total >= DC (crit otomatik success,
/// d20==1 otomatik fail yalnız attack roll için).
class D20TestResult {
  const D20TestResult({
    required this.testType,
    required this.d20Roll,
    required this.rawRolls,
    required this.total,
    required this.advantage,
    required this.disadvantage,
    required this.critical,
    required this.criticalMissRange,
    required this.totalBonus,
    this.success,
    this.dc,
    this.appliedBonuses = const [],
  });

  final D20TestType testType;
  final int d20Roll;
  final List<int> rawRolls;
  final int total;
  final bool advantage;
  final bool disadvantage;
  final bool critical;
  final bool criticalMissRange;
  final int totalBonus;
  final bool? success;
  final int? dc;

  /// Debug + UI: hangi kaynaktan hangi bonus geldi.
  final List<AppliedBonus> appliedBonuses;
}

class AppliedBonus {
  const AppliedBonus({
    required this.source,
    required this.amount,
    this.reason,
  });

  final String source;
  final num amount;
  final String? reason;
}
