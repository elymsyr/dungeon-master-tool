// SRD 5.2.1 Monster traits (catalogue from monster stat blocks pp. 258–364).
// Common traits shared across multiple monsters live here as a single shared
// row so monster entries can reference them by name.

import '_helpers.dart';

Map<String, dynamic> _t({
  required String name,
  required String kind,
  required String description,
  String source = 'SRD 5.2.1',
}) {
  return packEntity(
    slug: 'trait',
    name: name,
    description: description,
    attributes: {
      'source': source,
      'trait_kind': kind,
      'description': description,
    },
  );
}

List<Map<String, dynamic>> srdTraits() => [
      _t(name: 'Amphibious', kind: 'Movement', description: 'The creature can breathe air and water.'),
      _t(name: 'Legendary Resistance (3/Day)', kind: 'Defensive', description: 'If the creature fails a saving throw, it can choose to succeed instead. Three uses per day.'),
      _t(name: 'Magic Resistance', kind: 'Defensive', description: 'The creature has Advantage on saving throws against spells and other magical effects.'),
      _t(name: 'Pack Tactics', kind: 'Passive', description: 'The creature has Advantage on attack rolls against a creature if at least one of the creature\'s allies is within 5 feet of the target and the ally doesn\'t have the Incapacitated condition.'),
      _t(name: 'Keen Smell', kind: 'Sense', description: 'The creature has Advantage on Wisdom (Perception) checks that rely on smell.'),
      _t(name: 'Keen Sight', kind: 'Sense', description: 'The creature has Advantage on Wisdom (Perception) checks that rely on sight.'),
      _t(name: 'Keen Hearing', kind: 'Sense', description: 'The creature has Advantage on Wisdom (Perception) checks that rely on hearing.'),
      _t(name: 'Sunlight Sensitivity', kind: 'Defensive', description: 'While in sunlight, the creature has Disadvantage on attack rolls and on Wisdom (Perception) checks that rely on sight.'),
      _t(name: 'Spider Climb', kind: 'Movement', description: 'The creature can climb difficult surfaces, including upside down on ceilings, without an ability check.'),
      _t(name: 'Web Sense', kind: 'Sense', description: 'While in contact with a web, the creature knows the exact location of any other creature in contact with the same web.'),
      _t(name: 'Web Walker', kind: 'Movement', description: 'The creature ignores movement restrictions caused by webbing.'),
      _t(name: 'Aggressive', kind: 'Movement', description: 'As a Bonus Action, the creature can move up to its Speed toward a hostile creature it can see.'),
      _t(name: 'Brute', kind: 'Passive', description: 'A melee weapon attack from the creature deals one extra die of damage when it hits (included in the attack).'),
      _t(name: 'Reckless', kind: 'Passive', description: 'At the start of its turn, the creature can gain Advantage on all melee weapon attack rolls during that turn, but attack rolls against it have Advantage until the start of its next turn.'),
      _t(name: 'Flyby', kind: 'Movement', description: 'The creature doesn\'t provoke Opportunity Attacks when it flies out of an enemy\'s reach.'),
      _t(name: 'Standing Leap', kind: 'Movement', description: 'The creature\'s long jump is up to 30 feet and its high jump is up to 15 feet, with or without a running start.'),
      _t(name: 'Undead Fortitude', kind: 'Defensive', description: 'When the creature is reduced to 0 HP by damage that isn\'t Radiant or from a critical hit, it makes a Constitution saving throw (DC 5 + the damage taken). On a success, it drops to 1 HP instead.'),
      _t(name: 'Aboleth Telepathy', kind: 'Other', description: 'The aboleth can telepathically speak to any creature within 1 mile of itself. The contacted creature understands only if it shares a language with the aboleth.'),
      _t(name: 'Eldritch Restoration', kind: 'Defensive', description: 'If destroyed, the aboleth gains a new body in 5d10 days, restoring it to life. The new body appears within 1d100 miles of the aboleth\'s old body.'),
      _t(name: 'Mucous Cloud', kind: 'Passive', description: 'While underwater, the aboleth is surrounded by transformative mucus. A creature that touches the aboleth or hits it with a melee attack while within 5 feet of it must succeed on a DC 14 Constitution save or be diseased for 1d4 hours.'),
      _t(name: 'Probing Telepathy', kind: 'Other', description: 'If a creature communicates telepathically with the aboleth, the aboleth learns the creature\'s greatest desires.'),

      // ─── Dragon traits ───────────────────────────────────────────────────
      _t(name: 'Legendary Resistance (3/Day, or 4/Day in Lair)', kind: 'Defensive', description: 'If the dragon fails a saving throw, it can choose to succeed instead. Three uses per day, or four uses per day while in its lair.'),
      _t(name: 'Fire Aura', kind: 'Passive', description: 'At the end of each of the dragon\'s turns, each creature in a 10-foot Emanation originating from the dragon takes 17 (5d6) Fire damage.'),

      // ─── Lich traits ─────────────────────────────────────────────────────
      _t(name: 'Spellcasting (Lich)', kind: 'Spellcasting', description: 'The lich casts one of the following spells, requiring no Material components and using Intelligence as the spellcasting ability (spell save DC 20, +12 to hit with spell attacks). At will: Detect Magic, Detect Thoughts, Dispel Magic, Fireball, Mage Hand, Prestidigitation. 2/Day each: Plane Shift, Power Word Stun.'),
      _t(name: 'Rejuvenation', kind: 'Defensive', description: 'If it has a phylactery, a destroyed lich gains a new body in 1d10 days, regaining all its HP and becoming active again. The new body forms within 5 feet of the phylactery.'),
      _t(name: 'Turn Resistance', kind: 'Defensive', description: 'The lich has Advantage on saving throws against any effect that turns Undead.'),

      // ─── Beholder traits ─────────────────────────────────────────────────
      _t(name: 'Antimagic Cone', kind: 'Passive', description: 'The beholder\'s central eye creates an area of antimagic, as in the Antimagic Field spell, in a 150-foot Cone. At the start of each of its turns, the beholder decides which way the Cone faces and whether the Cone is active. The area works against the beholder\'s own eye rays.'),

      // ─── Mind Flayer traits ──────────────────────────────────────────────
      _t(name: 'Creature Sense', kind: 'Sense', description: 'The mind flayer is aware of the presence of any creature that has an Intelligence of 4 or higher within 2 miles of itself. It knows the distance and direction to each such creature, as well as the creature\'s Intelligence score, but it can\'t sense anything else about the creature.'),
      _t(name: 'Magic Resistance (MF)', kind: 'Defensive', description: 'The mind flayer has Advantage on saving throws against spells.'),

      // ─── Owlbear / Bear traits ───────────────────────────────────────────
      _t(name: 'Keen Sight and Smell', kind: 'Sense', description: 'The creature has Advantage on Wisdom (Perception) checks that rely on sight or smell.'),

      // ─── Hobgoblin traits ────────────────────────────────────────────────
      _t(name: 'Martial Advantage', kind: 'Passive', description: 'Once per turn, the hobgoblin can deal an extra 7 (2d6) damage to a creature it hits with a weapon attack if that creature is within 5 feet of an ally of the hobgoblin that doesn\'t have the Incapacitated condition.'),

      // ─── Animal traits ───────────────────────────────────────────────────
      _t(name: 'Charge', kind: 'Passive', description: 'If the creature moves at least 20 feet straight toward a target and then hits it with a melee weapon attack on the same turn, the target takes an extra die of damage and must succeed on a Strength save (DC = 8 + creature\'s STR mod + PB) or be knocked Prone.'),
      _t(name: 'Hold Breath', kind: 'Other', description: 'The creature can hold its breath for 15 minutes.'),
      _t(name: 'Pounce', kind: 'Movement', description: 'If the creature moves at least 20 feet straight toward a creature and then hits it with a Claws attack on the same turn, the target must succeed on a Strength save or have the Prone condition. If the target is Prone, the creature can make one Bite attack against it as a Bonus Action.'),
      _t(name: 'Running Leap', kind: 'Movement', description: 'With a 10-foot running start, the creature can long jump up to 25 feet.'),
      _t(name: 'Snow Camouflage', kind: 'Passive', description: 'The creature has Advantage on Dexterity (Stealth) checks made to hide in snowy terrain.'),

      // ─── More monster traits ────────────────────────────────────────────
      _t(name: 'Innate Spellcasting (Drow)', kind: 'Spellcasting', description: 'The drow\'s spellcasting ability is Charisma. It can innately cast Dancing Lights (at will), Darkness, Faerie Fire, Levitate (1/Day each).'),
      _t(name: 'Fey Ancestry', kind: 'Defensive', description: 'The creature has Advantage on saving throws against being Charmed, and magic can\'t put it to sleep.'),
      _t(name: 'Shapechanger (Werewolf)', kind: 'Other', description: 'The werewolf can use its action to polymorph into a wolf-humanoid hybrid or into a Large wolf, or back into its true form, which is Humanoid. Its statistics, other than its size and Speed, are the same in each form. Any equipment it is wearing or carrying isn\'t transformed. It reverts to its true form if it dies.'),
      _t(name: 'Regeneration', kind: 'Defensive', description: 'The creature regains 10 HP at the start of its turn if it has at least 1 HP. If the creature takes damage of a specific type (varies per creature), this trait doesn\'t function at the start of the creature\'s next turn.'),
      _t(name: 'Death Burst', kind: 'Defensive', description: 'When the creature dies, it explodes in a burst of energy. Each creature within 5 feet must make a Dexterity save or take damage as specified by the creature.'),
      _t(name: 'False Appearance', kind: 'Passive', description: 'While the creature remains motionless, it is indistinguishable from an ordinary object.'),
      _t(name: 'Siege Monster', kind: 'Passive', description: 'The creature deals double damage to objects and structures.'),
      _t(name: 'Damage Transfer', kind: 'Defensive', description: 'While the creature is grappling another creature, the target takes half the damage dealt to the creature.'),
      _t(name: 'Sure-Footed', kind: 'Defensive', description: 'The creature has Advantage on Strength and Dexterity saving throws made against effects that would knock it Prone.'),
      _t(name: 'Innate Spellcasting (Druid)', kind: 'Spellcasting', description: 'The creature\'s innate spellcasting ability is Wisdom. It can innately cast certain Druid spells, requiring no Material components.'),
      _t(name: 'Two Heads', kind: 'Passive', description: 'The creature has Advantage on Wisdom (Perception) checks and on saving throws against being Blinded, Charmed, Deafened, Frightened, Stunned, or knocked Unconscious.'),
      _t(name: 'Wakeful', kind: 'Defensive', description: 'When one of the creature\'s heads is asleep, its other head is awake.'),
      _t(name: 'Multiple Heads', kind: 'Passive', description: 'The creature has Advantage on saving throws against being Blinded, Charmed, Deafened, Frightened, Stunned, or knocked Unconscious. Whenever the creature takes 25 or more damage in a single turn, one of its heads dies. The creature dies if all its heads die.'),
      _t(name: 'Reactive Heads', kind: 'Other', description: 'For each head the creature has beyond one, it gets an extra Reaction that can be used only for Opportunity Attacks.'),
      _t(name: 'Acid Absorption', kind: 'Defensive', description: 'Whenever the creature is subjected to Acid damage, it takes no damage and instead regains a number of HP equal to the Acid damage dealt.'),
      _t(name: 'Magic Weapons', kind: 'Passive', description: 'The creature\'s weapon attacks are magical. When the creature hits with any weapon, the weapon deals an extra die of its damage (included in the attack).'),
      _t(name: 'Sneak Attack', kind: 'Passive', description: 'Once per turn, the creature deals an extra 7 (2d6) damage when it hits a target with a weapon attack and has Advantage on the attack roll, or when the target is within 5 feet of an ally of the creature that isn\'t Incapacitated and the creature doesn\'t have Disadvantage on the attack roll.'),
      _t(name: 'Cunning Action', kind: 'Other', description: 'On each of its turns, the creature can use a Bonus Action to take the Dash, Disengage, or Hide action.'),
      _t(name: 'Evasion', kind: 'Defensive', description: 'If the creature is subjected to an effect that allows it to make a Dex save to take only half damage, the creature instead takes no damage if it succeeds and only half damage if it fails.'),
      _t(name: 'Stone Camouflage', kind: 'Passive', description: 'The creature has Advantage on Dexterity (Stealth) checks made to Hide in rocky terrain.'),
      _t(name: 'Earth Glide', kind: 'Movement', description: 'The creature can burrow through nonmagical, unworked earth and stone. While doing so, it doesn\'t disturb the material it moves through.'),
      _t(name: 'Sunlight Hypersensitivity', kind: 'Defensive', description: 'While in sunlight, the creature has Disadvantage on attack rolls and ability checks. It dies if it starts its turn in sunlight and doesn\'t move to shade or cover by the end of that turn.'),
      _t(name: 'Innate Spellcasting (Demon)', kind: 'Spellcasting', description: 'The creature\'s innate spellcasting ability is Charisma. The creature can innately cast spells appropriate to its kind, requiring no Material components.'),
      _t(name: 'Magic Resistance (Strong)', kind: 'Defensive', description: 'The creature has Advantage on saving throws against spells and other magical effects.'),
      _t(name: 'Demonic Restoration', kind: 'Defensive', description: 'If the demon dies outside the Abyss, its body dissolves into ichor, and it gains a new body instantly, reviving with all its HP somewhere in the Abyss.'),
      _t(name: 'Devil\'s Sight', kind: 'Sense', description: 'Magical Darkness doesn\'t impede the creature\'s Darkvision.'),
      _t(name: 'Paralyzing Aura', kind: 'Other', description: 'Any creature touched or hit by a melee attack from the creature must make a Constitution save or have the Paralyzed condition.'),
    ];
