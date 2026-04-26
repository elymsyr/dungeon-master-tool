// SRD 5.2.1 Creature Actions — actions / bonus / reaction / legendary / lair
// extracted from monster stat blocks (pp. 258–364). Shared actions are
// authored once and referenced by name from each monster.

import '_helpers.dart';

/// Build a creature-action package row.
Map<String, dynamic> _a({
  required String name,
  required String actionType, // Action / Bonus Action / Reaction / Legendary Action / Lair Action
  required String description,
  bool isAttack = false,
  String? attackKind,
  int? attackBonus,
  int? reachFt,
  int? rangeNormalFt,
  int? rangeLongFt,
  String? damageDice,
  String? damageType,
  int? saveDc,
  String? saveAbility,
  String rechargeKind = 'None',
  int? rechargeMinRoll,
  int? usesPerDay,
  List<String> conditions = const [],
  String source = 'SRD 5.2.1',
}) {
  final attrs = <String, dynamic>{
    'source': source,
    'action_type': actionType,
    'description': description,
    'is_attack': isAttack,
    'recharge_kind': rechargeKind,
  };
  if (attackKind != null) attrs['attack_kind'] = attackKind;
  if (attackBonus != null) attrs['attack_bonus'] = attackBonus;
  if (reachFt != null) attrs['reach_ft'] = reachFt;
  if (rangeNormalFt != null) attrs['range_normal_ft'] = rangeNormalFt;
  if (rangeLongFt != null) attrs['range_long_ft'] = rangeLongFt;
  if (damageDice != null) attrs['damage_dice'] = damageDice;
  if (damageType != null) {
    attrs['damage_type_ref'] = lookup('damage-type', damageType);
  }
  if (saveDc != null) attrs['save_dc'] = saveDc;
  if (saveAbility != null) {
    attrs['save_ability_ref'] = lookup('ability', saveAbility);
  }
  if (rechargeMinRoll != null) attrs['recharge_min_roll'] = rechargeMinRoll;
  if (usesPerDay != null) attrs['uses_per_day'] = usesPerDay;
  if (conditions.isNotEmpty) {
    attrs['applied_condition_refs'] = [
      for (final c in conditions) lookup('condition', c),
    ];
  }
  return packEntity(
    slug: 'creature-action',
    name: name,
    description: description,
    attributes: attrs,
  );
}

List<Map<String, dynamic>> srdCreatureActions() => [
      // Generic Multiattack — referenced by many monsters.
      _a(
        name: 'Multiattack',
        actionType: 'Action',
        description:
            'The creature makes multiple attacks; the exact mix is given in its stat block.',
      ),

      // ─── Aboleth ─────────────────────────────────────────────────────────
      _a(
        name: 'Tentacle (Aboleth)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 9,
        reachFt: 15,
        damageDice: '2d6+5',
        damageType: 'Bludgeoning',
        description:
            '*Melee Attack Roll:* +9, reach 15 ft. *Hit:* 12 (2d6 + 5) Bludgeoning damage. If the target is a creature, it must succeed on a DC 14 Constitution save or be cursed with Aboleth Tentacle Disease.',
      ),
      _a(
        name: 'Psychic Drain',
        actionType: 'Action',
        description:
            'One creature charmed by the aboleth that the aboleth can see within 30 feet of itself takes 36 (8d8) Psychic damage and is no longer charmed.',
        damageDice: '8d8',
        damageType: 'Psychic',
      ),
      _a(
        name: 'Tail Swipe',
        actionType: 'Legendary Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 9,
        reachFt: 10,
        damageDice: '3d6+5',
        damageType: 'Bludgeoning',
        description:
            '*Melee Attack Roll:* +9, reach 10 ft. *Hit:* 15 (3d6 + 5) Bludgeoning damage.',
      ),
      _a(
        name: 'Psychic Slash',
        actionType: 'Legendary Action',
        description:
            'One creature within 30 feet that the aboleth can see takes 17 (4d8) Psychic damage.',
        damageDice: '4d8',
        damageType: 'Psychic',
      ),

      // ─── Goblin actions ──────────────────────────────────────────────────
      _a(
        name: 'Scimitar (Goblin)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 4,
        reachFt: 5,
        damageDice: '1d6+2',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Slashing damage.',
      ),
      _a(
        name: 'Shortbow (Goblin)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Ranged Weapon',
        attackBonus: 4,
        rangeNormalFt: 80,
        rangeLongFt: 320,
        damageDice: '1d6+2',
        damageType: 'Piercing',
        description:
            '*Ranged Attack Roll:* +4, range 80/320 ft. *Hit:* 5 (1d6 + 2) Piercing damage.',
      ),
      _a(
        name: 'Nimble Escape',
        actionType: 'Bonus Action',
        description:
            'The goblin takes the Disengage or Hide action.',
      ),

      // ─── Wolf actions ────────────────────────────────────────────────────
      _a(
        name: 'Bite (Wolf)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 4,
        reachFt: 5,
        damageDice: '2d4+2',
        damageType: 'Piercing',
        saveDc: 11,
        saveAbility: 'Strength',
        conditions: ['Prone'],
        description:
            '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (2d4 + 2) Piercing damage. If the target is a Large or smaller creature, it must succeed on a DC 11 Strength save or have the Prone condition.',
      ),

      // ─── Skeleton actions ────────────────────────────────────────────────
      _a(
        name: 'Shortsword (Skeleton)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 4,
        reachFt: 5,
        damageDice: '1d6+2',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.',
      ),
      _a(
        name: 'Shortbow (Skeleton)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Ranged Weapon',
        attackBonus: 4,
        rangeNormalFt: 80,
        rangeLongFt: 320,
        damageDice: '1d6+2',
        damageType: 'Piercing',
        description:
            '*Ranged Attack Roll:* +4, range 80/320 ft. *Hit:* 5 (1d6 + 2) Piercing damage.',
      ),

      // ─── Zombie actions ──────────────────────────────────────────────────
      _a(
        name: 'Slam (Zombie)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 3,
        reachFt: 5,
        damageDice: '1d6+1',
        damageType: 'Bludgeoning',
        description:
            '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Bludgeoning damage.',
      ),

      // ─── Generic animal actions ──────────────────────────────────────────
      _a(
        name: 'Bite (Brown Bear)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '1d8+4',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 8 (1d8 + 4) Piercing damage.',
      ),
      _a(
        name: 'Claws (Brown Bear)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '2d6+4',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 11 (2d6 + 4) Slashing damage.',
      ),
      _a(
        name: 'Bite (Giant Spider)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '1d8+3',
        damageType: 'Piercing',
        saveDc: 11,
        saveAbility: 'Constitution',
        conditions: ['Poisoned'],
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 7 (1d8 + 3) Piercing damage plus 9 (2d8) Poison damage, and the target must succeed on a DC 11 Constitution save or be Poisoned for 1 hour.',
      ),
      _a(
        name: 'Web (Giant Spider)',
        actionType: 'Action',
        rechargeKind: 'Roll',
        rechargeMinRoll: 5,
        saveDc: 11,
        saveAbility: 'Dexterity',
        conditions: ['Restrained'],
        description:
            '*Ranged*, range 30/60 ft. *Dexterity Saving Throw:* DC 11. *Failure:* The target has the Restrained condition until the web is destroyed (AC 10, HP 5; immune to Poison and Psychic damage). (Recharge 5–6).',
      ),
    ];
