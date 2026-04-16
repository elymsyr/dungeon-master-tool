import 'package:freezed_annotation/freezed_annotation.dart';

part 'rule_v2.freezed.dart';
part 'rule_v2.g.dart';

// ─── Field References ────────────────────────────────────────────────────────

/// Bir değere nasıl ulaşılacağını tanımlar.
enum RefScope {
  self,          // Bu entity'nin kendi field'ı
  related,       // Tek relation field üzerinden ilişkili entity'nin field'ı
  relatedItems,  // Liste relation field'ındaki her entity'nin field'ı
}

/// Bir field değerine referans.
@freezed
abstract class FieldRef with _$FieldRef {
  const factory FieldRef({
    required RefScope scope,
    required String fieldKey,
    /// scope == related veya relatedItems ise: hangi relation field'ından geçilecek
    String? relationFieldKey,
    /// statBlock/combatStats gibi map field'lar için alt-key (ör. 'STR', 'hp')
    String? nestedFieldKey,
  }) = _FieldRef;

  factory FieldRef.fromJson(Map<String, dynamic> json) =>
      _$FieldRefFromJson(json);
}

// ─── Comparison Operators ────────────────────────────────────────────────────

enum CompareOp {
  eq,
  neq,
  gt,
  gte,
  lt,
  lte,
  contains,        // Liste bir değeri içeriyor mu
  notContains,
  isSubsetOf,      // Sol, sağın alt kümesi mi
  isSupersetOf,    // Sol, sağın üst kümesi mi
  isDisjointFrom,  // Kesişim boş mu
  isEmpty,         // Sol boş/null mı (sağ gerekmiyor)
  isNotEmpty,      // Sol dolu mu (sağ gerekmiyor)
}

// ─── Predicates ──────────────────────────────────────────────────────────────

/// Boolean koşul — kuralın ne zaman çalışacağını belirler.
@Freezed(unionKey: 'type')
abstract class Predicate with _$Predicate {
  /// İki field referansını veya bir field ile literal değeri karşılaştır.
  const factory Predicate.compare({
    required FieldRef left,
    required CompareOp op,
    /// Karşılaştırma hedefi: başka bir field referansı
    FieldRef? right,
    /// Karşılaştırma hedefi: sabit değer (right null ise kullanılır)
    @JsonKey(name: 'literal') dynamic literalValue,
  }) = ComparePredicate;

  /// Tüm alt koşullar doğru olmalı (AND).
  const factory Predicate.and(List<Predicate> children) = AndPredicate;

  /// Alt koşullardan en az biri doğru olmalı (OR).
  const factory Predicate.or(List<Predicate> children) = OrPredicate;

  /// Alt koşulun tersini al (NOT).
  const factory Predicate.not(Predicate child) = NotPredicate;

  /// Her zaman doğru — koşulsuz kurallar için.
  const factory Predicate.always() = AlwaysPredicate;

  factory Predicate.fromJson(Map<String, dynamic> json) =>
      _$PredicateFromJson(json);
}

// ─── Value Expressions ───────────────────────────────────────────────────────

/// Değer birleştirme/toplama operatörleri.
enum AggregateOp {
  sum,
  product,
  min,
  max,
  concat,   // String birleştirme
  append,   // Liste birleştirme
  replace,  // İlk değeri al
}

/// Aritmetik operatörler.
enum ArithOp { add, subtract, multiply, divide }

/// Bir kuralın ürettiği değeri nasıl hesaplayacağını tanımlar.
@Freezed(unionKey: 'type')
abstract class ValueExpression with _$ValueExpression {
  /// Doğrudan bir field değerini kopyala.
  const factory ValueExpression.fieldValue(FieldRef source) = FieldValueExpr;

  /// Relation list'teki entity'lerin field'larını topla/birleştir.
  const factory ValueExpression.aggregate({
    required String relationFieldKey,
    required String sourceFieldKey,
    required AggregateOp op,
    /// true ise sadece equipped olan kaynaklardan topla
    @Default(false) bool onlyEquipped,
  }) = AggregateExpr;

  /// Sabit değer.
  const factory ValueExpression.literal(dynamic value) = LiteralExpr;

  /// Aritmetik işlem: left op right.
  const factory ValueExpression.arithmetic({
    required ValueExpression left,
    required ArithOp op,
    required ValueExpression right,
  }) = ArithmeticExpr;

  factory ValueExpression.fromJson(Map<String, dynamic> json) =>
      _$ValueExpressionFromJson(json);
}

// ─── Item Styling ────────────────────────────────────────────────────────────

/// Liste içindeki öğelerin görsel stilini tanımlar.
@freezed
abstract class ItemStyle with _$ItemStyle {
  const factory ItemStyle({
    @Default(false) bool faded,
    @Default(false) bool strikethrough,
    /// Hex renk override (ör. '#FF0000')
    String? color,
    /// Açıklama tooltip'i
    String? tooltip,
    /// Material icon adı
    String? icon,
  }) = _ItemStyle;

  factory ItemStyle.fromJson(Map<String, dynamic> json) =>
      _$ItemStyleFromJson(json);
}

// ─── Rule Effects ────────────────────────────────────────────────────────────

/// Kural çalıştığında ne olacağını tanımlar.
@Freezed(unionKey: 'type')
abstract class RuleEffect with _$RuleEffect {
  /// Hedef field'a hesaplanan değeri yaz.
  /// Eski pullField / mergeFields / conditionalList'in yerini alır.
  const factory RuleEffect.setValue({
    required String targetFieldKey,
    required ValueExpression value,
  }) = SetValueEffect;

  /// "To Be Equipped" — equip edilmeyi engelleyen koşul.
  /// Predicate false dönerse item equip edilemez, blockReason gösterilir.
  const factory RuleEffect.gateEquip({
    @Default('') String blockReason,
  }) = GateEquipEffect;

  /// "When Equipped" — item equip edildiğinde sahip entity'ye etki.
  /// Hedef field'a değer ekler/değiştirir sadece equip sırasında.
  const factory RuleEffect.modifyWhileEquipped({
    required String targetFieldKey,
    required ValueExpression value,
  }) = ModifyWhileEquippedEffect;

  /// Liste field'ındaki öğelere per-item stil uygula.
  /// Predicate her öğe için ayrı ayrı değerlendirilir.
  const factory RuleEffect.styleItems({
    required String listFieldKey,
    required ItemStyle style,
  }) = StyleItemsEffect;

  factory RuleEffect.fromJson(Map<String, dynamic> json) =>
      _$RuleEffectFromJson(json);
}

// ─── The Rule ────────────────────────────────────────────────────────────────

/// Yeni nesil kural tanımı — predicate + effect çifti.
@freezed
abstract class RuleV2 with _$RuleV2 {
  const factory RuleV2({
    required String ruleId,
    required String name,
    @Default(true) bool enabled,
    /// Kuralın ne zaman çalışacağı
    @JsonKey(name: 'when') required Predicate when_,
    /// Kuralın ne yapacağı
    @JsonKey(name: 'then') required RuleEffect then_,
    /// Çalışma sırası (düşük = önce)
    @Default(0) int priority,
    /// Kullanıcıya görünen açıklama
    @Default('') String description,
  }) = _RuleV2;

  factory RuleV2.fromJson(Map<String, dynamic> json) =>
      _$RuleV2FromJson(json);
}
