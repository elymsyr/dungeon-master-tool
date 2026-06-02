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
    @Default({}) Map<String, double> tokenSizeMultipliers,
    @Default(-1) int turnIndex,
    @Default(1) int round,
    @Default({}) Map<String, dynamic> tokenPositions,
    @Default(50) int gridSize,
    @Default(false) bool gridVisible,
    @Default(false) bool gridSnap,
    @Default(5) int feetPerCell,
    /// 5e diagonal counting rule (index into `DiagonalRule.values`, 0 =
    /// euclidean). Rides combat_state JSON — no Drift column.
    @Default(0) int diagonalRule,
    /// Versioned vector scene blob — future home for walls / lights / AoE /
    /// shapes / text (VTT Phases 3/4/6). Empty = no scene. Rides combat_state
    /// JSON (auto-persists via `Encounter.toJson()`) — no Drift column.
    @Default('') String sceneVectorJson,
    /// When true, monster/NPC HP is shown to players (bar on map + numeric in
    /// the initiative sidebar) on every projection output — cast, online share,
    /// second window. Default off. Hidden tokens stay fully hidden regardless.
    /// Rides combat_state JSON — no Drift column.
    @Default(false) bool showAllHp,
    /// When true, the player projection hides the HP bar + condition badge
    /// drawn under each token (the token name stays). Declutters the map when
    /// the initiative sidebar already carries that info. Default off. Rides
    /// combat_state JSON — no Drift column.
    @Default(false) bool hideTokenHud,
    /// Combatant ids whose tokens are hidden from players. Hidden tokens are
    /// filtered out of the player projection entirely (never sent), and render
    /// ghosted on the DM map so the DM can still see + move them.
    @Default([]) List<String> hiddenTokenIds,
    String? fogData,
    String? annotationData,
    String? measurementsData,
    /// Pen-tool strokes as vector JSON (array of `StrokeSnapshot.toJson()`).
    /// Replaces baking strokes into `annotationData` so each stroke keeps its
    /// identity and stays individually deletable across reload. `annotationData`
    /// now only holds legacy/imported bitmap art.
    String? strokesData,
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
    /// Snapshot of the source entity's combat stats at add-time. Edits in
    /// the encounter only mutate this map; the original entity is never
    /// written back. `entityId` is retained as a read-only reference so the
    /// row can open the original DB card.
    @Default({}) Map<String, dynamic> stats,
  }) = _Combatant;

  factory Combatant.fromJson(Map<String, dynamic> json) =>
      _$CombatantFromJson(json);
}

@freezed
abstract class CombatCondition with _$CombatCondition {
  const factory CombatCondition({
    required String name,
    int? duration,
    int? initialDuration,
    String? entityId,
  }) = _CombatCondition;

  factory CombatCondition.fromJson(Map<String, dynamic> json) =>
      _$CombatConditionFromJson(json);
}
