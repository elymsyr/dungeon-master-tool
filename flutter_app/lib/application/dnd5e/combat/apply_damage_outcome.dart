import '../spell/concentration_check_outcome.dart';
import 'damage_outcome.dart';

/// Combined result of running [DamageResolver] then (optionally)
/// [ConcentrationCheckResolver] on the same hit. [concentration] is null when
/// no save was rolled — either the target wasn't concentrating, the post-
/// mitigation damage was zero, or the hit killed the target outright (the
/// caller treats death as concentration ending without a roll).
class ApplyDamageOutcome {
  final DamageOutcome damage;
  final ConcentrationCheckOutcome? concentration;

  const ApplyDamageOutcome({
    required this.damage,
    required this.concentration,
  });

  bool get concentrationBroken =>
      concentration != null && concentration!.broken;
}
