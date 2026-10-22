// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'encounter_config.freezed.dart';
part 'encounter_config.g.dart';

@freezed
abstract class EncounterColumnConfig with _$EncounterColumnConfig {
  const factory EncounterColumnConfig({
    required String subFieldKey,
    required String label,
    @Default(false) bool editable,
    @Default(false) bool showButtons,
    @Default(0) int width,
  }) = _EncounterColumnConfig;

  factory EncounterColumnConfig.fromJson(Map<String, dynamic> json) =>
      _$EncounterColumnConfigFromJson(json);
}

@freezed
abstract class EncounterConfig with _$EncounterConfig {
  const factory EncounterConfig({
    @Default('combat_stats') String combatStatsFieldKey,
    @Default('condition_stats') String conditionStatsFieldKey,
    @Default('stat_block') String statBlockFieldKey,
    @Default('initiative') String initiativeSubField,
    @Default('initiative') String sortBySubField,
    @Default('desc') String sortDirection,
    @Default([]) List<EncounterColumnConfig> columns,
    @Default([]) List<String> conditions,
    /// Free templates only (docs/free-template/DESIGN.md §14.2): the Combat
    /// stats preset the encounter reads; its values are the columns and the
    /// sort value is one of them. Read through `free_encounter.dart`.
    @JsonKey(includeIfNull: false) String? combatPresetId,
    /// Free templates only (docs/free-template/DESIGN.md §14.3, V18): the
    /// dice rolled and added when the sort value is a Number.
    @JsonKey(includeIfNull: false) String? sortDice,
    /// Free templates only (DESIGN §14.6): category slug → the image fields
    /// a battle map can be picked from. Read through `free_encounter.dart`.
    @JsonKey(includeIfNull: false) Map<String, List<String>>? battlemapFields,
  }) = _EncounterConfig;

  factory EncounterConfig.fromJson(Map<String, dynamic> json) =>
      _$EncounterConfigFromJson(json);
}
