import 'package:freezed_annotation/freezed_annotation.dart';

part 'field_schema.freezed.dart';
part 'field_schema.g.dart';

/// Desteklenen alan tipleri — 16 tip.
/// Python'daki ("text", "combo", "entity_select") → zengin tip sistemi.
enum FieldType {
  text,
  textarea,
  markdown,
  integer,
  @JsonValue('float')
  float_,
  @JsonValue('boolean')
  boolean_,
  @JsonValue('enum')
  enum_,
  date,
  image,
  file,
  relation,
  tagList,
  statBlock,
  combatStats,
  actionList,
  spellList,
}

/// Alan görünürlüğü — online modda kimin görebileceğini belirler.
enum FieldVisibility {
  shared,
  dmOnly,
  @JsonValue('private')
  private_,
}

/// Tip-spesifik validation kuralları.
@freezed
abstract class FieldValidation with _$FieldValidation {
  const factory FieldValidation({
    double? minValue,
    double? maxValue,
    int? minLength,
    int? maxLength,
    String? pattern,
    List<String>? allowedValues,
    List<String>? allowedTypes,
    List<String>? allowedExtensions,
    String? customMessage,
  }) = _FieldValidation;

  factory FieldValidation.fromJson(Map<String, dynamic> json) =>
      _$FieldValidationFromJson(json);
}

/// Tek bir alanın tanımı.
@freezed
abstract class FieldSchema with _$FieldSchema {
  const factory FieldSchema({
    required String fieldId,
    required String categoryId,
    required String fieldKey,
    required String label,
    required FieldType fieldType,
    @Default(false) bool isRequired,
    @Default(null) dynamic defaultValue,
    @Default('') String placeholder,
    @Default('') String helpText,
    @Default(FieldValidation()) FieldValidation validation,
    @Default(FieldVisibility.shared) FieldVisibility visibility,
    @Default(0) int orderIndex,
    @Default(false) bool isBuiltin,
    required String createdAt,
    required String updatedAt,
  }) = _FieldSchema;

  factory FieldSchema.fromJson(Map<String, dynamic> json) =>
      _$FieldSchemaFromJson(json);
}
