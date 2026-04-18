// `@JsonKey(...)` on freezed factory parameters generates the expected
// `@JsonKey.new` on constructor params; the analyzer flags it but the
// annotation is consumed correctly by json_serializable. Ignore repo-wide.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'event_kind.dart';
import 'rule_v2.dart';

part 'rule_predicates_v3.freezed.dart';
part 'rule_predicates_v3.g.dart';

/// V3 predicate — V2 primitifleri + yeni 8 tip.
///
/// V2 predicate'leri (compare/and/or/not/always) bu modelde yeniden tanımlı,
/// böylece V3 engine tek predicate tipiyle çalışır. V2→V3 adapter `Predicate`
/// (v2) instance'larını `PredicateV3`'e çevirir.
@Freezed(unionKey: 'type')
abstract class PredicateV3 with _$PredicateV3 {
  // ── V2 parity ──────────────────────────────────────────────────────────────

  const factory PredicateV3.always() = AlwaysPredicate;

  const factory PredicateV3.compare({
    required FieldRef left,
    required CompareOp op,
    FieldRef? right,
    @JsonKey(name: 'literal') dynamic literalValue,
  }) = ComparePredicate;

  const factory PredicateV3.and(List<PredicateV3> children) = AndPredicate;

  const factory PredicateV3.or(List<PredicateV3> children) = OrPredicate;

  const factory PredicateV3.not(PredicateV3 child) = NotPredicate;

  // ── V3 yeni ────────────────────────────────────────────────────────────────

  /// Liste field'ının uzunluğunu bir sayı ile karşılaştır.
  /// Örn: attunements.length < 3
  const factory PredicateV3.listLength({
    required FieldRef list,
    required CompareOp op,
    required int value,
  }) = ListLengthPredicate;

  /// Resource state karşılaştırması.
  /// Örn: resources['rage_uses'].current > 0
  const factory PredicateV3.resource({
    required String resourceKey,
    required ResourceField field,
    required CompareOp op,
    required int value,
  }) = ResourcePredicate;

  /// Kullanıcı bir choice yapmış mı, ve opsiyonel olarak beklenen değerle eşleşiyor mu.
  const factory PredicateV3.hasChoice({
    required String choiceKey,
    String? expectedValue,
  }) = HasChoicePredicate;

  /// Entity'nin belirtilen condition'ı aktif mi.
  /// [minLevel] exhaustion gibi seviyeli condition'lar için.
  const factory PredicateV3.hasCondition({
    required String conditionId,
    int? minLevel,
  }) = HasConditionPredicate;

  /// Entity'nin belirtilen feature/feat/trait'i var mı.
  const factory PredicateV3.hasFeature({
    required String featureId,
  }) = HasFeaturePredicate;

  /// Encounter turn'ünün belirli bir fazında mıyız.
  const factory PredicateV3.inTurnPhase({
    required TurnPhase phase,
  }) = InTurnPhasePredicate;

  /// Belirli bir action tipi hâlâ kullanılabilir mi (bu turn'de harcanmamış).
  const factory PredicateV3.actionAvailable({
    required ActionType action,
  }) = ActionAvailablePredicate;

  /// Entity seviyesi karşılaştırması — opsiyonel class-specific filter.
  const factory PredicateV3.level({
    required CompareOp op,
    required int level,
    String? classFilter,
  }) = LevelPredicate;

  /// Event/trigger context değeri ile karşılaştırma.
  /// Örn: trigger.damage_type == 'fire', trigger.spell_level >= 3
  const factory PredicateV3.context({
    required String contextKey,
    @JsonKey(name: 'value') required dynamic expectedValue,
  }) = ContextPredicate;

  factory PredicateV3.fromJson(Map<String, dynamic> json) =>
      _$PredicateV3FromJson(json);
}
