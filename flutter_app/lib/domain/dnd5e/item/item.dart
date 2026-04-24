import '../catalog/content_reference.dart';
import '../core/ability.dart';
import '../core/dice_expression.dart';
import '../effect/effect_descriptor.dart';

/// Tier 0 enums keyed by engine for weapon dispatch.
enum WeaponCategory { simple, martial }

enum WeaponType { melee, ranged }

/// Normal/long range pair for ranged weapons. Both in feet.
class RangePair {
  final int normal;
  final int long;

  const RangePair._(this.normal, this.long);

  factory RangePair({required int normal, required int long}) {
    if (normal <= 0) throw ArgumentError('RangePair.normal must be > 0');
    if (long < normal) {
      throw ArgumentError('RangePair.long must be >= normal');
    }
    return RangePair._(normal, long);
  }

  @override
  bool operator ==(Object other) =>
      other is RangePair && other.normal == normal && other.long == long;
  @override
  int get hashCode => Object.hash(normal, long);
  @override
  String toString() => 'RangePair($normal/$long)';
}

/// Prerequisite a magic item may impose for attunement.
sealed class AttunementPrereq {
  const AttunementPrereq();
}

class AttunementByClass extends AttunementPrereq {
  final String classId;
  const AttunementByClass(this.classId);
  @override
  bool operator ==(Object other) =>
      other is AttunementByClass && other.classId == classId;
  @override
  int get hashCode => Object.hash('AttunementByClass', classId);
}

class AttunementBySpecies extends AttunementPrereq {
  final String speciesId;
  const AttunementBySpecies(this.speciesId);
  @override
  bool operator ==(Object other) =>
      other is AttunementBySpecies && other.speciesId == speciesId;
  @override
  int get hashCode => Object.hash('AttunementBySpecies', speciesId);
}

class AttunementByAlignment extends AttunementPrereq {
  final String alignmentId;
  const AttunementByAlignment(this.alignmentId);
  @override
  bool operator ==(Object other) =>
      other is AttunementByAlignment && other.alignmentId == alignmentId;
  @override
  int get hashCode => Object.hash('AttunementByAlignment', alignmentId);
}

class AttunementBySpellcaster extends AttunementPrereq {
  const AttunementBySpellcaster();
  @override
  bool operator ==(Object other) => other is AttunementBySpellcaster;
  @override
  int get hashCode => (AttunementBySpellcaster).hashCode;
}

/// Tier 1 root: every physical thing a character can pick up or use.
/// Sealed — engine dispatches on case for attack rolls, armor AC, etc.
sealed class Item {
  String get id;
  String get name;
  double get weightLb;
  int get costCp;
  String get rarityId;
}

class Weapon implements Item {
  @override
  final String id;
  @override
  final String name;
  @override
  final double weightLb;
  @override
  final int costCp;
  @override
  final String rarityId;
  final WeaponCategory category;
  final WeaponType type;
  final DiceExpression damage;
  final String damageTypeId;
  final Set<String> propertyIds;
  final String? masteryId;
  final RangePair? range;
  final DiceExpression? versatileDamage;

  Weapon._({
    required this.id,
    required this.name,
    required this.weightLb,
    required this.costCp,
    required this.rarityId,
    required this.category,
    required this.type,
    required this.damage,
    required this.damageTypeId,
    required this.propertyIds,
    required this.masteryId,
    required this.range,
    required this.versatileDamage,
  });

  factory Weapon({
    required String id,
    required String name,
    double weightLb = 0,
    int costCp = 0,
    required String rarityId,
    required WeaponCategory category,
    required WeaponType type,
    required DiceExpression damage,
    required String damageTypeId,
    Set<String> propertyIds = const {},
    String? masteryId,
    RangePair? range,
    DiceExpression? versatileDamage,
  }) {
    _validateItemBase(id: id, name: name, weightLb: weightLb, costCp: costCp);
    validateContentId(rarityId);
    validateContentId(damageTypeId);
    for (final p in propertyIds) {
      validateContentId(p);
    }
    if (masteryId != null) validateContentId(masteryId);
    if (type == WeaponType.ranged && range == null) {
      throw ArgumentError('Ranged Weapon requires RangePair');
    }
    return Weapon._(
      id: id,
      name: name,
      weightLb: weightLb,
      costCp: costCp,
      rarityId: rarityId,
      category: category,
      type: type,
      damage: damage,
      damageTypeId: damageTypeId,
      propertyIds: Set.unmodifiable(propertyIds),
      masteryId: masteryId,
      range: range,
      versatileDamage: versatileDamage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Weapon && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class Armor implements Item {
  @override
  final String id;
  @override
  final String name;
  @override
  final double weightLb;
  @override
  final int costCp;
  @override
  final String rarityId;
  final String categoryId;
  final int baseAc;
  final int? strengthRequirement;

  Armor._({
    required this.id,
    required this.name,
    required this.weightLb,
    required this.costCp,
    required this.rarityId,
    required this.categoryId,
    required this.baseAc,
    required this.strengthRequirement,
  });

  factory Armor({
    required String id,
    required String name,
    double weightLb = 0,
    int costCp = 0,
    required String rarityId,
    required String categoryId,
    required int baseAc,
    int? strengthRequirement,
  }) {
    _validateItemBase(id: id, name: name, weightLb: weightLb, costCp: costCp);
    validateContentId(rarityId);
    validateContentId(categoryId);
    if (baseAc < 10) throw ArgumentError('Armor.baseAc must be >= 10');
    if (strengthRequirement != null &&
        (strengthRequirement < 1 || strengthRequirement > 30)) {
      throw ArgumentError('Armor.strengthRequirement must be in [1, 30]');
    }
    return Armor._(
      id: id,
      name: name,
      weightLb: weightLb,
      costCp: costCp,
      rarityId: rarityId,
      categoryId: categoryId,
      baseAc: baseAc,
      strengthRequirement: strengthRequirement,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Armor && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class Shield implements Item {
  @override
  final String id;
  @override
  final String name;
  @override
  final double weightLb;
  @override
  final int costCp;
  @override
  final String rarityId;
  final int acBonus;

  Shield._(this.id, this.name, this.weightLb, this.costCp, this.rarityId,
      this.acBonus);

  factory Shield({
    required String id,
    required String name,
    double weightLb = 0,
    int costCp = 0,
    required String rarityId,
    int acBonus = 2,
  }) {
    _validateItemBase(id: id, name: name, weightLb: weightLb, costCp: costCp);
    validateContentId(rarityId);
    if (acBonus < 0) throw ArgumentError('Shield.acBonus must be >= 0');
    return Shield._(id, name, weightLb, costCp, rarityId, acBonus);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Shield && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class Gear implements Item {
  @override
  final String id;
  @override
  final String name;
  @override
  final double weightLb;
  @override
  final int costCp;
  @override
  final String rarityId;
  final String description;

  Gear._(this.id, this.name, this.weightLb, this.costCp, this.rarityId,
      this.description);

  factory Gear({
    required String id,
    required String name,
    double weightLb = 0,
    int costCp = 0,
    required String rarityId,
    String description = '',
  }) {
    _validateItemBase(id: id, name: name, weightLb: weightLb, costCp: costCp);
    validateContentId(rarityId);
    return Gear._(id, name, weightLb, costCp, rarityId, description);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Gear && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class Tool implements Item {
  @override
  final String id;
  @override
  final String name;
  @override
  final double weightLb;
  @override
  final int costCp;
  @override
  final String rarityId;
  final String? proficiencyId;

  Tool._(this.id, this.name, this.weightLb, this.costCp, this.rarityId,
      this.proficiencyId);

  factory Tool({
    required String id,
    required String name,
    double weightLb = 0,
    int costCp = 0,
    required String rarityId,
    String? proficiencyId,
  }) {
    _validateItemBase(id: id, name: name, weightLb: weightLb, costCp: costCp);
    validateContentId(rarityId);
    if (proficiencyId != null) validateContentId(proficiencyId);
    return Tool._(id, name, weightLb, costCp, rarityId, proficiencyId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Tool && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class Ammunition implements Item {
  @override
  final String id;
  @override
  final String name;
  @override
  final double weightLb;
  @override
  final int costCp;
  @override
  final String rarityId;
  final int quantityPerStack;

  Ammunition._(this.id, this.name, this.weightLb, this.costCp, this.rarityId,
      this.quantityPerStack);

  factory Ammunition({
    required String id,
    required String name,
    double weightLb = 0,
    int costCp = 0,
    required String rarityId,
    int quantityPerStack = 1,
  }) {
    _validateItemBase(id: id, name: name, weightLb: weightLb, costCp: costCp);
    validateContentId(rarityId);
    if (quantityPerStack <= 0) {
      throw ArgumentError('Ammunition.quantityPerStack must be > 0');
    }
    return Ammunition._(
        id, name, weightLb, costCp, rarityId, quantityPerStack);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Ammunition && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// A spell granted by a magic item that consumes charges when cast.
/// The item's charge pool and recharge cadence are tracked on the character's
/// inventory (equipped-item state), not here.
class ChargedSpell {
  final ContentReference spellId;
  final int chargesCost;

  const ChargedSpell._(this.spellId, this.chargesCost);

  factory ChargedSpell({required String spellId, int chargesCost = 1}) {
    validateContentId(spellId);
    if (chargesCost < 1) {
      throw ArgumentError('ChargedSpell.chargesCost must be >= 1');
    }
    return ChargedSpell._(spellId, chargesCost);
  }

  @override
  bool operator ==(Object other) =>
      other is ChargedSpell &&
      other.spellId == spellId &&
      other.chargesCost == chargesCost;

  @override
  int get hashCode => Object.hash(spellId, chargesCost);

  @override
  String toString() => 'ChargedSpell($spellId, $chargesCost)';
}

class MagicItem implements Item {
  @override
  final String id;
  @override
  final String name;
  @override
  final double weightLb;
  @override
  final int costCp;
  @override
  final String rarityId;
  final String? baseItemId;
  final bool requiresAttunement;
  final AttunementPrereq? attunementPrereq;
  final List<EffectDescriptor> effects;

  /// Spells that become known to the wielder while the item is equipped
  /// (Cloak of Displacement: none; Ioun Stone of Mastery: none; but e.g.
  /// Ring of Three Wishes grants Wish known — no save/att-roll bonus, a
  /// pure "you now know this spell" grant). Distinguished from [effects]
  /// because EffectDescriptor has no `GrantSpellKnown` variant today.
  final List<ContentReference> grantsSpellIds;

  /// Spells castable from the item's own charge pool (Wand of Fireballs:
  /// 7 charges, fireball costs 3). Character doesn't "know" them — they
  /// consume the item's charges, not the caster's slots.
  final List<ChargedSpell> grantsChargedSpells;

  /// Flat AC bonus while equipped (Cloak of Protection +1, Bracers of
  /// Defense +2). Stacks with base armor per SRD attunement rules.
  final int acBonus;

  /// Fixed ability-score bonuses (Gauntlets of Ogre Power → STR 19
  /// semantics are modeled via effects; simple +N bonuses like Amulet of
  /// Health live here).
  final Map<Ability, int> abilityBonuses;

  MagicItem._({
    required this.id,
    required this.name,
    required this.weightLb,
    required this.costCp,
    required this.rarityId,
    required this.baseItemId,
    required this.requiresAttunement,
    required this.attunementPrereq,
    required this.effects,
    required this.grantsSpellIds,
    required this.grantsChargedSpells,
    required this.acBonus,
    required this.abilityBonuses,
  });

  factory MagicItem({
    required String id,
    required String name,
    double weightLb = 0,
    int costCp = 0,
    required String rarityId,
    String? baseItemId,
    bool requiresAttunement = false,
    AttunementPrereq? attunementPrereq,
    List<EffectDescriptor> effects = const [],
    List<ContentReference> grantsSpellIds = const [],
    List<ChargedSpell> grantsChargedSpells = const [],
    int acBonus = 0,
    Map<Ability, int> abilityBonuses = const {},
  }) {
    _validateItemBase(id: id, name: name, weightLb: weightLb, costCp: costCp);
    validateContentId(rarityId);
    if (baseItemId != null) validateContentId(baseItemId);
    if (!requiresAttunement && attunementPrereq != null) {
      throw ArgumentError(
          'MagicItem.attunementPrereq requires requiresAttunement = true');
    }
    for (final spellId in grantsSpellIds) {
      validateContentId(spellId);
    }
    return MagicItem._(
      id: id,
      name: name,
      weightLb: weightLb,
      costCp: costCp,
      rarityId: rarityId,
      baseItemId: baseItemId,
      requiresAttunement: requiresAttunement,
      attunementPrereq: attunementPrereq,
      effects: List.unmodifiable(effects),
      grantsSpellIds: List.unmodifiable(grantsSpellIds),
      grantsChargedSpells: List.unmodifiable(grantsChargedSpells),
      acBonus: acBonus,
      abilityBonuses: Map.unmodifiable(abilityBonuses),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MagicItem && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

void _validateItemBase({
  required String id,
  required String name,
  required double weightLb,
  required int costCp,
}) {
  validateContentId(id);
  if (name.isEmpty) throw ArgumentError('Item.name must not be empty');
  if (weightLb < 0) throw ArgumentError('Item.weightLb must be >= 0');
  if (costCp < 0) throw ArgumentError('Item.costCp must be >= 0');
}
