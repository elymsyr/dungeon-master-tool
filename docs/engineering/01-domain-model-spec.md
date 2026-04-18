# 01 — Domain Model Spec

> **For Claude.** Typed Dart entities replacing schema-driven `Entity { fields: Map }` model.
> **Source rules:** [00-dnd5e-mechanics-reference.md](./00-dnd5e-mechanics-reference.md)
> **Content policy:** see [15-srd-core-package.md](./15-srd-core-package.md). Domain layer ships *mechanics only*; concrete entries (Stunned, Fireball, Goblin, etc.) arrive via packages.
> **Target package:** `flutter_app/lib/domain/dnd5e/`

## Conventions

- Pure immutable Dart classes. **No Freezed** (avoids codegen burden; manual `==`/`hashCode`/`copyWith`).
- All identifiers English. Field names `camelCase`. Class names `PascalCase`.
- Use sealed classes (Dart 3) for discriminated unions.
- No JSON serialization in domain layer — that lives in `data/dnd5e/mappers/`.
- All collections return `List<T>` typed (no `dynamic`).
- Validate invariants in factory constructors. Throw `ArgumentError` with specific message.
- No business logic in entities — only data + invariant guards. Logic in `application/dnd5e/services/`.

## Tier Split

Every type in this doc belongs to one of three tiers. The boundary rule: *does the engine reason about this symbolically with its own code path per member?* Yes → Tier 0 (structural, hardwired in Dart). No → Tier 1 (packageable data class with a namespaced `String id`).

- **Tier 0 — structural primitives.** `Ability`, `AbilityScore`, `AbilityScores`, `Die`, `DiceExpression`, `AdvantageState`, `Proficiency`, `ProficiencyBonus`, `SpellLevel`, `ChallengeRating`, plus stateful machines `Concentration`, `ActionEconomy`, `TurnState`, `DeathSaves`, `HitPoints`, `Exhaustion`.
- **Tier 1 — catalog entities.** Anything that a homebrew author might plausibly add, remove, or redefine. Conditions, damage types, skills, sizes, creature types, alignments, languages, spell schools, weapon properties, weapon masteries, armor categories, rarities — plus the larger typed entities (Spell, Item, Monster, Feat, Background, Species, CharacterClass, Subclass, Encounter, NpcTemplate).
- **Tier 2 — effect descriptors.** Closed serializable DSL that Tier 1 entities embed to declare behavior. See §Effects.

## ID Namespacing

Every Tier 1 entity carries a `String id` of shape `<packageId>:<localId>`, e.g. `srd:stunned`, `arctic_homebrew:frozen`. The package importer ([14-package-system-redesign.md](./14-package-system-redesign.md)) rewrites declared local ids at install time by prepending the owning package's manifest id. Cross-references inside a single package may use bare local ids and are resolved pre-write. This makes catalog-id collisions impossible by construction; the duplicate/skip/overwrite conflict prompt is reserved for same-source re-installs (e.g. SRD v1 → v2 upgrade).

`ContentReference<T>` is a documentation typedef:

```dart
typedef ContentReference<T> = String;   // always a namespaced id
```

Referential integrity is **not** enforced by the type system. A `ContentRegistryValidator` runs at world load time and at package import time; dangling references fail-closed with a user-visible warning listing missing ids.

## Directory Layout

```
flutter_app/lib/domain/dnd5e/
├── core/                           # Tier 0: structural primitives
│   ├── ability.dart                # enum Ability { strength, dexterity, ... }
│   ├── ability_score.dart          # value class, 1..30 with modifier
│   ├── ability_scores.dart         # 6-tuple
│   ├── proficiency.dart            # enum Proficiency { none, half, full, expertise }
│   ├── proficiency_bonus.dart      # int compute from level
│   ├── die.dart                    # enum Die { d4, d6, d8, d10, d12, d20, d100 }
│   ├── dice_expression.dart        # parser + roller "2d6+3"
│   └── advantage_state.dart        # enum { normal, advantage, disadvantage }
├── catalog/                        # Tier 1: mechanic primitive classes
│   ├── condition.dart              # class Condition { id, name, description, effects }
│   ├── damage_type.dart            # class DamageType { id, name, physical }
│   ├── skill.dart                  # class Skill { id, name, ability }
│   ├── size.dart                   # class Size { id, name, spaceFt, tokenScale }
│   ├── creature_type.dart          # class CreatureType { id, name }
│   ├── alignment.dart              # class Alignment { id, lawChaos, goodEvil }
│   ├── language.dart               # class Language { id, name, script? }
│   ├── spell_school.dart           # class SpellSchool { id, name, color? }
│   ├── weapon_property.dart        # class WeaponProperty { id, name, flags }
│   ├── weapon_property_flag.dart   # enum PropertyFlag (Tier 0 flag vocabulary)
│   ├── weapon_mastery.dart         # class WeaponMastery { id, name, description }
│   ├── armor_category.dart         # class ArmorCategory { id, name, stealthDisadvantage, maxDexCap }
│   └── rarity.dart                 # class Rarity { id, name, sortOrder, attunementTierReq }
├── effect/                         # Tier 2: serializable DSL
│   ├── effect_descriptor.dart      # sealed EffectDescriptor family
│   ├── predicate.dart              # sealed Predicate
│   └── duration.dart               # sealed Duration
├── character/
│   ├── character.dart              # PC root entity
│   ├── character_class_level.dart  # one entry per multiclass
│   ├── character_class.dart        # Tier 1: class definition
│   ├── subclass.dart               # Tier 1
│   ├── class_features_table.dart
│   ├── species.dart                # Tier 1
│   ├── lineage.dart                # Tier 1
│   ├── background.dart             # Tier 1
│   ├── feat.dart                   # Tier 1
│   ├── proficiency_set.dart        # weapon/armor/tool/save/skill profs (all by id)
│   ├── hit_points.dart             # current, max, temp
│   ├── hit_dice_pool.dart          # remaining HD per type
│   ├── death_saves.dart            # successes, failures
│   ├── exhaustion.dart             # 0..6
│   ├── spell_slots.dart            # per-level current/max
│   ├── pact_magic_slots.dart       # warlock-specific
│   ├── prepared_spells.dart
│   ├── inspiration.dart            # bool
│   └── inventory.dart              # List<InventoryEntry>
├── combat/
│   ├── encounter.dart
│   ├── combatant.dart              # sealed: PlayerCombatant | MonsterCombatant
│   ├── initiative.dart
│   ├── turn_state.dart             # actions used this turn
│   ├── action_economy.dart         # action / bonus / reaction flags
│   ├── concentration.dart          # spellId being concentrated
│   └── attack_resolution.dart      # AttackRoll, DamageRoll, SaveRoll value types
├── spell/
│   ├── spell.dart                  # Tier 1: immutable Spell definition
│   ├── spell_level.dart            # Tier 0: value class, int 0..9
│   ├── spell_component.dart        # V/S/M with material desc + cost
│   ├── casting_time.dart           # sealed
│   ├── spell_range.dart            # sealed: Self/Touch/Distance/Sight
│   ├── spell_duration.dart         # sealed
│   ├── spell_target.dart           # sealed
│   ├── area_of_effect.dart         # sealed: Cone/Cube/Cylinder/Emanation/Line/Sphere
│   └── ritual_tag.dart
├── item/
│   ├── item.dart                   # Tier 1 sealed: Weapon/Armor/Shield/Gear/MagicItem/Tool/Ammunition
│   ├── weapon.dart
│   ├── armor.dart
│   ├── magic_item.dart
│   └── attunement.dart
├── monster/
│   ├── monster.dart                # Tier 1: immutable monster definition
│   ├── stat_block.dart             # composition of all stat block fields
│   ├── monster_action.dart         # sealed: Attack/Multiattack/Save/Special
│   ├── challenge_rating.dart       # Tier 0: value class with XP and PB lookup
│   └── legendary_action.dart
└── world/
    ├── campaign.dart               # replaces template-coupled Campaign
    ├── world.dart                  # campaign container; owns installed package registry
    └── npc.dart                    # tracked NPC (typed, not Entity)
```

**Note.** `SpellSchool`, `WeaponProperty`, `WeaponMastery`, `ArmorCategory`, `Rarity`, `Language`, `Condition`, `DamageType`, `Skill`, `Size`, `CreatureType`, `Alignment` **are not Dart enums**. They are Tier 1 classes whose instances arrive via packages. A fresh world with no installed packages has empty catalogs for each.

## Key Type Signatures

### Ability (Tier 0)

```dart
enum Ability { strength, dexterity, constitution, intelligence, wisdom, charisma;
  String get short => switch (this) {
    strength => 'STR', dexterity => 'DEX', constitution => 'CON',
    intelligence => 'INT', wisdom => 'WIS', charisma => 'CHA',
  };
}
```

### AbilityScore (value class, Tier 0)

```dart
class AbilityScore {
  final int value;  // 1..30
  const AbilityScore._(this.value);
  factory AbilityScore(int v) {
    if (v < 1 || v > 30) throw ArgumentError('AbilityScore $v out of [1,30]');
    return AbilityScore._(v);
  }
  int get modifier => ((value - 10) / 2).floor();
}
```

### AbilityScores (Tier 0)

```dart
class AbilityScores {
  final AbilityScore str, dex, con, int_, wis, cha;
  const AbilityScores({required this.str, required this.dex, required this.con,
    required this.int_, required this.wis, required this.cha});
  AbilityScore byAbility(Ability a) => switch (a) {
    Ability.strength => str, Ability.dexterity => dex, ...
  };
  AbilityScores withBonus(Ability a, int delta) => /* immutable update */;
}
```

### Catalog: Condition (Tier 1)

```dart
class Condition {
  final String id;                         // 'srd:stunned'
  final String name;
  final String description;
  final List<EffectDescriptor> effects;    // typically ConditionInteraction + ModifyAttackRoll etc.
}
```

Example: the SRD Core package defines `srd:stunned` as:

```json
{ "id": "srd:stunned", "name": "Stunned", "description": "...",
  "effects": [
    { "case": "ConditionInteraction", "incapacitated": true, "speedZero": true,
      "autoFailSavesOf": ["STR","DEX"], "imposedAdvantageOnAttacksAgainst": true } ] }
```

### Catalog: DamageType (Tier 1)

```dart
class DamageType {
  final String id;          // 'srd:fire'
  final String name;
  final bool physical;      // bludgeoning/piercing/slashing; relevant for nonmagical-weapon resistance
}
```

### Catalog: Skill (Tier 1)

```dart
class Skill {
  final String id;          // 'srd:athletics'
  final String name;
  final Ability ability;    // Tier 0 — skill's governing ability is structural
}
```

### Catalog: WeaponProperty (Tier 1)

```dart
enum PropertyFlag {         // Tier 0 flag vocabulary; engine keys off flags, not ids
  finesse, heavy, light, loading, range, reach, thrown, twoHanded, versatile, ammunition,
  appliesToSneakAttack, ...
}

class WeaponProperty {
  final String id;          // 'srd:finesse'
  final String name;
  final Set<PropertyFlag> flags;
  final String? description;
}
```

Other catalog classes (`Size`, `CreatureType`, `Alignment`, `Language`, `SpellSchool`, `WeaponMastery`, `ArmorCategory`, `Rarity`) follow the same pattern: namespaced `id`, display fields, and (where relevant) a small set of Tier 0 flags the engine consults.

### Character

```dart
class Character {
  final String id;                               // UUID
  final String name;
  final List<CharacterClassLevel> classLevels;   // multiclass
  final ContentReference<Species> speciesId;
  final ContentReference<Lineage>? lineageId;
  final ContentReference<Background> backgroundId;
  final ContentReference<Alignment> alignmentId;
  final AbilityScores abilities;
  final ProficiencySet proficiencies;            // all by namespaced id (skills, saves by Ability, tools, weapons, armor)
  final HitPoints hp;
  final HitDicePool hitDice;
  final SpellSlots spellSlots;
  final PactMagicSlots? pactSlots;
  final PreparedSpells preparedSpells;
  final Inventory inventory;
  final List<ContentReference<Feat>> featIds;
  final Set<ContentReference<Condition>> activeConditionIds;
  final Map<ContentReference<Condition>, int> conditionDurationsRounds;
  final Exhaustion exhaustion;
  final DeathSaves deathSaves;
  final bool hasInspiration;
  final int experiencePoints;
  final Set<ContentReference<Language>> languageIds;

  int get totalLevel => classLevels.fold(0, (s, c) => s + c.level);
  int get proficiencyBonus => ProficiencyBonus.forLevel(totalLevel);
  int armorClassBase();   // pure: derives from inventory.equippedArmor + DEX + active effects
  int initiativeMod() => abilities.dex.modifier + (proficiencies.alertFeat ? proficiencyBonus : 0);
  int passivePerception();

  Character copyWith({...});
}
```

### Combatant (sealed)

```dart
sealed class Combatant {
  String get id;
  String get displayName;
  int get currentHp;
  int get maxHp;
  int get armorClass;
  int get initiativeRoll;
  Set<ContentReference<Condition>> get conditionIds;
  Map<ContentReference<Condition>, int> get conditionDurationsRounds;
  Concentration? get concentration;
  TurnState get turnState;
}

class PlayerCombatant extends Combatant {
  final Character character;       // reference
  final TokenPosition? mapPosition;
  ...
}

class MonsterCombatant extends Combatant {
  final Monster definition;        // shared definition
  final int instanceHp;            // rolled or chosen
  final TokenPosition? mapPosition;
  ...
}
```

### Spell

```dart
class Spell {
  final String id;                                           // 'srd:fireball'
  final String name;
  final SpellLevel level;
  final ContentReference<SpellSchool> schoolId;
  final CastingTime castingTime;
  final SpellRange range;
  final List<SpellComponent> components;
  final SpellDuration duration;
  final List<SpellTarget> targets;
  final AreaOfEffect? area;
  final List<EffectDescriptor> effects;                      // unified DSL (see §Effects)
  final bool ritual;
  final List<ContentReference<CharacterClass>> classListIds; // ['srd:wizard','srd:sorcerer']
  final String description;                                  // SRD verbatim when from SRD package
}
```

### Sealed AreaOfEffect

```dart
sealed class AreaOfEffect {
  bool includesOrigin();
}
class ConeAoE extends AreaOfEffect { final double lengthFt; ... }
class CubeAoE extends AreaOfEffect { final double sideFt; ... }
class CylinderAoE extends AreaOfEffect { final double radiusFt, heightFt; }
class EmanationAoE extends AreaOfEffect { final double distanceFt; }
class LineAoE extends AreaOfEffect { final double lengthFt, widthFt; }
class SphereAoE extends AreaOfEffect { final double radiusFt; }
```

### Item (sealed)

```dart
sealed class Item {
  String get id;                                       // namespaced
  String get name;
  double get weightLb;
  int get costCp;                                      // copper; avoid floats
  ContentReference<Rarity> get rarityId;
}
class Weapon extends Item {
  final WeaponCategory category;                       // Tier 0 enum: simple|martial
  final WeaponType type;                               // Tier 0 enum: melee|ranged
  final DiceExpression damage;
  final ContentReference<DamageType> damageTypeId;
  final Set<ContentReference<WeaponProperty>> propertyIds;
  final ContentReference<WeaponMastery>? masteryId;
  final RangePair? range;
  final DiceExpression? versatileDamage;
}
class Armor extends Item {
  final ContentReference<ArmorCategory> categoryId;
  ...
}
class Shield extends Item { ... }
class Gear extends Item { ... }
class MagicItem extends Item {
  final ContentReference<Item>? baseItemId;            // e.g., Plate Armor for +1 Plate
  final bool requiresAttunement;
  final AttunementPrereq? attunementPrereq;
  final List<EffectDescriptor> effects;
}
class Tool extends Item { ... }
class Ammunition extends Item { final int quantityPerStack; }
```

## Effects (Tier 2)

Content describes behavior via a closed, serializable sealed family. Engine logic in `application/dnd5e/services/` reads the descriptors and computes outcomes; content authors never write Dart. See [05-rule-engine-removal-spec.md](./05-rule-engine-removal-spec.md) for the `EffectCompiler` that turns descriptors into the `CompiledEffect` consumed by the attack/damage/save resolvers.

```dart
sealed class EffectDescriptor { /* no fields; each case declares its own */ }

class ModifyAttackRoll extends EffectDescriptor {
  final Predicate when;
  final int flatBonus;
  final AdvantageState advantage;
  final DiceExpression? extraDice;
  final EffectTarget appliesTo;   // attacker | targeted
}
class ModifyDamageRoll extends EffectDescriptor {
  final Predicate when;
  final int flatBonus;
  final DiceExpression? extraDice;
  final List<TypedDice> extraTypedDice;                // (dice, damageTypeId) pairs
  final ContentReference<DamageType>? damageTypeOverride;
}
class ModifySave extends EffectDescriptor {
  final Predicate when;
  final Ability ability;
  final int flatBonus;
  final AdvantageState advantage;
  final bool autoSucceed;
  final bool autoFail;
}
class ModifyAc extends EffectDescriptor {
  final Predicate when;
  final int flat;
  final AcFormula? formula;                             // flat | naturalPlusDex | unarmored(Ability) | mageArmor
}
class ModifyResistances extends EffectDescriptor {
  final Set<ContentReference<DamageType>> add;
  final Set<ContentReference<DamageType>> remove;
  final ResistanceKind kind;                            // resistance | immunity | vulnerability
}
class GrantCondition extends EffectDescriptor {
  final ContentReference<Condition> conditionId;
  final Duration duration;
  final SaveSpec? saveToResist;                         // {ability, dc}
}
class GrantProficiency extends EffectDescriptor {
  final ProficiencyKind kind;                           // save | skill | tool | weapon | armor | language
  final String targetId;                                // Ability short (for save) or namespaced id
  final Proficiency level;
}
class GrantSenseOrSpeed extends EffectDescriptor {
  final SenseOrSpeedKind kind;                          // darkvision | blindsight | tremorsense | walk | fly | swim | climb
  final int value;                                      // feet
}
class Heal extends EffectDescriptor {
  final DiceExpression? dice;
  final int flatBonus;
}
class ConditionInteraction extends EffectDescriptor {
  // Meta descriptor used by Condition.effects to declare what being under the condition does.
  final bool incapacitated;
  final bool speedZero;
  final Set<Ability> autoFailSavesOf;
  final bool imposedAdvantageOnAttacksAgainst;
  final bool attacksHaveDisadvantage;
  final bool cannotTakeActions;
  final bool cannotTakeReactions;
  final bool grappled;
  final bool restrained;
  final bool invisibleToSight;
  // ... closed list; extend only with cross-doc approval
}
class CustomEffect extends EffectDescriptor {
  final String implementationId;                        // 'srd:wish', 'srd:wild_shape'
  final Map<String, Object?> parameters;                // free-form payload for the registered impl
}
```

### Predicate (sealed)

```dart
sealed class Predicate { }
class Always extends Predicate { }
class All extends Predicate { final List<Predicate> all; }
class Any extends Predicate { final List<Predicate> any; }
class Not extends Predicate { final Predicate p; }
class AttackerHasCondition extends Predicate { final ContentReference<Condition> id; }
class TargetHasCondition   extends Predicate { final ContentReference<Condition> id; }
class AttackIsMelee        extends Predicate { }
class AttackIsRanged       extends Predicate { }
class AttackUsesAbility    extends Predicate { final Ability ability; }
class WeaponHasProperty    extends Predicate { final ContentReference<WeaponProperty> id; }
class DamageTypeIs         extends Predicate { final ContentReference<DamageType> id; }
class IsCritical           extends Predicate { }
class HasAdvantage         extends Predicate { }
class EffectActive         extends Predicate { final String effectId; }
```

Deliberately small and closed. No runtime-evaluated string expressions; no field access by name. Extensions require doc updates.

### Duration (sealed)

```dart
sealed class Duration { }
class Instantaneous   extends Duration { }
class RoundsDuration  extends Duration { final int rounds; }
class MinutesDuration extends Duration { final int minutes; }
class UntilRest       extends Duration { final RestKind kind; }        // short | long
class ConcentrationDuration extends Duration { final Duration max; }
class UntilRemoved    extends Duration { }
```

### CustomEffect registry

`CustomEffect.implementationId` resolves through an app-level registry:

```dart
abstract interface class CustomEffectImpl {
  String get id;                                        // 'srd:wish'
  CompiledEffect compile(Map<String, Object?> parameters);
}

class CustomEffectRegistry {
  void register(CustomEffectImpl impl);
  CustomEffectImpl? byId(String id);
}
```

Packages declare which `implementationId`s they depend on in `requiredRuntimeExtensions` ([14-package-system-redesign.md](./14-package-system-redesign.md)). Import fails fast when the runtime lacks an id. The SRD Core package's required set is enumerated in [15-srd-core-package.md](./15-srd-core-package.md).

## Invariants

- `AbilityScore.value ∈ [1, 30]`.
- `SpellLevel.value ∈ [0, 9]`.
- `Exhaustion.level ∈ [0, 6]`. Level 6 ⟹ character is dead (handled in service).
- `ChallengeRating.value` ∈ {0, 1/8, 1/4, 1/2, 1, 2, ..., 30}. Stored as `Fraction` or canonical string.
- `HitPoints.current ∈ [0, max]`. Damage clamps to 0; healing clamps to max.
- `Character.classLevels.length ≥ 1`.
- `Character.classLevels.every((cl) => cl.level ≥ 1)`.
- Multiclass: each entry's class must satisfy the prereq (13+ in primary ability).
- `SpellSlots.byLevel[N].current ≤ SpellSlots.byLevel[N].max`.
- `DeathSaves.successes ∈ [0,3]`, `failures ∈ [0,3]`. ≥3 of either ⟹ stable/dead transition.
- Every `ContentReference<T>` on a loaded entity resolves against the installed content registry. Enforced by `ContentRegistryValidator` at world load and at package import.

## Equality

Manual `==` and `hashCode` for value types. Use `id` for entity equality (Character, Monster, etc.).

## copyWith

Hand-written. Use `Object?` sentinels:

```dart
Character copyWith({String? name, Set<String>? activeConditionIds, ...}) =>
  Character(
    id: id,
    name: name ?? this.name,
    activeConditionIds: activeConditionIds ?? this.activeConditionIds,
    ...
  );
```

For removing optional values: separate `clearConcentration()` etc. methods.

## Open Questions

1. Should `Spell.description` be a `LocalizedString` even though SRD content stays English? → Default yes (i18n future-proof for homebrew).
2. Storage of CR: `Fraction` (custom) vs `double` vs canonical string? → **Recommend canonical string `'1/4'` + helper `toDouble()`.** Avoids float equality.
3. Do we need a `Creature` superclass for `Character | Monster`? → No; use `Combatant` sealed at the combat layer; `Character` and `Monster` are independent definitions.
4. Dangling `ContentReference` policy at world load? → **Fail-closed with user-visible warning** listing missing ids; offer "reinstall missing package" or "drop references" remediation. Do not silently null out.
5. Should `ConditionInteraction`'s flag set be a closed struct (current) or an extensible tag set? → Closed struct. Extensions go through this spec.
