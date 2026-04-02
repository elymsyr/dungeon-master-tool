import 'package:freezed_annotation/freezed_annotation.dart';

part 'category_rule.freezed.dart';
part 'category_rule.g.dart';

enum RuleType {
  pullField,        // Tek kaynaktan tek değer çek → hedefe yaz
  mergeFields,      // Birden fazla kaynaktan birleştir (toplama/liste)
  conditionalList,  // Tüm öğeleri ekle, koşula göre active/inactive
}

enum RuleOperation {
  replace,     // Üzerine yaz
  add,         // Sayısal toplama
  subtract,    // Sayısal çıkarma
  multiply,    // Sayısal çarpma
  appendList,  // Listeye ekle
}

@freezed
abstract class RuleSource with _$RuleSource {
  const factory RuleSource({
    required String relationFieldKey,  // Bu kategorideki relation field key
    required String sourceFieldKey,    // Kaynak entity'deki field key
  }) = _RuleSource;

  factory RuleSource.fromJson(Map<String, dynamic> json) =>
      _$RuleSourceFromJson(json);
}

@freezed
abstract class CategoryRule with _$CategoryRule {
  const factory CategoryRule({
    required String ruleId,
    required String name,
    required RuleType ruleType,
    @Default(true) bool enabled,
    required List<RuleSource> sources,
    required String targetFieldKey,
    @Default(RuleOperation.replace) RuleOperation operation,
    /// true = match (aynı ID varsa ekleme), false = add (her zaman ekle)
    @Default(false) bool matchOnly,
    /// true = equip edilmemiş kaynaklardan gelen öğeler deactivated olarak işaretlenir
    @Default(false) bool deactivateIfNotEquipped,
  }) = _CategoryRule;

  factory CategoryRule.fromJson(Map<String, dynamic> json) =>
      _$CategoryRuleFromJson(json);
}
