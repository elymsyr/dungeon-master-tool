import 'package:freezed_annotation/freezed_annotation.dart';

part 'field_schema.freezed.dart';
part 'field_schema.g.dart';

/// Desteklenen alan tipleri — 15 tip.
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
  pdf,
  relation,       // Tek referans veya liste referans (allowedTypes ile hedef kategori belirlenir)
  tagList,
  statBlock,
  combatStats,
  conditionStats,
  dice,           // Zar notasyonu: "2d6", "1d20+5", "3d8+2"
  slot,           // Dolu/boş checkbox satırı: spell slot, ammo, charges, hit dice
  proficiencyTable, // D&D 5e skills/saving throws — her satır: name, ability, proficient, expertise, misc
  levelTable,     // Map<int,int> — level → value progression tablosu (spell slot count, hit dice, vs.)
  levelTextTable, // Map<int,String> — level → free-form text (e.g. "At Higher Levels", per-level features narrative)
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
    @Default(false) bool isList,
    @Default(false) bool hasEquip,
    /// Relation list için "show all sources" filter UI'ını aktive eder.
    /// Varsayılan: sadece equipped itemlar görünür. Açıkken: rule-sourced
    /// itemlar da (class trait vs.) source badge ile görünür.
    @Default(false) bool showSourceFilter,
    @Default([]) List<String> allowedInSections,
    /// combatStats tipi için alt-alan tanımları. Encounter tablosu buradan beslenir.
    /// Her eleman: {key: 'hp', label: 'HP', type: 'text'|'integer'|'dice'}
    @Default([]) List<Map<String, String>> subFields,
    /// Hangi gruba ait (null = grupsuz, üstte render edilir)
    @Default(null) String? groupId,
    /// Grid layout'ta kaç sütun kaplar (1 = normal, 2+ = geniş)
    @Default(1) int gridColumnSpan,
    required String createdAt,
    required String updatedAt,
  }) = _FieldSchema;

  factory FieldSchema.fromJson(Map<String, dynamic> json) =>
      _$FieldSchemaFromJson(json);
}
