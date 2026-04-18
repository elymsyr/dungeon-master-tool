# 01 — Domain Model Spec

> **For Claude.** Typed Dart entities replacing schema-driven `Entity { fields: Map }` model.
> **Source rules:** [00-dnd5e-mechanics-reference.md](./00-dnd5e-mechanics-reference.md)
> **Target package:** `flutter_app/lib/domain/dnd5e/`

## Conventions

- Pure immutable Dart classes. **No Freezed** (avoids codegen burden; manual `==`/`hashCode`/`copyWith`).
- All identifiers English. Field names `camelCase`. Class names `PascalCase`.
- Use sealed classes (Dart 3) for discriminated unions.
- No JSON serialization in domain layer — that lives in `data/dnd5e/mappers/`.
- All collections return `List<T>` typed (no `dynamic`).
- Validate invariants in factory constructors. Throw `ArgumentError` with specific message.
- No business logic in entities — only data + invariant guards. Logic in `application/dnd5e/services/`.

## Directory Layout

```
flutter_app/lib/domain/dnd5e/
├── core/
│   ├── ability.dart            # enum Ability { strength, dexterity, ... }
│   ├── ability_score.dart      # value class, 1..30 with modifier
│   ├── ability_scores.dart     # 6-tuple
│   ├── proficiency.dart        # enum Proficiency { none, half, full, expertise }
│   ├── proficiency_bonus.dart  # int compute from level
│   ├── skill.dart              # enum Skill { acrobatics, ... }
│   ├── damage_type.dart        # enum DamageType { acid, ... }
│   ├── condition.dart          # enum Condition { blinded, ... }
│   ├── size.dart               # enum Size { tiny, ... }
│   ├── creature_type.dart      # enum CreatureType { aberration, ... }
│   ├── alignment.dart          # enum Alignment { lawfulGood, ..., unaligned }
│   ├── language.dart           # enum + custom string for homebrew
│   ├── die.dart                # enum Die { d4, d6, d8, d10, d12, d20, d100 }
│   ├── dice_expression.dart    # parser + roller "2d6+3"
│   └── advantage_state.dart    # enum { normal, advantage, disadvantage }
├── character/
│   ├── character.dart          # PC root entity
│   ├── character_class_level.dart   # one entry per multiclass
│   ├── character_class.dart    # static class data (Barbarian, Fighter, ...)
│   ├── subclass.dart
│   ├── class_features_table.dart
│   ├── species.dart
│   ├── lineage.dart
│   ├── background.dart
│   ├── feat.dart
│   ├── proficiency_set.dart    # weapon/armor/tool/save/skill profs
│   ├── hit_points.dart         # current, max, temp
│   ├── hit_dice_pool.dart      # remaining HD per type
│   ├── death_saves.dart        # successes, failures
│   ├── exhaustion.dart         # 0..6
│   ├── spell_slots.dart        # per-level current/max
│   ├── pact_magic_slots.dart   # warlock-specific
│   ├── prepared_spells.dart
│   ├── inspiration.dart        # bool
│   └── inventory.dart          # List<InventoryEntry>
├── combat/
│   ├── encounter.dart
│   ├── combatant.dart          # sealed: PlayerCombatant | MonsterCombatant
│   ├── initiative.dart
│   ├── turn_state.dart         # actions used this turn
│   ├── action_economy.dart     # action / bonus / reaction flags
│   ├── concentration.dart      # spellId being concentrated
│   └── attack_resolution.dart  # AttackRoll, DamageRoll, SaveRoll value types
├── spell/
│   ├── spell.dart              # immutable Spell definition
│   ├── spell_level.dart        # int 0..9
│   ├── spell_school.dart       # enum
│   ├── spell_component.dart    # V/S/M with material desc + cost
│   ├── casting_time.dart       # sealed
│   ├── spell_range.dart        # sealed: Self/Touch/Distance/Sight
│   ├── spell_duration.dart     # sealed
│   ├── spell_target.dart       # sealed
│   ├── area_of_effect.dart     # sealed: Cone/Cube/Cylinder/Emanation/Line/Sphere
│   ├── spell_effect.dart       # sealed: Damage/Save/Attack/Heal/Condition/Custom
│   └── ritual_tag.dart
├── item/
│   ├── item.dart               # sealed: Weapon/Armor/Shield/Gear/MagicItem/Tool/Ammunition
│   ├── weapon.dart
│   ├── weapon_property.dart    # enum
│   ├── weapon_mastery.dart     # enum
│   ├── armor.dart
│   ├── armor_category.dart     # enum Light/Medium/Heavy
│   ├── magic_item.dart
│   ├── rarity.dart             # enum
│   └── attunement.dart
├── monster/
│   ├── monster.dart            # immutable monster definition
│   ├── stat_block.dart         # composition of all stat block fields
│   ├── monster_action.dart     # sealed: Attack/Multiattack/Save/Special
│   ├── challenge_rating.dart   # value class, with XP and PB lookup
│   └── legendary_action.dart
└── world/
    ├── campaign.dart           # replaces template-coupled Campaign
    ├── world.dart              # campaign container
    └── npc.dart                # tracked NPC (typed, not Entity)
```

## Key Type Signatures

### Ability

```dart
enum Ability { strength, dexterity, constitution, intelligence, wisdom, charisma;
  String get short => switch (this) {
    strength => 'STR', dexterity => 'DEX', constitution => 'CON',
    intelligence => 'INT', wisdom => 'WIS', charisma => 'CHA',
  };
}
```

### AbilityScore (value class)

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

### AbilityScores

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

### Character

```dart
class Character {
  final String id;                               // UUID
  final String name;
  final List<CharacterClassLevel> classLevels;   // multiclass
  final Species species;
  final Lineage? lineage;
  final Background background;
  final Alignment alignment;
  final AbilityScores abilities;
  final ProficiencySet proficiencies;
  final HitPoints hp;
  final HitDicePool hitDice;
  final SpellSlots spellSlots;
  final PactMagicSlots? pactSlots;
  final PreparedSpells preparedSpells;
  final Inventory inventory;
  final List<Feat> feats;
  final List<Condition> activeConditions;
  final Exhaustion exhaustion;
  final DeathSaves deathSaves;
  final bool hasInspiration;
  final int experiencePoints;
  final List<Language> languages;

  int get totalLevel => classLevels.fold(0, (s, c) => s + c.level);
  int get proficiencyBonus => ProficiencyBonus.forLevel(totalLevel);
  int armorClassBase();   // pure: derives from inventory.equippedArmor + DEX + features
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
  Set<Condition> get conditions;
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
  final String id;                     // 'srd:fireball'
  final String name;
  final SpellLevel level;
  final SpellSchool school;
  final CastingTime castingTime;
  final SpellRange range;
  final List<SpellComponent> components;
  final SpellDuration duration;
  final List<SpellTarget> targets;
  final AreaOfEffect? area;
  final List<SpellEffect> effects;     // sealed: Damage/Save/Attack/Heal/Condition/Custom
  final bool ritual;
  final List<String> classLists;       // ['wizard','sorcerer']
  final String description;            // SRD verbatim, English (license)
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
  String get id;
  String get name;
  double get weightLb;
  int get costCp;       // canonical in copper to avoid floats
  Rarity get rarity;
}
class Weapon extends Item {
  final WeaponCategory category;
  final WeaponType type;                // melee/ranged
  final DiceExpression damage;
  final DamageType damageType;
  final Set<WeaponProperty> properties;
  final WeaponMastery mastery;
  final RangePair? range;               // (normal, long) for ranged/thrown
  final DiceExpression? versatileDamage;
}
class Armor extends Item { ... }
class Shield extends Item { ... }
class Gear extends Item { ... }
class MagicItem extends Item {
  final Item? baseItem;                 // e.g., Plate Armor for +1 Plate
  final bool requiresAttunement;
  final AttunementPrereq? attunementPrereq;
  final List<MagicItemEffect> effects;
}
class Tool extends Item { ... }
class Ammunition extends Item { final int quantityPerStack; }
```

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

## Equality

Manual `==` and `hashCode` for value types. Use `id` for entity equality (Character, Monster, etc.).

## copyWith

Hand-written. Use `Object?` sentinels:

```dart
Character copyWith({String? name, List<Condition>? activeConditions, ...}) =>
  Character(
    id: id,
    name: name ?? this.name,
    activeConditions: activeConditions ?? this.activeConditions,
    ...
  );
```

For removing optional values: separate `clearConcentration()` etc. methods.

## Open Questions

1. Should `Spell.description` be a `LocalizedString` even though SRD content stays English? → Default yes (i18n future-proof for homebrew).
2. Storage of CR: `Fraction` (custom) vs `double` vs canonical string? → **Recommend canonical string `'1/4'` + helper `toDouble()`.** Avoids float equality.
3. Do we need a `Creature` superclass for `Character | Monster`? → No; use `Combatant` sealed at the combat layer; `Character` and `Monster` are independent definitions.
