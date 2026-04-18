# Rule System V3 — Kod Uygulama Yönlendirmesi

Bu döküman, [RULES_V3_SPECIFICATION.md](RULES_V3_SPECIFICATION.md)'de tasarlanan rule engine'in Flutter/Dart tarafında nasıl implement edileceğine dair somut yönlendirmedir. Mevcut [rule_v2.dart](../flutter_app/lib/domain/entities/schema/rule_v2.dart) + [rule_engine_v2.dart](../flutter_app/lib/application/services/rule_engine_v2.dart) + [template_provider.dart](../flutter_app/lib/application/providers/template_provider.dart) altyapısı **bozulmadan** V3 ekleneceği için migration path de detaylı.

Referanslar:
- Template uyarlaması: [SRD_TEMPLATE_APPLICATION.md](SRD_TEMPLATE_APPLICATION.md)
- Mevcut altyapı: [TEMPLATES_FIELDS_GROUPS_RULES.md](TEMPLATES_FIELDS_GROUPS_RULES.md)

---

## 1. Yol Haritası — 6 Faz

| Faz | Kapsam | Tahmini Süre | Risk |
|-----|--------|--------------|------|
| 1 | Domain model V3 (entity extensions + RuleV3) | 1 hafta | Düşük |
| 2 | RuleEngineV3 (reactive path) + V2 adapter | 1.5 hafta | Orta |
| 3 | Event bus + event rules | 1 hafta | Orta |
| 4 | Resource manager + choice state + turn state | 1 hafta | Orta |
| 5 | D20 test pipeline + damage pipeline | 1 hafta | Yüksek |
| 6 | UI (builder v3, resource widgets, event tester) + SRD seed | 2 hafta | Orta |

Toplam: ~8 hafta. Her faz bağımsız PR.

---

## 2. Dizin Yapısı

```
flutter_app/lib/
├── domain/
│   └── entities/
│       ├── entity.dart                              [MODIFY: add resources/choices/turnState]
│       ├── applied_effect.dart                      [NEW]
│       ├── resource_state.dart                      [NEW]
│       ├── choice_state.dart                        [NEW]
│       ├── turn_state.dart                          [NEW]
│       └── schema/
│           ├── rule_v2.dart                         [KEEP — backward compat]
│           ├── rule_v3.dart                         [NEW — full V3 model]
│           ├── rule_triggers.dart                   [NEW]
│           ├── rule_predicates_v3.dart              [NEW]
│           ├── rule_expressions_v3.dart             [NEW]
│           ├── rule_effects_v3.dart                 [NEW]
│           ├── event_kind.dart                      [NEW]
│           ├── default_dnd5e_schema.dart            [KEEP]
│           ├── default_dnd5e_schema_v3.dart         [NEW — SRD 5.2.1 builder]
│           └── default_dnd5e_rules_v3.dart          [NEW — 60+ rule seeds]
│
├── application/
│   ├── services/
│   │   ├── rule_engine_v2.dart                      [KEEP]
│   │   ├── rule_engine_v3.dart                      [NEW — top-level orchestrator]
│   │   ├── rule_v2_to_v3_adapter.dart               [NEW]
│   │   ├── rule_evaluator/
│   │   │   ├── predicate_evaluator.dart             [NEW]
│   │   │   ├── expression_evaluator.dart            [NEW]
│   │   │   ├── effect_applier.dart                  [NEW]
│   │   │   └── context.dart                         [NEW — RuleContext class]
│   │   ├── event_bus.dart                           [NEW]
│   │   ├── resource_manager.dart                    [NEW]
│   │   ├── choice_manager.dart                      [NEW]
│   │   ├── turn_manager.dart                        [NEW]
│   │   ├── d20_test_service.dart                    [NEW]
│   │   ├── damage_pipeline.dart                     [NEW]
│   │   └── dice_roller.dart                         [NEW — abstraction for testing]
│   │
│   └── providers/
│       ├── template_provider.dart                   [KEEP]
│       ├── rule_engine_v3_provider.dart             [NEW]
│       ├── event_bus_provider.dart                  [NEW]
│       └── turn_context_provider.dart               [NEW — encounter-scope]
│
├── data/
│   └── database/
│       └── tables/
│           ├── world_schemas_table.dart             [MODIFY: schemaVersion field]
│           └── entity_resources_table.dart          [NEW — opsiyonel; json alternatif]
│
├── presentation/
│   ├── dialogs/
│   │   ├── rule_builder_dialog.dart                 [KEEP — V2]
│   │   └── rule_builder_dialog_v3.dart              [NEW — tabbed (Reactive/Event/D20/Resource/Choice)]
│   │
│   └── widgets/
│       ├── resource_widgets/
│       │   ├── spell_slot_tracker.dart              [NEW]
│       │   ├── hit_dice_tracker.dart                [NEW]
│       │   ├── class_resource_tracker.dart          [NEW]
│       │   └── concentration_indicator.dart         [NEW]
│       ├── d20_test_panel.dart                      [NEW — advantage/disadvantage UI]
│       ├── rule_debugger.dart                       [NEW — eval trace viewer]
│       └── event_log.dart                           [NEW]
│
└── test/
    ├── application/
    │   ├── rule_engine_v2_test.dart                 [KEEP]
    │   ├── rule_engine_v3_test.dart                 [NEW]
    │   ├── rule_evaluator_test.dart                 [NEW]
    │   ├── event_bus_test.dart                      [NEW]
    │   ├── resource_manager_test.dart               [NEW]
    │   └── d20_test_service_test.dart               [NEW]
    └── integration/
        └── srd_scenarios_test.dart                  [NEW — Fighter L5, Wizard cast Fireball, etc.]
```

---

## 3. Faz 1 — Domain Model V3

### 3.1 `rule_v3.dart` (freezed, sealed)

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'rule_triggers.dart';
import 'rule_predicates_v3.dart';
import 'rule_effects_v3.dart';

part 'rule_v3.freezed.dart';
part 'rule_v3.g.dart';

@freezed
abstract class RuleV3 with _$RuleV3 {
  const factory RuleV3({
    required String ruleId,
    required String name,
    @Default('') String description,
    @Default(true) bool enabled,
    @Default(0) int priority,

    @Default(RuleTrigger.always()) RuleTrigger trigger,
    @JsonKey(name: 'when') required PredicateV3 when_,
    @JsonKey(name: 'then') required RuleEffectV3 then_,

    @Default(RuleScope.reactive) RuleScope scope,
    @Default([]) List<String> dependsOn,
    @Default(1) int schemaVersion,
  }) = _RuleV3;

  factory RuleV3.fromJson(Map<String, dynamic> json) => _$RuleV3FromJson(json);
}

enum RuleScope { reactive, event, d20Test, damage, turnPhase }
```

### 3.2 `rule_triggers.dart`

```dart
@Freezed(unionKey: 'type')
sealed class RuleTrigger with _$RuleTrigger {
  const factory RuleTrigger.always() = AlwaysTrigger;

  const factory RuleTrigger.event({
    required EventKind event,
    PredicateV3? filter,
  }) = EventTrigger;

  const factory RuleTrigger.d20Test({
    required D20TestType testType,
    String? abilityFilter,
    String? skillFilter,
    String? saveAgainstFilter,
  }) = D20Trigger;

  const factory RuleTrigger.damageApply({
    String? damageTypeFilter,
    @Default(DamageDirection.taken) DamageDirection direction,
  }) = DamageTrigger;

  const factory RuleTrigger.turnPhase({
    required TurnPhase phase,
  }) = TurnTrigger;

  factory RuleTrigger.fromJson(Map<String, dynamic> json) =>
      _$RuleTriggerFromJson(json);
}
```

### 3.3 `event_kind.dart`

```dart
enum EventKind {
  // lifecycle
  onCreate, onLevelUp, onClassAdded, onSubclassUnlocked,

  // rest
  onShortRest, onLongRest, onDawn, onDusk,

  // combat
  onInitiativeRoll, onRoundStart, onRoundEnd, onTurnStart, onTurnEnd,
  onAttackMade, onAttackHit, onAttackMiss, onCriticalHit,
  onDamageDealt, onDamageTaken, onHpZero, onDeath, onStabilize,
  onConditionApplied, onConditionRemoved, onConcentrationBroken,
  onSpellCast, onSpellSlotConsumed, onCantripCast,
  onMove, onOpportunityAttackProvoked,

  // equipment
  onEquip, onUnequip, onAttune, onUnattune,

  // custom
  custom,
}
```

### 3.4 `resource_state.dart`

```dart
@freezed
abstract class ResourceState with _$ResourceState {
  const factory ResourceState({
    required String resourceKey,
    @Default(0) int current,
    @Default(0) int max,
    @Default(RefreshRule.never) RefreshRule refreshRule,
    @Default({}) Map<String, dynamic> metadata,
  }) = _ResourceState;

  factory ResourceState.fromJson(Map<String, dynamic> json) =>
      _$ResourceStateFromJson(json);
}

enum RefreshRule { never, shortRest, longRest, dawn, turn, custom }
```

### 3.5 `entity.dart` (modify)

```dart
@freezed
abstract class Entity with _$Entity {
  const factory Entity({
    // MEVCUT
    required String id,
    @Default('New Record') String name,
    required String categorySlug,
    @Default('') String source,
    @Default('') String description,
    @Default([]) List<String> images,
    @Default([]) List<String> tags,
    @Default('') String dmNotes,
    @Default([]) List<String> pdfs,
    String? locationId,
    @Default({}) Map<String, dynamic> fields,

    // YENİ V3
    @Default({}) Map<String, ResourceState> resources,
    @Default({}) Map<String, ChoiceState> choices,
    TurnState? turnState,
    @Default([]) List<AppliedEffect> activeEffects,
  }) = _Entity;
}
```

**Migration**: Mevcut Drift tablosundaki `fieldsJson` aynen kalır. Yeni 4 alan için ek JSON column'lar (`resourcesJson`, `choicesJson`, `turnStateJson`, `activeEffectsJson`). Boş default sayesinde eski kayıtlar otomatik okunur.

---

## 4. Faz 2 — Rule Engine V3 + V2 Adapter

### 4.1 `rule_engine_v3.dart`

```dart
class RuleEngineV3 {
  final PredicateEvaluator _predicateEval;
  final ExpressionEvaluator _expressionEval;
  final EffectApplier _effectApplier;

  RuleEvaluationResultV3 evaluateReactive({
    required Entity entity,
    required EntityCategorySchema category,
    required Map<String, Entity> allEntities,
  }) {
    final ctx = RuleContext(
      entity: entity,
      category: category,
      allEntities: allEntities,
      trigger: const RuleTrigger.always(),
    );

    // 1. Rule'ları topological sort
    final orderedRules = _topologicalSort(category.rulesV3);

    // 2. Her rule'u sırayla değerlendir
    final result = RuleEvaluationResultV3.empty();
    for (final rule in orderedRules) {
      if (!rule.enabled) continue;
      if (!_triggerMatches(rule.trigger, ctx)) continue;

      final predicateResult = _predicateEval.eval(rule.when_, ctx);
      if (!predicateResult) continue;

      _effectApplier.apply(rule.then_, ctx, result);
    }

    return result;
  }

  RuleEvaluationResultV3 evaluateEvent({
    required EventKind kind,
    required Entity entity,
    required Map<String, dynamic> payload,
    required Map<String, Entity> allEntities,
    required EntityCategorySchema category,
  }) {
    final ctx = RuleContext(
      entity: entity,
      category: category,
      allEntities: allEntities,
      trigger: RuleTrigger.event(event: kind),
      eventPayload: payload,
    );
    // iterate rules with EventTrigger matching `kind`
    // apply effects (CompositeEffect included)
    // collect cascade events (respect MAX_CASCADE_EVENTS)
  }
}

class RuleEvaluationResultV3 {
  Map<String, dynamic> computedValues;
  Map<String, ItemStyle> itemStyles;
  Map<String, String> equipGates;
  Map<String, dynamic> equippedModifiers;

  // YENİ
  Map<String, ResourceState> computedResources;
  List<AppliedEffect> grantedEffects;
  List<GrantedAdvantage> advantages;
  List<GrantedAdvantage> disadvantages;
  List<FeatureGrant> grantedFeatures;
  List<String> appliedConditions;
  List<EventKind> cascadedEvents;
  List<ChoicePrompt> pendingChoices;
}
```

### 4.2 `rule_v2_to_v3_adapter.dart`

```dart
class RuleV2ToV3Adapter {
  static RuleV3 upgrade(RuleV2 v2) {
    return RuleV3(
      ruleId: v2.ruleId,
      name: v2.name,
      description: v2.description,
      enabled: v2.enabled,
      priority: v2.priority,
      trigger: const RuleTrigger.always(),
      when_: _upgradePredicate(v2.when_),
      then_: _upgradeEffect(v2.then_),
      scope: RuleScope.reactive,
    );
  }

  static PredicateV3 _upgradePredicate(Predicate v2) { ... }
  static RuleEffectV3 _upgradeEffect(RuleEffect v2) { ... }
}
```

Engine önce `category.rulesV3` varsa onu, yoksa `category.rules` (V2) adapter üstünden kullanır.

### 4.3 `predicate_evaluator.dart`

```dart
class PredicateEvaluator {
  bool eval(PredicateV3 predicate, RuleContext ctx) {
    return switch (predicate) {
      AlwaysPredicate() => true,
      ComparePredicate p => _compare(p, ctx),
      AndPredicate p => p.children.every((c) => eval(c, ctx)),
      OrPredicate p => p.children.any((c) => eval(c, ctx)),
      NotPredicate p => !eval(p.child, ctx),
      ListLengthPredicate p => _listLength(p, ctx),
      ResourcePredicate p => _resource(p, ctx),
      HasChoicePredicate p => _hasChoice(p, ctx),
      HasConditionPredicate p => _hasCondition(p, ctx),
      HasFeaturePredicate p => _hasFeature(p, ctx),
      InTurnPhasePredicate p => _turnPhase(p, ctx),
      ActionAvailablePredicate p => _actionAvail(p, ctx),
      LevelPredicate p => _level(p, ctx),
      ContextPredicate p => _contextMatch(p, ctx),
    };
  }
}
```

### 4.4 `expression_evaluator.dart`

Benzer pattern. Tüm 17 expression tipi için `eval` fonksiyonu. `dice` için `DiceRoller` abstraction ile; test'te fake roller.

### 4.5 `effect_applier.dart`

```dart
class EffectApplier {
  void apply(RuleEffectV3 effect, RuleContext ctx, RuleEvaluationResultV3 result) {
    switch (effect) {
      case SetValueEffect e: result.computedValues[e.targetFieldKey] = _expEval.eval(e.value, ctx);
      case GateEquipEffect e: result.equipGates[ctx.entity.id] = e.blockReason;
      case ModifyWhileEquippedEffect e: ...;
      case StyleItemsEffect e: ...;
      case SetResourceMaxEffect e: result.computedResources[e.resourceKey] = ResourceState(...);
      case ConsumeResourceEffect e: _consumeResource(e, ctx, result);
      case RefreshResourceEffect e: ...;
      case GrantFeatureEffect e: result.grantedFeatures.add(FeatureGrant(...));
      case ApplyConditionEffect e: result.appliedConditions.add(e.conditionId);
      case GrantAdvantageEffect e: result.advantages.add(GrantedAdvantage(...));
      case GrantDisadvantageEffect e: result.disadvantages.add(...);
      case ModifyCriticalRangeEffect e: result.criticalRangeMin = e.newMinRange;
      case DamageRollEffect e: ...;
      case AttackRollEffect e: ...;
      case TempHpEffect e: ...;
      case HealEffect e: ...;
      case ApplyAppliedEffectEffect e: result.grantedEffects.add(e.effect);
      case BreakConcentrationEffect: ...;
      case GrantActionEffect e: ...;
      case PresentChoiceEffect e: result.pendingChoices.add(ChoicePrompt(...));
      case CompositeEffect e: for (final sub in e.effects) apply(sub, ctx, result);
      case ConditionalEffect e:
        if (_predEval.eval(e.condition, ctx)) apply(e.then_, ctx, result);
        else if (e.else_ != null) apply(e.else_!, ctx, result);
    }
  }
}
```

### 4.6 `RuleContext`

```dart
class RuleContext {
  final Entity entity;
  final EntityCategorySchema category;
  final Map<String, Entity> allEntities;
  final RuleTrigger trigger;
  final Map<String, dynamic> eventPayload;
  final TurnState? turnState;
  final int depth;           // infinite loop guard
  final DiceRoller diceRoller;

  RuleContext withDepth() => copyWith(depth: depth + 1);
  // helpers: relatedEntity(id), resource(key), choice(key), field(key)
}
```

---

## 5. Faz 3 — Event Bus

### 5.1 `event_bus.dart`

```dart
class GameEvent {
  final EventKind kind;
  final String sourceEntityId;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
}

class EventBus {
  final StreamController<GameEvent> _controller = StreamController.broadcast();
  final RuleEngineV3 _engine;
  final int _maxCascadeDepth;

  Stream<GameEvent> get stream => _controller.stream;

  void emit(GameEvent event, {int cascadeDepth = 0}) {
    if (cascadeDepth >= _maxCascadeDepth) {
      // log warning, drop event
      return;
    }

    _controller.add(event);

    final result = _engine.evaluateEvent(
      kind: event.kind,
      entity: _resolveEntity(event.sourceEntityId),
      payload: event.payload,
      allEntities: _allEntities,
      category: _categoryOf(event.sourceEntityId),
    );

    // Apply mutations to entity state (via repository)
    _applyMutations(event.sourceEntityId, result);

    // Cascade: emit events generated by this rule
    for (final next in result.cascadedEvents) {
      emit(GameEvent(kind: next, ...), cascadeDepth: cascadeDepth + 1);
    }
  }
}
```

### 5.2 Integration Points

- **onCreate**: Entity create edildiğinde `EntityRepository.save()` çağrısından sonra emit.
- **onLevelUp**: UI — XP threshold geçildiğinde user confirms → emit.
- **onLongRest**: UI — Rest dialog → emit.
- **onSpellCast**: Spell select widget → emit with `payload = {spell_id, slot_level}`.
- **onDamageTaken**: Encounter HP button (-X) → emit.
- **onAttackMade / onAttackHit**: D20 test service sonrası emit.

### 5.3 Event Log

UI'da `EventLog` widget — son N event'i gösterir (debugging + player recap). `EventBus.stream` dinler.

---

## 6. Faz 4 — Resource / Choice / Turn Managers

### 6.1 `resource_manager.dart`

```dart
class ResourceManager {
  ResourceState consume({
    required Entity entity,
    required String resourceKey,
    required int amount,
  }) {
    final state = entity.resources[resourceKey] ?? throw ResourceNotInitialized();
    if (state.current < amount) throw InsufficientResource(resourceKey);
    return state.copyWith(current: state.current - amount);
  }

  ResourceState refresh({
    required Entity entity,
    required String resourceKey,
    double? fraction,
    int? amount,
  }) {
    final state = entity.resources[resourceKey];
    if (state == null) return ResourceState(resourceKey: resourceKey);
    if (fraction != null) {
      final add = (state.max * fraction).ceil();
      return state.copyWith(current: (state.current + add).clamp(0, state.max));
    }
    if (amount != null) {
      return state.copyWith(current: (state.current + amount).clamp(0, state.max));
    }
    return state.copyWith(current: state.max); // full
  }

  Map<String, ResourceState> initializeFromRules({
    required Entity entity,
    required RuleEvaluationResultV3 result,
  }) {
    // Merge entity.resources with result.computedResources
    // Preserve current values; update max
  }
}
```

### 6.2 `choice_manager.dart`

```dart
class ChoiceManager {
  ChoiceState record({
    required Entity entity,
    required String choiceKey,
    required dynamic value,
    required String sourceRuleId,
  }) => ChoiceState(
    choiceKey: choiceKey,
    chosenValue: value,
    sourceRuleId: sourceRuleId,
  );

  Future<dynamic> promptUser({
    required BuildContext context,
    required ChoicePrompt prompt,
  }) {
    // show bottom sheet / dialog with options
    // return selected value
  }
}
```

### 6.3 `turn_manager.dart`

```dart
class TurnManager {
  TurnState advance({required TurnState current}) {
    // reset action/bonus/reaction, increment turn index, new round if loop
  }

  void markAction({required ActionType type, required TurnState state}) { ... }
}
```

---

## 7. Faz 5 — D20 Test + Damage Pipeline

### 7.1 `d20_test_service.dart`

```dart
class D20TestResult {
  final int d20Roll;
  final int total;
  final bool advantage;
  final bool disadvantage;
  final bool critical;
  final bool success;
  final List<String> appliedBonuses;
}

class D20TestService {
  D20TestResult rollTest({
    required Entity entity,
    required D20TestType type,
    String? ability,
    String? skill,
    int? dc,
    required TurnState? turnState,
  }) {
    // 1. Evaluate d20 rules for this test
    final ruleResult = _engine.evaluateD20Test(
      entity: entity,
      testType: type,
      ability: ability,
      skill: skill,
      turnState: turnState,
    );

    // 2. Determine advantage
    final hasAdv = ruleResult.advantages.isNotEmpty;
    final hasDisadv = ruleResult.disadvantages.isNotEmpty;
    final netAdv = hasAdv && !hasDisadv;
    final netDisadv = hasDisadv && !hasAdv;

    // 3. Roll d20 (1 or 2 dice)
    final roll1 = _dice.roll('1d20');
    final roll2 = (netAdv || netDisadv) ? _dice.roll('1d20') : null;
    final d20 = roll2 == null ? roll1
              : netAdv ? max(roll1, roll2) : min(roll1, roll2);

    // 4. Critical check
    final critMin = ruleResult.criticalRangeMin ?? 20;
    final isCrit = d20 >= critMin;

    // 5. Total = d20 + ability_mod + prof + misc
    final total = d20 + _computeModifier(entity, type, ability, skill, ruleResult);

    // 6. Success
    final success = dc != null ? total >= dc : (isCrit ? true : null);

    // 7. Emit events
    _eventBus.emit(GameEvent(kind: EventKind.onAttackMade, payload: {...}));
    if (isCrit) _eventBus.emit(GameEvent(kind: EventKind.onCriticalHit, ...));
    if (success == true) _eventBus.emit(GameEvent(kind: EventKind.onAttackHit, ...));

    return D20TestResult(...);
  }
}
```

### 7.2 `damage_pipeline.dart`

```dart
class DamagePipeline {
  DamageApplyResult apply({
    required Entity target,
    required int amount,
    required String damageTypeId,
    Entity? attacker,
    bool isCritical = false,
  }) {
    var actualAmount = amount;

    // 1. Critical → double dice damage (caller handles dice; here 2x)
    if (isCritical) actualAmount *= 2;

    // 2. Evaluate damage trigger rules
    final ruleResult = _engine.evaluateDamage(target, damageTypeId, amount);

    // 3. Check immunity → 0
    if (ruleResult.immunities.contains(damageTypeId)) {
      return DamageApplyResult(amountApplied: 0, reason: 'Immune');
    }

    // 4. Check resistance → half
    if (ruleResult.resistances.contains(damageTypeId)) {
      actualAmount = actualAmount ~/ 2;
    }

    // 5. Check vulnerability → double
    if (ruleResult.vulnerabilities.contains(damageTypeId)) {
      actualAmount *= 2;
    }

    // 6. Temp HP absorb first
    final tempHp = target.fields['combat_stats']?['temp_hp'] ?? 0;
    final tempAbsorbed = min(tempHp, actualAmount);
    actualAmount -= tempAbsorbed;

    // 7. HP reduce
    final hp = target.fields['combat_stats']?['hp'] ?? 0;
    final newHp = max(0, hp - actualAmount);

    // 8. Emit events
    _eventBus.emit(GameEvent(kind: EventKind.onDamageTaken, payload: {
      'damage': actualAmount, 'type': damageTypeId,
    }));
    if (newHp == 0) _eventBus.emit(GameEvent(kind: EventKind.onHpZero, ...));

    // 9. Return mutation spec (caller applies via repo)
    return DamageApplyResult(
      newHp: newHp,
      newTempHp: tempHp - tempAbsorbed,
      amountApplied: actualAmount,
    );
  }
}
```

---

## 8. Faz 6 — UI

### 8.1 Rule Builder V3 (5 tab)

Mevcut `rule_builder_dialog.dart` 4-tab (Set/Gate/Equip/Style). Yeni V3 dialog:

```
Tab 1: Reactive      (always-on; V2 ile aynı: Set/Gate/Equip/Style)
Tab 2: Event         (event trigger + filter; effect seçimi genişletilmiş)
Tab 3: D20 Test      (advantage/disadvantage/critical-range)
Tab 4: Resource      (setResourceMax/consume/refresh)
Tab 5: Choice        (presentChoice)
```

Her tab kendi form state'ini tutar; Save'de `RuleV3` oluşturur.

### 8.2 Resource Widgets

```dart
class SpellSlotTracker extends StatelessWidget {
  final Entity entity;
  // Her level için: "1: [x][x][ ][ ]" — click to consume/refresh
}

class ClassResourceTracker extends StatelessWidget {
  final Entity entity;
  final String resourceKey;
  // Progress bar + +/- buttons
}

class ConcentrationIndicator extends StatelessWidget {
  final Entity entity;
  // Badge: "Concentrating on: Bless" + X button to drop
}
```

### 8.3 Character Sheet Integration

`template_editor.dart` içinde:
- `Abilities` group → computed modifiers read-only (Rule output)
- `Combat` group → computed AC/PP/DC read-only
- `Spellcasting` group → `SpellSlotTracker`
- `Features` group → `ClassResourceTracker` per resource
- Event buttons: "Short Rest", "Long Rest", "Level Up" → EventBus.emit

### 8.4 Rule Debugger

```
[ ] Show evaluation trace
Last evaluation (entity: Aragorn):
  ✓ str_mod = 3 (rule: ability_mod_str)
  ✓ proficiency_bonus = 3 (rule: pb_by_level, table[5]=3)
  ✓ passive_perception = 12 (rule: passive_perception)
     └ 10 + 1 (wis_mod) + 0 (no prof)
  ✗ heavy_armor_gate: STR 16 ≥ 15, passed
  ...
```

`RuleEngineV3.evaluateReactive`'in debug modu trace dump üretir.

---

## 9. Serialization

### 9.1 `RuleV3.toJson` / `fromJson`

Freezed otomatik üretir. Union type'lar `@Freezed(unionKey: 'type')` ile serialize.

### 9.2 Storage

`EntityCategorySchema`:
```
@RulesJsonConverter() @Default([]) List<RuleV2> rules;      // V2 — keep
@RulesV3JsonConverter() @Default([]) List<RuleV3> rulesV3;  // V3 — new
```

`Entity`:
```
@Default({}) Map<String, ResourceState> resources;
@Default({}) Map<String, ChoiceState> choices;
TurnState? turnState;
@Default([]) List<AppliedEffect> activeEffects;
```

Drift:
- `world_schemas_table.dart`: `rulesV3Json TEXT` column ekle (veya `categoriesJson` içinde zaten yazar).
- `entities_table.dart` (mevcut): `resourcesJson TEXT`, `choicesJson TEXT`, `turnStateJson TEXT`, `activeEffectsJson TEXT` column'lar ekle. Migration script yazılmalı:

```dart
@DriftDatabase(...)
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 4; // current +1

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 4) {
        await m.addColumn(entitiesTable, entitiesTable.resourcesJson);
        await m.addColumn(entitiesTable, entitiesTable.choicesJson);
        await m.addColumn(entitiesTable, entitiesTable.turnStateJson);
        await m.addColumn(entitiesTable, entitiesTable.activeEffectsJson);
      }
    },
  );
}
```

### 9.3 Supabase Cloud

`cloud_backups.sql` schema aynen kalır — JSON blob değişikliği. Yeni backup'larda V3 field'lar, eski backup'lar restore edildiğinde empty default ile yüklenir.

---

## 10. Provider Entegrasyonu (Riverpod)

### 10.1 `rule_engine_v3_provider.dart`

```dart
final ruleEngineV3Provider = Provider<RuleEngineV3>((ref) {
  return RuleEngineV3(
    predicateEvaluator: PredicateEvaluator(),
    expressionEvaluator: ExpressionEvaluator(ref.watch(diceRollerProvider)),
    effectApplier: EffectApplier(),
  );
});

final entityEvaluationProvider = FutureProvider.family<RuleEvaluationResultV3, String>(
  (ref, entityId) async {
    final engine = ref.watch(ruleEngineV3Provider);
    final entity = await ref.watch(entityProvider(entityId).future);
    final category = await ref.watch(categoryProvider(entity.categorySlug).future);
    final all = await ref.watch(allEntitiesProvider.future);
    return engine.evaluateReactive(
      entity: entity, category: category, allEntities: all,
    );
  },
);
```

### 10.2 `event_bus_provider.dart`

```dart
final eventBusProvider = Provider<EventBus>((ref) {
  return EventBus(
    engine: ref.watch(ruleEngineV3Provider),
    entityRepo: ref.watch(entityRepositoryProvider),
  );
});

final eventLogProvider = StreamProvider<List<GameEvent>>((ref) {
  final bus = ref.watch(eventBusProvider);
  return bus.stream.bufferLast(50);
});
```

### 10.3 UI Tüketim

```dart
Widget build(BuildContext context, WidgetRef ref) {
  final evalAsync = ref.watch(entityEvaluationProvider(widget.entityId));
  return evalAsync.when(
    data: (result) => Column(children: [
      Text('PP: ${result.computedValues['passive_perception']}'),
      Text('AC: ${result.computedValues['combat_stats.ac']}'),
      // ...
    ]),
    loading: () => const CircularProgressIndicator(),
    error: (e, _) => Text('Rule error: $e'),
  );
}
```

---

## 11. SRD Seed Rules — `default_dnd5e_rules_v3.dart`

60+ rule'u kategorize helper fonksiyonları ile üretir:

```dart
class Dnd5eRulesV3 {
  static List<RuleV3> forPlayerCategory() => [
    ..._abilityModifierRules(),        // 6 rule
    _proficiencyBonusRule(),           // 1
    _totalLevelRule(),                 // 1
    _passivePerceptionRule(),
    _passiveInvestigationRule(),
    _passiveInsightRule(),
    _spellSaveDcRule(),
    _spellAttackBonusRule(),
    ..._acRules(),                     // 5
    _hpMaxRule(),
    ..._savingThrowBonusRules(),       // 6
    ..._skillBonusRules(),             // 18
    _carryingCapacityRule(),
    _attunementCapRule(),
    _styleCursedItemRule(),
    _styleUnpreparedSpellRule(),
    _styleRequiredAttunementRule(),
  ];

  static List<RuleV3> forPlayerEvents() => [
    _onCreateInitRule(),
    _onLevelUpHpRule(),
    _onLongRestRule(),
    _onShortRestRule(),
    _onSpellCastConsumeSlotRule(),
    _onDamageTakenConcentrationSaveRule(),
    _onHpZeroDeathSaveRule(),
    // ...
  ];

  static List<RuleV3> forPlayerD20Tests() => [
    _poisonedDisadvantageRule(),
    _frightenedDisadvantageRule(),
    _armorTrainingMissingDisadvantageRule(),
    _rageStrAdvantageRule(),
    // ...
  ];

  // Private builders:

  static RuleV3 _proficiencyBonusRule() => RuleV3(
    ruleId: 'rule_pb_by_level',
    name: 'Proficiency Bonus',
    trigger: const RuleTrigger.always(),
    when_: const PredicateV3.always(),
    then_: RuleEffectV3.setValue(
      targetFieldKey: 'proficiency_bonus',
      value: ValueExpressionV3.tableLookup(
        table: ValueExpressionV3.literal(kPbByLevel),
        key: ValueExpressionV3.fieldValue(
          FieldRef(scope: RefScope.self, fieldKey: 'total_level')),
      ),
    ),
  );

  // ... diğer rule'lar
}
```

Her kategori için `generateDefaultDnd5eSchemaV3()` builder içinde `rulesV3: Dnd5eRulesV3.forPlayerCategory() + forPlayerEvents() + forPlayerD20Tests()`.

---

## 12. Test Stratejisi

### 12.1 Unit Test Örnekleri

```dart
// rule_engine_v3_test.dart
test('STR 16 → str_mod = 3', () {
  final entity = Entity(
    id: 'pc', categorySlug: 'player',
    fields: {'stat_block': {'STR': 16}},
  );
  final result = engine.evaluateReactive(
    entity: entity, category: testCategory, allEntities: {},
  );
  expect(result.computedValues['str_mod'], 3);
});

test('Level 5 → PB 3', () {
  final entity = Entity(id: 'pc', categorySlug: 'player',
    fields: {'total_level': 5});
  final result = engine.evaluateReactive(...);
  expect(result.computedValues['proficiency_bonus'], 3);
});

test('Attunement 3 items → 4th blocked', () {
  final entity = Entity(id: 'pc', fields: {
    'attunements': [ref1, ref2, ref3]
  });
  final result = engine.evaluateEvent(
    kind: EventKind.onAttune,
    entity: entity,
    payload: {'new_item_id': 'item4'},
  );
  expect(result.equipGates['item4'], contains('3 items'));
});

test('Long rest refreshes spell slots', () {
  final entity = Entity(
    resources: {
      'spell_slot_1': ResourceState(max: 4, current: 1),
    },
  );
  final result = engine.evaluateEvent(kind: EventKind.onLongRest, entity: entity);
  expect(result.computedResources['spell_slot_1']?.current, 4);
});

test('Poisoned disadvantage on attack', () {
  final entity = Entity(activeEffects: [AppliedEffect(
    conditionId: 'condition-poisoned'
  )]);
  final result = engine.evaluateD20Test(
    entity: entity,
    testType: D20TestType.attackRoll,
  );
  expect(result.disadvantages, isNotEmpty);
});
```

### 12.2 Integration Test — SRD Scenarios

```dart
// test/integration/srd_scenarios_test.dart

testWidgets('Create Fighter L5, equip Plate, expected AC 18', (tester) async {
  // 1. Open app, new campaign
  // 2. Create PC, Fighter L5, STR 16 DEX 14 CON 14
  // 3. Add Plate Armor to equipment, equip
  // 4. Verify combat_stats.ac = 18 (plate 18 + 0 dex cap)
});

testWidgets('Wizard L5 cast Fireball, slot consumed', (tester) async {
  // 1. Create Wizard L5, INT 18
  // 2. Verify spell_save_dc = 15 (8 + 3 PB + 4 INT)
  // 3. Emit onSpellCast event with Fireball (level 3, slot 3)
  // 4. Verify spell_slot_3.current -1
});

testWidgets('Barbarian Rage damage bonus', (tester) async {
  // 1. Create Barbarian L3, STR 16
  // 2. Activate Rage (consume rage_uses -1)
  // 3. Roll attack with Greataxe + hit
  // 4. Verify damage includes +2 rage bonus
});
```

### 12.3 Golden Test — Serialization

```dart
test('RuleV3 JSON round-trip', () {
  final rule = Dnd5eRulesV3.forPlayerCategory().first;
  final json = rule.toJson();
  final restored = RuleV3.fromJson(json);
  expect(restored, rule);
});
```

---

## 13. Rollout Plan

### 13.1 Feature Flag

```dart
class FeatureFlags {
  static bool ruleEngineV3 = false;  // default off
}
```

- Faz 1-4 merged ama `ruleEngineV3 = false`.
- Internal testing: flag true.
- Faz 5-6 + test coverage tamamlanınca flag default on.
- 1 sürüm sonra flag kaldır, V2 engine deprecated.

### 13.2 Template Dual Support

- Eski `builtin-dnd5e-default` (originalHash v1) → V2 rules → V3 engine V2 adapter ile çalıştırır.
- Yeni `builtin-dnd5e-srd-v5.2.1` (originalHash yeni) → V3 rules → native.

Kullanıcı Template Marketplace'ten yeni template'i seçtiğinde, mevcut kampanyası V2 kalır (opsiyonel migration wizard).

### 13.3 Migration Wizard (opsiyonel, faz 7)

"Kampanyanı SRD 5.2.1 template'ine yükselt" butonu:
1. Entity field'larını map'le (eski slug → yeni slug)
2. Rule'ları upgrade (V2 → V3 adapter)
3. Resource'ları başlat (onCreate event trigger)
4. Kullanıcı onayı + rollback

---

## 14. Risk ve Azaltma

| Risk | Olasılık | Etki | Azaltma |
|------|----------|------|---------|
| V3 evaluator performance (60+ rule × entity) | Orta | Orta | Memoization + dirty flag + batched eval |
| JSON schema değişikliği legacy kampanya'yı kırar | Düşük | Yüksek | V2 keep + adapter + feature flag |
| Event cascade sonsuz loop | Düşük | Orta | `MAX_CASCADE_EVENTS = 50` + loop detection |
| Freezed + union codegen karmaşıklığı | Orta | Düşük | İlk faz core model + codegen validation test |
| UI rule builder V3 karmaşıklığı | Yüksek | Orta | Wizard tarzı adımlı UI; JSON view fallback |
| Çoklu entity evaluation N² scaling | Orta | Orta | Provider family + cache invalidation scope |
| Dice roll determinizmi test'te | Düşük | Orta | `DiceRoller` interface, test'te `SeededDiceRoller` |

---

## 15. Acceptance Kriterleri (her faz için)

### Faz 1 (Domain Model)
- [ ] `RuleV3` + tüm sealed class'lar freezed + toJson/fromJson
- [ ] `Entity` yeni alanları + migration backward compat
- [ ] Unit test: JSON round-trip her tip için
- [ ] Lint clean, build passes

### Faz 2 (Engine + Adapter)
- [ ] `RuleEngineV3.evaluateReactive` tüm reactive rule tipleri için çalışır
- [ ] V2 → V3 adapter, mevcut V2 rule seed'leri için eşdeğer sonuç verir
- [ ] Unit test: 95% predicate/expression/effect coverage
- [ ] Mevcut V2 test suite regresyonsuz geçer

### Faz 3 (Event Bus)
- [ ] `EventBus.emit` cascade safe, depth limitli
- [ ] Event rules 10+ senaryoda çalışır (onLongRest, onSpellCast, vb.)
- [ ] Integration test: full rest cycle

### Faz 4 (Resource / Choice / Turn)
- [ ] Spell slot consume + refresh
- [ ] Concentration break on new spell
- [ ] Exhaustion level stacking
- [ ] Choice prompt UI

### Faz 5 (D20 + Damage)
- [ ] Advantage/disadvantage resolution
- [ ] Critical range modification
- [ ] Damage pipeline: resistance/vulnerability/immunity
- [ ] Concentration damage save

### Faz 6 (UI + Seed)
- [ ] Rule builder v3 dialog 5 tab
- [ ] Resource tracker widgets (spell slot, hit dice, class resource)
- [ ] Rule debugger trace mode
- [ ] `default_dnd5e_schema_v3.dart` 60+ rule seeded
- [ ] SRD scenarios test: Fighter/Wizard/Barbarian end-to-end

---

## 16. Key File Skeleton Önerisi

Geliştirmeye başlarken ilk yazılacak 5 dosya (sıralı):

### 16.1 `rule_v3.dart` (faz 1, gün 1)
Minimal freezed class — trigger always, predicate always, effect setValue. Compile-able baseline.

### 16.2 `rule_predicates_v3.dart` (faz 1, gün 2-3)
V2'den kopyala + yeni 8 tip ekle. Her tip için ayrı freezed factory.

### 16.3 `rule_expressions_v3.dart` (faz 1, gün 4-5)
V2'den kopyala + yeni 11 tip ekle. Recursive — dikkatli.

### 16.4 `rule_effects_v3.dart` (faz 1, gün 6-7)
V2'den kopyala + yeni 14 tip ekle. `CompositeEffect` + `ConditionalEffect` özel dikkat.

### 16.5 `rule_engine_v3.dart` (faz 2, hafta 2)
İlk versiyon: yalnız `evaluateReactive`, trigger filter yok (always varsay). Adapter sonra eklenir.

Bu 5 dosya tamamlandığında faz 1 biter, faz 2'ye geçilebilir.

---

## 17. Özet

| Metric | Değer |
|--------|-------|
| Yeni dosya sayısı | ~30 |
| Değiştirilecek mevcut dosya | 4 |
| Yeni domain tip | ~50 (freezed classes + enums) |
| Yeni servis | 8 |
| Yeni provider | 3 |
| Yeni UI widget | ~10 |
| Test dosyası | ~8 |
| Tahmini LOC | ~6000 (kod) + ~3000 (test) |
| Toplam faz süresi | 8 hafta (tek geliştirici) / 4 hafta (iki geliştirici paralel) |

Bu kılavuz, V3 rule engine'i mevcut altyapıyı bozmadan kademeli olarak inşa etmek için somut yol haritasıdır. Her faz bağımsız merge edilebilir ve feature flag ile production'a izole edilir.
