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
  }) = _EncounterConfig;

  factory EncounterConfig.fromJson(Map<String, dynamic> json) =>
      _$EncounterConfigFromJson(json);
}
