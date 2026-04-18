# 05 — Rule Engine Removal & Replacement Pattern

> **For Claude.** RuleV2/RuleEngineV2 deletion + replacement pattern (compiled effects driven by a serializable descriptor DSL).
> **Content policy.** No concrete D&D content lives in the app binary. Descriptors come from installed packages; see [14-package-system-redesign.md](./14-package-system-redesign.md) and [15-srd-core-package.md](./15-srd-core-package.md). `EffectDescriptor` family is defined in [01-domain-model-spec.md](./01-domain-model-spec.md) §Effects.

## What's Removed

```
flutter_app/lib/domain/entities/schema/rule_v2.dart
  - sealed Predicate (Compare, And, Or, Not, Always)
  - sealed ValueExpression (Literal, FieldRef, Aggregate, ...)
  - RuleV2 { name, when, then }
flutter_app/lib/application/services/rule_engine_v2.dart
  - RuleEngineV2.evaluate(entity, context) → EvaluationResult
flutter_app/test/...rule_engine_v2_test.dart
```

## Why Removed

- Generic engine inflated complexity for marginal benefit.
- Every D&D feature already mechanically distinct; expressing as `Predicate + ValueExpression` was lossy and required string field keys (no compile-time safety).
- Direct Dart functions: type-safe, debuggable, testable, IDE-navigable.

## Replacement Pattern: Compiled Feature Effects

A "feature" (class feature, feat, spell, magic item, condition) is described by a list of `EffectDescriptor` cases ([01-domain-model-spec.md](./01-domain-model-spec.md) §Effects). Content authors write those descriptors in package JSON; they never write Dart. An **`EffectCompiler`** turns each descriptor list into a `CompiledEffect` — the internal representation the combat resolvers consume. `FeatureEffect` (below) is the shape of that compiled form; it is an *internal interface*, not a user-facing extension point.

### Signature Types

```dart
// flutter_app/lib/domain/dnd5e/feature/feature_effect.dart

typedef AttackRollModifier = AttackRollMods Function(AttackRollContext ctx);
typedef DamageRollModifier = DamageRollMods Function(DamageRollContext ctx);
typedef SaveModifier       = SaveMods       Function(SaveContext ctx);
typedef AcModifier         = int             Function(Character c);
typedef InitiativeModifier = int             Function(Character c);
typedef PassiveSenseMod    = int             Function(Character c, Sense sense);

class AttackRollMods {
  final int flatBonus;
  final AdvantageState advantageState;
  final List<DiceExpression> extraDice;
  const AttackRollMods({this.flatBonus = 0, this.advantageState = AdvantageState.normal,
                        this.extraDice = const []});
}
class DamageRollMods {
  final List<DiceExpression> extraDice;
  final int flatBonus;
  final Set<ContentReference<DamageType>> additionalTypeIds;   // namespaced ids
}
class SaveMods {
  final int flatBonus;
  final AdvantageState advantageState;
  final bool autoSucceed;
  final bool autoFail;
}

class AttackRollContext {
  final Combatant attacker;
  final Combatant target;
  final Weapon? weapon;
  final Spell? spell;
  final bool isMelee;
  final bool isRanged;
  final double distanceFt;
}
```

### Compiled Feature Shape (internal)

```dart
// flutter_app/lib/application/dnd5e/effect/compiled_effect.dart

abstract class FeatureEffect {
  String get id;                                       // source descriptor id or aggregate key
  String get name;

  // Hooks the resolvers call. Default = no-op.
  AttackRollMods modifyAttackRoll(AttackRollContext ctx) => const AttackRollMods();
  DamageRollMods modifyDamageRoll(DamageRollContext ctx) => const DamageRollMods();
  SaveMods modifySave(SaveContext ctx) => const SaveMods();
  int modifyAc(Character c) => 0;
  int modifyInitiative(Character c) => 0;
  bool grantsCondition(Combatant c, ContentReference<Condition> conditionId) => false;
}
```

`FeatureEffect` subclasses are **not hand-written for SRD content**. They are emitted by the `EffectCompiler` from `EffectDescriptor` lists carried by content. The three examples below illustrate what the compiler *produces*; they are not files shipped in the app binary.

### Example (compiler output): Barbarian Rage

```dart
// Compiler-output illustration — not a file that ships. Shown here so reviewers
// can see the shape of what EffectCompiler produces from a Rage class-feature
// descriptor list in the SRD package.

class RageEffect extends FeatureEffect {
  final int rageDamageBonus;       // from class level (Rage Damage column)
  RageEffect({required this.rageDamageBonus});
  @override final id = 'barbarian:rage';
  @override final name = 'Rage';

  @override
  DamageRollMods modifyDamageRoll(DamageRollContext ctx) {
    if (!ctx.attacker.isRaging) return const DamageRollMods();
    if (!ctx.usesStrength) return const DamageRollMods();
    return DamageRollMods(flatBonus: rageDamageBonus);
  }

  @override
  SaveMods modifySave(SaveContext ctx) {
    if (!ctx.actor.isRaging) return const SaveMods();
    if (ctx.ability == Ability.strength) return const SaveMods(advantageState: AdvantageState.advantage);
    return const SaveMods();
  }
}
```

### Example (compiler output): Sneak Attack

```dart
class SneakAttackEffect extends FeatureEffect {
  final int sneakAttackDice;       // 1d6 per 2 rogue levels, rounded up
  SneakAttackEffect({required this.sneakAttackDice});
  @override final id = 'rogue:sneak_attack';
  @override final name = 'Sneak Attack';

  @override
  DamageRollMods modifyDamageRoll(DamageRollContext ctx) {
    if (!ctx.attacker.canSneakAttackThisTurn) return const DamageRollMods();
    if (!_qualifies(ctx)) return const DamageRollMods();
    return DamageRollMods(extraDice: [DiceExpression('${sneakAttackDice}d6')]);
  }

  bool _qualifies(DamageRollContext ctx) {
    final w = ctx.weapon;
    if (w == null) return false;
    // WeaponProperty is a Tier 1 catalog entity; the compiler resolves 'srd:finesse'
    // at compile time into this flag check.
    if (!w.hasPropertyFlag(PropertyFlag.finesse) && !w.type.isRanged) return false;
    if (ctx.hasAdvantage) return true;
    if (ctx.hasAllyAdjacentToTarget && !ctx.hasDisadvantage) return true;
    return false;
  }
}
```

### Example (compiler output): Bless Spell

```dart
class BlessEffect extends FeatureEffect {
  @override final id = 'spell:bless';
  @override final name = 'Bless';

  @override
  AttackRollMods modifyAttackRoll(AttackRollContext ctx) {
    if (!ctx.attacker.hasActiveEffect(id)) return const AttackRollMods();
    return AttackRollMods(extraDice: [DiceExpression('1d4')]);
  }

  @override
  SaveMods modifySave(SaveContext ctx) {
    if (!ctx.actor.hasActiveEffect(id)) return const SaveMods();
    return SaveMods(extraDice: [DiceExpression('1d4')] /* if SaveMods supports */);
  }
}
```

(Update `SaveMods` to include `extraDice` if needed — symmetric with attack mods.)

## Aggregation: How They Combine

The combat resolver iterates active effects and reduces:

```dart
// flutter_app/lib/application/dnd5e/combat/attack_resolver.dart

AttackRollResult resolveAttack(AttackRollContext ctx, List<FeatureEffect> activeEffects) {
  AdvantageState adv = AdvantageState.normal;
  int flatBonus = 0;
  final extraDice = <DiceExpression>[];

  for (final fx in activeEffects) {
    final m = fx.modifyAttackRoll(ctx);
    flatBonus += m.flatBonus;
    extraDice.addAll(m.extraDice);
    adv = adv.combine(m.advantageState);   // see AdvantageState.combine rules
  }

  // Apply core formula: see rules §1, §10.
  final d20 = adv.roll();
  final attackTotal = d20 + ctx.attackerAbilityMod + ctx.proficiencyBonus + flatBonus
                    + extraDice.map((d) => d.roll()).fold(0, (a,b)=>a+b);
  // ... compare to target.armorClass, build result
}
```

## Effect Lifecycle

```
Where effects come from (sources):
  - Always-on:    species traits, passive class features (Unarmored Defense)
  - Toggled:      Rage (entered as Bonus Action), Patient Defense
  - Time-limited: Bless (Concentration up to 1 min), Hex
  - Per-attack:   Sneak Attack
  - Conditional:  Reckless Attack (current turn only)

Stored on Combatant:
  Set<String> activeEffectIds       // by effect id
  Map<String, EffectInstanceData>?  // for parameterized effects (e.g., Rage damage tier)
```

```dart
class Combatant {
  final Set<String> activeEffectIds;
  final Map<String, EffectInstanceData> effectData;

  bool hasActiveEffect(String id) => activeEffectIds.contains(id);
  bool get isRaging => activeEffectIds.contains('barbarian:rage');
}
```

`FeatureEffect` instances themselves are stateless / parameterized at construction. The `Combatant` holds which IDs are active; the registry maps id → effect instance.

## Effect Registry

```dart
// flutter_app/lib/application/dnd5e/feature/feature_registry.dart

class FeatureEffectRegistry {
  final Map<String, FeatureEffect Function(EffectInstanceData)> _factories = {};

  void register(String id, FeatureEffect Function(EffectInstanceData) factory) {
    _factories[id] = factory;
  }

  FeatureEffect resolve(String id, EffectInstanceData data) =>
    _factories[id]!(data);

  List<FeatureEffect> activeFor(Combatant c) =>
    c.activeEffectIds.map((id) => resolve(id, c.effectData[id] ?? const EffectInstanceData.empty())).toList();
}
```

Registered at app boot:

```dart
final featureRegistryProvider = Provider<FeatureEffectRegistry>((ref) {
  final r = FeatureEffectRegistry();
  r.register('barbarian:rage', (data) => RageEffect(rageDamageBonus: data.intArg('damageBonus')));
  r.register('rogue:sneak_attack', (data) => SneakAttackEffect(sneakAttackDice: data.intArg('dice')));
  r.register('spell:bless', (_) => BlessEffect());
  // ...
  return r;
});
```

## Where Effects Live in the Codebase

```
domain/dnd5e/effect/effect_descriptor.dart      # Tier 2 sealed descriptor family (see Doc 01)
domain/dnd5e/effect/predicate.dart              # Predicate sealed family
domain/dnd5e/effect/duration.dart               # Duration sealed family
application/dnd5e/effect/compiled_effect.dart   # FeatureEffect base (internal compiled form)
application/dnd5e/effect/effect_compiler.dart   # descriptors → FeatureEffect
application/dnd5e/effect/custom_effect_registry.dart  # whitelisted Dart escape hatches
application/dnd5e/feature/feature_registry.dart # per-Combatant active-effect index
application/dnd5e/combat/{attack|save|damage}_resolver.dart  # apply chain (unchanged)
```

**No `domain/dnd5e/content/` directory.** All concrete content (Rage, Sneak Attack, Bless, Stunned, Fireball, …) arrives as `EffectDescriptor` lists in installed packages and is compiled at load time.

## CustomEffect Extensibility

A minority of SRD features resist pure-descriptor encoding (Wish's open-ended branch, Wild Shape's form substitution, Polymorph, Animate Dead, Summon families, Simulacrum, Shapechange, Glyph of Warding). These use the `CustomEffect` descriptor case, which names an `implementationId`:

```dart
// application/dnd5e/effect/custom_effect_registry.dart

abstract interface class CustomEffectImpl {
  String get id;                                        // 'srd:wish'
  CompiledEffect compile(Map<String, Object?> parameters);
}

class CustomEffectRegistry {
  final Map<String, CustomEffectImpl> _byId = {};
  void register(CustomEffectImpl impl) => _byId[impl.id] = impl;
  CustomEffectImpl? byId(String id) => _byId[id];
  bool has(String id) => _byId.containsKey(id);
}
```

Registered at app boot. The set of registered ids is closed, small, and documented. Packages declare the ones they depend on in `requiredRuntimeExtensions`; the package importer rejects packages whose required ids aren't registered ([14-package-system-redesign.md](./14-package-system-redesign.md) §Package Importer step 0). The SRD Core package's required set is enumerated in [15-srd-core-package.md](./15-srd-core-package.md) §Whitelisted `CustomEffect` Implementations.

Homebrew packages can name an `implementationId` the app does not ship, but the package will only import on runtimes that have registered it (which in practice means runtimes that have been extended via a code plugin — out of scope for MVP).

## Migration of Existing Rules

In v4 codebase, `RuleV2` was used to express:
- "If field X equals Y, set field Z to W."
- Aggregate "sum of all related items' field A into self.B."

These were used for things like:
- Inventory weight totaling.
- Encumbrance status from carried weight.
- AC computation from equipped armor.

Replacement: **all such derivations live in `Character`/`Combatant` getters or service methods.** No data-driven rules engine. Fewer abstractions, more code — but trivial to read & test.

```dart
// instead of RuleV2 aggregation:
class Character {
  double get carriedWeight => inventory.entries.fold(0.0, (s, e) => s + e.totalWeight);
  bool get isEncumbered => carriedWeight > abilities.str.value * 5;   // simplified
}
```

## Testing

Testing focuses on **the compiler** and **the resolver pipeline**, not hand-authored `FeatureEffect` subclasses.

- `EffectCompiler` tests: for each `EffectDescriptor` case, assert that compilation produces the expected `CompiledEffect` behavior over representative contexts.
- Integration tests: load the SRD Core package into a test registry, then exercise scenarios end-to-end (e.g. "Raging STR-weapon attack adds rage damage bonus"; "Stunned target auto-fails DEX save and is attacked with advantage").
- `CustomEffect` tests: assert each whitelisted impl produces expected behavior.

```dart
test('Rage adds rage damage bonus to STR weapon attack', () {
  final ctx = DamageRollContext(
    attacker: testCombatant().copyWith(activeEffectIds: {'barbarian:rage'}),
    weapon: testGreataxe(),
    usesStrength: true,
  );
  final mods = RageEffect(rageDamageBonus: 2).modifyDamageRoll(ctx);
  expect(mods.flatBonus, 2);
});
```

## Acceptance

- All 5 deleted files removed; 0 grep hits for `RuleV2|RuleEngineV2|ValueExpression` (note: `Predicate` is now reused by the descriptor DSL and will still appear).
- `FeatureEffect` interface defined in `application/dnd5e/effect/compiled_effect.dart`.
- No `domain/dnd5e/content/` directory exists.
- `EffectCompiler` compiles every `EffectDescriptor` case to a `CompiledEffect` covered by unit tests.
- Rage, Sneak Attack, Bless, Stunned integration tests pass against the SRD Core package — with **zero hand-written `FeatureEffect` subclasses** for any of them.
- `CustomEffect` registry rejects packages whose `requiredRuntimeExtensions` include unregistered ids.
- `AttackResolver`, `DamageResolver`, `SaveResolver` apply effects in pipeline.
- Old aggregation use cases (encumbrance, AC) re-implemented as getters.
- `flutter analyze` + `flutter test` clean.

## Open Questions

1. Should effects be stackable (e.g., 2 Bless from different casters)? → Per SRD §24.17 "same spell, only most potent applies." So registry collapses duplicates per source-spell-id. Different effects (Bless + Bardic Inspiration) stack normally.
2. Should `FeatureEffect` know its remaining duration? → No. Duration tracked on `Combatant.effectData[id].roundsRemaining`. Effect itself is pure.
3. Where does turn-end "expire effects" logic live? → `application/dnd5e/combat/turn_engine.dart` advances rounds and decrements/expires effects.
