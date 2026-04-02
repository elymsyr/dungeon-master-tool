import 'package:freezed_annotation/freezed_annotation.dart';

part 'encounter_layout.freezed.dart';
part 'encounter_layout.g.dart';

@freezed
abstract class EncounterLayout with _$EncounterLayout {
  const factory EncounterLayout({
    required String layoutId,
    required String schemaId,
    @Default('Standard D&D') String name,
    @Default([]) List<EncounterColumn> columns,
    @Default([]) List<SortRule> sortRules,
  }) = _EncounterLayout;

  factory EncounterLayout.fromJson(Map<String, dynamic> json) =>
      _$EncounterLayoutFromJson(json);
}

@freezed
abstract class EncounterColumn with _$EncounterColumn {
  const factory EncounterColumn({
    required String fieldKey,
    required String displayLabel,
    @Default(0) int width,
    @Default(false) bool isEditable,
    @Default('{value}') String formatTemplate,
  }) = _EncounterColumn;

  factory EncounterColumn.fromJson(Map<String, dynamic> json) =>
      _$EncounterColumnFromJson(json);
}

@freezed
abstract class SortRule with _$SortRule {
  const factory SortRule({
    required String fieldKey,
    @Default('desc') String direction,
    @Default(0) int priority,
  }) = _SortRule;

  factory SortRule.fromJson(Map<String, dynamic> json) =>
      _$SortRuleFromJson(json);
}
