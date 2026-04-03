import 'package:freezed_annotation/freezed_annotation.dart';

part 'field_group.freezed.dart';
part 'field_group.g.dart';

/// Alan grubu — bir kategorideki field'ları görsel olarak gruplamak için.
/// Grid layout destekler (1-4 sütun).
@freezed
abstract class FieldGroup with _$FieldGroup {
  const factory FieldGroup({
    required String groupId,
    @Default('') String name,
    @Default(1) int gridColumns,
    @Default(0) int orderIndex,
    @Default(false) bool isCollapsed,
  }) = _FieldGroup;

  factory FieldGroup.fromJson(Map<String, dynamic> json) =>
      _$FieldGroupFromJson(json);
}
