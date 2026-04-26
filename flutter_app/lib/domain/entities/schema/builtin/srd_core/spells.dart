// SRD 5.2.1 Spells (pp. 104–175). The full SRD ships ~350 spells; this file
// covers the canonical, most-played selection across all 9 levels — every
// cantrip, every level-1 spell, and a representative high-impact slice of
// levels 2–9. Each entry uses typed identity fields plus markdown narrative
// `description`. The empty leftover spells can be authored incrementally —
// see srd_core_pack_test.dart for integrity coverage.
//
// Component glossary used below:
//   V = Verbal, S = Somatic, M = Material (with optional cost / consumed)
// Range types: Self, Touch, Ranged (with `range_ft`), Sight, Unlimited
// Duration units used: Instantaneous, Rounds, Minutes, Hours, Days.
//   "Until dispelled" mapped to Days (closest persistent unit). Reviewers can
//   remap when an "Until Dispelled" lookup row is added to Tier-0.

import '_helpers.dart';

const _v = 'Verbal';
const _s = 'Somatic';
const _m = 'Material';

/// Compact spell builder. `range`: 'Self' / 'Touch' / int (ft) / 'Sight' /
/// 'Unlimited'. `duration`: pass 'Instantaneous' or `${amount} ${unit}` like
/// '1 Minute', '10 Minutes', '8 Hours', '1 Round', '24 Hours'.
Map<String, dynamic> _spell({
  required String name,
  required int level,
  required String school,
  required String castTime,
  required dynamic range,
  required List<String> components,
  required String duration,
  required List<String> classes,
  required String description,
  bool ritual = false,
  bool concentration = false,
  String? material,
  int? materialCostGp,
  bool materialConsumed = false,
  String? saveAbility,
  String? attackType,
  List<String> damageTypes = const [],
  List<String> conditions = const [],
}) {
  // Range parse
  String rangeType;
  int? rangeFt;
  if (range == 'Self') {
    rangeType = 'Self';
  } else if (range == 'Touch') {
    rangeType = 'Touch';
  } else if (range == 'Sight') {
    rangeType = 'Sight';
  } else if (range == 'Unlimited') {
    rangeType = 'Unlimited';
  } else if (range is int) {
    rangeType = 'Ranged';
    rangeFt = range;
  } else {
    rangeType = 'Ranged';
  }

  // Casting time parse: "Action" / "Bonus Action" / "Reaction" / "1 Minute" / "1 Hour"
  int castAmount = 1;
  String castUnit = castTime;
  if (castTime.contains(' ')) {
    final parts = castTime.split(' ');
    castAmount = int.tryParse(parts[0]) ?? 1;
    castUnit = parts.sublist(1).join(' ');
  }

  // Duration parse: "Instantaneous" or "<amount> <unit>"
  int? durAmount;
  String durUnit = duration;
  if (duration != 'Instantaneous' && duration.contains(' ')) {
    final parts = duration.split(' ');
    durAmount = int.tryParse(parts[0]);
    durUnit = parts.sublist(1).join(' ');
    // Normalize: "Round" -> "Rounds", etc.
    if (!durUnit.endsWith('s') && durUnit != 'Instantaneous') {
      durUnit = '${durUnit}s';
    }
  }

  return packEntity(
    slug: 'spell',
    name: name,
    description: description,
    attributes: {
      'level': level,
      'school_ref': lookup('spell-school', school),
      'casting_time_amount': castAmount,
      'casting_time_unit_ref': lookup('casting-time-unit', castUnit),
      'is_ritual': ritual,
      'range_type': rangeType,
      if (rangeFt != null) 'range_ft': rangeFt,
      'components': [for (final c in components) lookup('casting-component', c)],
      if (material != null) 'material_description': material,
      if (materialCostGp != null) 'material_cost_gp': materialCostGp,
      if (material != null) 'material_consumed': materialConsumed,
      'duration_unit_ref': lookup('duration-unit', durUnit),
      if (durAmount != null) 'duration_amount': durAmount,
      'requires_concentration': concentration,
      'description': description,
      'class_refs': [for (final c in classes) ref('class', c)],
      if (damageTypes.isNotEmpty)
        'damage_type_refs': [
          for (final t in damageTypes) lookup('damage-type', t)
        ],
      if (saveAbility != null)
        'save_ability_ref': lookup('ability', saveAbility),
      if (attackType != null) 'attack_type': attackType,
      if (conditions.isNotEmpty)
        'applied_condition_refs': [
          for (final c in conditions) lookup('condition', c)
        ],
    },
  );
}

List<Map<String, dynamic>> srdSpells() => [
      // ─── Cantrips (Level 0) ──────────────────────────────────────────────
      _spell(
        name: 'Acid Splash',
        level: 0,
        school: 'Evocation',
        castTime: 'Action',
        range: 60,
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Wizard'],
        saveAbility: 'Dexterity',
        damageTypes: ['Acid'],
        description:
            'Hurl a bubble of acid. Choose one or two creatures within range no more than 5 feet apart. A target must succeed on a Dexterity saving throw or take 1d6 Acid damage.\n\n'
                '**Cantrip Upgrade.** The damage increases by 1d6 at character levels 5 (2d6), 11 (3d6), and 17 (4d6).',
      ),
      _spell(
        name: 'Chill Touch',
        level: 0,
        school: 'Necromancy',
        castTime: 'Action',
        range: 120,
        components: [_v, _s],
        duration: '1 Round',
        classes: ['Sorcerer', 'Warlock', 'Wizard'],
        attackType: 'Ranged',
        damageTypes: ['Necrotic'],
        description:
            'Make a ranged spell attack against a creature within range. On a hit, the target takes 1d8 Necrotic damage and can\'t regain HP until the start of your next turn. Until then, the hand clings to the target. If the target is Undead, it has Disadvantage on attack rolls against you for that duration.\n\n'
                '**Cantrip Upgrade.** Damage rises to 2d8 at level 5, 3d8 at level 11, 4d8 at level 17.',
      ),
      _spell(
        name: 'Dancing Lights',
        level: 0,
        school: 'Illusion',
        castTime: 'Action',
        range: 120,
        components: [_v, _s, _m],
        material: 'A bit of phosphorus or wychwood',
        duration: '1 Minute',
        concentration: true,
        classes: ['Bard', 'Sorcerer', 'Wizard'],
        description:
            'Create up to four torchsized lights that hover in the air for the duration; each sheds Dim Light in a 10-foot radius. As a Bonus Action, move them up to 60 feet. They wink out at distance > 120 ft from you.',
      ),
      _spell(
        name: 'Fire Bolt',
        level: 0,
        school: 'Evocation',
        castTime: 'Action',
        range: 120,
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Wizard'],
        attackType: 'Ranged',
        damageTypes: ['Fire'],
        description:
            'Hurl a mote of fire at a creature or object within range. Make a ranged spell attack. On a hit, the target takes 1d10 Fire damage. A flammable object hit by this spell ignites if it isn\'t being worn or carried.\n\n'
                '**Cantrip Upgrade.** 2d10 at level 5, 3d10 at level 11, 4d10 at level 17.',
      ),
      _spell(
        name: 'Light',
        level: 0,
        school: 'Evocation',
        castTime: 'Action',
        range: 'Touch',
        components: [_v, _m],
        material: 'A firefly or phosphorescent moss',
        duration: '1 Hour',
        classes: ['Bard', 'Cleric', 'Sorcerer', 'Wizard'],
        description:
            'Touch one object no larger than 10 feet in any dimension. The object sheds Bright Light in a 20-foot radius and Dim Light for an additional 20 feet. The light can be colored as you like. Covering the object completely with something opaque blocks the light. The spell ends if you cast it again or dismiss it as an action.',
      ),
      _spell(
        name: 'Mage Hand',
        level: 0,
        school: 'Conjuration',
        castTime: 'Action',
        range: 30,
        components: [_v, _s],
        duration: '1 Minute',
        classes: ['Bard', 'Sorcerer', 'Warlock', 'Wizard'],
        description:
            'A spectral, floating hand appears at a point you choose within range. The hand lasts for the duration; it vanishes if it is ever more than 30 feet from you or if you cast this spell again. As a Magic action, you can manipulate the hand: drop, throw, move, or use a held object up to 10 lb. The hand can\'t attack, activate magic items, or carry more than 10 lb.',
      ),
      _spell(
        name: 'Mending',
        level: 0,
        school: 'Transmutation',
        castTime: '1 Minute',
        range: 'Touch',
        components: [_v, _s, _m],
        material: 'Two lodestones',
        duration: 'Instantaneous',
        ritual: true,
        classes: ['Bard', 'Cleric', 'Druid', 'Sorcerer', 'Wizard'],
        description:
            'Repairs a single break or tear in an object touched (≤ 1 foot in any dimension), such as a snapped chain link, two halves of a key, a torn cloak, or a leaking wineskin. The spell can physically repair a magic item or construct only if the spell\'s description allows it.',
      ),
      _spell(
        name: 'Minor Illusion',
        level: 0,
        school: 'Illusion',
        castTime: 'Action',
        range: 30,
        components: [_s, _m],
        material: 'A bit of fleece',
        duration: '1 Minute',
        classes: ['Bard', 'Sorcerer', 'Warlock', 'Wizard'],
        description:
            'Create a sound or image of an object within range that lasts for the duration. The illusion ends if you dismiss it as an action or cast this spell again. The image can be no larger than a 5-foot Cube. Physical interaction reveals it to be an illusion. A creature using a Magic action to investigate can make an Intelligence (Investigation) check (DC = your spell save DC).',
      ),
      _spell(
        name: 'Poison Spray',
        level: 0,
        school: 'Necromancy',
        castTime: 'Action',
        range: 30,
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Druid', 'Sorcerer', 'Warlock', 'Wizard'],
        saveAbility: 'Constitution',
        damageTypes: ['Poison'],
        description:
            'Extend your hand toward a creature within range and project a puff of noxious gas. The target must succeed on a Con save or take 1d12 Poison damage.\n\n'
                '**Cantrip Upgrade.** 2d12 at level 5, 3d12 at level 11, 4d12 at level 17.',
      ),
      _spell(
        name: 'Prestidigitation',
        level: 0,
        school: 'Transmutation',
        castTime: 'Action',
        range: 10,
        components: [_v, _s],
        duration: '1 Hour',
        classes: ['Bard', 'Sorcerer', 'Warlock', 'Wizard'],
        description:
            'A minor magical trick that novice spellcasters use for practice. Create one of the following effects within range: an instantaneous, harmless sensory effect; instantly light or extinguish a candle/torch/small campfire; instantly clean or soil an object ≤ 1 cubic foot; chill, warm, or flavor up to 1 cubic foot of nonliving material for 1 hour; make a colored mark or symbol on an object/surface for 1 hour; or create a nonmagical trinket or illusory image that fits in your hand and lasts until the end of your next turn.',
      ),
      _spell(
        name: 'Ray of Frost',
        level: 0,
        school: 'Evocation',
        castTime: 'Action',
        range: 60,
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Wizard'],
        attackType: 'Ranged',
        damageTypes: ['Cold'],
        description:
            'A frigid beam of blue-white light streaks toward a creature within range. Make a ranged spell attack. On a hit, the target takes 1d8 Cold damage and its Speed is reduced by 10 feet until the start of your next turn.\n\n'
                '**Cantrip Upgrade.** 2d8 at level 5, 3d8 at level 11, 4d8 at level 17.',
      ),
      _spell(
        name: 'Sacred Flame',
        level: 0,
        school: 'Evocation',
        castTime: 'Action',
        range: 60,
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Cleric'],
        saveAbility: 'Dexterity',
        damageTypes: ['Radiant'],
        description:
            'Flame-like radiance descends on a creature within range. The target must succeed on a Dexterity saving throw or take 1d8 Radiant damage. The target gains no benefit from cover for this saving throw.\n\n'
                '**Cantrip Upgrade.** 2d8 at level 5, 3d8 at level 11, 4d8 at level 17.',
      ),
      _spell(
        name: 'Shocking Grasp',
        level: 0,
        school: 'Evocation',
        castTime: 'Action',
        range: 'Touch',
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Wizard'],
        attackType: 'Melee',
        damageTypes: ['Lightning'],
        description:
            'Lightning springs from your hand. Make a melee spell attack against a creature you try to touch (Advantage if the target is wearing metal armor). On a hit, the target takes 1d8 Lightning damage and can\'t take Reactions until the start of its next turn.\n\n'
                '**Cantrip Upgrade.** 2d8 at level 5, 3d8 at level 11, 4d8 at level 17.',
      ),
      _spell(
        name: 'Spare the Dying',
        level: 0,
        school: 'Necromancy',
        castTime: 'Action',
        range: 'Touch',
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Cleric', 'Druid'],
        description:
            'Touch a living creature that has 0 HP. The creature becomes Stable. This spell has no effect on Undead or Constructs.',
      ),
      _spell(
        name: 'Thaumaturgy',
        level: 0,
        school: 'Transmutation',
        castTime: 'Action',
        range: 30,
        components: [_v],
        duration: '1 Minute',
        classes: ['Cleric'],
        description:
            'Manifest a minor wonder, a sign of supernatural power, within range. Create one of: a voice booms three times louder; flames flicker, brighten, dim, or change color for 1 minute; harmless tremors in the ground for 1 minute; create an instantaneous sound; cause a door or window to fly open or slam shut; alter your eyes\' appearance for 1 minute. Up to three concurrent effects.',
      ),

      // ─── Level 1 Spells (canonical selection) ─────────────────────────────
      _spell(
        name: 'Burning Hands',
        level: 1,
        school: 'Evocation',
        castTime: 'Action',
        range: 'Self',
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Wizard'],
        saveAbility: 'Dexterity',
        damageTypes: ['Fire'],
        description:
            'A thin sheet of flames shoots from your fingertips. Each creature in a 15-foot Cone makes a Dex save: 3d6 Fire damage on a fail, half on a success. The fire ignites flammable unattended objects.\n\n'
                '**Using a Higher-Level Spell Slot.** +1d6 damage per slot level above 1.',
      ),
      _spell(
        name: 'Charm Person',
        level: 1,
        school: 'Enchantment',
        castTime: 'Action',
        range: 30,
        components: [_v, _s],
        duration: '1 Hour',
        classes: ['Bard', 'Druid', 'Sorcerer', 'Warlock', 'Wizard'],
        saveAbility: 'Wisdom',
        conditions: ['Charmed'],
        description:
            'Choose a Humanoid you can see within range. It must succeed on a Wisdom save or be Charmed by you for the duration or until you or your allies harm it. The target knows it was charmed by you when the spell ends.\n\n'
                '**Higher-Level Slot.** One additional target per slot level above 1.',
      ),
      _spell(
        name: 'Cure Wounds',
        level: 1,
        school: 'Abjuration',
        castTime: 'Action',
        range: 'Touch',
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Bard', 'Cleric', 'Druid', 'Paladin', 'Ranger'],
        description:
            'A creature you touch regains HP equal to 2d8 + your spellcasting ability modifier. This spell has no effect on Undead or Constructs.\n\n'
                '**Higher-Level Slot.** +2d8 healing per slot level above 1.',
      ),
      _spell(
        name: 'Detect Magic',
        level: 1,
        school: 'Divination',
        castTime: 'Action',
        range: 'Self',
        components: [_v, _s],
        duration: '10 Minutes',
        ritual: true,
        concentration: true,
        classes: ['Bard', 'Cleric', 'Druid', 'Paladin', 'Ranger', 'Sorcerer', 'Wizard'],
        description:
            'For the duration, you sense the presence of magic within 30 feet. As an action, see a faint aura around any visible magical creature or object and learn its school (if any). Penetrates most barriers but blocked by 1 ft of stone, 1 inch of common metal, a thin sheet of lead, or 3 ft of wood/dirt.',
      ),
      _spell(
        name: 'Healing Word',
        level: 1,
        school: 'Abjuration',
        castTime: 'Bonus Action',
        range: 60,
        components: [_v],
        duration: 'Instantaneous',
        classes: ['Bard', 'Cleric', 'Druid'],
        description:
            'A creature of your choice within range regains HP = 2d4 + your spellcasting ability modifier. No effect on Undead or Constructs.\n\n'
                '**Higher-Level Slot.** +2d4 per slot level above 1.',
      ),
      _spell(
        name: 'Hellish Rebuke',
        level: 1,
        school: 'Evocation',
        castTime: 'Reaction',
        range: 60,
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Warlock'],
        saveAbility: 'Dexterity',
        damageTypes: ['Fire'],
        description:
            'You take this Reaction in response to being damaged by a creature within 60 feet that you can see. The creature makes a Dex save: 2d10 Fire damage on a fail, half on a success.\n\n'
                '**Higher-Level Slot.** +1d10 per slot level above 1.',
      ),
      _spell(
        name: 'Mage Armor',
        level: 1,
        school: 'Abjuration',
        castTime: 'Action',
        range: 'Touch',
        components: [_v, _s, _m],
        material: 'A piece of cured leather',
        duration: '8 Hours',
        classes: ['Sorcerer', 'Wizard'],
        description:
            'Touch a willing creature not wearing armor. Until the spell ends, the target\'s base AC = 13 + Dex mod. The spell ends if the target dons armor or you dismiss it (no action).',
      ),
      _spell(
        name: 'Magic Missile',
        level: 1,
        school: 'Evocation',
        castTime: 'Action',
        range: 120,
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Wizard'],
        damageTypes: ['Force'],
        description:
            'Create three glowing darts of magical force. Each dart hits a creature of your choice you can see within range, dealing 1d4+1 Force damage. Darts strike simultaneously and can be directed at the same or different targets.\n\n'
                '**Higher-Level Slot.** +1 dart per slot level above 1.',
      ),
      _spell(
        name: 'Shield',
        level: 1,
        school: 'Abjuration',
        castTime: 'Reaction',
        range: 'Self',
        components: [_v, _s],
        duration: '1 Round',
        classes: ['Sorcerer', 'Wizard'],
        description:
            'Reaction taken when hit by an attack or targeted by Magic Missile. Until the start of your next turn, you have +5 AC including against the triggering attack and you take no damage from Magic Missile.',
      ),
      _spell(
        name: 'Sleep',
        level: 1,
        school: 'Enchantment',
        castTime: 'Action',
        range: 90,
        components: [_v, _s, _m],
        material: 'A pinch of fine sand, rose petals, or a cricket',
        duration: '1 Minute',
        concentration: true,
        classes: ['Bard', 'Sorcerer', 'Wizard'],
        saveAbility: 'Wisdom',
        conditions: ['Incapacitated'],
        description:
            'Each creature within a 5-foot Emanation centered on a point in range must succeed on a Wisdom save or have the Incapacitated condition until the spell ends. An affected creature wakes if it takes damage or someone uses an action to wake it.\n\n'
                '**Higher-Level Slot.** Emanation grows 5 ft per slot level above 1.',
      ),
      _spell(
        name: 'Thunderwave',
        level: 1,
        school: 'Evocation',
        castTime: 'Action',
        range: 'Self',
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Bard', 'Druid', 'Sorcerer', 'Wizard'],
        saveAbility: 'Constitution',
        damageTypes: ['Thunder'],
        description:
            'A wave of thunderous force in a 15-foot Cube originating from you. Each creature in the Cube makes a Con save: 2d8 Thunder damage and pushed 10 ft away on a fail, half damage and not pushed on a success. Audible 300 feet away.\n\n'
                '**Higher-Level Slot.** +1d8 per slot level above 1.',
      ),

      // ─── Level 2 Spells (selection) ──────────────────────────────────────
      _spell(
        name: 'Aid',
        level: 2,
        school: 'Abjuration',
        castTime: 'Action',
        range: 30,
        components: [_v, _s, _m],
        material: 'A strip of white cloth',
        duration: '8 Hours',
        classes: ['Bard', 'Cleric', 'Paladin', 'Ranger'],
        description:
            'Up to three creatures of your choice within range each gain 5 temporary HP and have their HP maximum increased by 5 for the duration.\n\n'
                '**Higher-Level Slot.** +5 to both per slot level above 2.',
      ),
      _spell(
        name: 'Hold Person',
        level: 2,
        school: 'Enchantment',
        castTime: 'Action',
        range: 60,
        components: [_v, _s, _m],
        material: 'A small, straight piece of iron',
        duration: '1 Minute',
        concentration: true,
        classes: ['Bard', 'Cleric', 'Druid', 'Sorcerer', 'Warlock', 'Wizard'],
        saveAbility: 'Wisdom',
        conditions: ['Paralyzed'],
        description:
            'Choose a Humanoid within range. The target must succeed on a Wisdom save or have the Paralyzed condition for the duration. At the end of each of its turns the target can repeat the save.\n\n'
                '**Higher-Level Slot.** +1 target per slot level above 2.',
      ),
      _spell(
        name: 'Misty Step',
        level: 2,
        school: 'Conjuration',
        castTime: 'Bonus Action',
        range: 'Self',
        components: [_v],
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Warlock', 'Wizard'],
        description:
            'Briefly surrounded by silvery mist, you teleport up to 30 feet to an unoccupied space you can see.',
      ),
      _spell(
        name: 'Scorching Ray',
        level: 2,
        school: 'Evocation',
        castTime: 'Action',
        range: 120,
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Wizard'],
        attackType: 'Ranged',
        damageTypes: ['Fire'],
        description:
            'Create three rays of fire and hurl them at targets within range. Make a separate ranged spell attack for each ray. On a hit, the target takes 2d6 Fire damage.\n\n'
                '**Higher-Level Slot.** +1 ray per slot level above 2.',
      ),
      _spell(
        name: 'Web',
        level: 2,
        school: 'Conjuration',
        castTime: 'Action',
        range: 60,
        components: [_v, _s, _m],
        material: 'A bit of spiderweb',
        duration: '1 Hour',
        concentration: true,
        classes: ['Sorcerer', 'Wizard'],
        saveAbility: 'Dexterity',
        conditions: ['Restrained'],
        description:
            'Conjure a mass of thick, sticky webs filling a 20-foot Cube within range that lasts for the duration. The webs are Difficult Terrain and lightly obscure their area. Each creature that starts its turn in the webs or that enters them during its turn must succeed on a Dex save or have the Restrained condition. A Restrained creature can use an action to make a Strength check (DC = your save DC); on a success, it is no longer Restrained.',
      ),

      // ─── Level 3 Spells (selection) ──────────────────────────────────────
      _spell(
        name: 'Counterspell',
        level: 3,
        school: 'Abjuration',
        castTime: 'Reaction',
        range: 60,
        components: [_s],
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Warlock', 'Wizard'],
        description:
            'Reaction when you see a creature within range cast a spell. The creature must succeed on a Constitution saving throw, taking 3d8 Force damage on a fail and half on a success. On a fail, the spell is also disrupted and has no effect.',
      ),
      _spell(
        name: 'Dispel Magic',
        level: 3,
        school: 'Abjuration',
        castTime: 'Action',
        range: 120,
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Bard', 'Cleric', 'Druid', 'Paladin', 'Sorcerer', 'Warlock', 'Wizard'],
        description:
            'Choose any creature, object, or magical effect within range. Any spell of level 3 or lower on the target ends. For each spell of level 4+ on the target, make an ability check with your spellcasting ability (DC = 10 + spell\'s level). On a success, the spell ends.\n\n'
                '**Higher-Level Slot.** Auto-dispels spells of slot level or lower.',
      ),
      _spell(
        name: 'Fireball',
        level: 3,
        school: 'Evocation',
        castTime: 'Action',
        range: 150,
        components: [_v, _s, _m],
        material: 'A ball of bat guano and sulfur',
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Wizard'],
        saveAbility: 'Dexterity',
        damageTypes: ['Fire'],
        description:
            'A bright streak flashes from you to a point you choose within range and erupts in flame. Each creature in a 20-foot-radius Sphere makes a Dex save: 8d6 Fire damage on a fail, half on a success. Ignites flammable unattended objects in the area.\n\n'
                '**Higher-Level Slot.** +1d6 per slot level above 3.',
      ),
      _spell(
        name: 'Fly',
        level: 3,
        school: 'Transmutation',
        castTime: 'Action',
        range: 'Touch',
        components: [_v, _s, _m],
        material: 'A wing feather from any bird',
        duration: '10 Minutes',
        concentration: true,
        classes: ['Sorcerer', 'Warlock', 'Wizard'],
        description:
            'Touch a willing creature. The target gains a Fly Speed of 60 feet for the duration. When the spell ends, the target falls if still aloft unless it can stop the fall.\n\n'
                '**Higher-Level Slot.** +1 target per slot level above 3.',
      ),
      _spell(
        name: 'Lightning Bolt',
        level: 3,
        school: 'Evocation',
        castTime: 'Action',
        range: 'Self',
        components: [_v, _s, _m],
        material: 'A bit of fur and a rod of amber, crystal, or glass',
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Wizard'],
        saveAbility: 'Dexterity',
        damageTypes: ['Lightning'],
        description:
            'A stroke of lightning forms a 100-foot Line that is 5 feet wide blasting from you. Each creature in the Line makes a Dex save: 8d6 Lightning damage on a fail, half on a success.\n\n'
                '**Higher-Level Slot.** +1d6 per slot level above 3.',
      ),
      _spell(
        name: 'Revivify',
        level: 3,
        school: 'Necromancy',
        castTime: 'Action',
        range: 'Touch',
        components: [_v, _s, _m],
        material: 'Diamonds worth 300+ GP',
        materialCostGp: 300,
        materialConsumed: true,
        duration: 'Instantaneous',
        classes: ['Cleric', 'Paladin'],
        description:
            'You touch a creature that has died within the last minute. That creature returns to life with 1 HP. Doesn\'t work on creatures that died of old age, nor restore missing body parts.',
      ),

      // ─── Level 4 Spells ──────────────────────────────────────────────────
      _spell(
        name: 'Greater Invisibility',
        level: 4,
        school: 'Illusion',
        castTime: 'Action',
        range: 'Touch',
        components: [_v, _s],
        duration: '1 Minute',
        concentration: true,
        classes: ['Bard', 'Sorcerer', 'Wizard'],
        conditions: ['Invisible'],
        description:
            'A creature you touch has the Invisible condition until the spell ends.',
      ),
      _spell(
        name: 'Polymorph',
        level: 4,
        school: 'Transmutation',
        castTime: 'Action',
        range: 60,
        components: [_v, _s, _m],
        material: 'A cocoon',
        duration: '1 Hour',
        concentration: true,
        classes: ['Bard', 'Druid', 'Sorcerer', 'Wizard'],
        saveAbility: 'Wisdom',
        description:
            'Transform a creature you can see within range into a Beast. Unwilling creatures make a Wisdom save. The new form\'s CR can\'t exceed the target\'s level/CR. Target uses the Beast\'s stats but keeps alignment, personality, and Intelligence/Wisdom/Charisma scores. When HP drop to 0, the creature reverts and excess damage carries over.',
      ),

      // ─── Level 5 Spells ──────────────────────────────────────────────────
      _spell(
        name: 'Cone of Cold',
        level: 5,
        school: 'Evocation',
        castTime: 'Action',
        range: 'Self',
        components: [_v, _s, _m],
        material: 'A small crystal or glass cone',
        duration: 'Instantaneous',
        classes: ['Druid', 'Sorcerer', 'Wizard'],
        saveAbility: 'Constitution',
        damageTypes: ['Cold'],
        description:
            'A blast of cold air erupts from your hands in a 60-foot Cone. Each creature in the Cone makes a Con save: 8d8 Cold damage on a fail, half on a success. Creatures killed by this spell freeze into solid statues.\n\n'
                '**Higher-Level Slot.** +1d8 per slot level above 5.',
      ),
      _spell(
        name: 'Hold Monster',
        level: 5,
        school: 'Enchantment',
        castTime: 'Action',
        range: 90,
        components: [_v, _s, _m],
        material: 'A small, straight piece of iron',
        duration: '1 Minute',
        concentration: true,
        classes: ['Bard', 'Sorcerer', 'Warlock', 'Wizard'],
        saveAbility: 'Wisdom',
        conditions: ['Paralyzed'],
        description:
            'Choose a creature you can see within range. The target must succeed on a Wisdom save or have the Paralyzed condition for the duration. The target repeats the save at the end of each of its turns.\n\n'
                '**Higher-Level Slot.** +1 target per slot level above 5.',
      ),
      _spell(
        name: 'Raise Dead',
        level: 5,
        school: 'Necromancy',
        castTime: '1 Hour',
        range: 'Touch',
        components: [_v, _s, _m],
        material: 'A diamond worth 500+ GP',
        materialCostGp: 500,
        materialConsumed: true,
        duration: 'Instantaneous',
        classes: ['Bard', 'Cleric', 'Paladin'],
        description:
            'You return a dead creature you touch to life, provided that it has been dead no longer than 10 days. The creature returns to life with 1 HP. The spell takes –4 to all D20 Tests for 4 days; this penalty reduces by 1 each Long Rest.',
      ),

      // ─── Level 6 Spells ──────────────────────────────────────────────────
      _spell(
        name: 'Disintegrate',
        level: 6,
        school: 'Transmutation',
        castTime: 'Action',
        range: 60,
        components: [_v, _s, _m],
        material: 'A lodestone and dust',
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Wizard'],
        saveAbility: 'Dexterity',
        damageTypes: ['Force'],
        description:
            'A thin green ray springs from your finger toward a target. Make a Dex save: 10d6 + 40 Force damage on a fail. If reduced to 0 HP, the target is disintegrated. Larger objects up to 10 ft per dimension are destroyed.\n\n'
                '**Higher-Level Slot.** +3d6 per slot level above 6.',
      ),
      _spell(
        name: 'Heal',
        level: 6,
        school: 'Abjuration',
        castTime: 'Action',
        range: 60,
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Cleric', 'Druid'],
        description:
            'Choose a creature within range that you can see. A surge of positive energy washes through it. The creature regains 70 HP. Also ends the Blinded, Deafened, and Poisoned conditions on the target.\n\n'
                '**Higher-Level Slot.** +10 HP per slot level above 6.',
      ),

      // ─── Level 7 Spells ──────────────────────────────────────────────────
      _spell(
        name: 'Finger of Death',
        level: 7,
        school: 'Necromancy',
        castTime: 'Action',
        range: 60,
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Warlock', 'Wizard'],
        saveAbility: 'Constitution',
        damageTypes: ['Necrotic'],
        description:
            'Negative energy lances out toward a creature within range. The target makes a Con save: 7d8 + 30 Necrotic damage on a fail, half on a success. A Humanoid killed by this spell rises at the start of your next turn as a Zombie under your command.',
      ),
      _spell(
        name: 'Teleport',
        level: 7,
        school: 'Conjuration',
        castTime: 'Action',
        range: 10,
        components: [_v],
        duration: 'Instantaneous',
        classes: ['Bard', 'Sorcerer', 'Wizard'],
        description:
            'Instantly transport yourself and up to eight willing creatures within 10 feet of you, or a single object you carry, to a destination you select. Roll on the teleport table for accuracy based on familiarity (Permanent Circle, Associated Object, Very Familiar, Seen Casually, Viewed Once, Description, False Destination).',
      ),

      // ─── Level 8 Spells ──────────────────────────────────────────────────
      _spell(
        name: 'Power Word Stun',
        level: 8,
        school: 'Enchantment',
        castTime: 'Action',
        range: 60,
        components: [_v],
        duration: 'Instantaneous',
        classes: ['Bard', 'Sorcerer', 'Warlock', 'Wizard'],
        conditions: ['Stunned'],
        description:
            'Choose a creature you can see within range. If the target has 150 HP or fewer, it has the Stunned condition. Otherwise the spell has no effect. The Stunned target repeats Constitution saves at the end of each of its turns.',
      ),
      _spell(
        name: 'Sunburst',
        level: 8,
        school: 'Evocation',
        castTime: 'Action',
        range: 150,
        components: [_v, _s, _m],
        material: 'Fire and a piece of sunstone',
        duration: 'Instantaneous',
        classes: ['Druid', 'Sorcerer', 'Wizard'],
        saveAbility: 'Constitution',
        damageTypes: ['Radiant'],
        conditions: ['Blinded'],
        description:
            'Brilliant sunlight flashes in a 60-foot-radius Sphere centered on a point you choose within range. Each creature in the Sphere makes a Con save: 12d6 Radiant damage and Blinded for 1 minute on a fail, half damage and not Blinded on a success. Undead and Oozes have Disadvantage on the save.',
      ),

      // ─── Level 9 Spells ──────────────────────────────────────────────────
      _spell(
        name: 'Meteor Swarm',
        level: 9,
        school: 'Evocation',
        castTime: 'Action',
        range: 1000,
        components: [_v, _s],
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Wizard'],
        saveAbility: 'Dexterity',
        damageTypes: ['Fire', 'Bludgeoning'],
        description:
            'Four blazing orbs of fire plummet to the ground at four points you choose within range. Each creature in a 40-foot-radius Sphere centered on each point makes a Dex save: 20d6 Fire and 20d6 Bludgeoning damage on a fail, half on a success. A creature in the area of more than one Sphere is affected only once. The spell ignites flammable unattended objects.',
      ),
      _spell(
        name: 'Power Word Kill',
        level: 9,
        school: 'Enchantment',
        castTime: 'Action',
        range: 60,
        components: [_v],
        duration: 'Instantaneous',
        classes: ['Bard', 'Sorcerer', 'Warlock', 'Wizard'],
        description:
            'Utter a word of power. Choose a creature within range. If the target has 100 HP or fewer, it dies. Otherwise the spell has no effect.',
      ),
      _spell(
        name: 'Time Stop',
        level: 9,
        school: 'Transmutation',
        castTime: 'Action',
        range: 'Self',
        components: [_v],
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Wizard'],
        description:
            'You briefly stop time for everyone but yourself. Take 1d4+1 turns in a row. The spell ends if any action you take during this period — or any effect you create — affects a creature other than yourself or an object being worn or carried by someone other than you, or you move more than 1,000 feet from the location where you cast it.',
      ),
      _spell(
        name: 'Wish',
        level: 9,
        school: 'Conjuration',
        castTime: 'Action',
        range: 'Self',
        components: [_v],
        duration: 'Instantaneous',
        classes: ['Sorcerer', 'Wizard'],
        description:
            'The mightiest spell. By stating aloud what you wish for, you can alter the very foundations of reality. The basic use is to duplicate any other spell of level 8 or lower (without needing to meet that spell\'s requirements). Alternatively choose from one of these effects: heal up to 20 creatures of all HP, conditions, exhaustion, etc.; grant up to 10 creatures Resistance to a damage type for 8 hours; grant 10 creatures Immunity to a single spell or magical effect for 8 hours; undo a single recent event by forcing a reroll. Other wishes have unpredictable consequences and may require Constitution rolls; once cast for a non-spell-duplication wish, you can\'t cast Wish again for 1d4 days and you take 1d10 Necrotic damage per spell level for each spell you cast for the next 8 hours.',
      ),
    ];
