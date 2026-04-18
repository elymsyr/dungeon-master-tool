import '../../../domain/entities/applied_effect.dart';
import '../../../domain/entities/resource_state.dart';
import '../../../domain/entities/schema/event_kind.dart';
import '../../../domain/entities/schema/rule_v2.dart' show ItemStyle;

/// Granted advantage/disadvantage source — debugging + merge için kaynak izlenir.
class GrantedAdvantage {
  const GrantedAdvantage({
    required this.scope,
    this.filter,
    required this.sourceRuleId,
    this.reason,
  });

  final AdvantageScope scope;
  final String? filter;
  final String sourceRuleId;
  final String? reason;
}

/// Granted feature — onLevelUp vb. rule'ların verdiği feature/feat.
class FeatureGrant {
  const FeatureGrant({
    required this.featureId,
    this.source,
    required this.sourceRuleId,
  });

  final String featureId;
  final String? source;
  final String sourceRuleId;
}

/// Bir effect'in atomic apply için tuttuğu deltalar.
class ResourceDelta {
  const ResourceDelta({
    required this.resourceKey,
    this.consume = 0,
    this.refreshAmount,
    this.refreshFraction,
    this.refreshToFull = false,
    this.setMax,
    this.setRefreshRule,
  });

  final String resourceKey;
  final int consume;
  final int? refreshAmount;
  final double? refreshFraction;
  final bool refreshToFull;
  final int? setMax;
  final RefreshRule? setRefreshRule;
}

/// Damage roll mutasyonu — pipeline sonrası uygulanır.
class DamageRollMutation {
  const DamageRollMutation({
    required this.op,
    required this.amount,
    required this.sourceRuleId,
  });

  final DamageModOp op;
  final num amount;
  final String sourceRuleId;
}

/// Pending user choice — UI tarafında çözülür.
class ChoicePrompt {
  const ChoicePrompt({
    required this.choiceKey,
    required this.options,
    required this.sourceRuleId,
    this.required = true,
  });

  final String choiceKey;
  final List<ChoiceOption> options;
  final String sourceRuleId;
  final bool required;
}

/// RuleEngineV3 evaluation sonucu. Mutable — effect_applier bu result'a yazar.
///
/// V3 engine reactive/event/d20/damage path'lerinin hepsinden tek result tipi
/// üretir; caller gerekli field'ları filtreler.
class RuleEvaluationResultV3 {
  RuleEvaluationResultV3();

  /// fieldKey → hesaplanan değer (setValue)
  final Map<String, dynamic> computedValues = <String, dynamic>{};

  /// entityId → per-item stil (styleItems)
  final Map<String, ItemStyle> itemStyles = <String, ItemStyle>{};

  /// entityId → blockReason (gateEquip)
  final Map<String, String> equipGates = <String, String>{};

  /// fieldKey → while-equipped modifiers
  final Map<String, dynamic> equippedModifiers = <String, dynamic>{};

  // ── V3 ─────────────────────────────────────────────────────────────────────

  /// resourceKey → güncel ResourceState (computedMax + deltas applied).
  final Map<String, ResourceState> computedResources = <String, ResourceState>{};

  /// Apply edilecek delta listesi (consume/refresh/setMax).
  final List<ResourceDelta> resourceDeltas = <ResourceDelta>[];

  /// applyEffect etkileri — entity.activeEffects listesine eklenecek.
  final List<AppliedEffect> grantedEffects = <AppliedEffect>[];

  /// grantFeature → featureId listesi.
  final List<FeatureGrant> grantedFeatures = <FeatureGrant>[];

  /// revokeFeature → featureId listesi.
  final List<String> revokedFeatures = <String>[];

  /// applyCondition → conditionId listesi.
  final List<String> appliedConditions = <String>[];

  /// removeCondition → conditionId listesi.
  final List<String> removedConditions = <String>[];

  /// D20 context — rule'ların verdiği advantage/disadvantage'lar.
  final List<GrantedAdvantage> advantages = <GrantedAdvantage>[];
  final List<GrantedAdvantage> disadvantages = <GrantedAdvantage>[];

  /// modifyCriticalRange → en düşük newMinRange kazanır (default 20).
  int? criticalRangeMin;

  /// Attack roll bonus'ları (toplanır).
  num attackRollBonus = 0;

  /// Damage roll mutasyonları (pipeline tarafından uygulanır).
  final List<DamageRollMutation> damageRollMutations = <DamageRollMutation>[];

  /// grantTempHp → toplam temp HP (max alınır).
  int grantedTempHp = 0;

  /// heal → (targetField, amount) listesi.
  final List<MapEntry<String, num>> healings = <MapEntry<String, num>>[];

  /// breakConcentration tetiklendi mi.
  bool concentrationBroken = false;

  /// grantAction → (actionId, type) listesi.
  final List<({String actionId, ActionType type})> grantedActions = [];

  /// presentChoice → UI tarafında resolve bekleyen listeler.
  final List<ChoicePrompt> pendingChoices = <ChoicePrompt>[];

  /// Event cascade (engine içinde limit altında).
  final List<EventKind> cascadedEvents = <EventKind>[];

  bool get isEmpty =>
      computedValues.isEmpty &&
      itemStyles.isEmpty &&
      equipGates.isEmpty &&
      equippedModifiers.isEmpty &&
      computedResources.isEmpty &&
      resourceDeltas.isEmpty &&
      grantedEffects.isEmpty &&
      grantedFeatures.isEmpty &&
      revokedFeatures.isEmpty &&
      appliedConditions.isEmpty &&
      removedConditions.isEmpty &&
      advantages.isEmpty &&
      disadvantages.isEmpty &&
      criticalRangeMin == null &&
      attackRollBonus == 0 &&
      damageRollMutations.isEmpty &&
      grantedTempHp == 0 &&
      healings.isEmpty &&
      !concentrationBroken &&
      grantedActions.isEmpty &&
      pendingChoices.isEmpty &&
      cascadedEvents.isEmpty;
}
