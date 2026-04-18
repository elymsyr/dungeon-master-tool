// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'turn_state.freezed.dart';
part 'turn_state.g.dart';

/// Bir round içindeki advantage/disadvantage kaynağının izlenmesi.
/// Engine netAdv/netDisadv hesabını toplarken kaynak id'leri debug için tutar.
@freezed
abstract class AdvantageSource with _$AdvantageSource {
  const factory AdvantageSource({
    required String sourceId,
    required String reason,
  }) = _AdvantageSource;

  factory AdvantageSource.fromJson(Map<String, dynamic> json) =>
      _$AdvantageSourceFromJson(json);
}

/// Encounter turn state — action economy + d20 context + attack flow.
///
/// Entity başına bir TurnState; encounter başladığında `entityId` +
/// `initiativeOrder` set edilir. Her round'ta `TurnManager.advance` reset eder.
@freezed
abstract class TurnState with _$TurnState {
  const factory TurnState({
    required String entityId,
    @Default(1) int roundNumber,
    @Default(0) int initiativeOrder,

    // ── Action Economy ───────────────────────────────────────────────────────
    @Default(false) bool actionUsed,
    @Default(false) bool bonusActionUsed,
    @Default(false) bool reactionUsed,
    @Default(0) int movementUsed,

    // ── D20 Context ──────────────────────────────────────────────────────────
    @Default(<AdvantageSource>[]) List<AdvantageSource> advantageSources,
    @Default(<AdvantageSource>[]) List<AdvantageSource> disadvantageSources,

    /// Default 20; Champion L3 → 19; Improved Critical → 19; Superior Critical → 18.
    @Default(20) int criticalRangeMin,

    // ── Attack Flow ──────────────────────────────────────────────────────────
    /// Bu turn'de yapılan attack sayısı (Extra Attack, TWF kontrolü için).
    @Default(0) int attacksThisTurn,

    /// İlk attack yapıldı mı — TWF, Crossbow Expert için.
    @Default(false) bool firstAttackMade,

    /// Concentration üzerinde olduğu effect id'si (varsa).
    String? concentratingOn,
  }) = _TurnState;

  factory TurnState.fromJson(Map<String, dynamic> json) =>
      _$TurnStateFromJson(json);
}
