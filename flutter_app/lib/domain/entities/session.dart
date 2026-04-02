import 'package:freezed_annotation/freezed_annotation.dart';

part 'session.freezed.dart';
part 'session.g.dart';

@freezed
abstract class Session with _$Session {
  const factory Session({
    required String id,
    @Default('') String name,
    @Default('') String notes,
    @Default('') String logs,
    @Default([]) List<Map<String, dynamic>> encounters,
    String? activeEncounterId,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);
}

@freezed
abstract class Encounter with _$Encounter {
  const factory Encounter({
    required String id,
    @Default('') String name,
    @Default([]) List<Combatant> combatants,
    String? mapPath,
    @Default(50) int tokenSize,
    @Default({}) Map<String, int> tokenSizeOverrides,
    @Default(-1) int turnIndex,
    @Default(1) int round,
    @Default({}) Map<String, dynamic> tokenPositions,
    @Default(50) int gridSize,
    @Default(false) bool gridVisible,
    @Default(false) bool gridSnap,
    @Default(5) int feetPerCell,
    String? encounterLayoutId,
  }) = _Encounter;

  factory Encounter.fromJson(Map<String, dynamic> json) =>
      _$EncounterFromJson(json);
}

@freezed
abstract class Combatant with _$Combatant {
  const factory Combatant({
    required String id,
    required String name,
    @Default(0) int init,
    @Default(10) int ac,
    @Default(10) int hp,
    @Default(10) int maxHp,
    String? entityId,
    @Default([]) List<CombatCondition> conditions,
    String? tokenId,
  }) = _Combatant;

  factory Combatant.fromJson(Map<String, dynamic> json) =>
      _$CombatantFromJson(json);
}

@freezed
abstract class CombatCondition with _$CombatCondition {
  const factory CombatCondition({
    required String name,
    int? duration,
  }) = _CombatCondition;

  factory CombatCondition.fromJson(Map<String, dynamic> json) =>
      _$CombatConditionFromJson(json);
}
