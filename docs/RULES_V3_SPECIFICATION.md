# Rule System V3 — Sıfırdan Spesifikasyon

D&D 5e SRD 5.2.1'in **tüm** oyun mekaniklerini veri-odaklı (declarative) şekilde ifade edebilen rule engine'in sıfırdan tasarımı. Mevcut `RuleV2` ([rule_v2.dart](../flutter_app/lib/domain/entities/schema/rule_v2.dart)) altyapısı SRD kapsamının ~40%'ını karşılıyor. V3, kalan 60%'ı (event model, resource tracking, choice state, advantage/disadvantage, conditional expression, AoE, concentration, rest mechanics vb.) ekliyor.

Bu döküman yalnızca **tasarım ve JSON grammar**. Kod tarafına uygulama için [RULES_V3_IMPLEMENTATION_GUIDE.md](RULES_V3_IMPLEMENTATION_GUIDE.md). Uygulanan template için [SRD_TEMPLATE_APPLICATION.md](SRD_TEMPLATE_APPLICATION.md).

---

## 1. Motivasyon — Neden V3?

### V2 eksiklikleri (SRD uygulamasında ortaya çıkan)

| Mekanik | V2 durum | Problem |
|---------|----------|---------|
| Ability modifier (floor((score-10)/2)) | `ValueExpression.modifier` ✓ | — |
| PB by level | `tableLookup` ✓ | — |
| Passive Perception (10 + WIS + PB if prof) | **Kısıtlı** | Conditional expression yok (if/else). Workaround: iki rule + priority. |
| Spell Slots by class level | `tableLookup` ✓ | Multiclass toplama desteği kısıtlı (aggregate var ama nested lookup karmaşık). |
| Advantage/Disadvantage | **Yok** | D20 test context'i yok. |
| Armor training missing | gateEquip ✓ | Soft-penalty (Disadvantage on STR/DEX) ifade edilemiyor. |
| Attunement cap (3) | `compare` ✓ ama count() yok | List length fonksiyonu yok. |
| Concentration (single slot) | **Yok** | Resource tracking yok. |
| Spell slot consume on cast | **Yok** | Event model yok. |
| Hit dice / rage uses / channel divinity | **Yok** | Resource pool yok. |
| Rest mechanics (short/long recovery) | **Yok** | Event yok. |
| Choice state (player picks Drow lineage) | **Yok** | User-choice snapshot yok. |
| Feature unlocked at level N | **Yok** | Level-gated rule set yok. |
| Multiclass primary ability gate | `compare` ✓ | — |
| Area of Effect spell | **Yok** | Spatial reasoning yok (çoğunlukla narrative). |
| Damage resistance application | **Yok** | Combat damage flow event yok. |
| Death saves, stabilize | **Yok** | HP=0 event yok. |
| Critical hit damage doubling | **Yok** | Roll context yok. |
| Carrying capacity / encumbered | `arithmetic` ✓ | — |
| Two-weapon fighting eligibility | **Yok** | Turn-state yok (ilk attack yapıldı mı). |
| Counterspell / Reaction trigger | **Yok** | Reaction framework yok. |
| Initiative roll with bonus | `arithmetic` ✓ | Encounter entegrasyonu ayrı. |

### V3 hedefleri

1. **Geriye uyumluluk**: V2 RuleV2 JSON'ları V3 engine'de aynen çalışır (adapter layer).
2. **Tam SRD coverage**: Tüm 5e Core mekaniği ifade edilebilir.
3. **Event-driven**: `on_level_up`, `on_short_rest`, `on_long_rest`, `on_spell_cast`, `on_attack`, `on_damage_dealt`, `on_damage_taken`, `on_turn_start`, `on_turn_end` vb.
4. **Resource tracking**: Spell slots, hit dice, class uses (rage, channel divinity, bardic inspiration), charges, concentration slot.
5. **Choice state**: Player seçimleri kalıcı ve rule context'te erişilebilir.
6. **Conditional expression**: If/else expression tree.
7. **Turn context**: D20 test state, advantage/disadvantage, critical.
8. **Determinism**: Aynı state + rule seti → aynı sonuç (seed tabanlı rastgelelik opsiyonel).
9. **Sandbox**: Rule evaluation infinite loop'tan korumalı (depth + iteration cap).

---

## 2. Kavramsal Model

### 2.1 Üç Katmanlı Rule

```
┌─────────────────────────────────────────────────┐
│ REACTIVE RULES   (always-on, evaluated on read) │
│ — modifier/AC/DC/passive hesaplamaları          │
│ — styleItems (cursed, unprepared, faded)        │
│ — gateEquip (attunement cap, armor req)         │
├─────────────────────────────────────────────────┤
│ EVENT RULES      (fired on events)              │
│ — on_level_up: grant class features              │
│ — on_long_rest: recover spell slots, hit dice    │
│ — on_spell_cast: consume slot, break concentr.  │
│ — on_damage_taken: check resistance/immune      │
├─────────────────────────────────────────────────┤
│ CONDITIONAL RULES (evaluated in turn context)   │
│ — advantage/disadvantage granting                │
│ — critical range modification (19-20)            │
│ — weapon mastery property activation             │
└─────────────────────────────────────────────────┘
```

### 2.2 Kavramlar

- **Entity**: Runtime instance (PC, NPC, Monster, Item, …).
- **Context**: Rule evaluation'ın olduğu an — state + trigger + ilgili entity'ler.
- **State**: Entity.fields + Entity.resources + Entity.choices + Entity.turnState.
- **Rule**: `(trigger, when, then)` tuple.
- **Trigger**: `always` (reactive), `event:<name>` (event), `d20_test` (conditional).
- **Predicate**: Bool expression (V2 ile aynı primitives + yeni).
- **Expression**: Value-producing tree (V2 + conditional + list ops + string).
- **Effect**: State mutation veya context contribution.

---

## 3. Entity Model Genişletme

### 3.1 `Entity` — yeni alanlar

```dart
@freezed
class Entity {
  // MEVCUT
  String id;
  String name;
  String categorySlug;
  Map<String, dynamic> fields;         // field data

  // YENİ — V3
  Map<String, ResourceState> resources;  // kaynaklar
  Map<String, ChoiceState> choices;      // kullanıcı seçimleri
  TurnState? turnState;                   // combat içindeyse
  List<AppliedEffect> activeEffects;      // geçici modifier'lar
}
```

### 3.2 `ResourceState`

```dart
class ResourceState {
  String resourceKey;        // 'spell_slot_1', 'hit_dice_d10', 'rage_uses', 'channel_divinity', 'concentration'
  int current;               // kullanılmamış miktar
  int max;                   // tavan (rule-computed)
  int expended;              // kullanılmış = max - current
  RefreshRule refreshRule;   // ne zaman yenilenir
}

enum RefreshRule { never, shortRest, longRest, dawn, turn, custom }
```

Örnekler:
- `spell_slot_1` — max=4, current=2 (2 used), refresh=longRest
- `hit_dice_d10` — max=5, current=3 (2 spent on SR), refresh=longRest (half recovery)
- `rage_uses` — max=3 (Barbarian L3), refresh=longRest
- `concentration` — max=1, current=0 or 1, refresh=never (replaced on new cast)
- `attunement` — max=3, current=count(attunements list)

### 3.3 `ChoiceState`

```dart
class ChoiceState {
  String choiceKey;          // 'species_lineage', 'fighting_style', 'expertise_skills'
  dynamic chosenValue;       // id or list of ids
  String sourceRuleId;       // hangi rule bu seçimi istedi
}
```

Örnek:
- `species_lineage` → `lineage-high-elf`
- `fighter_style` → `feat-archery`
- `rogue_expertise_2` → `['skill-stealth', 'skill-thieves-tools']`

### 3.4 `TurnState` (encounter içinde)

```dart
class TurnState {
  String entityId;
  int roundNumber;
  int initiativeOrder;

  // action economy
  bool actionUsed;
  bool bonusActionUsed;
  bool reactionUsed;
  int movementUsed;

  // d20 context
  List<AdvantageSource> advantageSources;
  List<AdvantageSource> disadvantageSources;
  int criticalRangeMin;      // default 20; Champion L3 = 19

  // attack flow
  int attacksThisTurn;
  bool firstAttackMade;      // TWF, Crossbow Expert
}
```

### 3.5 `AppliedEffect`

Geçici modifier (spell, condition):

```dart
class AppliedEffect {
  String effectId;
  String sourceId;           // spell/action/magic-item id
  String targetField;        // 'combat_stats.ac', 'str_mod'
  ValueExpression modifier;  // +2
  DurationSpec duration;     // rounds / minutes / hours / concentration / permanent
  int? remainingTurns;
  bool requiresConcentration;
}
```

---

## 4. Rule Schema V3

### 4.1 Üst seviye

```dart
@freezed
class RuleV3 {
  String ruleId;
  String name;
  String description;
  bool enabled;
  int priority;              // ascending execution

  RuleTrigger trigger;       // NEW — always / event / d20_test / damage_apply ...
  Predicate when_;           // same as V2 but richer
  RuleEffectV3 then_;        // expanded effect set

  RuleScope scope;           // NEW — where this rule lives
  List<RuleDependency>? dependsOn;  // NEW — other rules it reads (topological order)
}
```

### 4.2 `RuleTrigger`

```dart
@Freezed(unionKey: 'type')
sealed class RuleTrigger {
  factory RuleTrigger.always() = AlwaysTrigger;

  factory RuleTrigger.event({
    required EventKind event,
    Predicate? filter,       // opsiyonel pre-filter
  }) = EventTrigger;

  factory RuleTrigger.d20Test({
    required D20TestType testType,      // ability_check, saving_throw, attack_roll
    String? abilityFilter,              // 'STR', 'DEX' vs.
    String? skillFilter,                // 'stealth'
    String? saveAgainstFilter,          // condition save
  }) = D20Trigger;

  factory RuleTrigger.damageApply({
    String? damageTypeFilter,
    DamageDirection direction,          // taken / dealt
  }) = DamageTrigger;

  factory RuleTrigger.turnPhase({
    TurnPhase phase,         // start / end / before_attack / after_attack
  }) = TurnTrigger;
}

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

enum D20TestType { abilityCheck, savingThrow, attackRoll, initiative }
enum DamageDirection { taken, dealt }
enum TurnPhase { start, end, beforeAttack, afterAttack, beforeSave, afterSave }
```

### 4.3 Yeni `Predicate` primitifleri

V2'nin predicate set'ine ek:

```dart
sealed class Predicate {
  // V2 mevcut: compare, and, or, not, always
  ...

  // V3 yeni:
  factory Predicate.listLengthCompare({
    required FieldRef list,
    required CompareOp op,
    required int value,
  }) = ListLengthPredicate;

  factory Predicate.resourceCompare({
    required String resourceKey,
    required ResourceField field,  // current / max / expended
    required CompareOp op,
    required int value,
  }) = ResourcePredicate;

  factory Predicate.hasChoice({
    required String choiceKey,
    String? expectedValue,
  }) = HasChoicePredicate;

  factory Predicate.hasCondition({
    required String conditionId,
    int? minLevel,              // exhaustion
  }) = HasConditionPredicate;

  factory Predicate.hasFeature({
    required String featureId,  // feat/trait id
  }) = HasFeaturePredicate;

  factory Predicate.inTurnPhase({
    required TurnPhase phase,
  }) = TurnPhasePredicate;

  factory Predicate.actionAvailable({
    required ActionType action,  // action / bonus / reaction
  }) = ActionAvailablePredicate;

  factory Predicate.entityLevel({
    required CompareOp op,
    required int level,
    String? classFilter,        // class-specific level
  }) = LevelPredicate;

  factory Predicate.contextMatches({
    required String contextKey, // 'trigger.damage_type', 'trigger.attacker_id'
    required dynamic value,
  }) = ContextPredicate;
}
```

### 4.4 Yeni `ValueExpression` primitifleri

V2'nin expression set'ine ek:

```dart
sealed class ValueExpression {
  // V2: literal, fieldValue, aggregate, arithmetic, tableLookup, modifier
  ...

  // V3 yeni:
  factory ValueExpression.ifThenElse({
    required Predicate condition,
    required ValueExpression then_,
    required ValueExpression else_,
  }) = IfThenElseExpr;

  factory ValueExpression.listLength(FieldRef list) = ListLengthExpr;

  factory ValueExpression.listFilter({
    required FieldRef list,
    required Predicate filter,
    required AggregateOp op,
    String? sourceFieldKey,
  }) = ListFilterExpr;

  factory ValueExpression.min(List<ValueExpression> values) = MinExpr;
  factory ValueExpression.max(List<ValueExpression> values) = MaxExpr;
  factory ValueExpression.clamp({
    required ValueExpression value,
    required ValueExpression minValue,
    required ValueExpression maxValue,
  }) = ClampExpr;

  factory ValueExpression.dice({
    required String notation,     // "2d6+3"
    ValueExpression? bonus,
    bool average,                  // true: use average, false: roll (needs rand context)
  }) = DiceExpr;

  factory ValueExpression.stringFormat({
    required String template,     // "Need STR {0} to equip"
    required List<ValueExpression> args,
  }) = StringFormatExpr;

  factory ValueExpression.resourceValue({
    required String resourceKey,
    required ResourceField field,
  }) = ResourceExpr;

  factory ValueExpression.choice({
    required String choiceKey,
    ValueExpression? fallback,
  }) = ChoiceExpr;

  factory ValueExpression.contextValue(String contextKey) = ContextExpr;
  // 'trigger.spell_level', 'trigger.damage_amount', 'turn.round_number'

  factory ValueExpression.levelInClass(String classId) = LevelInClassExpr;
  factory ValueExpression.totalLevel() = TotalLevelExpr;
  factory ValueExpression.proficiencyBonus() = PBExpr;  // shortcut
}

enum ResourceField { current, max, expended }
```

### 4.5 Yeni `RuleEffectV3`

V2'nin effect set'ine ek:

```dart
sealed class RuleEffectV3 {
  // V2: setValue, gateEquip, modifyWhileEquipped, styleItems
  ...

  // V3 yeni:
  factory RuleEffectV3.setResourceMax({
    required String resourceKey,
    required ValueExpression value,
    required RefreshRule refreshRule,
  }) = SetResourceMaxEffect;

  factory RuleEffectV3.consumeResource({
    required String resourceKey,
    required ValueExpression amount,
    bool blockIfInsufficient,
  }) = ConsumeResourceEffect;

  factory RuleEffectV3.refreshResource({
    required String resourceKey,
    ValueExpression? amount,       // null = full
    double? fraction,              // 0.5 = half (hit dice on long rest)
  }) = RefreshResourceEffect;

  factory RuleEffectV3.grantFeature({
    required String featureId,
    String? source,                // 'class:fighter:level_2'
  }) = GrantFeatureEffect;

  factory RuleEffectV3.revokeFeature({
    required String featureId,
  }) = RevokeFeatureEffect;

  factory RuleEffectV3.applyCondition({
    required String conditionId,
    DurationSpec? duration,
    ValueExpression? saveDC,
    String? saveAbility,
  }) = ApplyConditionEffect;

  factory RuleEffectV3.removeCondition({
    required String conditionId,
  }) = RemoveConditionEffect;

  factory RuleEffectV3.grantAdvantage({
    required AdvantageScope scope,
    required String? filter,       // skill/ability/save type
  }) = GrantAdvantageEffect;

  factory RuleEffectV3.grantDisadvantage({
    required AdvantageScope scope,
    required String? filter,
  }) = GrantDisadvantageEffect;

  factory RuleEffectV3.modifyCriticalRange({
    required int newMinRange,      // Champion L3 → 19
  }) = ModifyCriticalRangeEffect;

  factory RuleEffectV3.modifyDamageRoll({
    required DamageModOp op,       // add, multiply, halve, negate, reroll1s, minimumDie
    required ValueExpression value,
  }) = DamageRollEffect;

  factory RuleEffectV3.modifyAttackRoll({
    required ValueExpression bonus,
  }) = AttackRollEffect;

  factory RuleEffectV3.grantTempHp({
    required ValueExpression amount,
  }) = TempHpEffect;

  factory RuleEffectV3.heal({
    required ValueExpression amount,
    String? targetField,            // 'combat_stats.hp'
  }) = HealEffect;

  factory RuleEffectV3.applyEffect({
    required AppliedEffect effect,
  }) = ApplyAppliedEffectEffect;

  factory RuleEffectV3.breakConcentration() = BreakConcentrationEffect;

  factory RuleEffectV3.grantAction({
    required String actionId,
    required ActionType type,      // bonus_action / reaction
  }) = GrantActionEffect;

  factory RuleEffectV3.presentChoice({
    required String choiceKey,
    required List<ChoiceOption> options,
    bool required,
  }) = PresentChoiceEffect;

  factory RuleEffectV3.composite(List<RuleEffectV3> effects) = CompositeEffect;

  factory RuleEffectV3.conditional({
    required Predicate condition,
    required RuleEffectV3 then_,
    RuleEffectV3? else_,
  }) = ConditionalEffect;
}

enum AdvantageScope { attackRoll, savingThrow, abilityCheck, d20Test }
enum DamageModOp { add, multiply, halve, negate, minimumDieOf, rerollBelow }
enum ActionType { action, bonusAction, reaction, free, legendary, lair }

class ChoiceOption {
  String id;
  String label;
  dynamic value;
  Predicate? prerequisite;
}
```

---

## 5. Evaluation Pipeline

### 5.1 Reactive Evaluation (her entity read'te)

```
1. collect all RuleV3 with trigger=always for entity.category
2. topological sort by dependsOn + priority
3. for each rule:
   a. evaluate when_ predicate in context(entity, state)
   b. if true → apply then_ effect
4. compose:
   - computedValues map
   - equipGates map
   - itemStyles map
   - equippedModifiers map
   - grantedAdvantages list
   - activeConditions list
   - currentResourceMaxes
```

### 5.2 Event Dispatch

```
emitEvent(kind, payload) →
  1. find rules with trigger=event(kind) for affected entities
  2. optional filter predicate
  3. evaluate in priority order
  4. apply effects atomically (batched mutation)
  5. re-evaluate reactive rules (state changed)
  6. emit downstream events (cascading; depth-limited)
```

### 5.3 D20 Test Context

```
rollD20Test(entity, testType, ability, skill?, dc?) →
  1. collect rules with trigger=d20_test matching filters
  2. gather advantageSources + disadvantageSources
  3. net advantage: adv XOR disadv (cancel on both)
  4. compute modifiers: ability_mod + PB (if prof) + misc + active effects
  5. roll (externally or simulated)
  6. check critical range
  7. result = {total, crit, success, advantage_applied, disadvantage_applied}
  8. emit events: onAttackMade / onAttackHit / onCriticalHit etc.
```

### 5.4 Damage Application Pipeline

```
applyDamage(target, amount, type, attacker) →
  1. check resistance/vulnerability/immunity rules
  2. apply multipliers (resistance=0.5 floor, vulnerability=2x)
  3. check temp_hp absorption
  4. subtract from hp
  5. if hp<=0: emit onHpZero
  6. if target was concentrating: trigger concentration save
  7. event cascade
```

### 5.5 Rest Mechanics

```
shortRest(entity) →
  emit onShortRest
  → rules with event=onShortRest execute:
    - refresh pact magic slots (Warlock)
    - refresh rage uses (Barbarian L_ — not standard)
    - refresh superiority dice (Battle Master)
    - optionally spend hit dice for healing (user interaction)

longRest(entity) →
  emit onLongRest
  → rules execute:
    - refresh all spell slots
    - refresh hit dice (half, round up)
    - refresh class uses (rage, channel divinity, lay on hands pool)
    - reset death saves
    - reduce exhaustion by 1
    - heal to max HP
```

---

## 6. SRD Mekanik Katalogu → RuleV3 Eşlemesi

### 6.1 Karakter Yaratma (SRD p.19)

| Mekanik | Rule yapısı |
|---------|-------------|
| Total level = sum(class_levels) | `always` → `setValue(total_level, arithmetic(sum over class_levels[].level))` |
| PB by total_level | `always` → `setValue(proficiency_bonus, tableLookup(kPBTable, total_level))` |
| XP → level up | `event:onCreate, always` → `setValue(level, tableLookup(kXPTable, xp))` — reverse |
| Starting HP | `event:onCreate` → `setResourceMax(hp, hit_die_max + con_mod)` |
| Level-up HP | `event:onLevelUp` → `setResourceMax(hp, prev_max + hit_die_avg + con_mod)` |

### 6.2 Six Abilities (SRD p.5)

```
for each ability in [STR, DEX, CON, INT, WIS, CHA]:
  RuleV3(
    ruleId: 'ability_mod_<ability>',
    trigger: always,
    when: always,
    then: setValue(
      target: '<ability>_mod',
      value: modifier(fieldValue(self, stat_block.<ability>)))
  )
```

### 6.3 Passive Perception (SRD p.22)

```
RuleV3(
  trigger: always,
  when: always,
  then: setValue(
    target: 'passive_perception',
    value: arithmetic(
      literal(10) +
      fieldValue(self, wis_mod) +
      ifThenElse(
        condition: hasChoice('skill_perception_proficient'),
        then: proficiencyBonus(),
        else: literal(0))))
)
```

### 6.4 Spell Save DC & Attack (SRD p.23)

```
spell_save_dc = 8 + PB + spellcasting_ability_mod
spell_attack_bonus = PB + spellcasting_ability_mod
```

Spellcasting ability → class'tan gelir:
```
spellcasting_ability_mod = ifThenElse(
  condition: hasFeature('class-wizard'),
  then: fieldValue(self, int_mod),
  else: ifThenElse(
    condition: hasFeature('class-cleric|druid|ranger'),
    then: fieldValue(self, wis_mod),
    ...))
```

### 6.5 AC (SRD p.22)

```
// 1. Base AC (no armor)
RuleV3(
  ruleId: 'ac_unarmored',
  trigger: always,
  when: listLengthCompare('equipped_armors', eq, 0),
  then: setValue('combat_stats.ac', arithmetic(literal(10) + dex_mod))
)

// 2. Light armor equipped
RuleV3(
  ruleId: 'ac_light',
  trigger: always,
  when: hasEquippedArmor(category='Light'),
  then: modifyWhileEquipped(
    targetFieldKey: 'combat_stats.ac',
    value: arithmetic(fieldValue(armor, base_ac) + dex_mod))
)

// 3. Medium armor (Dex cap 2)
RuleV3(
  ruleId: 'ac_medium',
  then: modifyWhileEquipped(
    value: arithmetic(base_ac + min(dex_mod, literal(2))))
)

// 4. Heavy armor (no Dex)
RuleV3(
  ruleId: 'ac_heavy',
  then: modifyWhileEquipped(
    value: fieldValue(armor, base_ac))
)

// 5. Shield +2
RuleV3(
  ruleId: 'ac_shield',
  when: hasEquippedArmor(category='Shield'),
  then: modifyWhileEquipped(value: literal(2))
)
```

### 6.6 Hit Points Max (SRD p.22)

```
RuleV3(
  trigger: always,
  when: always,
  then: setResourceMax(
    resourceKey: 'hp',
    refreshRule: longRest,
    value: sum over class_levels[], for each entry:
      (hit_die_max_of_class + con_mod)  // first level
      + (level - 1) × (hit_die_avg_of_class + con_mod)  // subsequent
  )
)
```

### 6.7 Saving Throws & Skills (SRD p.6)

Her save + skill için:
```
RuleV3(
  ruleId: 'save_bonus_<ability>',
  trigger: always,
  then: setValue(
    '<ability>_save_bonus',
    arithmetic(
      <ability>_mod +
      ifThenElse(hasChoice('save_prof_<ability>'), proficiencyBonus(), literal(0))))
)

RuleV3(
  ruleId: 'skill_bonus_<skill>',
  trigger: always,
  then: setValue(
    'skill_<skill>_bonus',
    arithmetic(
      <ability>_mod +
      ifThenElse(hasChoice('skill_prof_<skill>'),
        proficiencyBonus() × ifThenElse(hasChoice('skill_expertise_<skill>'), literal(2), literal(1)),
        literal(0))))
)
```

### 6.8 Advantage / Disadvantage (SRD p.7)

```
// Barbarian Rage — Advantage on STR checks & saves
RuleV3(
  ruleId: 'rage_str_advantage',
  trigger: d20Test(testType: savingThrow, abilityFilter: 'STR'),
  when: hasResource('rage', current > 0),  // rage active
  then: grantAdvantage(scope: savingThrow, filter: 'STR')
)

// Poisoned condition — Disadvantage on attack rolls & ability checks
RuleV3(
  ruleId: 'poisoned_disadv_attack',
  trigger: d20Test(testType: attackRoll),
  when: hasCondition('condition-poisoned'),
  then: grantDisadvantage(scope: attackRoll)
)

// Hide in Heavy Obscurement — Advantage on Stealth
// Pack Tactics (monster) — Advantage if ally within 5ft
```

### 6.9 Armor Training Missing (SRD p.92)

```
RuleV3(
  ruleId: 'armor_training_disadvantage',
  trigger: d20Test(testType: abilityCheck, abilityFilter: 'STR|DEX'),
  when: hasEquippedArmor AND armor.category NOT IN self.armor_training,
  then: grantDisadvantage(scope: d20Test, filter: 'STR|DEX')
)

RuleV3(
  ruleId: 'armor_training_no_spells',
  trigger: event:onSpellCast,
  when: hasEquippedArmor AND armor.category NOT IN self.armor_training,
  then: composite([
    // block or warn
    gateAction(action: 'magic', reason: 'Cannot cast spells without armor training')
  ])
)
```

### 6.10 Attunement Cap (SRD p.204)

```
RuleV3(
  ruleId: 'attunement_cap',
  trigger: event:onAttune,
  when: listLengthCompare('attunements', gte, 3),
  then: gateEquip(blockReason: 'Already attuned to 3 items.')
)
```

### 6.11 Concentration (SRD p.179)

```
// Concentration slot
RuleV3(
  ruleId: 'concentration_slot_init',
  trigger: event:onCreate,
  then: setResourceMax('concentration', literal(1), refresh: never)
)

// New concentration spell breaks old one
RuleV3(
  ruleId: 'concentration_replace',
  trigger: event:onSpellCast,
  when: contextMatches('trigger.spell.concentration', true),
  then: composite([
    breakConcentration(),
    consumeResource('concentration', amount: literal(1))
  ])
)

// Damage triggers Concentration save
RuleV3(
  ruleId: 'concentration_damage_save',
  trigger: event:onDamageTaken,
  when: resourceCompare('concentration', current, gt, 0),
  then: composite([
    // DC = max(10, damage/2)
    requestSave(
      ability: 'CON',
      dc: max(literal(10), floor(contextValue('trigger.damage') / 2)))
    // on fail: breakConcentration()
  ])
)
```

### 6.12 Death Saves (SRD p.17)

```
RuleV3(
  trigger: event:onHpZero,
  when: entity.categorySlug == 'player',
  then: composite([
    applyCondition('condition-unconscious'),
    setResourceMax('death_save_success', literal(3)),
    setResourceMax('death_save_fail', literal(3)),
    setValue('combat_stats.hp', literal(0))
  ])
)

RuleV3(
  trigger: event:onLongRest,
  then: composite([
    setValue('combat_stats.death_save_success', literal(0)),
    setValue('combat_stats.death_save_fail', literal(0))
  ])
)
```

### 6.13 Spell Slot Consume on Cast (SRD p.104)

```
RuleV3(
  ruleId: 'spell_slot_consume',
  trigger: event:onSpellCast,
  when: contextValue('trigger.spell.level') > 0,  // not cantrip
  then: consumeResource(
    resourceKey: 'spell_slot_' + contextValue('trigger.slot_used'),
    amount: literal(1),
    blockIfInsufficient: true)
)
```

### 6.14 Long Rest Recovery (SRD p.185)

```
RuleV3(
  trigger: event:onLongRest,
  then: composite([
    // spell slots full
    for level in 1..9:
      refreshResource('spell_slot_<level>', amount: null),  // null = full

    // hit dice: half, round up
    refreshResource('hit_dice_d6', fraction: 0.5),
    refreshResource('hit_dice_d8', fraction: 0.5),
    ...

    // class uses
    refreshResource('rage_uses'),
    refreshResource('channel_divinity'),
    refreshResource('bardic_inspiration'),

    // hp full
    setValue('combat_stats.hp', fieldValue('combat_stats.max_hp')),

    // exhaustion -1
    conditional(
      when: hasCondition('condition-exhaustion'),
      then: decrementConditionLevel('condition-exhaustion'))
  ])
)
```

### 6.15 Rage (Barbarian, SRD p.28)

```
// Resource init on Barbarian level gain
RuleV3(
  trigger: event:onClassAdded('class-barbarian'),
  then: setResourceMax('rage_uses',
    tableLookup(kBarbarianRageTable, levelInClass('class-barbarian')),
    refresh: longRest)
)

// Rage damage bonus
RuleV3(
  trigger: d20Test(testType: attackRoll),
  when: andPredicate([
    hasResource('rage_active', eq, 1),
    weaponIsMelee,
    usingStrForAttack]),
  then: modifyDamageRoll(op: add,
    value: tableLookup(kBarbarianRageDamageTable, levelInClass('class-barbarian')))
)

// Rage advantage on STR
RuleV3(
  trigger: d20Test,
  when: hasResource('rage_active', eq, 1) AND (testType = STR check or STR save),
  then: grantAdvantage(scope: d20Test, filter: 'STR')
)
```

### 6.16 Weapon Mastery (SRD p.90)

```
// Cleave — hit adjacent target
RuleV3(
  ruleId: 'mastery_cleave',
  trigger: event:onAttackHit,
  when: andPredicate([
    weaponHasMastery('Cleave'),
    hasFeature('class-fighter-mastery-cleave'),
    contextMatches('trigger.is_melee', true)
  ]),
  then: grantAction(actionId: 'cleave_secondary_attack', type: free)
)

// Topple — Con save vs prone
RuleV3(
  ruleId: 'mastery_topple',
  trigger: event:onAttackHit,
  when: weaponHasMastery('Topple'),
  then: applyCondition(
    conditionId: 'condition-prone',
    saveDC: arithmetic(literal(8) + proficiencyBonus() + ability_mod_used_in_attack),
    saveAbility: 'CON')
)
```

### 6.17 Exhaustion Penalty (SRD p.181)

```
RuleV3(
  trigger: d20Test,
  when: hasCondition('condition-exhaustion'),
  then: setValue(
    'active_d20_penalty',
    arithmetic(conditionLevel('condition-exhaustion') × literal(2)))
)

// Speed reduction
RuleV3(
  trigger: always,
  when: hasCondition('condition-exhaustion'),
  then: modifyWhileEquipped(
    targetFieldKey: 'combat_stats.speed',
    value: arithmetic(literal(-5) × conditionLevel('condition-exhaustion')))
)
```

### 6.18 Multiclass Prerequisite (SRD p.25)

```
RuleV3(
  ruleId: 'multiclass_prereq_barbarian',
  trigger: event:onClassAdded('class-barbarian'),
  when: compare(left: fieldValue('stat_block.STR'), op: lt, literal(13)),
  then: composite([
    revokeEffect,  // undo add
    presentChoice(key: 'multiclass_warning',
      options: [{id:'acknowledge', label:'STR must be ≥13'}])
  ])
)
```

### 6.19 Two-Weapon Fighting (SRD p.89, Light property)

```
RuleV3(
  ruleId: 'twf_bonus_attack',
  trigger: event:onAttackMade,
  when: andPredicate([
    contextMatches('trigger.weapon.property', 'Light'),
    compare(turnState.firstAttackMade, eq, true),
    compare(turnState.bonusActionUsed, eq, false)
  ]),
  then: grantAction(actionId: 'twf_extra_attack', type: bonusAction)
)
```

### 6.20 Darkvision / Sunlight Sensitivity

```
// Drow Sunlight Sensitivity — Disadvantage in bright sunlight
RuleV3(
  trigger: d20Test(testType: attackRoll),
  when: andPredicate([
    hasFeature('trait-drow-sunlight-sensitivity'),
    contextMatches('environment.light', 'bright_sunlight')
  ]),
  then: grantDisadvantage(scope: attackRoll)
)
```

---

## 7. Tüm SRD Mekaniklerinin RuleV3 Gruplandırması

### 7.1 Reactive (always) — ~30 rule
Ability mods (6), PB, total_level, passive_perception, passive_investigation, passive_insight, spell_save_dc, spell_attack_bonus, AC computations (5 variants), HP max, carrying_capacity, current_load, encumbered flag, speed modifiers, 6 save bonuses, 18 skill bonuses, attunement count check, style:unprepared-spell, style:cursed-item, style:required-attunement-missing.

### 7.2 Lifecycle Events — ~15 rule
onCreate: resource init (spell slots, class uses, concentration slot, death saves).
onLevelUp: hp increase, feature grant, spell slot table refresh, subclass unlock check.
onClassAdded: multiclass prereq check, class-specific resource init.
onSubclassUnlocked: subclass feature grant.

### 7.3 Rest Events — ~10 rule
onShortRest: pact magic, hit dice spend choice, class features (rage etc. depending).
onLongRest: all slots refresh, hit dice half, class uses refresh, hp full, exhaustion -1, death save reset.
onDawn: magic item charge refresh.

### 7.4 Combat Events — ~25 rule
onInitiativeRoll: initiative bonus.
onTurnStart: legendary action refresh (if end of any creature), rechargeable ability check.
onAttackMade / onAttackHit / onAttackMiss / onCriticalHit.
onDamageDealt: weapon mastery triggers (Cleave, Graze, Nick, Push, Sap, Slow, Topple, Vex).
onDamageTaken: resistance/vulnerability/immunity apply, concentration save trigger, temp_hp absorb.
onHpZero: death save start, unconscious apply.
onConditionApplied / onConditionRemoved.
onConcentrationBroken: end spell effects.

### 7.5 D20 Test Context — ~20 rule
Advantage grants: Help action, Pack Tactics, Hidden attacker, Rage STR, Bless (+1d4), ...
Disadvantage grants: Poisoned, Frightened, Prone (melee), Long range, Armor training missing, Dodged target, ...
Critical range: Champion 19-20, Assassin on surprise, Paladin Oath, ...

### 7.6 Equipment Gates — ~10 rule
Heavy armor STR requirement.
Armor training missing (soft: disadvantage; not hard block).
Attunement cap.
Two-handed weapon + shield conflict.
Feat prerequisites.
Multiclass prereqs.

### 7.7 Spell Mechanics — ~10 rule
Spell slot consume on cast.
Ritual cast (bypass slot).
Concentration start/break.
Spell components check.
Spellcasting ability resolve.
Higher-level cast damage scaling.

---

## 8. Sandbox & Determinizm

### 8.1 Evaluation Limits

```
MAX_RULE_DEPTH          = 10     // dependency chain
MAX_CASCADE_EVENTS      = 50     // rule triggering rule triggering rule
MAX_FIELD_REF_DEPTH     = 3      // self → related → related (V2 ile aynı)
MAX_EVALUATION_MS       = 100    // per-entity timeout
MAX_LIST_SIZE           = 1000   // aggregate / filter
```

### 8.2 Conflict Resolution

1. **Priority ascending**: Düşük priority önce çalışır.
2. **Source tagging**: Rule-produced values `source: 'rule:<id>'` ile işaretlenir; manuel değerler korunur.
3. **Modifier stacking**:
   - Same type (numeric add): sum
   - Different types: apply in specified order (add, then multiply, then clamp)
   - Advantage/Disadvantage: net (both cancel)
4. **Value source precedence** (AC için örnek):
   - Unarmored Defense (Monk, Barbarian) vs. armor: player picks (choice)
   - Mage Armor: temporary overlay (AppliedEffect)
   - Magic item (+1): stacks (modifyWhileEquipped)

### 8.3 Determinizm

- Tüm rule'lar saf fonksiyon (yan etki yok): input (state, context) → output (mutation list).
- Dice roll → rule engine **dışı** (caller sağlar).
- Tie-breaking: ruleId alphabetical.
- Serialization round-trip: input JSON + state → aynı output.

---

## 9. JSON Örnekleri

### 9.1 Reactive Rule (Ability Modifier)

```json
{
  "ruleId": "ability_mod_str",
  "name": "STR Modifier",
  "priority": 0,
  "enabled": true,
  "trigger": { "type": "always" },
  "when": { "type": "always" },
  "then": {
    "type": "setValue",
    "targetFieldKey": "str_mod",
    "value": {
      "type": "modifier",
      "source": { "scope": "self", "fieldKey": "stat_block", "nestedFieldKey": "STR" }
    }
  }
}
```

### 9.2 Event Rule (Long Rest)

```json
{
  "ruleId": "long_rest_recovery",
  "name": "Long Rest — Refresh Spell Slots",
  "priority": 100,
  "trigger": { "type": "event", "event": "onLongRest" },
  "when": { "type": "always" },
  "then": {
    "type": "composite",
    "effects": [
      { "type": "refreshResource", "resourceKey": "spell_slot_1" },
      { "type": "refreshResource", "resourceKey": "spell_slot_2" },
      { "type": "refreshResource", "resourceKey": "hit_dice_d10", "fraction": 0.5 },
      {
        "type": "setValue",
        "targetFieldKey": "combat_stats.hp",
        "value": { "type": "fieldValue", "source": { "scope": "self", "fieldKey": "combat_stats.max_hp" } }
      }
    ]
  }
}
```

### 9.3 D20 Test Rule (Rage Advantage)

```json
{
  "ruleId": "rage_str_advantage",
  "name": "Rage — Advantage on STR saves",
  "trigger": {
    "type": "d20Test",
    "testType": "savingThrow",
    "abilityFilter": "STR"
  },
  "when": {
    "type": "resourceCompare",
    "resourceKey": "rage_active",
    "field": "current",
    "op": "eq",
    "value": 1
  },
  "then": {
    "type": "grantAdvantage",
    "scope": "savingThrow",
    "filter": "STR"
  }
}
```

### 9.4 Conditional Expression (Passive Perception)

```json
{
  "ruleId": "passive_perception",
  "trigger": { "type": "always" },
  "when": { "type": "always" },
  "then": {
    "type": "setValue",
    "targetFieldKey": "passive_perception",
    "value": {
      "type": "arithmetic",
      "op": "add",
      "left": { "type": "literal", "value": 10 },
      "right": {
        "type": "arithmetic",
        "op": "add",
        "left": { "type": "fieldValue", "source": { "scope": "self", "fieldKey": "wis_mod" } },
        "right": {
          "type": "ifThenElse",
          "condition": { "type": "hasChoice", "choiceKey": "skill_prof_perception" },
          "then": { "type": "proficiencyBonus" },
          "else": { "type": "literal", "value": 0 }
        }
      }
    }
  }
}
```

---

## 10. V2 → V3 Geriye Uyumluluk

### Adapter Layer

V2 rule'ları V3 engine'de yorumlanır:

```
V2.Predicate.compare          → V3.Predicate.compare (aynı)
V2.Predicate.and/or/not       → V3 aynı
V2.ValueExpression.* (6 tip) → V3 aynı 6 tip
V2.RuleEffect.setValue        → V3.setValue
V2.RuleEffect.gateEquip       → V3.gateEquip
V2.RuleEffect.modifyWhileEquipped → V3 aynı
V2.RuleEffect.styleItems      → V3 aynı

V2 RuleV2 → V3 RuleV3:
  trigger = always
  ruleScope = reactive
  diğer alanlar 1-1 mapping
```

### Migration Path

1. V3 engine yazılır, V2 rule'ları `always` trigger ile yorumlar.
2. Storage: mevcut `categoriesJson` içindeki rule array'i geriye uyumlu kalır.
3. UI: V3 event/resource/choice UI'ı **ek** olarak eklenir (mevcut 4-tab dialog değişmez).
4. Yeni built-in schema (`builtin-dnd5e-srd-v5.2.1`) V3 rule'ları ile seed edilir; eski `builtin-dnd5e-default` aynen kalır.

---

## 11. Test Stratejisi

### 11.1 Unit Test Katmanları

1. **Predicate evaluation** — her predicate tipi için deterministik test
2. **Expression evaluation** — her expression tipi + edge case (div-by-zero, list-empty, nested)
3. **Effect application** — state mutation izole
4. **Rule pipeline** — topological sort + priority
5. **Event cascade** — depth limit + loop detection
6. **D20 test flow** — advantage/disadvantage resolution
7. **Damage pipeline** — resistance stack, concentration save
8. **Rest mechanics** — resource refresh
9. **Integration: SRD scenarios** — Fighter L5 creation, Wizard cast Fireball, Barbarian rage damage calc

### 11.2 Property-Based Tests

- `∀ Entity E, Rule R: apply(R, E) = apply(R, apply(R, E))` (idempotency for reactive)
- `∀ event sequence: final state = sum of individual event applies` (commutativity where applicable)
- `∀ Rule R, Entity E: serialize(apply(R, E)) round-trips` (persistence)

### 11.3 Coverage Hedefi

- Predicate: 100% variant coverage
- Expression: 100%
- Effect: 100%
- SRD rule seed: 95%+ line coverage
- Integration scenarios: tüm 12 class × level 1-5 sample character

---

## 12. Açık Tasarım Soruları

| # | Soru | Öneri |
|---|------|-------|
| 1 | Dice roll engine içinde mi? | Hayır — external `DiceRoller` interface, seed-based test için swap edilebilir |
| 2 | Rule editor UI v3 sıfırdan mı? | Hayır — mevcut 4-tab dialog korunur, yeni "Event" + "Resource" + "Choice" tab eklenir |
| 3 | V3 içinde reactive/event ayrımı çok mu? | Trade-off: tek unified trigger vs. ayrı optimize edilmiş path. Öneri: union `RuleTrigger` ama evaluator iç tarafta optimize |
| 4 | Concentration tracker UI? | Encounter tracker'da "Concentrating on: X" rozeti |
| 5 | Choice persistence | `Entity.choices` map; ayrı Drift tablosu gerekmez |
| 6 | Resource UI | Character sheet'te progress bar + +/- butonlar; her resource için ayrı widget |
| 7 | Rule versiyonlama | `RuleV3.schemaVersion` field; migration script v2→v3 |

---

## 13. Özet

| Metric | V2 | V3 |
|--------|----|-----|
| Trigger tipleri | 1 (always) | 5 (always, event, d20, damage, turnPhase) |
| Predicate primitifleri | 5 | 13 |
| Expression primitifleri | 6 | 17 |
| Effect primitifleri | 4 | 18 |
| Event kind sayısı | 0 | ~30 |
| Resource tracking | ✗ | ✓ |
| Choice state | ✗ | ✓ |
| Turn state | ✗ | ✓ |
| SRD coverage | ~40% | ~95% |

V3 spec, SRD 5.2.1'in tüm temel mekaniklerini data-driven şekilde ifade eder. Kod uygulaması için [RULES_V3_IMPLEMENTATION_GUIDE.md](RULES_V3_IMPLEMENTATION_GUIDE.md).
