// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import 'event_kind.dart';
import 'rule_predicates_v3.dart';
import 'rule_v2.dart';

part 'rule_expressions_v3.freezed.dart';
part 'rule_expressions_v3.g.dart';

/// V3 value expression — V2 primitifleri + 11 yeni tip.
///
/// Recursive. `ifThenElse` içinde başka expression ve predicate alır;
/// infinite-loop koruması engine tarafında (depth cap).
@Freezed(unionKey: 'type')
abstract class ValueExpressionV3 with _$ValueExpressionV3 {
  // ── V2 parity ──────────────────────────────────────────────────────────────

  /// Sabit değer.
  const factory ValueExpressionV3.literal(
    @JsonKey(name: 'value') dynamic value,
  ) = LiteralExprV3;

  /// Doğrudan bir field değerini kopyala.
  const factory ValueExpressionV3.fieldValue(FieldRef source) = FieldValueExprV3;

  /// Relation list'teki entity'lerin field'larını topla/birleştir.
  const factory ValueExpressionV3.aggregate({
    required String relationFieldKey,
    required String sourceFieldKey,
    required AggregateOp op,
    @Default(false) bool onlyEquipped,
  }) = AggregateExprV3;

  /// Aritmetik: left op right.
  const factory ValueExpressionV3.arithmetic({
    required ValueExpressionV3 left,
    required ArithOp op,
    required ValueExpressionV3 right,
  }) = ArithmeticExprV3;

  /// Tablo araması.
  const factory ValueExpressionV3.tableLookup({
    required FieldRef table,
    required ValueExpressionV3 key,
    ValueExpressionV3? fallback,
  }) = TableLookupExprV3;

  /// Ability modifier: floor((score - 10) / 2).
  const factory ValueExpressionV3.modifier(FieldRef source) = ModifierExprV3;

  // ── V3 yeni ────────────────────────────────────────────────────────────────

  /// if/else expression — passive perception gibi koşullu hesaplamalar için.
  const factory ValueExpressionV3.ifThenElse({
    required PredicateV3 condition,
    @JsonKey(name: 'then') required ValueExpressionV3 then_,
    @JsonKey(name: 'else') required ValueExpressionV3 else_,
  }) = IfThenElseExpr;

  /// List field uzunluğu.
  const factory ValueExpressionV3.listLength(FieldRef list) = ListLengthExpr;

  /// List'i predicate ile filtrele ve aggregate et.
  const factory ValueExpressionV3.listFilter({
    required FieldRef list,
    required PredicateV3 filter,
    required AggregateOp op,
    String? sourceFieldKey,
  }) = ListFilterExpr;

  /// Minimum.
  const factory ValueExpressionV3.min(List<ValueExpressionV3> values) = MinExpr;

  /// Maximum.
  const factory ValueExpressionV3.max(List<ValueExpressionV3> values) = MaxExpr;

  /// Bir değeri min/max aralığına sıkıştır.
  const factory ValueExpressionV3.clamp({
    required ValueExpressionV3 value,
    required ValueExpressionV3 minValue,
    required ValueExpressionV3 maxValue,
  }) = ClampExpr;

  /// Zar notasyonu ("2d6+3"). [average] true ise ortalama değer (rand yok).
  const factory ValueExpressionV3.dice({
    required String notation,
    ValueExpressionV3? bonus,
    @Default(false) bool average,
  }) = DiceExpr;

  /// String template: "Need STR {0} to equip".
  const factory ValueExpressionV3.stringFormat({
    required String template,
    required List<ValueExpressionV3> args,
  }) = StringFormatExpr;

  /// Resource state değeri.
  const factory ValueExpressionV3.resourceValue({
    required String resourceKey,
    required ResourceField field,
  }) = ResourceExpr;

  /// Kullanıcı seçimi değeri.
  const factory ValueExpressionV3.choice({
    required String choiceKey,
    ValueExpressionV3? fallback,
  }) = ChoiceExpr;

  /// Trigger/turn context değeri.
  /// Örn: 'trigger.spell_level', 'turn.round_number'
  const factory ValueExpressionV3.contextValue(String contextKey) = ContextExpr;

  /// Belirli class'taki seviye (multiclass).
  const factory ValueExpressionV3.levelInClass(String classId) = LevelInClassExpr;

  /// Toplam seviye (sum of all class levels).
  const factory ValueExpressionV3.totalLevel() = TotalLevelExpr;

  /// PB shortcut — total level → table lookup.
  const factory ValueExpressionV3.proficiencyBonus() = PBExpr;

  factory ValueExpressionV3.fromJson(Map<String, dynamic> json) =>
      _$ValueExpressionV3FromJson(json);
}
