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

      // ─── Adult Red Dragon actions ───────────────────────────────────────
      _a(
        name: 'Rend (Adult Red Dragon)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 14,
        reachFt: 10,
        damageDice: '2d10+8',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +14, reach 10 ft. *Hit:* 19 (2d10 + 8) Slashing damage plus 9 (2d8) Fire damage.',
      ),
      _a(
        name: 'Fire Breath',
        actionType: 'Action',
        rechargeKind: 'Roll',
        rechargeMinRoll: 5,
        saveDc: 21,
        saveAbility: 'Dexterity',
        damageDice: '18d10',
        damageType: 'Fire',
        description:
            '*Constitution Saving Throw:* DC 21, each creature in a 60-foot Cone. *Failure:* 99 (18d10) Fire damage. *Success:* Half damage. (Recharge 5–6).',
      ),
      _a(
        name: 'Commanding Presence',
        actionType: 'Legendary Action',
        saveDc: 18,
        saveAbility: 'Wisdom',
        conditions: ['Frightened'],
        description:
            'The dragon uses Spellcasting to cast Command (level 2 version), using the same spellcasting ability as its Spellcasting trait. The dragon can\'t take this action again until the start of its next turn.',
      ),
      _a(
        name: 'Frightful Presence',
        actionType: 'Legendary Action',
        saveDc: 18,
        saveAbility: 'Wisdom',
        conditions: ['Frightened'],
        description:
            '*Wisdom Saving Throw:* DC 18, each creature in a 60-foot Emanation originating from the dragon that isn\'t already Frightened. *Failure:* The target has the Frightened condition until the start of the dragon\'s next turn.',
      ),
      _a(
        name: 'Tail Attack',
        actionType: 'Legendary Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 14,
        reachFt: 15,
        damageDice: '2d8+8',
        damageType: 'Bludgeoning',
        description:
            '*Melee Attack Roll:* +14, reach 15 ft. *Hit:* 17 (2d8 + 8) Bludgeoning damage.',
      ),

      // ─── Lich actions ───────────────────────────────────────────────────
      _a(
        name: 'Eldritch Burst',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Ranged Spell',
        attackBonus: 12,
        rangeNormalFt: 120,
        damageDice: '4d12',
        damageType: 'Force',
        description:
            '*Melee or Ranged Attack Roll:* +12, reach 5 ft. or range 120 ft. *Hit:* 31 (4d12 + 5) Force damage.',
      ),
      _a(
        name: 'Paralyzing Touch',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Spell',
        attackBonus: 12,
        reachFt: 5,
        damageDice: '3d6',
        damageType: 'Cold',
        saveDc: 18,
        saveAbility: 'Constitution',
        conditions: ['Paralyzed'],
        description:
            '*Melee Attack Roll:* +12, reach 5 ft. *Hit:* 15 (3d6 + 5) Cold damage, and the target must succeed on a DC 18 Constitution save or have the Paralyzed condition for 1 minute. The target repeats the save at the end of each of its turns.',
      ),

      // ─── Beholder actions ───────────────────────────────────────────────
      _a(
        name: 'Bite (Beholder)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '2d6',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 9 (2d6 + 2) Piercing damage.',
      ),
      _a(
        name: 'Eye Rays',
        actionType: 'Action',
        description:
            'The beholder shoots three of the following magical eye rays at random (rerolling duplicates), choosing one to three targets it can see within 120 feet of itself: Charm Ray, Paralyzing Ray, Fear Ray, Slowing Ray, Enervation Ray, Telekinetic Ray, Sleep Ray, Petrification Ray, Disintegration Ray, Death Ray. See the SRD beholder stat block for each ray\'s save DC and effect.',
      ),
      _a(
        name: 'Eye Ray (Lair)',
        actionType: 'Legendary Action',
        description:
            'The beholder uses Eye Rays. The beholder can\'t take this action again until the start of its next turn.',
      ),

      // ─── Mind Flayer actions ────────────────────────────────────────────
      _a(
        name: 'Tentacles',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 7,
        reachFt: 5,
        damageDice: '2d10+4',
        damageType: 'Psychic',
        saveDc: 15,
        saveAbility: 'Intelligence',
        conditions: ['Stunned'],
        description:
            '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 15 (2d10 + 4) Psychic damage. If the target is a Medium or smaller creature, it has the Grappled condition (escape DC 15) and the Stunned condition until the grapple ends.',
      ),
      _a(
        name: 'Mind Blast',
        actionType: 'Action',
        rechargeKind: 'Roll',
        rechargeMinRoll: 5,
        saveDc: 15,
        saveAbility: 'Intelligence',
        damageDice: '4d8+4',
        damageType: 'Psychic',
        conditions: ['Stunned'],
        description:
            '*Intelligence Saving Throw:* DC 15, each creature in a 60-foot Cone. *Failure:* 22 (4d8 + 4) Psychic damage and the target has the Stunned condition until the end of the mind flayer\'s next turn. *Success:* Half damage only. (Recharge 5–6).',
      ),
      _a(
        name: 'Extract Brain',
        actionType: 'Action',
        isAttack: true,
        damageDice: '10d10',
        damageType: 'Piercing',
        description:
            'The mind flayer targets a Humanoid it is grappling. *Melee Attack Roll:* +7, reach 5 ft. *Hit:* 55 (10d10) Piercing damage. If this damage reduces the target to 0 HP, the mind flayer kills it by extracting its brain.',
      ),

      // ─── Ogre actions ───────────────────────────────────────────────────
      _a(
        name: 'Greatclub',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 6,
        reachFt: 5,
        damageDice: '2d8+4',
        damageType: 'Bludgeoning',
        description:
            '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 13 (2d8 + 4) Bludgeoning damage.',
      ),
      _a(
        name: 'Javelin (Ogre)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Ranged Weapon',
        attackBonus: 6,
        rangeNormalFt: 30,
        rangeLongFt: 120,
        damageDice: '2d6+4',
        damageType: 'Piercing',
        description:
            '*Melee or Ranged Attack Roll:* +6, reach 5 ft. or range 30/120 ft. *Hit:* 11 (2d6 + 4) Piercing damage.',
      ),

      // ─── Owlbear actions ────────────────────────────────────────────────
      _a(
        name: 'Beak (Owlbear)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 7,
        reachFt: 5,
        damageDice: '1d10+5',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 10 (1d10 + 5) Piercing damage.',
      ),
      _a(
        name: 'Claws (Owlbear)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 7,
        reachFt: 5,
        damageDice: '2d8+5',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 14 (2d8 + 5) Slashing damage.',
      ),

      // ─── Hobgoblin Warrior actions ──────────────────────────────────────
      _a(
        name: 'Longsword (Hobgoblin)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 3,
        reachFt: 5,
        damageDice: '1d8+1',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 5 (1d8 + 1) Slashing damage, or 6 (1d10 + 1) Slashing damage if used with two hands.',
      ),
      _a(
        name: 'Longbow (Hobgoblin)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Ranged Weapon',
        attackBonus: 3,
        rangeNormalFt: 150,
        rangeLongFt: 600,
        damageDice: '1d8+1',
        damageType: 'Piercing',
        description:
            '*Ranged Attack Roll:* +3, range 150/600 ft. *Hit:* 5 (1d8 + 1) Piercing damage.',
      ),

      // ─── Bandit actions ─────────────────────────────────────────────────
      _a(
        name: 'Scimitar (Bandit)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 3,
        reachFt: 5,
        damageDice: '1d6+1',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Slashing damage.',
      ),
      _a(
        name: 'Light Crossbow (Bandit)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Ranged Weapon',
        attackBonus: 3,
        rangeNormalFt: 80,
        rangeLongFt: 320,
        damageDice: '1d8+1',
        damageType: 'Piercing',
        description:
            '*Ranged Attack Roll:* +3, range 80/320 ft. *Hit:* 5 (1d8 + 1) Piercing damage.',
      ),

      // ─── Animal actions (added) ─────────────────────────────────────────
      _a(
        name: 'Talons (Giant Eagle)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '2d6+3',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Slashing damage.',
      ),
      _a(
        name: 'Bite (Dire Wolf)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '2d6+3',
        damageType: 'Piercing',
        saveDc: 13,
        saveAbility: 'Strength',
        conditions: ['Prone'],
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Piercing damage. If the target is a Large or smaller creature, it must succeed on a DC 13 Strength save or have the Prone condition.',
      ),
      _a(
        name: 'Bite (Tiger)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '1d10+3',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 8 (1d10 + 3) Piercing damage.',
      ),
      _a(
        name: 'Claws (Tiger)',
        actionType: 'Bonus Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '2d6+3',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Slashing damage.',
      ),
      _a(
        name: 'Bite (Lion)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '1d8+3',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 7 (1d8 + 3) Piercing damage.',
      ),
      _a(
        name: 'Bite (Crocodile)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 4,
        reachFt: 5,
        damageDice: '1d10+2',
        damageType: 'Piercing',
        conditions: ['Grappled'],
        description:
            '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (1d10 + 2) Piercing damage, and the target has the Grappled condition (escape DC 12).',
      ),
      _a(
        name: 'Tusk (Boar)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 3,
        reachFt: 5,
        damageDice: '1d6+1',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Slashing damage. If the boar moved 20+ ft. straight toward the target before the hit, the damage is increased by 3 (1d6) and the target must succeed on a DC 11 Strength save or have the Prone condition.',
      ),
      _a(
        name: 'Bite (Mastiff)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 3,
        reachFt: 5,
        damageDice: '1d6+1',
        damageType: 'Piercing',
        saveDc: 11,
        saveAbility: 'Strength',
        conditions: ['Prone'],
        description:
            '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Piercing damage. If the target is a Medium or smaller creature, it must succeed on a DC 11 Strength save or have the Prone condition.',
      ),
      _a(
        name: 'Hooves (Riding Horse)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 2,
        reachFt: 5,
        damageDice: '2d4+1',
        damageType: 'Bludgeoning',
        description:
            '*Melee Attack Roll:* +2, reach 5 ft. *Hit:* 6 (2d4 + 1) Bludgeoning damage.',
      ),

      // ─── Kobold ─────────────────────────────────────────────────────────
      _a(
        name: 'Dagger (Kobold)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 4,
        reachFt: 5,
        damageDice: '1d4+2',
        damageType: 'Piercing',
        description:
            '*Melee or Ranged Attack Roll:* +4, reach 5 ft. or range 20/60 ft. *Hit:* 4 (1d4 + 2) Piercing damage.',
      ),
      _a(
        name: 'Sling (Kobold)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Ranged Weapon',
        attackBonus: 4,
        rangeNormalFt: 30,
        rangeLongFt: 120,
        damageDice: '1d4+2',
        damageType: 'Bludgeoning',
        description:
            '*Ranged Attack Roll:* +4, range 30/120 ft. *Hit:* 4 (1d4 + 2) Bludgeoning damage.',
      ),

      // ─── Orc ────────────────────────────────────────────────────────────
      _a(
        name: 'Greataxe (Orc)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '1d12+3',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 9 (1d12 + 3) Slashing damage.',
      ),
      _a(
        name: 'Javelin (Orc)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Ranged Weapon',
        attackBonus: 5,
        rangeNormalFt: 30,
        rangeLongFt: 120,
        damageDice: '1d6+3',
        damageType: 'Piercing',
        description:
            '*Melee or Ranged Attack Roll:* +5, reach 5 ft. or range 30/120 ft. *Hit:* 6 (1d6 + 3) Piercing damage.',
      ),

      // ─── Gnoll ──────────────────────────────────────────────────────────
      _a(
        name: 'Bite (Gnoll)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 4,
        reachFt: 5,
        damageDice: '1d4+2',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage.',
      ),
      _a(
        name: 'Spear (Gnoll)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 4,
        reachFt: 5,
        damageDice: '1d6+2',
        damageType: 'Piercing',
        description:
            '*Melee or Ranged Attack Roll:* +4, reach 5 ft. or range 20/60 ft. *Hit:* 5 (1d6 + 2) Piercing damage.',
      ),

      // ─── Bugbear ────────────────────────────────────────────────────────
      _a(
        name: 'Morningstar (Bugbear)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 4,
        reachFt: 5,
        damageDice: '2d8+2',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 11 (2d8 + 2) Piercing damage.',
      ),
      _a(
        name: 'Javelin (Bugbear)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 4,
        reachFt: 5,
        damageDice: '2d6+2',
        damageType: 'Piercing',
        description:
            '*Melee or Ranged Attack Roll:* +4, reach 5 ft. or range 30/120 ft. *Hit:* 9 (2d6 + 2) Piercing damage.',
      ),

      // ─── Drow ───────────────────────────────────────────────────────────
      _a(
        name: 'Rapier (Drow)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 4,
        reachFt: 5,
        damageDice: '1d8+2',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 6 (1d8 + 2) Piercing damage.',
      ),
      _a(
        name: 'Hand Crossbow (Drow)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Ranged Weapon',
        attackBonus: 4,
        rangeNormalFt: 30,
        rangeLongFt: 120,
        damageDice: '1d6+2',
        damageType: 'Piercing',
        saveDc: 13,
        saveAbility: 'Constitution',
        description:
            '*Ranged Attack Roll:* +4, range 30/120 ft. *Hit:* 5 (1d6 + 2) Piercing damage. The target must succeed on a DC 13 Con save or have the Poisoned condition for 1 hour. If the save fails by 5 or more, the target also has the Unconscious condition while Poisoned in this way; the target wakes up if it takes damage or another creature uses an action to shake it awake.',
      ),

      // ─── Werewolf ───────────────────────────────────────────────────────
      _a(
        name: 'Bite (Werewolf)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '1d8+3',
        damageType: 'Piercing',
        saveDc: 12,
        saveAbility: 'Constitution',
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. (hybrid or wolf form only). *Hit:* 7 (1d8 + 3) Piercing damage. If the target is a Humanoid, it must succeed on a DC 12 Con save or be cursed with werewolf lycanthropy.',
      ),
      _a(
        name: 'Claws (Werewolf)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '2d4+3',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. (hybrid form only). *Hit:* 8 (2d4 + 3) Slashing damage.',
      ),

      // ─── Troll ──────────────────────────────────────────────────────────
      _a(
        name: 'Bite (Troll)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 7,
        reachFt: 5,
        damageDice: '1d6+4',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 7 (1d6 + 4) Piercing damage.',
      ),
      _a(
        name: 'Claws (Troll)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 7,
        reachFt: 5,
        damageDice: '2d6+4',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 11 (2d6 + 4) Slashing damage.',
      ),

      // ─── Hydra ──────────────────────────────────────────────────────────
      _a(
        name: 'Bite (Hydra)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 8,
        reachFt: 10,
        damageDice: '1d10+5',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +8, reach 10 ft. *Hit:* 10 (1d10 + 5) Piercing damage. The hydra makes one Bite attack per head.',
      ),

      // ─── Vampire ────────────────────────────────────────────────────────
      _a(
        name: 'Vampire Bite',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 9,
        reachFt: 5,
        damageDice: '1d6+4',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +9 (with Advantage if target is Grappled, Incapacitated, or Restrained), reach 5 ft. *Hit:* 7 (1d6 + 4) Piercing damage plus 10 (3d6) Necrotic damage. The target\'s HP maximum is reduced by an amount equal to the Necrotic damage taken, and the vampire regains HP equal to that amount. If the target is reduced to 0 HP by this attack, it dies; if the target was a Humanoid, it rises 24 hours later as a Vampire Spawn under the vampire\'s control.',
      ),
      _a(
        name: 'Charm (Vampire)',
        actionType: 'Action',
        saveDc: 17,
        saveAbility: 'Wisdom',
        conditions: ['Charmed'],
        description:
            'The vampire targets one Humanoid it can see within 30 feet. The target must succeed on a DC 17 Wisdom save or have the Charmed condition for 24 hours, regarding the vampire as a trusted friend. The Charmed target obeys the vampire\'s spoken commands. The target is unaware of being treated this way.',
      ),

      // ─── Demon (Balor) ──────────────────────────────────────────────────
      _a(
        name: 'Flame Whip (Balor)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 14,
        reachFt: 30,
        damageDice: '2d6+8',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +14, reach 30 ft. *Hit:* 15 (2d6 + 8) Slashing damage plus 10 (3d6) Fire damage.',
      ),
      _a(
        name: 'Lightning Sword (Balor)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 14,
        reachFt: 10,
        damageDice: '3d8+8',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +14, reach 10 ft. *Hit:* 21 (3d8 + 8) Slashing damage plus 13 (3d8) Lightning damage.',
      ),

      // ─── Pit Fiend ──────────────────────────────────────────────────────
      _a(
        name: 'Bite (Pit Fiend)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 14,
        reachFt: 10,
        damageDice: '4d6+8',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +14, reach 10 ft. *Hit:* 22 (4d6 + 8) Piercing damage. The target has the Poisoned condition until the start of the pit fiend\'s next turn.',
      ),

      // ─── Air / Earth / Fire / Water Elementals ──────────────────────────
      _a(
        name: 'Slam (Air Elemental)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 8,
        reachFt: 10,
        damageDice: '2d8+5',
        damageType: 'Bludgeoning',
        description:
            '*Melee Attack Roll:* +8, reach 10 ft. *Hit:* 14 (2d8 + 5) Bludgeoning damage.',
      ),
      _a(
        name: 'Slam (Earth Elemental)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 8,
        reachFt: 10,
        damageDice: '2d10+5',
        damageType: 'Bludgeoning',
        description:
            '*Melee Attack Roll:* +8, reach 10 ft. *Hit:* 16 (2d10 + 5) Bludgeoning damage.',
      ),
      _a(
        name: 'Touch (Fire Elemental)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 6,
        reachFt: 5,
        damageDice: '2d6+3',
        damageType: 'Fire',
        description:
            '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 10 (2d6 + 3) Fire damage. The target catches fire if not already burning, taking 1d10 Fire damage at the start of each of its turns until a creature douses the flame.',
      ),
      _a(
        name: 'Slam (Water Elemental)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 7,
        reachFt: 5,
        damageDice: '2d8+4',
        damageType: 'Bludgeoning',
        description:
            '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 13 (2d8 + 4) Bludgeoning damage.',
      ),

      // ─── Ghoul ──────────────────────────────────────────────────────────
      _a(
        name: 'Bite (Ghoul)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 2,
        reachFt: 5,
        damageDice: '2d6+2',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +2, reach 5 ft. *Hit:* 9 (2d6 + 2) Piercing damage.',
      ),
      _a(
        name: 'Claws (Ghoul)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 4,
        reachFt: 5,
        damageDice: '2d4+2',
        damageType: 'Slashing',
        saveDc: 10,
        saveAbility: 'Constitution',
        conditions: ['Paralyzed'],
        description:
            '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (2d4 + 2) Slashing damage. If the target is a creature other than an Elf or Undead, it must succeed on a DC 10 Con save or have the Paralyzed condition for 1 minute. The target repeats the save at the end of each of its turns.',
      ),

      // ─── Wight ──────────────────────────────────────────────────────────
      _a(
        name: 'Life Drain',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 4,
        reachFt: 5,
        damageDice: '1d6+2',
        damageType: 'Necrotic',
        saveDc: 13,
        saveAbility: 'Constitution',
        description:
            '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Necrotic damage. The target must succeed on a DC 13 Con save or its HP maximum is reduced by an amount equal to the damage taken. The reduction lasts until the target finishes a Long Rest. The target dies if its HP maximum is reduced to 0.',
      ),

      // ─── Specter ────────────────────────────────────────────────────────
      _a(
        name: 'Life Drain (Specter)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Spell',
        attackBonus: 4,
        reachFt: 5,
        damageDice: '3d6',
        damageType: 'Necrotic',
        saveDc: 10,
        saveAbility: 'Constitution',
        description:
            '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 10 (3d6) Necrotic damage. The target must succeed on a DC 10 Con save or its HP maximum is reduced by an amount equal to the damage taken.',
      ),

      // ─── Animated Object ────────────────────────────────────────────────
      _a(
        name: 'Slam (Animated Armor)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 4,
        reachFt: 5,
        damageDice: '1d6+2',
        damageType: 'Bludgeoning',
        description:
            '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Bludgeoning damage.',
      ),
      _a(
        name: 'Constrict (Rug)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '2d6+3',
        damageType: 'Bludgeoning',
        conditions: ['Grappled', 'Restrained'],
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Bludgeoning damage. The target has the Grappled and Restrained conditions (escape DC 13).',
      ),

      // ─── Stone Giant ────────────────────────────────────────────────────
      _a(
        name: 'Greatclub (Stone Giant)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 9,
        reachFt: 15,
        damageDice: '3d8+6',
        damageType: 'Bludgeoning',
        description:
            '*Melee Attack Roll:* +9, reach 15 ft. *Hit:* 19 (3d8 + 6) Bludgeoning damage.',
      ),
      _a(
        name: 'Rock (Stone Giant)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Ranged Weapon',
        attackBonus: 9,
        rangeNormalFt: 60,
        rangeLongFt: 240,
        damageDice: '4d10+6',
        damageType: 'Bludgeoning',
        description:
            '*Ranged Attack Roll:* +9, range 60/240 ft. *Hit:* 28 (4d10 + 6) Bludgeoning damage. If the target is a creature, it must succeed on a DC 17 Strength save or have the Prone condition.',
      ),

      // ─── Hill Giant ─────────────────────────────────────────────────────
      _a(
        name: 'Greatclub (Hill Giant)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 8,
        reachFt: 10,
        damageDice: '3d8+5',
        damageType: 'Bludgeoning',
        description:
            '*Melee Attack Roll:* +8, reach 10 ft. *Hit:* 18 (3d8 + 5) Bludgeoning damage.',
      ),
      _a(
        name: 'Rock (Hill Giant)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Ranged Weapon',
        attackBonus: 8,
        rangeNormalFt: 60,
        rangeLongFt: 240,
        damageDice: '3d10+5',
        damageType: 'Bludgeoning',
        description:
            '*Ranged Attack Roll:* +8, range 60/240 ft. *Hit:* 21 (3d10 + 5) Bludgeoning damage.',
      ),

      // ─── Manticore ──────────────────────────────────────────────────────
      _a(
        name: 'Bite (Manticore)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '1d8+3',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 7 (1d8 + 3) Piercing damage.',
      ),
      _a(
        name: 'Tail Spike',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Ranged Weapon',
        attackBonus: 5,
        rangeNormalFt: 100,
        rangeLongFt: 200,
        damageDice: '1d8+3',
        damageType: 'Piercing',
        description:
            '*Ranged Attack Roll:* +5, range 100/200 ft. *Hit:* 7 (1d8 + 3) Piercing damage. The manticore can hurl up to three spikes per turn.',
      ),

      // ─── Minotaur ───────────────────────────────────────────────────────
      _a(
        name: 'Greataxe (Minotaur)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 6,
        reachFt: 5,
        damageDice: '2d12+4',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 17 (2d12 + 4) Slashing damage.',
      ),
      _a(
        name: 'Gore',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 6,
        reachFt: 5,
        damageDice: '2d8+4',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 13 (2d8 + 4) Piercing damage.',
      ),

      // ─── Basilisk ───────────────────────────────────────────────────────
      _a(
        name: 'Bite (Basilisk)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '2d6+3',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Piercing damage plus 7 (2d6) Poison damage.',
      ),
      _a(
        name: 'Petrifying Gaze',
        actionType: 'Action',
        saveDc: 12,
        saveAbility: 'Constitution',
        conditions: ['Restrained', 'Petrified'],
        description:
            'The basilisk targets one creature it can see within 30 feet. If the target can see the basilisk, the target must succeed on a DC 12 Con save or be magically Restrained as it slowly turns to stone. The Restrained target must repeat the save at the end of its next turn. On a successful save, the spell ends. On a failed save, the target has the Petrified condition for 24 hours.',
      ),

      // ─── Cockatrice ─────────────────────────────────────────────────────
      _a(
        name: 'Bite (Cockatrice)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 3,
        reachFt: 5,
        damageDice: '1d4+1',
        damageType: 'Piercing',
        saveDc: 11,
        saveAbility: 'Constitution',
        conditions: ['Petrified'],
        description:
            '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 3 (1d4 + 1) Piercing damage. The target must succeed on a DC 11 Con save or magically begin to turn to stone. The target has the Restrained condition until the end of its next turn, when it makes another Con save. On a fail, the target has the Petrified condition for 24 hours.',
      ),

      // ─── Ettin ──────────────────────────────────────────────────────────
      _a(
        name: 'Battleaxe (Ettin)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 7,
        reachFt: 5,
        damageDice: '2d8+5',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 14 (2d8 + 5) Slashing damage.',
      ),
      _a(
        name: 'Morningstar (Ettin)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 7,
        reachFt: 5,
        damageDice: '2d8+5',
        damageType: 'Piercing',
        description:
            '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 14 (2d8 + 5) Piercing damage.',
      ),

      // ─── Harpy ──────────────────────────────────────────────────────────
      _a(
        name: 'Claws (Harpy)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 3,
        reachFt: 5,
        damageDice: '2d4+1',
        damageType: 'Slashing',
        description:
            '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 6 (2d4 + 1) Slashing damage.',
      ),
      _a(
        name: 'Luring Song',
        actionType: 'Action',
        saveDc: 11,
        saveAbility: 'Wisdom',
        conditions: ['Charmed'],
        description:
            'The harpy sings a magical melody. Every Humanoid and Giant within 300 feet that can hear the song must succeed on a DC 11 Wisdom save or be Charmed until the song ends. The harpy must take a Bonus Action on its later turns to continue singing.',
      ),

      // ─── Will-o\'-Wisp ──────────────────────────────────────────────────
      _a(
        name: 'Shock',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Spell',
        attackBonus: 4,
        reachFt: 5,
        damageDice: '2d8',
        damageType: 'Lightning',
        description:
            '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 9 (2d8) Lightning damage.',
      ),

      // ─── Mummy ──────────────────────────────────────────────────────────
      _a(
        name: 'Rotting Fist',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 5,
        reachFt: 5,
        damageDice: '2d6+2',
        damageType: 'Bludgeoning',
        saveDc: 12,
        saveAbility: 'Constitution',
        description:
            '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 9 (2d6 + 2) Bludgeoning damage plus 10 (3d6) Necrotic damage. If the target is a creature, it must succeed on a DC 12 Con save or be cursed with mummy rot. The cursed target can\'t regain HP, and its HP maximum decreases by 10 (3d6) every 24 hours. The curse lasts until removed by the Remove Curse spell or comparable magic.',
      ),
      _a(
        name: 'Dreadful Glare',
        actionType: 'Action',
        saveDc: 12,
        saveAbility: 'Wisdom',
        conditions: ['Frightened', 'Paralyzed'],
        description:
            'The mummy targets one creature it can see within 60 feet. If the target can see the mummy, it must succeed on a DC 12 Wisdom save against this magic or have the Frightened condition until the end of the mummy\'s next turn. On a fail by 5+, the target also has the Paralyzed condition.',
      ),

      // ─── Treant ─────────────────────────────────────────────────────────
      _a(
        name: 'Slam (Treant)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Melee Weapon',
        attackBonus: 10,
        reachFt: 5,
        damageDice: '3d6+6',
        damageType: 'Bludgeoning',
        description:
            '*Melee Attack Roll:* +10, reach 5 ft. *Hit:* 16 (3d6 + 6) Bludgeoning damage.',
      ),
      _a(
        name: 'Rock (Treant)',
        actionType: 'Action',
        isAttack: true,
        attackKind: 'Ranged Weapon',
        attackBonus: 10,
        rangeNormalFt: 60,
        rangeLongFt: 180,
        damageDice: '4d10+6',
        damageType: 'Bludgeoning',
        description:
            '*Ranged Attack Roll:* +10, range 60/180 ft. *Hit:* 28 (4d10 + 6) Bludgeoning damage.',
      ),

      // ─── More animal actions ────────────────────────────────────────────
      _a(name: 'Bite (Cat)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 0, reachFt: 5, damageDice: '1', damageType: 'Piercing', description: '*Melee Attack Roll:* +0, reach 5 ft. *Hit:* 1 Piercing damage.'),
      _a(name: 'Bite (Rat)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 0, reachFt: 5, damageDice: '1', damageType: 'Piercing', description: '*Melee Attack Roll:* +0, reach 5 ft. *Hit:* 1 Piercing damage.'),
      _a(name: 'Bite (Giant Rat)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d4+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage.'),
      _a(name: 'Talons (Hawk)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 1 Slashing damage.'),
      _a(name: 'Bite (Pony)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '2d4+2', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (2d4 + 2) Bludgeoning damage.'),
      _a(name: 'Bite (Camel)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d4+3', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 5 (1d4 + 3) Bludgeoning damage.'),
      _a(name: 'Stomp (Elephant)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 5, damageDice: '3d10+6', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +8, reach 5 ft. (only against creature that is Prone). *Hit:* 22 (3d10 + 6) Bludgeoning damage.'),
      _a(name: 'Gore (Elephant)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 5, damageDice: '3d8+6', damageType: 'Piercing', description: '*Melee Attack Roll:* +8, reach 5 ft. *Hit:* 19 (3d8 + 6) Piercing damage. If the elephant moved 20+ ft. straight toward the target before the hit, the target takes an extra 9 (2d8) Piercing damage.'),
      _a(name: 'Bite (Ape)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d6+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 6 (1d6 + 3) Piercing damage.'),
      _a(name: 'Fist (Ape)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d6+3', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 6 (1d6 + 3) Bludgeoning damage.'),
      _a(name: 'Rock (Ape)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 5, rangeNormalFt: 25, rangeLongFt: 50, damageDice: '1d6+3', damageType: 'Bludgeoning', description: '*Ranged Attack Roll:* +5, range 25/50 ft. *Hit:* 6 (1d6 + 3) Bludgeoning damage.'),
      _a(name: 'Bite (Constrictor)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.'),
      _a(name: 'Constrict (Constrictor)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '2d4+2', damageType: 'Bludgeoning', conditions: ['Grappled', 'Restrained'], description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (2d4 + 2) Bludgeoning damage. The target has the Grappled condition (escape DC 14) and the Restrained condition until the grapple ends.'),
      _a(name: 'Bite (Giant Snake)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 10, damageDice: '1d8+4', damageType: 'Piercing', saveDc: 11, saveAbility: 'Constitution', conditions: ['Poisoned'], description: '*Melee Attack Roll:* +6, reach 10 ft. *Hit:* 8 (1d8 + 4) Piercing damage plus 10 (3d6) Poison damage. The target must succeed on a DC 11 Con save or be Poisoned for 1 hour.'),
      _a(name: 'Talons (Eagle)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d4+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Slashing damage.'),
      _a(name: 'Bite (Owl)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1', damageType: 'Slashing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 1 Slashing damage.'),
      _a(name: 'Bite (Frog)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 1, reachFt: 5, damageDice: '1', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +1, reach 5 ft. *Hit:* 1 Bludgeoning damage.'),
      _a(name: 'Bite (Giant Frog)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d6+1', damageType: 'Piercing', conditions: ['Grappled'], description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Piercing damage. The target has the Grappled condition (escape DC 11). Until the grapple ends, the target is also Restrained.'),
      _a(name: 'Bite (Giant Centipede)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d4+2', damageType: 'Piercing', saveDc: 11, saveAbility: 'Constitution', conditions: ['Poisoned'], description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage plus 10 (3d6) Poison damage. The target must succeed on a DC 11 Con save or be Poisoned for 1 hour.'),
      _a(name: 'Bite (Giant Lizard)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d8+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 6 (1d8 + 2) Piercing damage.'),
      _a(name: 'Bite (Polar Bear)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '1d8+5', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 9 (1d8 + 5) Piercing damage.'),
      _a(name: 'Claws (Polar Bear)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d6+5', damageType: 'Slashing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 12 (2d6 + 5) Slashing damage.'),
      _a(name: 'Hooves (Warhorse)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d6+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 11 (2d6 + 4) Bludgeoning damage.'),
      _a(name: 'Bite (Velociraptor)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.'),
      _a(name: 'Bite (Octopus)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d4+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage.'),

      // ─── Adult Black Dragon (CR 14) ───────────────────────────────────────
      _a(name: 'Bite (Adult Black Dragon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 11, reachFt: 10, damageDice: '2d10+6', damageType: 'Piercing', description: '*Melee Attack Roll:* +11, reach 10 ft. *Hit:* 17 (2d10 + 6) Piercing damage plus 4 (1d8) Acid damage.'),
      _a(name: 'Claw (Adult Black Dragon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 11, reachFt: 5, damageDice: '2d6+6', damageType: 'Slashing', description: '*Melee Attack Roll:* +11, reach 5 ft. *Hit:* 13 (2d6 + 6) Slashing damage.'),
      _a(name: 'Tail (Adult Black Dragon)', actionType: 'Legendary Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 11, reachFt: 15, damageDice: '2d8+6', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +11, reach 15 ft. *Hit:* 15 (2d8 + 6) Bludgeoning damage.'),
      _a(name: 'Acid Breath', actionType: 'Action', rechargeKind: 'Recharge', rechargeMinRoll: 5, saveDc: 18, saveAbility: 'Dexterity', damageDice: '15d8', damageType: 'Acid', description: '*Dexterity Saving Throw:* DC 18, each creature in a 60-foot-long, 5-foot-wide Line. *Failure:* 67 (15d8) Acid damage. *Success:* Half damage.'),

      // ─── Adult Blue Dragon (CR 16) ────────────────────────────────────────
      _a(name: 'Bite (Adult Blue Dragon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 12, reachFt: 10, damageDice: '2d10+7', damageType: 'Piercing', description: '*Melee Attack Roll:* +12, reach 10 ft. *Hit:* 18 (2d10 + 7) Piercing damage plus 5 (1d10) Lightning damage.'),
      _a(name: 'Claw (Adult Blue Dragon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 12, reachFt: 5, damageDice: '2d6+7', damageType: 'Slashing', description: '*Melee Attack Roll:* +12, reach 5 ft. *Hit:* 14 (2d6 + 7) Slashing damage.'),
      _a(name: 'Tail (Adult Blue Dragon)', actionType: 'Legendary Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 12, reachFt: 15, damageDice: '2d8+7', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +12, reach 15 ft. *Hit:* 16 (2d8 + 7) Bludgeoning damage.'),
      _a(name: 'Lightning Breath', actionType: 'Action', rechargeKind: 'Recharge', rechargeMinRoll: 5, saveDc: 19, saveAbility: 'Dexterity', damageDice: '16d10', damageType: 'Lightning', description: '*Dexterity Saving Throw:* DC 19, each creature in a 90-foot-long, 5-foot-wide Line. *Failure:* 88 (16d10) Lightning damage. *Success:* Half damage.'),

      // ─── Adult Green Dragon (CR 15) ───────────────────────────────────────
      _a(name: 'Bite (Adult Green Dragon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 11, reachFt: 10, damageDice: '2d10+6', damageType: 'Piercing', description: '*Melee Attack Roll:* +11, reach 10 ft. *Hit:* 17 (2d10 + 6) Piercing damage plus 7 (2d6) Poison damage.'),
      _a(name: 'Claw (Adult Green Dragon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 11, reachFt: 5, damageDice: '2d6+6', damageType: 'Slashing', description: '*Melee Attack Roll:* +11, reach 5 ft. *Hit:* 13 (2d6 + 6) Slashing damage.'),
      _a(name: 'Tail (Adult Green Dragon)', actionType: 'Legendary Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 11, reachFt: 15, damageDice: '2d8+6', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +11, reach 15 ft. *Hit:* 15 (2d8 + 6) Bludgeoning damage.'),
      _a(name: 'Poison Breath', actionType: 'Action', rechargeKind: 'Recharge', rechargeMinRoll: 5, saveDc: 18, saveAbility: 'Constitution', damageDice: '15d6', damageType: 'Poison', description: '*Constitution Saving Throw:* DC 18, each creature in a 60-foot Cone. *Failure:* 56 (15d6) Poison damage. *Success:* Half damage.'),

      // ─── Adult White Dragon (CR 13) ───────────────────────────────────────
      _a(name: 'Bite (Adult White Dragon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 10, damageDice: '2d10+6', damageType: 'Piercing', description: '*Melee Attack Roll:* +10, reach 10 ft. *Hit:* 17 (2d10 + 6) Piercing damage plus 4 (1d8) Cold damage.'),
      _a(name: 'Claw (Adult White Dragon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 5, damageDice: '2d6+6', damageType: 'Slashing', description: '*Melee Attack Roll:* +10, reach 5 ft. *Hit:* 13 (2d6 + 6) Slashing damage.'),
      _a(name: 'Tail (Adult White Dragon)', actionType: 'Legendary Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 15, damageDice: '2d8+6', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +10, reach 15 ft. *Hit:* 15 (2d8 + 6) Bludgeoning damage.'),
      _a(name: 'Cold Breath', actionType: 'Action', rechargeKind: 'Recharge', rechargeMinRoll: 5, saveDc: 18, saveAbility: 'Constitution', damageDice: '12d8', damageType: 'Cold', description: '*Constitution Saving Throw:* DC 18, each creature in a 60-foot Cone. *Failure:* 54 (12d8) Cold damage. *Success:* Half damage.'),

      // Dragon legendary helpers (shared)
      _a(name: 'Wing Attack', actionType: 'Legendary Action', saveDc: 19, saveAbility: 'Dexterity', damageDice: '2d6+6', damageType: 'Bludgeoning', description: 'The dragon beats its wings. Each creature within 10 feet must succeed on a Dexterity save or take 13 (2d6 + 6) Bludgeoning damage and have the Prone condition. The dragon can then fly up to half its Fly Speed.'),
      _a(name: 'Frightful Presence (Dragon)', actionType: 'Action', saveDc: 18, saveAbility: 'Wisdom', conditions: ['Frightened'], description: 'Each creature of the dragon\'s choice within 120 feet must succeed on a DC 18 Wisdom save or have the Frightened condition for 1 minute.'),

      // ─── Chuul ───────────────────────────────────────────────────────────
      _a(name: 'Pincer (Chuul)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 10, damageDice: '2d6+4', damageType: 'Bludgeoning', conditions: ['Grappled'], description: '*Melee Attack Roll:* +6, reach 10 ft. *Hit:* 11 (2d6 + 4) Bludgeoning damage. The target has the Grappled condition (escape DC 14). The chuul has two pincers, each of which can grapple only one target.'),
      _a(name: 'Paralyzing Tentacles', actionType: 'Bonus Action', saveDc: 13, saveAbility: 'Constitution', conditions: ['Poisoned', 'Paralyzed'], description: 'One creature Grappled by the chuul must succeed on a DC 13 Con save or be Poisoned. While Poisoned this way, the target is Paralyzed.'),

      // ─── Otyugh ──────────────────────────────────────────────────────────
      _a(name: 'Bite (Otyugh)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d8+3', damageType: 'Piercing', saveDc: 15, saveAbility: 'Constitution', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 12 (2d8 + 3) Piercing damage. If the target is a creature, it must succeed on a DC 15 Con save or be infected with a disease. Until the disease is cured, the target can\'t regain HP.'),
      _a(name: 'Tentacle (Otyugh)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 10, damageDice: '1d8+3', damageType: 'Piercing', conditions: ['Grappled'], description: '*Melee Attack Roll:* +6, reach 10 ft. *Hit:* 7 (1d8 + 3) Piercing damage. The target has the Grappled condition (escape DC 13).'),

      // ─── Roper ───────────────────────────────────────────────────────────
      _a(name: 'Bite (Roper)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '4d8+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 22 (4d8 + 4) Piercing damage.'),
      _a(name: 'Tendril (Roper)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 50, damageDice: '0', damageType: 'Bludgeoning', conditions: ['Grappled', 'Restrained'], description: '*Melee Attack Roll:* +7, reach 50 ft. *Hit:* The target has the Grappled condition (escape DC 15) and the Restrained condition until the grapple ends. The roper can have up to six tendrils, each of which can grapple only one target.'),

      // ─── Nothic ──────────────────────────────────────────────────────────
      _a(name: 'Claw (Nothic)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '2d6+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 9 (2d6 + 2) Slashing damage.'),
      _a(name: 'Rotting Gaze', actionType: 'Action', saveDc: 12, saveAbility: 'Constitution', damageDice: '3d6', damageType: 'Necrotic', description: '*Constitution Saving Throw:* DC 12, one creature within 30 feet. *Failure:* 10 (3d6) Necrotic damage.'),
      _a(name: 'Weird Insight', actionType: 'Action', saveDc: 12, saveAbility: 'Wisdom', description: '*Wisdom Saving Throw:* DC 12, one creature within 30 feet. *Failure:* The nothic learns one of the creature\'s closely held secrets.'),

      // ─── Dryad ───────────────────────────────────────────────────────────
      _a(name: 'Vine Whip (Dryad)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 10, damageDice: '2d4+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 10 ft. *Hit:* 8 (2d4 + 3) Slashing damage.'),
      _a(name: 'Fey Charm', actionType: 'Action', saveDc: 14, saveAbility: 'Wisdom', conditions: ['Charmed'], description: 'The dryad targets one Humanoid or Beast within 30 feet. If the target can see the dryad, it must succeed on a DC 14 Wisdom save or be magically Charmed by the dryad for 24 hours.'),

      // ─── Gargoyle ────────────────────────────────────────────────────────
      _a(name: 'Bite (Gargoyle)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.'),
      _a(name: 'Claws (Gargoyle)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '2d6+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 9 (2d6 + 2) Slashing damage.'),

      // ─── Couatl ──────────────────────────────────────────────────────────
      _a(name: 'Bite (Couatl)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 5, damageDice: '1d6+5', damageType: 'Piercing', saveDc: 13, saveAbility: 'Constitution', conditions: ['Poisoned', 'Unconscious'], description: '*Melee Attack Roll:* +8, reach 5 ft. *Hit:* 8 (1d6 + 5) Piercing damage and 12 (3d6 + 1) Poison damage. The target must succeed on a DC 13 Con save or be Poisoned for 24 hours; while Poisoned, it is also Unconscious but wakes if it takes damage.'),
      _a(name: 'Constrict (Couatl)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d6+4', damageType: 'Bludgeoning', conditions: ['Grappled', 'Restrained'], description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 11 (2d6 + 4) Bludgeoning damage; the target has the Grappled condition (escape DC 15) and the Restrained condition until the grapple ends.'),

      // ─── Sphinx (Andro/Gyno) ─────────────────────────────────────────────
      _a(name: 'Claws (Sphinx)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 12, reachFt: 5, damageDice: '2d8+8', damageType: 'Slashing', description: '*Melee Attack Roll:* +12, reach 5 ft. *Hit:* 17 (2d8 + 8) Slashing damage.'),
      _a(name: 'Roar (Sphinx)', actionType: 'Action', usesPerDay: 3, saveDc: 18, saveAbility: 'Wisdom', conditions: ['Frightened', 'Paralyzed', 'Deafened'], description: 'The sphinx emits a magical roar. Whenever it roars, the roar has a different effect, as detailed below; the sphinx can\'t roar the same way again until it finishes a Long Rest. *First Roar:* Each creature within 500 feet that can hear the roar must succeed on a DC 18 Wisdom save or have the Frightened condition for 1 minute. *Second Roar:* Each creature within 500 feet that can hear the roar must succeed on a DC 18 Wisdom save or have the Paralyzed condition for 1 minute. *Third Roar:* Each creature within 500 feet that can hear the roar must succeed on a DC 18 Constitution save or take 44 (8d10) Thunder damage and be Deafened.'),

      // ─── Death Dog ───────────────────────────────────────────────────────
      _a(name: 'Bite (Death Dog)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', saveDc: 12, saveAbility: 'Constitution', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage. If the target is a creature, it must succeed on a DC 12 Con save or be cursed with a disease. Until cured, the target loses 5 (1d10) HP at dawn each day.'),

      // ─── Knight (CR 3) ───────────────────────────────────────────────────
      _a(name: 'Greatsword (Knight)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '2d6+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Slashing damage.'),
      _a(name: 'Heavy Crossbow (Knight)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 2, rangeNormalFt: 100, rangeLongFt: 400, damageDice: '1d10', damageType: 'Piercing', description: '*Ranged Attack Roll:* +2, range 100/400 ft. *Hit:* 5 (1d10) Piercing damage.'),
      _a(name: 'Leadership', actionType: 'Bonus Action', usesPerDay: 1, description: 'For 1 minute, the knight can utter a special command or warning whenever a nonhostile creature it can see within 30 feet makes an attack roll or saving throw. The creature can add a d4 to its roll. A creature can benefit from only one Leadership die at a time.'),

      // ─── Veteran (CR 3) ──────────────────────────────────────────────────
      _a(name: 'Longsword (Veteran)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d8+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 7 (1d8 + 3) Slashing damage, or 8 (1d10 + 3) if used with two hands.'),
      _a(name: 'Shortsword (Veteran)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d6+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 6 (1d6 + 3) Piercing damage.'),
      _a(name: 'Heavy Crossbow (Veteran)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 3, rangeNormalFt: 100, rangeLongFt: 400, damageDice: '1d10+1', damageType: 'Piercing', description: '*Ranged Attack Roll:* +3, range 100/400 ft. *Hit:* 6 (1d10 + 1) Piercing damage.'),

      // ─── Gladiator (CR 5) ────────────────────────────────────────────────
      _a(name: 'Spear (Gladiator)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d6+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 5 ft (or range 20/60 ft). *Hit:* 11 (2d6 + 4) Piercing damage.'),
      _a(name: 'Shield Bash', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d4+4', damageType: 'Bludgeoning', saveDc: 15, saveAbility: 'Strength', conditions: ['Prone'], description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 9 (2d4 + 4) Bludgeoning damage. If the target is a Medium or smaller creature, it must succeed on a DC 15 Strength save or have the Prone condition.'),
      _a(name: 'Parry', actionType: 'Reaction', description: 'When the gladiator is hit by a melee attack, it adds 3 to its AC against that attack, potentially turning the hit into a miss. The gladiator must be wielding a melee weapon.'),

      // ─── Mage (CR 6) ─────────────────────────────────────────────────────
      _a(name: 'Arcane Burst', actionType: 'Action', isAttack: true, attackKind: 'Spell', attackBonus: 7, reachFt: 5, rangeNormalFt: 120, damageDice: '4d10', damageType: 'Force', description: '*Melee or Ranged Spell Attack Roll:* +7, reach 5 ft or range 120 ft. *Hit:* 22 (4d10) Force damage.'),

      // ─── Priest (CR 2) ───────────────────────────────────────────────────
      _a(name: 'Mace (Priest)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 2, reachFt: 5, damageDice: '1d6', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +2, reach 5 ft. *Hit:* 3 (1d6) Bludgeoning damage plus 5 (2d4) Radiant damage.'),
      _a(name: 'Radiance of the Dawn', actionType: 'Action', usesPerDay: 1, saveDc: 13, saveAbility: 'Constitution', damageDice: '4d10', damageType: 'Radiant', description: 'A magical light flares out from the priest. *Constitution Saving Throw:* DC 13, each enemy in a 30-foot Emanation. *Failure:* 22 (4d10) Radiant damage. *Success:* Half damage.'),

      // ─── Cult Fanatic (CR 2) ─────────────────────────────────────────────
      _a(name: 'Dagger (Fanatic)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, rangeNormalFt: 20, rangeLongFt: 60, damageDice: '1d4+2', damageType: 'Piercing', description: '*Melee or Ranged Attack Roll:* +4, reach 5 ft or range 20/60 ft. *Hit:* 4 (1d4 + 2) Piercing damage plus 3 (1d6) Necrotic damage.'),

      // ─── Spy (CR 1) ──────────────────────────────────────────────────────
      _a(name: 'Shortsword (Spy)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.'),
      _a(name: 'Hand Crossbow (Spy)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 4, rangeNormalFt: 30, rangeLongFt: 120, damageDice: '1d6+2', damageType: 'Piercing', description: '*Ranged Attack Roll:* +4, range 30/120 ft. *Hit:* 5 (1d6 + 2) Piercing damage.'),

      // ─── Assassin (CR 8) ─────────────────────────────────────────────────
      _a(name: 'Shortsword (Assassin)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1d6+3', damageType: 'Piercing', saveDc: 15, saveAbility: 'Constitution', conditions: ['Poisoned'], description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 6 (1d6 + 3) Piercing damage plus 17 (5d6) Poison damage. The target must succeed on a DC 15 Con save or be Poisoned for 1 hour.'),
      _a(name: 'Light Crossbow (Assassin)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 6, rangeNormalFt: 80, rangeLongFt: 320, damageDice: '1d8+3', damageType: 'Piercing', saveDc: 15, saveAbility: 'Constitution', conditions: ['Poisoned'], description: '*Ranged Attack Roll:* +6, range 80/320 ft. *Hit:* 7 (1d8 + 3) Piercing damage plus 17 (5d6) Poison damage. The target must succeed on a DC 15 Con save or be Poisoned for 1 hour.'),

      // ─── Tyrannosaurus Rex (CR 8) ────────────────────────────────────────
      _a(name: 'Bite (T-Rex)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 10, damageDice: '4d12+7', damageType: 'Piercing', conditions: ['Grappled'], description: '*Melee Attack Roll:* +10, reach 10 ft. *Hit:* 33 (4d12 + 7) Piercing damage. If the target is a Medium or smaller creature, it has the Grappled condition (escape DC 17). The T-Rex can grapple only one target at a time.'),
      _a(name: 'Tail (T-Rex)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 10, damageDice: '3d8+7', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +10, reach 10 ft. *Hit:* 20 (3d8 + 7) Bludgeoning damage.'),

      // ─── Triceratops (CR 5) ──────────────────────────────────────────────
      _a(name: 'Gore (Triceratops)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 9, reachFt: 5, damageDice: '4d8+6', damageType: 'Piercing', description: '*Melee Attack Roll:* +9, reach 5 ft. *Hit:* 24 (4d8 + 6) Piercing damage.'),
      _a(name: 'Stomp (Triceratops)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 9, reachFt: 5, damageDice: '2d10+6', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +9, reach 5 ft, one Prone creature. *Hit:* 17 (2d10 + 6) Bludgeoning damage.'),

      // ─── Allosaurus / Pteranodon / Plesiosaurus ──────────────────────────
      _a(name: 'Bite (Allosaurus)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d10+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 15 (2d10 + 4) Piercing damage.'),
      _a(name: 'Bite (Pteranodon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d4+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage.'),
      _a(name: 'Bite (Plesiosaurus)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 10, damageDice: '3d6+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 10 ft. *Hit:* 14 (3d6 + 4) Piercing damage.'),

      // ─── Mammoth / Rhinoceros / Killer Whale ─────────────────────────────
      _a(name: 'Gore (Mammoth)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 10, damageDice: '4d8+6', damageType: 'Piercing', description: '*Melee Attack Roll:* +10, reach 10 ft. *Hit:* 24 (4d8 + 6) Piercing damage.'),
      _a(name: 'Stomp (Mammoth)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 5, damageDice: '4d10+6', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +10, reach 5 ft, one Prone creature. *Hit:* 28 (4d10 + 6) Bludgeoning damage.'),
      _a(name: 'Gore (Rhinoceros)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d8+5', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 14 (2d8 + 5) Piercing damage.'),
      _a(name: 'Bite (Killer Whale)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '5d6+5', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 21 (5d6 + 5) Piercing damage.'),

      // ─── Stirge ──────────────────────────────────────────────────────────
      _a(name: 'Proboscis (Stirge)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d4+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 5 (1d4 + 3) Piercing damage, and the stirge attaches to the target. While attached, the stirge can\'t attack, and at the start of each of the stirge\'s turns, the target loses 5 (1d4 + 3) HP.'),

      // ─── Giant Crab / Giant Octopus / Giant Shark ────────────────────────
      _a(name: 'Claw (Giant Crab)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d6+1', damageType: 'Bludgeoning', conditions: ['Grappled'], description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Bludgeoning damage. The target has the Grappled condition (escape DC 11). The crab has two claws, each grappling one target.'),
      _a(name: 'Tentacles (Giant Octopus)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 15, damageDice: '2d6+3', damageType: 'Bludgeoning', conditions: ['Grappled', 'Restrained'], description: '*Melee Attack Roll:* +5, reach 15 ft. *Hit:* 10 (2d6 + 3) Bludgeoning damage. The target has the Grappled condition (escape DC 16) and the Restrained condition until the grapple ends.'),
      _a(name: 'Bite (Giant Shark)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '3d10+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 20 (3d10 + 4) Piercing damage.'),
      _a(name: 'Bite (Hunter Shark)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '2d8+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 13 (2d8 + 4) Piercing damage.'),
      _a(name: 'Bite (Reef Shark)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d8+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 6 (1d8 + 2) Piercing damage.'),
      _a(name: 'Bite (Quipper)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d6+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 6 (1d6 + 3) Piercing damage.'),

      // ─── Swarm bites ─────────────────────────────────────────────────────
      _a(name: 'Bites (Swarm of Bats)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 0, damageDice: '4d4', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 0 ft. *Hit:* 10 (4d4) Piercing damage, or 5 (2d4) if the swarm has half its HP or fewer.'),
      _a(name: 'Bites (Swarm of Insects)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 0, damageDice: '4d4', damageType: 'Piercing', description: '*Melee Attack Roll:* +3, reach 0 ft. *Hit:* 10 (4d4) Piercing damage, or 5 (2d4) if the swarm has half its HP or fewer.'),
      _a(name: 'Bites (Swarm of Rats)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 0, damageDice: '2d6', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 0 ft. *Hit:* 7 (2d6) Piercing damage, or 3 (1d6) if the swarm has half its HP or fewer.'),
      _a(name: 'Bites (Swarm of Quippers)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 0, damageDice: '4d6', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 0 ft. *Hit:* 14 (4d6) Piercing damage, or 7 (2d6) if the swarm has half its HP or fewer.'),

      // ─── Animal-roster actions — batch 1 ─────────────────────────────────
      _a(name: 'Tail (Ankylosaurus)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 10, damageDice: '4d6+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +7, reach 10 ft. *Hit:* 18 (4d6 + 4) Bludgeoning damage. If the target is a Huge or smaller creature, it must succeed on a DC 14 Strength save or have the Prone condition.'),
      _a(name: 'Bite (Archelon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d10+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 15 (2d10 + 4) Piercing damage. If the target is a Large or smaller creature, it has the Grappled condition (escape DC 14).'),
      _a(name: 'Bite (Baboon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 1, reachFt: 5, damageDice: '1d4-1', damageType: 'Piercing', description: '*Melee Attack Roll:* +1, reach 5 ft. *Hit:* 1 (1d4 − 1) Piercing damage.'),
      _a(name: 'Bite (Badger)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 2, reachFt: 5, damageDice: '1d4', damageType: 'Piercing', description: '*Melee Attack Roll:* +2, reach 5 ft. *Hit:* 2 (1d4) Piercing damage.'),
      _a(name: 'Bite (Bat)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 0, reachFt: 5, damageDice: '1', damageType: 'Piercing', description: '*Melee Attack Roll:* +0, reach 5 ft. *Hit:* 1 Piercing damage.'),
      _a(name: 'Bite (Black Bear)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d6+1', damageType: 'Piercing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Piercing damage.'),
      _a(name: 'Claws (Black Bear)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '2d4+1', damageType: 'Slashing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 6 (2d4 + 1) Slashing damage.'),
      _a(name: 'Beak (Blood Hawk)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d4+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage.'),
      _a(name: 'Claws (Crab)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 0, reachFt: 5, damageDice: '1', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +0, reach 5 ft. *Hit:* 1 Bludgeoning damage.'),
      _a(name: 'Ram (Deer)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 2, reachFt: 5, damageDice: '1d4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +2, reach 5 ft. *Hit:* 2 (1d4) Bludgeoning damage.'),
      _a(name: 'Hooves (Draft Horse)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '2d4+2', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (2d4 + 2) Bludgeoning damage.'),
      _a(name: 'Ram (Elk)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d8+2', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 6 (1d8 + 2) Bludgeoning damage. If the elk moved 20+ feet straight toward the target immediately before the hit, the target takes an extra 7 (2d6) Bludgeoning damage and must succeed on a DC 12 Strength save or have the Prone condition.'),
      _a(name: 'Hooves (Elk)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '2d4+2', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (2d4 + 2) Bludgeoning damage.'),
      _a(name: 'Bite (Flying Snake)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 1 Piercing damage plus 7 (3d4) Poison damage.'),
      _a(name: 'Fist (Giant Ape)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 10, damageDice: '3d10+6', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +6, reach 10 ft. *Hit:* 22 (3d10 + 6) Bludgeoning damage.'),
      _a(name: 'Rock (Giant Ape)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 6, rangeNormalFt: 50, rangeLongFt: 100, damageDice: '7d6+6', damageType: 'Bludgeoning', description: '*Ranged Attack Roll:* +6, range 50/100 ft. *Hit:* 30 (7d6 + 6) Bludgeoning damage.'),
      _a(name: 'Claw (Giant Badger)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '2d4+1', damageType: 'Slashing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 6 (2d4 + 1) Slashing damage.'),
      _a(name: 'Bite (Giant Bat)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.'),
      _a(name: 'Tusk (Giant Boar)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d6+4', damageType: 'Slashing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 11 (2d6 + 4) Slashing damage. If the boar moved 20+ feet straight toward the target immediately before the hit, the target takes an extra 7 (2d6) Slashing damage.'),
      _a(name: 'Bite (Giant Crocodile)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 5, damageDice: '3d10+5', damageType: 'Piercing', description: '*Melee Attack Roll:* +8, reach 5 ft. *Hit:* 21 (3d10 + 5) Piercing damage. If the target is a Huge or smaller creature, it has the Grappled condition (escape DC 16).'),
      _a(name: 'Tail (Giant Crocodile)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 10, damageDice: '2d8+5', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +8, reach 10 ft. *Hit:* 14 (2d8 + 5) Bludgeoning damage. If the target is a Large or smaller creature, it has the Prone condition.'),
      _a(name: 'Ram (Giant Elk)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 10, damageDice: '2d6+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +6, reach 10 ft. *Hit:* 11 (2d6 + 4) Bludgeoning damage. If the elk moved 20+ feet straight toward the target immediately before the hit, the target takes an extra 7 (2d6) Bludgeoning damage and must succeed on a DC 14 Strength save or have the Prone condition.'),
      _a(name: 'Hooves (Giant Elk)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '4d4+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 14 (4d4 + 4) Bludgeoning damage.'),
      _a(name: 'Bite (Giant Fire Beetle)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 1, reachFt: 5, damageDice: '1d6', damageType: 'Slashing', description: '*Melee Attack Roll:* +1, reach 5 ft. *Hit:* 3 (1d6) Slashing damage.'),
      _a(name: 'Ram (Giant Goat)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '2d4+3', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 8 (2d4 + 3) Bludgeoning damage.'),
      _a(name: 'Bite (Giant Hyena)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '2d6+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Piercing damage.'),
      _a(name: 'Talons (Giant Owl)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '2d6+1', damageType: 'Slashing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 8 (2d6 + 1) Slashing damage.'),
      _a(name: 'Sting (Giant Scorpion)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d10+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (1d10 + 2) Piercing damage. The target must make a DC 12 Constitution save, taking 22 (4d10) Poison damage on a failure or half on a success.'),
      _a(name: 'Claw (Giant Scorpion)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d8+2', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 6 (1d8 + 2) Bludgeoning damage. The target has the Grappled condition (escape DC 12).'),
      _a(name: 'Bite (Giant Seahorse)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d6+1', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Bludgeoning damage. If the seahorse moved 20+ feet straight toward the target immediately before the hit, the target takes an extra 7 (2d6) Bludgeoning damage.'),
      _a(name: 'Bite (Giant Toad)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d10+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (1d10 + 2) Piercing damage plus 5 (2d4) Poison damage. The target has the Grappled condition (escape DC 13). While Grappled, the target is also Restrained.'),
      _a(name: 'Bite (Giant Venomous Snake)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 10, damageDice: '1d4+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 10 ft. *Hit:* 6 (1d4 + 4) Piercing damage plus 10 (3d6) Poison damage.'),
      _a(name: 'Talons (Giant Vulture)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '2d4+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 8 (2d4 + 3) Slashing damage.'),
      _a(name: 'Sting (Giant Wasp)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d6+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 6 (1d6 + 3) Piercing damage plus 14 (4d6) Poison damage. The target must succeed on a DC 11 Constitution save or have the Poisoned condition for 1 hour.'),
      _a(name: 'Bite (Giant Weasel)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d4+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 5 (1d4 + 3) Piercing damage.'),
      _a(name: 'Bite (Giant Wolf Spider)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d6+1', damageType: 'Piercing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Piercing damage plus 7 (2d6) Poison damage. The target must make a DC 11 Constitution save: on a fail, it has the Poisoned condition for 1 hour.'),
      _a(name: 'Ram (Goat)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d4+1', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 3 (1d4 + 1) Bludgeoning damage.'),
      _a(name: 'Bite (Hippopotamus)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 5, damageDice: '3d10+5', damageType: 'Piercing', description: '*Melee Attack Roll:* +8, reach 5 ft. *Hit:* 21 (3d10 + 5) Piercing damage.'),
      _a(name: 'Bite (Hyena)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 2, reachFt: 5, damageDice: '1d6', damageType: 'Piercing', description: '*Melee Attack Roll:* +2, reach 5 ft. *Hit:* 3 (1d6) Piercing damage.'),
      _a(name: 'Bite (Jackal)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 1, reachFt: 5, damageDice: '1d4-1', damageType: 'Piercing', description: '*Melee Attack Roll:* +1, reach 5 ft. *Hit:* 1 (1d4 − 1) Piercing damage.'),
      _a(name: 'Bite (Lizard)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 0, reachFt: 5, damageDice: '1', damageType: 'Piercing', description: '*Melee Attack Roll:* +0, reach 5 ft. *Hit:* 1 Piercing damage.'),
      _a(name: 'Hooves (Mule)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 2, reachFt: 5, damageDice: '1d4+2', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +2, reach 5 ft. *Hit:* 4 (1d4 + 2) Bludgeoning damage.'),
      _a(name: 'Bite (Panther)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.'),
      _a(name: 'Pounce (Panther)', actionType: 'Bonus Action', description: 'If the panther moves at least 20 feet straight toward a creature and then hits it with a Bite attack on the same turn, the target must succeed on a DC 12 Strength save or have the Prone condition. If the target has the Prone condition, the panther can make one Bite attack against it as a Bonus Action.'),
      _a(name: 'Bite (Piranha)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 0, reachFt: 5, damageDice: '1', damageType: 'Piercing', description: '*Melee Attack Roll:* +0, reach 5 ft. *Hit:* 1 Piercing damage, or 0 if the piranha has half its HP or fewer.'),
      _a(name: 'Beak (Raven)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 1 Piercing damage.'),
      _a(name: 'Bite (Saber-Toothed Tiger)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1d10+5', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 10 (1d10 + 5) Piercing damage.'),
      _a(name: 'Claw (Saber-Toothed Tiger)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d6+5', damageType: 'Slashing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 12 (2d6 + 5) Slashing damage.'),
      _a(name: 'Sting (Scorpion)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1', damageType: 'Piercing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 1 Piercing damage. The target must make a DC 9 Constitution save, taking 4 (1d8) Poison damage on a fail or half on a success.'),
      _a(name: 'Bite (Spider)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 1 Piercing damage plus 2 (1d4) Poison damage.'),
      _a(name: 'Bite (Venomous Snake)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d4+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage plus 3 (1d6) Poison damage.'),
      _a(name: 'Bite (Weasel)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 1 Piercing damage.'),
      _a(name: 'Bites (Swarm of Piranhas)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 0, damageDice: '4d6', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 0 ft. *Hit:* 14 (4d6) Piercing damage, or 7 (2d6) if the swarm has half its HP or fewer.'),
      _a(name: 'Beaks (Swarm of Ravens)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '2d6', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (2d6) Piercing damage, or 3 (1d6) if the swarm has half its HP or fewer.'),
      _a(name: 'Bites (Swarm of Venomous Snakes)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '4d6', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 14 (4d6) Piercing damage plus 14 (4d6) Poison damage, or half each if the swarm has half its HP or fewer.'),

      // ─── Gap closure: actions for missing monsters ──────────────────────
      // Generic dragon physical attack, reused across all true dragons.
      _a(name: 'Rend (Dragon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 10, damageDice: '2d8+5', damageType: 'Slashing', description: '*Melee Attack Roll:* +7, reach 10 ft. *Hit:* 14 (2d8 + 5) Slashing damage. Bonus and reach scale with dragon size.'),
      // Per-color breath weapons. One generic entry; numbers scale by stat block.
      _a(name: 'Acid Breath', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, damageDice: '12d8', damageType: 'Acid', saveDc: 14, saveAbility: 'Dexterity', description: '*Dexterity Saving Throw:* DC scales with stat block, each creature in a Line. *Failure:* Acid damage. *Success:* Half damage.'),
      _a(name: 'Lightning Breath', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, damageDice: '12d10', damageType: 'Lightning', saveDc: 14, saveAbility: 'Dexterity', description: '*Dexterity Saving Throw:* DC scales with stat block, each creature in a Line. *Failure:* Lightning damage. *Success:* Half damage.'),
      _a(name: 'Cold Breath', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, damageDice: '10d8', damageType: 'Cold', saveDc: 14, saveAbility: 'Constitution', description: '*Constitution Saving Throw:* DC scales with stat block, each creature in a Cone. *Failure:* Cold damage. *Success:* Half damage.'),
      _a(name: 'Poison Breath', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, damageDice: '12d6', damageType: 'Poison', saveDc: 14, saveAbility: 'Constitution', description: '*Constitution Saving Throw:* DC scales with stat block, each creature in a Cone. *Failure:* Poison damage. *Success:* Half damage.'),
      _a(name: 'Sleep Breath', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, saveDc: 14, saveAbility: 'Constitution', description: '*Constitution Saving Throw:* each creature in a Cone. *Failure:* Incapacitated until end of next turn; then repeats save. *Second Failure:* Unconscious 1 minute (or 10 minutes for adult+).', conditions: ['Incapacitated', 'Unconscious']),
      _a(name: 'Slowing Breath', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, saveDc: 14, saveAbility: 'Constitution', description: '*Constitution Saving Throw:* each creature in a Cone. *Failure:* Speed halved and can\'t use Reactions for 1 minute. The creature repeats the save at end of each turn.'),
      _a(name: 'Weakening Breath', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, saveDc: 14, saveAbility: 'Strength', description: '*Strength Saving Throw:* each creature in a Cone. *Failure:* Disadvantage on Strength-based attacks/checks/saves and weight allowance halved for 1 minute.'),
      _a(name: 'Paralyzing Breath', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, saveDc: 14, saveAbility: 'Constitution', description: '*Constitution Saving Throw:* each creature in a Cone. *Failure:* Paralyzed for 1 minute, repeats save at end of each turn.', conditions: ['Paralyzed']),
      _a(name: 'Repulsion Breath', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, saveDc: 14, saveAbility: 'Strength', description: '*Strength Saving Throw:* each creature in a Cone. *Failure:* Pushed 60 feet and knocked Prone.', conditions: ['Prone']),

      // NPC humanoids — one signature attack each.
      _a(name: 'Quarterstaff (Mage)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d6+1', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 4 (1d6 + 1) Bludgeoning damage.'),
      _a(name: 'Quarterstaff (Archmage)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d6+1', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 4 (1d6 + 1) Bludgeoning damage plus 18 (4d8) Force damage.'),
      _a(name: 'Spellcasting (Archmage)', actionType: 'Action', description: 'The archmage casts one of its prepared spells, using Intelligence as the spellcasting ability (spell save DC 17, +9 to hit with spell attacks). At will: Detect Magic, Detect Thoughts, Disguise Self, Mage Hand, Prestidigitation. 3/Day each: Counterspell, Fire Bolt, Fireball, Lightning Bolt. 1/Day each: Cone of Cold, Globe of Invulnerability, Mind Blank, Time Stop.'),
      _a(name: 'Scimitar (Bandit Captain)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d6+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 6 (1d6 + 3) Slashing damage.'),
      _a(name: 'Pistol (Bandit Captain)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 5, rangeNormalFt: 30, rangeLongFt: 90, damageDice: '1d10+3', damageType: 'Piercing', description: '*Ranged Attack Roll:* +5, range 30/90 ft. *Hit:* 8 (1d10 + 3) Piercing damage.'),
      _a(name: 'Greataxe (Berserker)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d12+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 9 (1d12 + 3) Slashing damage.'),
      _a(name: 'Cudgel (Commoner)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 2, reachFt: 5, damageDice: '1d4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +2, reach 5 ft. *Hit:* 2 (1d4) Bludgeoning damage.'),
      _a(name: 'Sickle (Cultist)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d4+1', damageType: 'Slashing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 3 (1d4 + 1) Slashing damage plus 3 (1d6) Necrotic damage.'),
      _a(name: 'Sickle (Druid)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d4+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Slashing damage.'),
      _a(name: 'Spellcasting (Druid NPC)', actionType: 'Action', description: 'The druid casts one of its prepared spells, using Wisdom as the spellcasting ability (spell save DC 13). At will: Druidcraft, Produce Flame, Shillelagh. 1/Day each: Cure Wounds, Entangle, Faerie Fire, Speak with Animals, Thunderwave.'),
      _a(name: 'Spear (Guard)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d6+1', damageType: 'Piercing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Piercing damage, or 5 (1d8 + 1) if used with two hands.'),
      _a(name: 'Halberd (Guard Captain)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 10, damageDice: '1d10+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +6, reach 10 ft. *Hit:* 8 (1d10 + 3) Slashing damage.'),
      _a(name: 'Heavy Crossbow (Guard Captain)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 4, rangeNormalFt: 100, rangeLongFt: 400, damageDice: '1d10+2', damageType: 'Piercing', description: '*Ranged Attack Roll:* +4, range 100/400 ft. *Hit:* 7 (1d10 + 2) Piercing damage.'),
      _a(name: 'Shortsword (Spy)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.'),
      _a(name: 'Hand Crossbow (Spy)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 4, rangeNormalFt: 30, rangeLongFt: 120, damageDice: '1d6+2', damageType: 'Piercing', description: '*Ranged Attack Roll:* +4, range 30/120 ft. *Hit:* 5 (1d6 + 2) Piercing damage.'),
      _a(name: 'Shortsword (Assassin)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1d6+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 6 (1d6 + 3) Piercing damage plus 24 (7d6) Poison damage.'),
      _a(name: 'Light Crossbow (Assassin)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 6, rangeNormalFt: 80, rangeLongFt: 320, damageDice: '1d8+3', damageType: 'Piercing', description: '*Ranged Attack Roll:* +6, range 80/320 ft. *Hit:* 7 (1d8 + 3) Piercing damage plus 24 (7d6) Poison damage.'),
      _a(name: 'Mace (Priest Acolyte)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 2, reachFt: 5, damageDice: '1d6', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +2, reach 5 ft. *Hit:* 3 (1d6) Bludgeoning damage.'),
      _a(name: 'Longsword (Knight)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d8+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 8 (1d8 + 3) Slashing damage, or 9 (1d10 + 3) if used with two hands.'),
      _a(name: 'Heavy Crossbow (Knight)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 2, rangeNormalFt: 100, rangeLongFt: 400, damageDice: '1d10', damageType: 'Piercing', description: '*Ranged Attack Roll:* +2, range 100/400 ft. *Hit:* 5 (1d10) Piercing damage.'),
      _a(name: 'Longsword (Veteran)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d8+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 7 (1d8 + 3) Slashing damage, or 8 (1d10 + 3) two-handed.'),
      _a(name: 'Shortsword (Veteran)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d6+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 6 (1d6 + 3) Piercing damage.'),
      _a(name: 'Heavy Crossbow (Veteran)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 3, rangeNormalFt: 100, rangeLongFt: 400, damageDice: '1d10+1', damageType: 'Piercing', description: '*Ranged Attack Roll:* +3, range 100/400 ft. *Hit:* 6 (1d10 + 1) Piercing damage.'),
      _a(name: 'Mace (Noble)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d6+1', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Bludgeoning damage.'),
      _a(name: 'Spear (Tough)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.'),
      _a(name: 'Greatsword (Tough Boss)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d6+4', damageType: 'Slashing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 11 (2d6 + 4) Slashing damage.'),
      _a(name: 'Spear (Warrior Infantry)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.'),
      _a(name: 'Longsword (Warrior Veteran)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d8+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 7 (1d8 + 3) Slashing damage.'),
      _a(name: 'Scimitar (Pirate)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Slashing damage.'),
      _a(name: 'Rapier (Pirate Captain)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1d8+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 8 (1d8 + 4) Piercing damage.'),
      _a(name: 'Longbow (Scout)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 4, rangeNormalFt: 150, rangeLongFt: 600, damageDice: '1d8+2', damageType: 'Piercing', description: '*Ranged Attack Roll:* +4, range 150/600 ft. *Hit:* 6 (1d8 + 2) Piercing damage.'),
      _a(name: 'Shortsword (Scout)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.'),
      _a(name: 'Trident (Sahuagin Warrior)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d6+1', damageType: 'Piercing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Piercing damage, or 5 (1d8 + 1) two-handed.'),
      _a(name: 'Bite (Sahuagin Warrior)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d4+1', damageType: 'Piercing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 3 (1d4 + 1) Piercing damage.'),
      _a(name: 'Spear (Merfolk Skirmisher)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d6+1', damageType: 'Piercing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Piercing damage.'),
      _a(name: 'Harpoon (Merrow)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d6+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 11 (2d6 + 4) Piercing damage. The target is pulled up to 10 feet straight toward the merrow.'),
      _a(name: 'Bite (Merrow)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1d8+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 8 (1d8 + 4) Piercing damage.'),

      // Devils
      _a(name: 'Trident (Bearded Devil)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.'),
      _a(name: 'Beard (Bearded Devil)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d8+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 6 (1d8 + 2) Piercing damage and the target must succeed on a DC 12 Constitution save or have the Poisoned condition for 1 minute.', conditions: ['Poisoned']),
      _a(name: 'Glaive (Barbed Devil)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 10, damageDice: '2d10+4', damageType: 'Slashing', description: '*Melee Attack Roll:* +8, reach 10 ft. *Hit:* 15 (2d10 + 4) Slashing damage plus 7 (2d6) Fire damage.'),
      _a(name: 'Tail (Barbed Devil)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 10, damageDice: '2d8+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +8, reach 10 ft. *Hit:* 13 (2d8 + 4) Piercing damage.'),
      _a(name: 'Spiked Chain (Chain Devil)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 10, damageDice: '2d6+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +8, reach 10 ft. *Hit:* 11 (2d6 + 4) Piercing damage. The target has the Grappled condition (escape DC 14) and is Restrained until the grapple ends.', conditions: ['Grappled', 'Restrained']),
      _a(name: 'Bite (Bone Devil)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 10, damageDice: '1d10+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +8, reach 10 ft. *Hit:* 9 (1d10 + 4) Piercing damage.'),
      _a(name: 'Sting (Bone Devil)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 10, damageDice: '2d8+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +8, reach 10 ft. *Hit:* 13 (2d8 + 4) Piercing damage plus 17 (5d6) Poison damage. The target must succeed on a DC 14 Constitution save or have the Poisoned condition for 1 minute.', conditions: ['Poisoned']),
      _a(name: 'Fork (Horned Devil)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 10, damageDice: '2d8+6', damageType: 'Piercing', description: '*Melee Attack Roll:* +10, reach 10 ft. *Hit:* 15 (2d8 + 6) Piercing damage.'),
      _a(name: 'Hurl Flame (Horned Devil)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Spell', attackBonus: 7, rangeNormalFt: 150, damageDice: '4d6', damageType: 'Fire', description: '*Ranged Spell Attack:* +7, range 150 ft. *Hit:* 14 (4d6) Fire damage. If the target is a flammable object that isn\'t being worn or carried, it ignites.'),
      _a(name: 'Bite (Ice Devil)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 5, damageDice: '2d6+5', damageType: 'Piercing', description: '*Melee Attack Roll:* +10, reach 5 ft. *Hit:* 12 (2d6 + 5) Piercing damage plus 10 (3d6) Cold damage.'),
      _a(name: 'Spear (Ice Devil)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 5, damageDice: '2d6+5', damageType: 'Piercing', description: '*Melee Attack Roll:* +10, reach 5 ft. *Hit:* 12 (2d6 + 5) Piercing damage plus 10 (3d6) Cold damage.'),
      _a(name: 'Tail (Ice Devil)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 10, damageDice: '3d6+5', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +10, reach 10 ft. *Hit:* 15 (3d6 + 5) Bludgeoning damage plus 10 (3d6) Cold damage.'),
      _a(name: 'Sting (Lemure)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d4+1', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 3 (1d4 + 1) Bludgeoning damage.'),
      _a(name: 'Sting (Imp)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d4+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 5 (1d4 + 3) Piercing damage plus 10 (3d6) Poison damage.'),
      _a(name: 'Scourge (Erinyes)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 5, damageDice: '1d8+4', damageType: 'Slashing', description: '*Melee Attack Roll:* +8, reach 5 ft. *Hit:* 8 (1d8 + 4) Slashing damage plus 22 (4d8 + 4) Fire damage.'),
      _a(name: 'Longbow (Erinyes)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 7, rangeNormalFt: 150, rangeLongFt: 600, damageDice: '1d8+3', damageType: 'Piercing', description: '*Ranged Attack Roll:* +7, range 150/600 ft. *Hit:* 7 (1d8 + 3) Piercing damage plus 27 (6d8) Poison damage. On failed DC 14 Con save, target is Poisoned until cured.', conditions: ['Poisoned']),
      _a(name: 'Mace (Pit Fiend)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 14, reachFt: 10, damageDice: '2d6+8', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +14, reach 10 ft. *Hit:* 15 (2d6 + 8) Bludgeoning damage plus 21 (6d6) Fire damage.'),
      _a(name: 'Fireball (Pit Fiend)', actionType: 'Action', usesPerDay: 3, damageDice: '14d6', damageType: 'Fire', saveDc: 21, saveAbility: 'Dexterity', description: 'The pit fiend casts Fireball (level 5; 14d6 Fire damage; 20-foot Sphere; DC 21 Dex save for half).'),

      // Demons
      _a(name: 'Bite (Dretch)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 2, reachFt: 5, damageDice: '1d6', damageType: 'Piercing', description: '*Melee Attack Roll:* +2, reach 5 ft. *Hit:* 3 (1d6) Piercing damage.'),
      _a(name: 'Claws (Dretch)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 2, reachFt: 5, damageDice: '2d4', damageType: 'Slashing', description: '*Melee Attack Roll:* +2, reach 5 ft. *Hit:* 5 (2d4) Slashing damage.'),
      _a(name: 'Claws (Quasit)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d4+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Slashing damage plus 7 (2d6) Poison damage.'),
      _a(name: 'Pincer (Glabrezu)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 9, reachFt: 10, damageDice: '2d6+5', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +9, reach 10 ft. *Hit:* 12 (2d6 + 5) Bludgeoning damage. Target is Grappled (escape DC 15) if pincer is free.', conditions: ['Grappled']),
      _a(name: 'Bite (Hezrou)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d10+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 15 (2d10 + 4) Piercing damage.'),
      _a(name: 'Claws (Hezrou)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d6+4', damageType: 'Slashing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 11 (2d6 + 4) Slashing damage.'),
      _a(name: 'Bite (Marilith)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 9, reachFt: 5, damageDice: '2d10+5', damageType: 'Piercing', description: '*Melee Attack Roll:* +9, reach 5 ft. *Hit:* 16 (2d10 + 5) Piercing damage.'),
      _a(name: 'Longsword (Marilith)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 9, reachFt: 5, damageDice: '2d8+5', damageType: 'Slashing', description: '*Melee Attack Roll:* +9, reach 5 ft. *Hit:* 14 (2d8 + 5) Slashing damage.'),
      _a(name: 'Bite (Nalfeshnee)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 5, damageDice: '5d10+5', damageType: 'Piercing', description: '*Melee Attack Roll:* +10, reach 5 ft. *Hit:* 32 (5d10 + 5) Piercing damage.'),
      _a(name: 'Claws (Nalfeshnee)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 10, damageDice: '3d6+5', damageType: 'Slashing', description: '*Melee Attack Roll:* +10, reach 10 ft. *Hit:* 15 (3d6 + 5) Slashing damage.'),
      _a(name: 'Beak (Vrock)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d10+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 14 (2d10 + 3) Piercing damage.'),
      _a(name: 'Talons (Vrock)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d6+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 10 (2d6 + 3) Slashing damage.'),
      _a(name: 'Spores (Vrock)', actionType: 'Action', usesPerDay: 1, description: 'A 15-foot-radius cloud of toxic spores extends from the vrock. The spores spread around corners. Each creature in that area must succeed on a DC 14 Constitution save or be Poisoned. While Poisoned this way, a target takes 5 (1d10) Poison damage at the start of each of its turns.', conditions: ['Poisoned']),

      // Mephits
      _a(name: 'Claws (Dust Mephit)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d4+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Slashing damage.'),
      _a(name: 'Claws (Ice Mephit)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d4+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 3 (1d4 + 2) Slashing damage plus 2 (1d4) Cold damage.'),
      _a(name: 'Claws (Magma Mephit)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d4+1', damageType: 'Slashing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 3 (1d4 + 1) Slashing damage plus 2 (1d4) Fire damage.'),
      _a(name: 'Claws (Steam Mephit)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d4+1', damageType: 'Slashing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 3 (1d4 + 1) Slashing damage plus 2 (1d4) Fire damage.'),

      // Giants
      _a(name: 'Greataxe (Cloud Giant)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 12, reachFt: 10, damageDice: '3d12+8', damageType: 'Slashing', description: '*Melee Attack Roll:* +12, reach 10 ft. *Hit:* 27 (3d12 + 8) Slashing damage.'),
      _a(name: 'Rock (Cloud Giant)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 12, rangeNormalFt: 60, rangeLongFt: 240, damageDice: '4d10+8', damageType: 'Bludgeoning', description: '*Ranged Attack Roll:* +12, range 60/240 ft. *Hit:* 30 (4d10 + 8) Bludgeoning damage.'),
      _a(name: 'Greatsword (Fire Giant)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 11, reachFt: 10, damageDice: '6d6+7', damageType: 'Slashing', description: '*Melee Attack Roll:* +11, reach 10 ft. *Hit:* 28 (6d6 + 7) Slashing damage.'),
      _a(name: 'Rock (Fire Giant)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 11, rangeNormalFt: 60, rangeLongFt: 240, damageDice: '4d10+7', damageType: 'Bludgeoning', description: '*Ranged Attack Roll:* +11, range 60/240 ft. *Hit:* 29 (4d10 + 7) Bludgeoning damage.'),
      _a(name: 'Greataxe (Frost Giant)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 9, reachFt: 10, damageDice: '3d12+6', damageType: 'Slashing', description: '*Melee Attack Roll:* +9, reach 10 ft. *Hit:* 25 (3d12 + 6) Slashing damage.'),
      _a(name: 'Rock (Frost Giant)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 9, rangeNormalFt: 60, rangeLongFt: 240, damageDice: '4d10+6', damageType: 'Bludgeoning', description: '*Ranged Attack Roll:* +9, range 60/240 ft. *Hit:* 28 (4d10 + 6) Bludgeoning damage.'),
      _a(name: 'Thunderous Greatsword (Storm Giant)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 14, reachFt: 10, damageDice: '6d6+9', damageType: 'Slashing', description: '*Melee Attack Roll:* +14, reach 10 ft. *Hit:* 30 (6d6 + 9) Slashing damage plus 13 (3d8) Thunder damage.'),
      _a(name: 'Lightning Strike (Storm Giant)', actionType: 'Action', usesPerDay: 3, damageDice: '12d8', damageType: 'Lightning', saveDc: 17, saveAbility: 'Dexterity', description: '*Dexterity Saving Throw:* DC 17, one creature within 500 feet. *Failure:* 54 (12d8) Lightning damage. *Success:* Half damage.'),

      // Undead extras
      _a(name: 'Withering Touch (Wraith)', actionType: 'Action', isAttack: true, attackKind: 'Melee Spell', attackBonus: 6, reachFt: 5, damageDice: '4d8+3', damageType: 'Necrotic', description: '*Melee Spell Attack:* +6, reach 5 ft. *Hit:* 21 (4d8 + 3) Necrotic damage.'),
      _a(name: 'Strength-Draining Touch (Shadow)', actionType: 'Action', isAttack: true, attackKind: 'Melee Spell', attackBonus: 4, reachFt: 5, damageDice: '2d6+2', damageType: 'Necrotic', description: '*Melee Spell Attack:* +4, reach 5 ft. *Hit:* 9 (2d6 + 2) Necrotic damage and the target\'s Strength is reduced by 1d4. The target dies if this reduces it to 0; otherwise the reduction lasts until the target finishes a Short or Long Rest.'),
      _a(name: 'Rotting Fist (Mummy Lord)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 9, reachFt: 5, damageDice: '3d6+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +9, reach 5 ft. *Hit:* 14 (3d6 + 4) Bludgeoning damage plus 21 (6d6) Necrotic damage. The target must succeed on a DC 16 Con save or be cursed with mummy rot.'),
      _a(name: 'Spellcasting (Mummy Lord)', actionType: 'Action', description: 'The mummy lord casts one of the following spells, using Wisdom (spell save DC 17). At will: Sacred Flame, Thaumaturgy. 3/Day each: Dispel Magic, Hold Person. 1/Day each: Animate Dead, Insect Plague.'),
      _a(name: 'Claws (Vampire Spawn)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d4+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 8 (2d4 + 3) Slashing damage. The target is Grappled (escape DC 13). Until the grapple ends, the target is Restrained.', conditions: ['Grappled', 'Restrained']),
      _a(name: 'Bite (Vampire Spawn)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1d6+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 6 (1d6 + 3) Piercing damage plus 7 (2d6) Necrotic damage.'),
      _a(name: 'Bite (Vampire Familiar)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage plus 5 (2d4) Necrotic damage.'),
      _a(name: 'Slam (Ghost)', actionType: 'Action', isAttack: true, attackKind: 'Melee Spell', attackBonus: 5, reachFt: 5, damageDice: '4d6+3', damageType: 'Necrotic', description: '*Melee Spell Attack:* +5, reach 5 ft. *Hit:* 17 (4d6 + 3) Necrotic damage.'),
      _a(name: 'Etherealness (Ghost)', actionType: 'Action', description: 'The ghost shifts from the Material Plane to the Border Ethereal, or vice versa. It is visible on the Material Plane while it is in the Border Ethereal, and vice versa, yet it can\'t affect or be affected by anything on the other plane.'),
      _a(name: 'Horrifying Visage (Ghost)', actionType: 'Action', saveDc: 13, saveAbility: 'Wisdom', description: '*Wisdom Saving Throw:* DC 13, each non-Undead creature in a 60-foot Cone. *Failure:* 10 (3d6) Psychic damage and the target has the Frightened condition for 1 minute. *Success:* Half damage and immune to this ghost\'s Horrifying Visage for 24 hours.', damageDice: '3d6', damageType: 'Psychic', conditions: ['Frightened']),
      _a(name: 'Bite (Ghast)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '2d8+1', damageType: 'Piercing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 12 (2d8 + 1) Piercing damage.'),
      _a(name: 'Claws (Ghast)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '2d6+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Slashing damage. The target must succeed on a DC 10 Constitution save or be Paralyzed for 1 minute.', conditions: ['Paralyzed']),
      _a(name: 'Slam (Ogre Zombie)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d10+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 13 (2d10 + 4) Bludgeoning damage.'),
      _a(name: 'Shortsword (Minotaur Skeleton)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d6+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 11 (2d6 + 4) Piercing damage.'),
      _a(name: 'Hooves (Warhorse Skeleton)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d6+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 11 (2d6 + 4) Bludgeoning damage.'),
      _a(name: 'Slams (Swarm of Crawling Claws)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '4d6+2', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 16 (4d6 + 2) Bludgeoning damage, or half if the swarm has half its HP or fewer.'),

      // Lycanthropes
      _a(name: 'Bite (Werebear)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d10+5', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 16 (2d10 + 5) Piercing damage. If the target is Humanoid, it must succeed on a DC 14 Con save or be cursed with Werebear lycanthropy.'),
      _a(name: 'Claws (Werebear)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d8+5', damageType: 'Slashing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 14 (2d8 + 5) Slashing damage.'),
      _a(name: 'Tusks (Wereboar)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '2d6+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Slashing damage. If target is Humanoid, DC 12 Con save or cursed with Wereboar lycanthropy.'),
      _a(name: 'Bite (Wererat)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage. If target is Humanoid, DC 11 Con save or cursed with Wererat lycanthropy.'),
      _a(name: 'Bite (Weretiger)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1d10+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 9 (1d10 + 4) Piercing damage. If target is Humanoid, DC 13 Con save or cursed with Weretiger lycanthropy.'),
      _a(name: 'Claws (Weretiger)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1d8+4', damageType: 'Slashing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 8 (1d8 + 4) Slashing damage.'),

      // Constructs and Golems
      _a(name: 'Slam (Clay Golem)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 5, damageDice: '2d10+5', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +8, reach 5 ft. *Hit:* 16 (2d10 + 5) Bludgeoning damage. The target\'s HP maximum is reduced by an amount equal to the damage.'),
      _a(name: 'Slam (Flesh Golem)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d8+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 13 (2d8 + 4) Bludgeoning damage.'),
      _a(name: 'Slam (Stone Golem)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 5, damageDice: '3d8+6', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +10, reach 5 ft. *Hit:* 19 (3d8 + 6) Bludgeoning damage.'),
      _a(name: 'Slam (Iron Golem)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 13, reachFt: 5, damageDice: '3d8+7', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +13, reach 5 ft. *Hit:* 20 (3d8 + 7) Bludgeoning damage.'),
      _a(name: 'Sword (Iron Golem)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 13, reachFt: 10, damageDice: '3d10+7', damageType: 'Slashing', description: '*Melee Attack Roll:* +13, reach 10 ft. *Hit:* 23 (3d10 + 7) Slashing damage.'),
      _a(name: 'Bite (Animated Flying Sword)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d8+1', damageType: 'Slashing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 5 (1d8 + 1) Slashing damage.'),
      _a(name: 'Smother (Animated Rug of Smothering)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '2d6+3', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Bludgeoning damage. The target is Grappled (escape DC 13) and Blinded.', conditions: ['Grappled', 'Blinded']),
      _a(name: 'Slam (Helmed Horror Shield Guardian)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d6+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 11 (2d6 + 4) Bludgeoning damage.'),
      _a(name: 'Bite (Homunculus)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d4+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage and DC 10 Con save or Poisoned 1 minute.', conditions: ['Poisoned']),
      _a(name: 'Slam (Invisible Stalker)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d6+3', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 10 (2d6 + 3) Bludgeoning damage.'),
      _a(name: 'Sting (Magmin)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Slashing damage plus 7 (2d6) Fire damage.'),
      _a(name: 'Slam (Azer Sentinel)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d8+3', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 7 (1d8 + 3) Bludgeoning damage plus 3 (1d6) Fire damage.'),

      // Aberrations & Monstrosities
      _a(name: 'Bite (Ankheg)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '2d6+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Slashing damage plus 3 (1d6) Acid damage. Target is Grappled (escape DC 13) if Large or smaller.', conditions: ['Grappled']),
      _a(name: 'Acid Spray (Ankheg)', actionType: 'Action', rechargeKind: 'Long Rest', damageDice: '5d10', damageType: 'Acid', saveDc: 13, saveAbility: 'Dexterity', description: '*Dexterity Saving Throw:* DC 13, each creature in a 30-foot Line. *Failure:* 10 (3d6) Acid damage. *Success:* Half damage.'),
      _a(name: 'Beak (Axe Beak)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d8+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 6 (1d8 + 2) Slashing damage.'),
      _a(name: 'Bite (Behir)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 10, damageDice: '3d10+6', damageType: 'Piercing', description: '*Melee Attack Roll:* +10, reach 10 ft. *Hit:* 22 (3d10 + 6) Piercing damage.'),
      _a(name: 'Lightning Breath (Behir)', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, damageDice: '12d10', damageType: 'Lightning', saveDc: 16, saveAbility: 'Dexterity', description: '*Dexterity Saving Throw:* DC 16, each creature in a 60-foot Line. *Failure:* 66 (12d10) Lightning damage. *Success:* Half damage.'),
      _a(name: 'Pseudopod (Black Pudding)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 10, damageDice: '1d6+3', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +5, reach 10 ft. *Hit:* 6 (1d6 + 3) Bludgeoning damage plus 18 (4d8) Acid damage.'),
      _a(name: 'Bite (Blink Dog)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d6+1', damageType: 'Piercing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Piercing damage.'),
      _a(name: 'Teleport (Blink Dog)', actionType: 'Bonus Action', description: 'The blink dog magically teleports up to 40 feet to an unoccupied space it can see.'),
      _a(name: 'Bite (Bulette)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '4d12+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 30 (4d12 + 4) Piercing damage.'),
      _a(name: 'Pike (Centaur Trooper)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 10, damageDice: '1d10+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 10 ft. *Hit:* 9 (1d10 + 4) Piercing damage.'),
      _a(name: 'Hooves (Centaur Trooper)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d6+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 11 (2d6 + 4) Bludgeoning damage.'),
      _a(name: 'Bite (Chimera)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d6+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 11 (2d6 + 4) Piercing damage.'),
      _a(name: 'Fire Breath (Chimera)', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, damageDice: '7d8', damageType: 'Fire', saveDc: 15, saveAbility: 'Dexterity', description: '*Dexterity Saving Throw:* DC 15, each creature in a 15-foot Cone. *Failure:* 31 (7d8) Fire damage. *Success:* Half damage.'),
      _a(name: 'Tail (Cloaker)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 10, damageDice: '2d6+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 10 ft. *Hit:* 10 (2d6 + 3) Piercing damage.'),
      _a(name: 'Attach (Cloaker)', actionType: 'Action', description: 'A Medium or smaller target the cloaker can see is grappled, blinded by it, suffocating after 5 rounds, and the cloaker can\'t use this attack again while grappling. Escape DC 14.', conditions: ['Grappled', 'Blinded']),
      _a(name: 'Tentacles (Darkmantle)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d6+3', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 6 (1d6 + 3) Bludgeoning damage. The target is Grappled (escape DC 13) and the darkmantle attaches.', conditions: ['Grappled']),
      _a(name: 'Bite (Doppelganger)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1d6+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 7 (1d6 + 4) Piercing damage.'),
      _a(name: 'Read Thoughts (Doppelganger)', actionType: 'Action', description: 'The doppelganger magically reads the surface thoughts of one creature within 60 feet. Until the doppelganger\'s concentration ends, it has Advantage on attack rolls and ability checks against the target.'),
      _a(name: 'Bite (Dragon Turtle)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 13, reachFt: 15, damageDice: '3d12+7', damageType: 'Piercing', description: '*Melee Attack Roll:* +13, reach 15 ft. *Hit:* 26 (3d12 + 7) Piercing damage.'),
      _a(name: 'Steam Breath (Dragon Turtle)', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, damageDice: '15d6', damageType: 'Fire', saveDc: 18, saveAbility: 'Constitution', description: '*Constitution Saving Throw:* DC 18, each creature in a 60-foot Cone. *Failure:* 52 (15d6) Fire damage. *Success:* Half damage.'),
      _a(name: 'Claws (Drider)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d4+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 8 (2d4 + 3) Slashing damage.'),
      _a(name: 'Web Bite (Drider)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1d4+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 5 (1d4 + 3) Piercing damage plus 9 (2d8) Poison damage.'),
      _a(name: 'Bite (Ettercap)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d8+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 6 (1d8 + 2) Piercing damage plus 4 (1d8) Poison damage. DC 11 Con save or Poisoned 1 minute.', conditions: ['Poisoned']),
      _a(name: 'Web (Ettercap)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 4, rangeNormalFt: 30, rangeLongFt: 60, description: '*Ranged Attack Roll:* +4, range 30/60 ft. *Hit:* The target is Restrained (escape DC 11). The web has AC 10 and 5 HP, vulnerable to Fire.', conditions: ['Restrained']),
      _a(name: 'Engulf (Gelatinous Cube)', actionType: 'Action', saveDc: 12, saveAbility: 'Dexterity', description: 'The cube moves up to its Speed. While doing so, it can enter Large or smaller creatures\' spaces. Each engulfed creature is Restrained and takes 10 (3d6) Acid damage at the start of each of the cube\'s turns.', damageDice: '3d6', damageType: 'Acid', conditions: ['Restrained']),
      _a(name: 'Bites (Gibbering Mouther)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 2, reachFt: 5, damageDice: '4d6', damageType: 'Piercing', description: '*Melee Attack Roll:* +2, reach 5 ft. *Hit:* 17 (4d6 + 3) Piercing damage. If the target is a Large or smaller creature, it must succeed on a DC 10 Strength save or have the Prone condition.', conditions: ['Prone']),
      _a(name: 'Spear (Gnoll Warrior)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.'),
      _a(name: 'Goblin Boss Scimitar', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Slashing damage.'),
      _a(name: 'Goblin Minion Sickle', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d4+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Slashing damage.'),
      _a(name: 'Gore (Gorgon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 5, damageDice: '2d12+5', damageType: 'Piercing', description: '*Melee Attack Roll:* +8, reach 5 ft. *Hit:* 18 (2d12 + 5) Piercing damage.'),
      _a(name: 'Petrifying Breath (Gorgon)', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, saveDc: 13, saveAbility: 'Constitution', description: '*Constitution Saving Throw:* DC 13, each creature in a 30-foot Cone. *First Failure:* Restrained and begins to turn to stone. *Second Failure:* Petrified.', conditions: ['Restrained', 'Petrified']),
      _a(name: 'Pseudopod (Gray Ooze)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d6+1', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 4 (1d6 + 1) Bludgeoning damage plus 7 (2d6) Acid damage and target\'s armor takes a -1 penalty until repaired.'),
      _a(name: 'Claws (Green Hag)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d8+4', damageType: 'Slashing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 13 (2d8 + 4) Slashing damage.'),
      _a(name: 'Tentacles (Grick)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '2d6+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 9 (2d6 + 2) Slashing damage.'),
      _a(name: 'Beak (Griffon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1d8+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 8 (1d8 + 4) Piercing damage.'),
      _a(name: 'Claws (Grimlock)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d8+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 6 (1d8 + 2) Slashing damage.'),
      _a(name: 'Spear (Guardian Naga)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 10, damageDice: '1d6+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +8, reach 10 ft. *Hit:* 6 (1d6 + 3) Piercing damage plus 22 (5d8) Poison damage.'),
      _a(name: 'Spit Poison (Guardian Naga)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 8, rangeNormalFt: 15, rangeLongFt: 30, damageDice: '10d8', damageType: 'Poison', description: '*Ranged Attack Roll:* +8, range 15/30 ft. *Hit:* 45 (10d8) Poison damage.'),
      _a(name: 'Bite (Spirit Naga)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 10, damageDice: '1d6+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 10 ft. *Hit:* 7 (1d6 + 4) Piercing damage plus 14 (4d6) Poison damage.'),
      _a(name: 'Claws (Half-Dragon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1d6+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 6 (1d6 + 3) Slashing damage.'),
      _a(name: 'Breath Weapon (Half-Dragon)', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, damageDice: '6d6', saveDc: 14, saveAbility: 'Constitution', description: 'Breath weapon shape and damage type depend on parent dragon\'s color. *Saving Throw:* DC 14, each creature in area. *Failure:* 21 (6d6) damage. *Success:* Half damage.'),
      _a(name: 'Bite (Hell Hound)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d8+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 7 (1d8 + 3) Piercing damage plus 7 (2d6) Fire damage.'),
      _a(name: 'Fire Breath (Hell Hound)', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, damageDice: '6d6', damageType: 'Fire', saveDc: 12, saveAbility: 'Dexterity', description: '*Dexterity Saving Throw:* DC 12, each creature in a 15-foot Cone. *Failure:* 21 (6d6) Fire damage. *Success:* Half damage.'),
      _a(name: 'Beak (Hippogriff)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d10+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (1d10 + 2) Piercing damage.'),
      _a(name: 'Longsword (Hobgoblin Captain)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d8+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 7 (1d8 + 3) Slashing damage.'),
      _a(name: 'Tentacles (Kraken)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 17, reachFt: 30, damageDice: '3d8+10', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +17, reach 30 ft. *Hit:* 23 (3d8 + 10) Bludgeoning damage. Target is Grappled (escape DC 18) and Restrained.', conditions: ['Grappled', 'Restrained']),
      _a(name: 'Lightning Storm (Kraken)', actionType: 'Action', damageDice: '4d10', damageType: 'Lightning', saveDc: 23, saveAbility: 'Dexterity', description: 'Each creature within 10 feet of a tentacle takes 22 (4d10) Lightning damage on failed DC 23 Dex save, half on success.'),
      _a(name: 'Claws (Lamia)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d10+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 14 (2d10 + 3) Slashing damage.'),
      _a(name: 'Pseudopod (Mimic)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d8+3', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 7 (1d8 + 3) Bludgeoning damage. If in object form, target is also Grappled (escape DC 13) and Adhered.', conditions: ['Grappled']),
      _a(name: 'Greataxe (Minotaur of Baphomet)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d12+4', damageType: 'Slashing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 17 (2d12 + 4) Slashing damage.'),
      _a(name: 'Bite (Night Hag)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d8+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 13 (2d8 + 4) Piercing damage.'),
      _a(name: 'Bite (Sea Hag)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '2d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 9 (2d6 + 2) Piercing damage.'),
      _a(name: 'Hooves (Nightmare)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d8+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 13 (2d8 + 4) Bludgeoning damage plus 7 (2d6) Fire damage.'),
      _a(name: 'Pseudopod (Ochre Jelly)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '2d6+2', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 9 (2d6 + 2) Bludgeoning damage plus 3 (1d6) Acid damage.'),
      _a(name: 'Claws (Oni)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d8+4', damageType: 'Slashing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 13 (2d8 + 4) Slashing damage.'),
      _a(name: 'Hooves (Pegasus)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d6+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 11 (2d6 + 4) Bludgeoning damage.'),
      _a(name: 'Bite (Phase Spider)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d10+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 7 (1d10 + 2) Piercing damage plus 18 (4d8) Poison damage.'),
      _a(name: 'Bite (Pseudodragon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1d4+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage.'),
      _a(name: 'Sting (Pseudodragon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1d4+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage. DC 11 Con save or Poisoned 1 hour.', conditions: ['Poisoned']),
      _a(name: 'Bite (Purple Worm)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 9, reachFt: 10, damageDice: '3d8+6', damageType: 'Piercing', description: '*Melee Attack Roll:* +9, reach 10 ft. *Hit:* 19 (3d8 + 6) Piercing damage.'),
      _a(name: 'Tail Stinger (Purple Worm)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 9, reachFt: 10, damageDice: '3d6+6', damageType: 'Piercing', description: '*Melee Attack Roll:* +9, reach 10 ft. *Hit:* 19 (3d6 + 6) Piercing damage plus 21 (6d6) Poison damage.'),
      _a(name: 'Claws (Rakshasa)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d6+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 9 (2d6 + 3) Slashing damage plus 7 (2d6) Necrotic damage.'),
      _a(name: 'Bite (Remorhaz)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 11, reachFt: 10, damageDice: '6d10+7', damageType: 'Piercing', description: '*Melee Attack Roll:* +11, reach 10 ft. *Hit:* 40 (6d10 + 7) Piercing damage plus 10 (3d6) Fire damage. Target is Grappled (escape DC 17), Restrained, Blinded.', conditions: ['Grappled', 'Restrained', 'Blinded']),
      _a(name: 'Talons (Roc)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 13, reachFt: 5, damageDice: '4d8+9', damageType: 'Slashing', description: '*Melee Attack Roll:* +13, reach 5 ft. *Hit:* 27 (4d8 + 9) Slashing damage.'),
      _a(name: 'Bite (Rust Monster)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d8+1', damageType: 'Piercing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 5 (1d8 + 1) Piercing damage. Iron, steel, copper, brass, silver, gold, mithral, adamantine corrodes.'),
      _a(name: 'Spear (Salamander)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d6+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 11 (2d6 + 4) Piercing damage plus 7 (2d6) Fire damage.'),
      _a(name: 'Tail (Salamander)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 10, damageDice: '2d8+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +7, reach 10 ft. *Hit:* 13 (2d8 + 4) Bludgeoning damage plus 7 (2d6) Fire damage and target is Grappled.', conditions: ['Grappled']),
      _a(name: 'Ram (Satyr)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Bludgeoning damage.'),
      _a(name: 'Bite (Shambling Mound)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d8+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 13 (2d8 + 4) Bludgeoning damage. The target is Grappled (escape DC 14), Restrained.', conditions: ['Grappled', 'Restrained']),
      _a(name: 'Spores (Shrieker Fungus)', actionType: 'Reaction', description: 'When a creature comes within 30 feet of the shrieker or a source of Bright Light is brought within 30 feet of it, the shrieker emits a shriek audible within 300 feet for 1 minute or until it dies.'),
      _a(name: 'Slam (Solar)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 15, reachFt: 5, damageDice: '4d8+8', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +15, reach 5 ft. *Hit:* 26 (4d8 + 8) Bludgeoning damage plus 27 (6d8) Radiant damage.'),
      _a(name: 'Slaying Longbow (Solar)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 13, rangeNormalFt: 600, rangeLongFt: 1500, damageDice: '2d8+6', damageType: 'Piercing', description: '*Ranged Attack Roll:* +13, range 600/1500 ft. *Hit:* 15 (2d8 + 6) Piercing damage plus 27 (6d8) Radiant damage.'),
      _a(name: 'Mace (Planetar)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 12, reachFt: 5, damageDice: '2d6+7', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +12, reach 5 ft. *Hit:* 14 (2d6 + 7) Bludgeoning damage plus 22 (5d8) Radiant damage.'),
      _a(name: 'Greatsword (Deva)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 5, damageDice: '2d6+4', damageType: 'Slashing', description: '*Melee Attack Roll:* +8, reach 5 ft. *Hit:* 11 (2d6 + 4) Slashing damage plus 18 (4d8) Radiant damage.'),
      _a(name: 'Claws (Sphinx)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 9, reachFt: 5, damageDice: '2d8+4', damageType: 'Slashing', description: '*Melee Attack Roll:* +9, reach 5 ft. *Hit:* 13 (2d8 + 4) Slashing damage.'),
      _a(name: 'Roar (Sphinx of Lore)', actionType: 'Bonus Action', usesPerDay: 3, description: 'The sphinx emits a magical roar. Each creature within 500 feet that can hear the roar must succeed on a Wisdom save or have a curse effect (varies by roar use).'),
      _a(name: 'Shortbow (Sprite)', actionType: 'Action', isAttack: true, attackKind: 'Ranged Weapon', attackBonus: 6, rangeNormalFt: 40, rangeLongFt: 160, damageDice: '1d6+3', damageType: 'Piercing', description: '*Ranged Attack Roll:* +6, range 40/160 ft. *Hit:* 1 Piercing damage and target must succeed on DC 10 Con save or be Poisoned for 1 minute (or sleep instead).', conditions: ['Poisoned']),
      _a(name: 'Proboscis (Stirge)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d4+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 5 (1d4 + 3) Piercing damage. The stirge attaches to the target. While attached, the stirge doesn\'t attack and the target takes 5 (1d4 + 3) HP drain at the start of each of the stirge\'s turns.'),
      _a(name: 'Claws (Succubus)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d6+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 6 (1d6 + 3) Slashing damage.'),
      _a(name: 'Charm (Succubus)', actionType: 'Action', usesPerDay: 1, saveDc: 15, saveAbility: 'Wisdom', description: 'The succubus targets one Humanoid it can see within 30 feet. The target must succeed on a DC 15 Wisdom save or have the Charmed condition for 1 day.', conditions: ['Charmed']),
      _a(name: 'Bite (Tarrasque)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 19, reachFt: 15, damageDice: '4d12+10', damageType: 'Piercing', description: '*Melee Attack Roll:* +19, reach 15 ft. *Hit:* 36 (4d12 + 10) Piercing damage and target is Grappled (escape DC 20).', conditions: ['Grappled']),
      _a(name: 'Swallow (Tarrasque)', actionType: 'Action', damageDice: '8d6', damageType: 'Acid', description: 'The tarrasque swallows a Grappled, Large or smaller creature. The swallowed target takes 64 (16d6) Acid damage at the start of each of the tarrasque\'s turns.'),
      _a(name: 'Slam (Troll Limb)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Bludgeoning damage.'),
      _a(name: 'Hooves (Unicorn)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d6+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 11 (2d6 + 4) Bludgeoning damage.'),
      _a(name: 'Horn (Unicorn)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '1d8+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 8 (1d8 + 4) Piercing damage plus 9 (2d8) Radiant damage.'),
      _a(name: 'Spores (Violet Fungus)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 2, reachFt: 10, damageDice: '4d8', damageType: 'Necrotic', description: '*Melee Attack Roll:* +2, reach 10 ft. *Hit:* 4 (1d8) Necrotic damage. The fungus has four such pseudopods, each making one attack.'),
      _a(name: 'Bite (Winter Wolf)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '2d6+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Piercing damage.'),
      _a(name: 'Cold Breath (Winter Wolf)', actionType: 'Action', rechargeKind: 'Roll', rechargeMinRoll: 5, damageDice: '6d8', damageType: 'Cold', saveDc: 12, saveAbility: 'Constitution', description: '*Constitution Saving Throw:* DC 12, each creature in a 15-foot Cone. *Failure:* 18 (4d8) Cold damage. *Success:* Half damage.'),
      _a(name: 'Bite (Worg)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '2d6+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Piercing damage.'),
      _a(name: 'Bite (Wyvern)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d6+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 11 (2d6 + 4) Piercing damage.'),
      _a(name: 'Stinger (Wyvern)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 10, damageDice: '2d6+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 10 ft. *Hit:* 11 (2d6 + 4) Piercing damage plus 24 (7d6) Poison damage.'),
      _a(name: 'Claws (Xorn)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '1d6+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 6 (1d6 + 3) Slashing damage.'),
      _a(name: 'Bite (Xorn)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '3d6+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 13 (3d6 + 3) Piercing damage.'),
      _a(name: 'Bite (Awakened Tree)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 10, damageDice: '3d6+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +6, reach 10 ft. *Hit:* 14 (3d6 + 4) Bludgeoning damage.'),
      _a(name: 'Slam (Awakened Shrub)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 1, reachFt: 5, damageDice: '1d4-1', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +1, reach 5 ft. *Hit:* 1 (1d4 − 1) Bludgeoning damage.'),
      _a(name: 'Greatclub (Hobgoblin Captain Stalker)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d8+3', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 7 (1d8 + 3) Bludgeoning damage.'),
      _a(name: 'Morningstar (Bugbear Stalker)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '2d8+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 12 (2d8 + 3) Piercing damage.'),
      _a(name: 'Scimitar (Djinni)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 9, reachFt: 5, damageDice: '2d6+5', damageType: 'Slashing', description: '*Melee Attack Roll:* +9, reach 5 ft. *Hit:* 12 (2d6 + 5) Slashing damage plus 9 (2d8) Lightning or Thunder damage.'),
      _a(name: 'Scimitar (Efreeti)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 10, reachFt: 5, damageDice: '2d6+6', damageType: 'Slashing', description: '*Melee Attack Roll:* +10, reach 5 ft. *Hit:* 13 (2d6 + 6) Slashing damage plus 9 (2d8) Fire damage.'),
      _a(name: 'Snake Hair (Medusa)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d4+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 4 (1d4 + 2) Piercing damage plus 14 (4d6) Poison damage.'),
      _a(name: 'Petrifying Gaze (Medusa)', actionType: 'Action', saveDc: 14, saveAbility: 'Constitution', description: '*Constitution Saving Throw:* DC 14, each creature within 30 feet that can see the medusa. *First Failure:* Restrained. *Second Failure:* Petrified.', conditions: ['Restrained', 'Petrified']),
      _a(name: 'Scimitar (Incubus)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '1d6+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 6 (1d6 + 3) Slashing damage.'),
      _a(name: 'Tentacle (Otyugh)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 10, damageDice: '1d8+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 10 ft. *Hit:* 7 (1d8 + 3) Piercing damage. Target is Grappled (escape DC 13).', conditions: ['Grappled']),
      _a(name: 'Glaive (Oni)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 10, damageDice: '2d10+5', damageType: 'Slashing', description: '*Melee Attack Roll:* +8, reach 10 ft. *Hit:* 16 (2d10 + 5) Slashing damage plus 9 (2d8) Necrotic damage.'),
      _a(name: 'Beak (Roc)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 13, reachFt: 10, damageDice: '4d8+9', damageType: 'Piercing', description: '*Melee Attack Roll:* +13, reach 10 ft. *Hit:* 27 (4d8 + 9) Piercing damage.'),
      _a(name: 'Bite (Seahorse)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 2, reachFt: 5, damageDice: '1', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +2, reach 5 ft. *Hit:* 1 Bludgeoning damage.'),
      _a(name: 'Slam (Awakened Tree)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 10, damageDice: '3d6+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +6, reach 10 ft. *Hit:* 14 (3d6 + 4) Bludgeoning damage.'),
      _a(name: 'Bite (Cloaker)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d6+3', damageType: 'Piercing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 10 (2d6 + 3) Piercing damage. The cloaker can grapple the target (escape DC 13).', conditions: ['Grappled']),
      _a(name: 'Beak (Grick)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d6+2', damageType: 'Piercing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 5 (1d6 + 2) Piercing damage.'),
      _a(name: 'Stone Axe (Grimlock)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d8+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 6 (1d8 + 2) Slashing damage.'),
      _a(name: 'Claws (Griffon)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 5, damageDice: '2d6+3', damageType: 'Slashing', description: '*Melee Attack Roll:* +6, reach 5 ft. *Hit:* 10 (2d6 + 3) Slashing damage.'),
      _a(name: 'Claws (Hippogriff)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '2d6+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 9 (2d6 + 2) Slashing damage.'),
      _a(name: 'Slam (Shambling Mound)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 5, damageDice: '2d8+4', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +7, reach 5 ft. *Hit:* 13 (2d8 + 4) Bludgeoning damage.'),
      _a(name: 'Engulf (Shambling Mound)', actionType: 'Action', saveDc: 14, saveAbility: 'Strength', description: 'The shambling mound engulfs a Medium or smaller creature it is grappling. The engulfed target is Blinded, Restrained, and unable to breathe, and it is moved with the mound.', conditions: ['Blinded', 'Restrained']),
      _a(name: 'Claw (Sphinx)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 12, reachFt: 5, damageDice: '2d8+8', damageType: 'Slashing', description: '*Melee Attack Roll:* +12, reach 5 ft. *Hit:* 17 (2d8 + 8) Slashing damage.'),
      _a(name: 'Claws (Sphinx of Wonder)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 4, reachFt: 5, damageDice: '1d4+2', damageType: 'Slashing', description: '*Melee Attack Roll:* +4, reach 5 ft. *Hit:* 4 (1d4 + 2) Slashing damage plus 5 (2d4) Psychic damage.'),
      _a(name: 'Bite (Cockatrice)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 3, reachFt: 5, damageDice: '1d4+1', damageType: 'Piercing', description: '*Melee Attack Roll:* +3, reach 5 ft. *Hit:* 3 (1d4 + 1) Piercing damage; petrification possible.'),
      _a(name: 'Touch (Sprite)', actionType: 'Action', saveDc: 10, saveAbility: 'Charisma', description: 'The sprite touches a creature; on a failed save, the creature has Charmed or Frightened condition.', conditions: ['Charmed', 'Frightened']),
      _a(name: 'Wing Attack (Pegasus)', actionType: 'Bonus Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 5, reachFt: 5, damageDice: '2d6+3', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +5, reach 5 ft. *Hit:* 10 (2d6 + 3) Bludgeoning damage.'),
      _a(name: 'Tail (Wyvern)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 7, reachFt: 10, damageDice: '2d6+4', damageType: 'Piercing', description: '*Melee Attack Roll:* +7, reach 10 ft. *Hit:* 11 (2d6 + 4) Piercing damage plus 24 (7d6) Poison damage on save fail.'),
      _a(name: 'Charm (Lamia)', actionType: 'Action', saveDc: 13, saveAbility: 'Wisdom', description: 'A creature within 30 feet must succeed on a DC 13 Wisdom save or be Charmed for 24 hours.', conditions: ['Charmed']),
      _a(name: 'Constrict (Spirit Naga)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 6, reachFt: 10, damageDice: '2d8+3', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +6, reach 10 ft. *Hit:* 11 (2d8 + 3) Bludgeoning damage; target is Grappled.', conditions: ['Grappled']),
      _a(name: 'Constrict (Guardian Naga)', actionType: 'Action', isAttack: true, attackKind: 'Melee Weapon', attackBonus: 8, reachFt: 10, damageDice: '3d6+5', damageType: 'Bludgeoning', description: '*Melee Attack Roll:* +8, reach 10 ft. *Hit:* 15 (3d6 + 5) Bludgeoning damage; target is Grappled.', conditions: ['Grappled']),
    ];
