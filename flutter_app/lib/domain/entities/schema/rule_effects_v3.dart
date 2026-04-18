// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../applied_effect.dart';
import 'event_kind.dart';
import 'rule_expressions_v3.dart';
import 'rule_predicates_v3.dart';
import 'rule_v2.dart';

part 'rule_effects_v3.freezed.dart';
part 'rule_effects_v3.g.dart';

/// V3 rule effect — V2 primitifleri + 18 yeni tip.
///
/// `CompositeEffect` ve `ConditionalEffect` recursive — engine depth cap uygular.
@Freezed(unionKey: 'type')
abstract class RuleEffectV3 with _$RuleEffectV3 {
  // ── V2 parity ──────────────────────────────────────────────────────────────

  const factory RuleEffectV3.setValue({
    required String targetFieldKey,
    required ValueExpressionV3 value,
  }) = SetValueEffectV3;

  const factory RuleEffectV3.gateEquip({
    @Default('') String blockReason,
  }) = GateEquipEffectV3;

  const factory RuleEffectV3.modifyWhileEquipped({
    required String targetFieldKey,
    required ValueExpressionV3 value,
  }) = ModifyWhileEquippedEffectV3;

  const factory RuleEffectV3.styleItems({
    required String listFieldKey,
    required ItemStyle style,
  }) = StyleItemsEffectV3;

  // ── Resource Management ────────────────────────────────────────────────────

  /// Bir resource'un tavan değerini hesapla + refresh kuralını set et.
  /// Örn: spell_slot_3 max = class.spell_slot_table[level][3].
  const factory RuleEffectV3.setResourceMax({
    required String resourceKey,
    required ValueExpressionV3 value,
    required RefreshRule refreshRule,
  }) = SetResourceMaxEffect;

  /// Resource'u tüket (current -= amount).
  /// [blockIfInsufficient] true ise yetersizken effect başarısız olur.
  const factory RuleEffectV3.consumeResource({
    required String resourceKey,
    required ValueExpressionV3 amount,
    @Default(true) bool blockIfInsufficient,
  }) = ConsumeResourceEffect;

  /// Resource'u yenile. [amount] null ise tam dolum; [fraction] varsa oranla.
  const factory RuleEffectV3.refreshResource({
    required String resourceKey,
    ValueExpressionV3? amount,
    double? fraction,
  }) = RefreshResourceEffect;

  // ── Feature Grant / Revoke ─────────────────────────────────────────────────

  /// Bir feature/feat/trait'i entity'ye ver.
  const factory RuleEffectV3.grantFeature({
    required String featureId,
    String? source,
  }) = GrantFeatureEffect;

  /// Feature'u geri al.
  const factory RuleEffectV3.revokeFeature({
    required String featureId,
  }) = RevokeFeatureEffect;

  // ── Conditions ─────────────────────────────────────────────────────────────

  const factory RuleEffectV3.applyCondition({
    required String conditionId,
    DurationSpec? duration,
    ValueExpressionV3? saveDC,
    String? saveAbility,
  }) = ApplyConditionEffect;

  const factory RuleEffectV3.removeCondition({
    required String conditionId,
  }) = RemoveConditionEffect;

  // ── D20 Context ────────────────────────────────────────────────────────────

  const factory RuleEffectV3.grantAdvantage({
    required AdvantageScope scope,
    String? filter,
  }) = GrantAdvantageEffect;

  const factory RuleEffectV3.grantDisadvantage({
    required AdvantageScope scope,
    String? filter,
  }) = GrantDisadvantageEffect;

  /// Champion L3 → newMinRange = 19.
  const factory RuleEffectV3.modifyCriticalRange({
    required int newMinRange,
  }) = ModifyCriticalRangeEffect;

  // ── Damage / Attack Rolls ──────────────────────────────────────────────────

  const factory RuleEffectV3.modifyDamageRoll({
    required DamageModOp op,
    required ValueExpressionV3 value,
  }) = DamageRollEffect;

  const factory RuleEffectV3.modifyAttackRoll({
    required ValueExpressionV3 bonus,
  }) = AttackRollEffect;

  // ── HP / Healing ───────────────────────────────────────────────────────────

  const factory RuleEffectV3.grantTempHp({
    required ValueExpressionV3 amount,
  }) = TempHpEffect;

  const factory RuleEffectV3.heal({
    required ValueExpressionV3 amount,
    String? targetField,
  }) = HealEffect;

  // ── Applied Effects ────────────────────────────────────────────────────────

  /// Spell/feature kaynaklı geçici modifier'ı entity'ye ekle.
  const factory RuleEffectV3.applyEffect({
    required AppliedEffect effect,
  }) = ApplyAppliedEffectEffect;

  const factory RuleEffectV3.breakConcentration() = BreakConcentrationEffect;

  // ── Turn Economy ───────────────────────────────────────────────────────────

  const factory RuleEffectV3.grantAction({
    required String actionId,
    @JsonKey(name: 'actionType') required ActionType actionType,
  }) = GrantActionEffect;

  // ── User Choice ────────────────────────────────────────────────────────────

  const factory RuleEffectV3.presentChoice({
    required String choiceKey,
    required List<ChoiceOption> options,
    @Default(true) bool required,
  }) = PresentChoiceEffect;

  // ── Composition ────────────────────────────────────────────────────────────

  const factory RuleEffectV3.composite(List<RuleEffectV3> effects) =
      CompositeEffect;

  const factory RuleEffectV3.conditional({
    required PredicateV3 condition,
    @JsonKey(name: 'then') required RuleEffectV3 then_,
    @JsonKey(name: 'else') RuleEffectV3? else_,
  }) = ConditionalEffect;

  factory RuleEffectV3.fromJson(Map<String, dynamic> json) =>
      _$RuleEffectV3FromJson(json);
}
