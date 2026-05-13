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
      _t(name: 'Amphibious (Dragon)', kind: 'Movement', description: 'The dragon can breathe air and water.'),
      _t(name: 'Ice Walk', kind: 'Movement', description: 'The dragon can move across and climb icy surfaces without needing to make an ability check. Difficult terrain composed of ice or snow doesn\'t cost it extra movement.'),
      _t(name: 'Stench', kind: 'Passive', description: 'Any creature other than the monster that starts its turn within 5 feet of the monster must succeed on a Constitution save or have the Poisoned condition until the start of its next turn.'),
      _t(name: 'Tentacles (Chuul)', kind: 'Other', description: 'When the chuul hits a creature with a Pincer, it can drag the target with its tentacles, causing the target to have the Poisoned condition until the start of the chuul\'s next turn. While Poisoned, the target is also Paralyzed.'),
      _t(name: 'Sense Magic', kind: 'Sense', description: 'The chuul senses magic within 120 feet of itself. This trait otherwise works like the Detect Magic spell but isn\'t itself magical.'),
      _t(name: 'Limited Telepathy', kind: 'Other', description: 'The creature can magically communicate simple ideas, emotions, and images telepathically with any creature within 30 feet that can understand a language.'),
      _t(name: 'Tree Stride', kind: 'Movement', description: 'Once on her turn, the dryad can use 10 feet of her movement to step magically into one living tree within her reach and emerge from a second living tree within 60 feet that she can see, appearing in an unoccupied space within 5 feet of the second tree.'),
      _t(name: 'Speak with Beasts and Plants', kind: 'Other', description: 'The dryad can communicate with Beasts and Plants as if they shared a language.'),
      _t(name: 'Speak with Plants', kind: 'Other', description: 'The creature can communicate with Plants as if they shared a language.'),
      _t(name: 'False Appearance (Gargoyle)', kind: 'Passive', description: 'While the gargoyle remains motionless, it is indistinguishable from an inanimate statue.'),
      _t(name: 'Spider Climb (Roper)', kind: 'Movement', description: 'The roper can climb difficult surfaces, including upside down on ceilings, without needing to make an ability check.'),
      _t(name: 'Aversion to Light', kind: 'Defensive', description: 'When in sunlight, the nothic has Disadvantage on attack rolls and ability checks.'),
      _t(name: 'Tentacles', kind: 'Passive', description: 'A creature Grappled by the otyugh can\'t use Bite attacks against the otyugh and is at risk of being infected with disease.'),
      _t(name: 'Beast of Burden', kind: 'Passive', description: 'The creature is considered Large for the purpose of determining its carrying capacity.'),
      _t(name: 'Reckless Attacker', kind: 'Passive', description: 'At the start of its turn, the creature can gain Advantage on all melee attack rolls during that turn, but attack rolls against it have Advantage until the start of its next turn.'),
      _t(name: 'Brave', kind: 'Defensive', description: 'The creature has Advantage on saving throws against being Frightened.'),
      _t(name: 'Spell Resistance', kind: 'Defensive', description: 'The couatl has Advantage on saving throws against spells and other magical effects.'),
      _t(name: 'Shielded Mind', kind: 'Defensive', description: 'The couatl is immune to scrying and to any effect that would sense its emotions, read its thoughts, or detect its location.'),
      _t(name: 'Inscrutable', kind: 'Defensive', description: 'The sphinx is immune to any effect that would sense its emotions or read its thoughts, as well as any divination spell that it refuses.'),
      _t(name: 'Multi-Headed (Hydra)', kind: 'Passive', description: 'The hydra has five heads. While it has more than one head, the hydra has advantage on saves against being Blinded, Charmed, Deafened, Frightened, Stunned, and knocked Unconscious.'),
      _t(name: 'Aura of the Dead', kind: 'Passive', description: 'The death knight emits an aura of fear in a 30-foot radius.'),
      _t(name: 'Spellcasting (Mage)', kind: 'Spellcasting', description: 'The mage casts one of the following spells, using Intelligence as the spellcasting ability (spell save DC 14, +6 to hit with spell attacks). At will: Detect Magic, Light, Mage Hand, Prestidigitation. 1/Day each: Counterspell, Fire Bolt, Fireball, Mage Armor.'),
      _t(name: 'Spellcasting (Priest)', kind: 'Spellcasting', description: 'The priest casts one of the following spells, using Wisdom as the spellcasting ability (spell save DC 13, +5 to hit with spell attacks). At will: Light, Sacred Flame, Thaumaturgy. 1/Day each: Cure Wounds, Bless, Spirit Guardians.'),
      _t(name: 'Spellcasting (Cult Fanatic)', kind: 'Spellcasting', description: 'The fanatic casts one of the following spells, using Wisdom as the spellcasting ability (spell save DC 11). At will: Light, Sacred Flame, Thaumaturgy. 1/Day each: Hold Person, Spiritual Weapon.'),
      _t(name: 'Pack Tactics (Death Dog)', kind: 'Passive', description: 'The death dog has Advantage on attack rolls if at least one of its allies is within 5 feet of the target and the ally doesn\'t have the Incapacitated condition.'),
      _t(name: 'Two-Headed (Death Dog)', kind: 'Passive', description: 'The death dog has Advantage on Wisdom (Perception) checks and on saving throws against being Blinded, Charmed, Deafened, Frightened, Stunned, or Unconscious.'),
      _t(name: 'Blood Frenzy', kind: 'Passive', description: 'The creature has Advantage on attack rolls against any creature that doesn\'t have all its HP.'),
      _t(name: 'Water Breathing', kind: 'Other', description: 'The creature can breathe only underwater.'),
      _t(name: 'Hold Breath (Crocodile)', kind: 'Other', description: 'The crocodile can hold its breath for 30 minutes.'),
      _t(name: 'Trampling Charge', kind: 'Passive', description: 'If the creature moves at least 20 feet straight toward a target and then hits it with a melee attack on the same turn, the target must succeed on a Strength save or have the Prone condition. If the target is Prone, the creature can make one Stomp attack against it as a Bonus Action.'),
      _t(name: 'Beast Whisperer', kind: 'Other', description: 'The creature can speak with Beasts as if they shared a language.'),
      _t(name: 'Swarm', kind: 'Passive', description: 'The swarm can occupy another creature\'s space and vice versa, and the swarm can move through any opening large enough for one of its component creatures. The swarm can\'t regain HP or gain Temporary HP.'),
      _t(name: 'Echolocation', kind: 'Sense', description: 'The creature can\'t use its Blindsight while Deafened.'),
      _t(name: 'Avoidance', kind: 'Defensive', description: 'If an effect requires a save and the creature is in the area, it takes no damage if it succeeds and only half damage if it fails.'),
      _t(name: 'Nine Lives Stealer', kind: 'Other', description: 'When the creature drops to 0 HP, it transfers its life to a phylactery rather than dying.'),
      _t(name: 'Construct Nature', kind: 'Other', description: 'The construct doesn\'t require air, food, drink, or sleep.'),
      _t(name: 'Plant Camouflage', kind: 'Passive', description: 'The creature has Advantage on Dexterity (Stealth) checks made to hide in terrain with ample obscuring vegetation.'),
      _t(name: 'Frightful Presence', kind: 'Passive', description: 'When the creature appears, each creature of its choice within 120 feet that can see the creature must succeed on a Wisdom save or have the Frightened condition for 1 minute. A target can repeat the save at the end of each of its turns; if successful, the target is immune to this creature\'s Frightful Presence for 24 hours.'),
      _t(name: 'Innate Spellcasting (Sphinx)', kind: 'Spellcasting', description: 'The sphinx\'s innate spellcasting ability is Intelligence (spell save DC 18). It can innately cast certain spells, requiring no Material components.'),

      // ─── Animal-roster traits — batch 1 ─────────────────────────────────
      _t(name: 'Flyby (Bat)', kind: 'Movement', description: 'The bat doesn\'t provoke Opportunity Attacks when it flies out of an enemy\'s reach.'),
      _t(name: 'Nimble Escape', kind: 'Other', description: 'The creature takes the Disengage or Hide action as a Bonus Action on each of its turns.'),
      _t(name: 'Climb (Animal)', kind: 'Movement', description: 'The creature has a Climb Speed equal to its Walk Speed.'),
      _t(name: 'Burrow (Giant Badger)', kind: 'Movement', description: 'The badger has a Burrow Speed of 10 feet through nonmagical, unworked earth and stone.'),
      _t(name: 'Stealth Master', kind: 'Passive', description: 'The creature has Advantage on Dexterity (Stealth) checks while in dim light or darkness.'),
      _t(name: 'Death Burst (Fire Beetle)', kind: 'Other', description: 'When reduced to 0 HP, the beetle erupts in a flash of fire. Each creature within 5 feet must make a DC 10 Dex save, taking 3 (1d6) Fire damage on a fail or half on a success.'),
      _t(name: 'Light (Fire Beetle)', kind: 'Other', description: 'The beetle sheds Bright Light in a 10-foot radius and Dim Light for an additional 10 feet.'),
      _t(name: 'Camouflage (Octopus)', kind: 'Passive', description: 'The octopus has Advantage on Dexterity (Stealth) checks made while underwater.'),
      _t(name: 'Hold Breath (Octopus)', kind: 'Other', description: 'While out of water, the octopus can hold its breath for 30 minutes.'),
      _t(name: 'Underwater Camouflage', kind: 'Passive', description: 'The creature has Advantage on Dexterity (Stealth) checks made while underwater.'),
      _t(name: 'Ink Cloud', kind: 'Other', description: 'While underwater, the octopus can use a Bonus Action to expel ink in a 10-foot Cube. The area is Heavily Obscured for 1 minute.'),
      _t(name: 'Water Breathing (Animal)', kind: 'Other', description: 'The creature can breathe only underwater.'),
      _t(name: 'Charge (Animal)', kind: 'Other', description: 'If the creature moves at least 20 feet straight toward a target and then hits with a melee attack on the same turn, the target takes extra damage.'),
      _t(name: 'Mimicry', kind: 'Other', description: 'The creature can mimic simple sounds it has heard, such as a person whispering, a baby crying, or an animal chittering. A creature can discern the sounds are imitations with a successful Wisdom (Insight) check (DC 14).'),
      _t(name: 'Shapechanger (Werecreature)', kind: 'Other', description: 'The creature can use its action to polymorph into a hybrid or beast form, or back into its true (humanoid) form.'),
      _t(name: 'Hooves (Trampling)', kind: 'Other', description: 'If the creature moves at least 20 feet straight toward a target and then hits with a Hooves attack on the same turn, the target takes extra Bludgeoning damage and has the Prone condition.'),

      // ─── Gap closure: missing traits for added monsters ──────────────────
      _t(name: 'Fear Aura', kind: 'Passive', description: 'Any creature hostile to the source that starts its turn within 20 feet of the source must succeed on a Wisdom save or have the Frightened condition until the start of its next turn. On a success, the creature is immune to this aura for 24 hours.'),
      _t(name: 'Innate Spellcasting (Hag)', kind: 'Spellcasting', description: 'The hag\'s innate spellcasting ability is Charisma. It can innately cast certain spells, requiring no Material components.'),
      _t(name: 'Reactive', kind: 'Passive', description: 'The creature can take one Reaction on every turn of combat, not only on turns other than its own.'),
      _t(name: 'Lightning Absorption', kind: 'Defensive', description: 'Whenever the creature is subjected to Lightning damage, it takes no damage and instead regains a number of HP equal to the Lightning damage dealt.'),
      _t(name: 'Fire Absorption', kind: 'Defensive', description: 'Whenever the creature is subjected to Fire damage, it takes no damage and instead regains a number of HP equal to the Fire damage dealt.'),
      _t(name: 'Cold Absorption', kind: 'Defensive', description: 'Whenever the creature is subjected to Cold damage, it takes no damage and instead regains a number of HP equal to the Cold damage dealt.'),
      _t(name: 'Treasure Sense', kind: 'Sense', description: 'The creature can pinpoint the location of precious metals and stones (gold, silver, gems, etc.) within 60 feet, by smell.'),
      _t(name: 'Earth Walk', kind: 'Movement', description: 'The creature can move through nonmagical, unworked earth and stone as if it were Difficult Terrain. It doesn\'t disturb the material it moves through.'),
      _t(name: 'Heated Body', kind: 'Passive', description: 'A creature that touches the creature or hits it with a melee attack while within 5 feet of it takes 5 (1d10) Fire damage.'),
      _t(name: 'Innate Spellcasting (Lamia)', kind: 'Spellcasting', description: 'The lamia\'s innate spellcasting ability is Charisma. It can innately cast certain spells, requiring no Material components.'),
      _t(name: 'Steal Memories', kind: 'Other', description: 'When the creature kills a victim, it can siphon the victim\'s memories, learning all that the victim knew.'),
      _t(name: 'Blessed by Tyche', kind: 'Defensive', description: 'When the creature would fail a saving throw, it can choose to succeed instead. Limited uses per long rest.'),
      _t(name: 'Misty Escape', kind: 'Defensive', description: 'When the creature drops to 0 HP outside its resting place, it transforms into a cloud of mist instead of falling unconscious, provided that it isn\'t in sunlight or running water.'),
      _t(name: 'Shapechanger (Vampire)', kind: 'Other', description: 'The vampire can use its action to polymorph into a Tiny bat, a Medium cloud of mist, or back into its true form.'),
      _t(name: 'Spider Climb (Vampire)', kind: 'Movement', description: 'The vampire can climb difficult surfaces, including upside down on ceilings, without an ability check.'),
      _t(name: 'Vampire Weaknesses', kind: 'Defensive', description: 'Forbiddance, sunlight, running water, stake to the heart, etc.'),
      _t(name: 'Innate Spellcasting (Rakshasa)', kind: 'Spellcasting', description: 'The rakshasa\'s innate spellcasting ability is Charisma. It can innately cast certain illusion and enchantment spells.'),
      _t(name: 'Limited Magic Immunity', kind: 'Defensive', description: 'The creature is immune to spells of 6th level or lower unless it wishes to be affected. It has Advantage on saving throws against all other spells and magical effects.'),
      _t(name: 'Air Form', kind: 'Movement', description: 'The creature can enter a hostile creature\'s space and stop there. It can move through a space as narrow as 1 inch without squeezing.'),
      _t(name: 'Earth Glide (Xorn)', kind: 'Movement', description: 'The xorn can burrow through nonmagical, unworked earth and stone. While doing so, it doesn\'t disturb the material it moves through.'),
      _t(name: 'Stone Camouflage (Xorn)', kind: 'Passive', description: 'The xorn has Advantage on Dexterity (Stealth) checks made to Hide in rocky terrain.'),
      _t(name: 'Innate Spellcasting (Pixie)', kind: 'Spellcasting', description: 'The creature\'s innate spellcasting ability is Charisma. It can innately cast certain enchantment and illusion spells.'),
      _t(name: 'Immutable Form', kind: 'Defensive', description: 'The creature is immune to any spell or effect that would alter its form.'),
      _t(name: 'Sunlight Sensitivity (Acute)', kind: 'Defensive', description: 'While in sunlight, the creature has Disadvantage on attack rolls as well as on Wisdom (Perception) checks that rely on sight.'),
      _t(name: 'Sphinx Spellcasting', kind: 'Spellcasting', description: 'The sphinx casts spells using Intelligence as the spellcasting ability. Spell save DC scales with stat block.'),
      _t(name: 'Whelm', kind: 'Passive', description: 'When the creature drops to 0 HP, it doesn\'t die. Instead, it falls Unconscious and rerolls (resurrects) at full HP at the start of its next turn (limited uses per stat block).'),
      _t(name: 'Spell Storing (Lich)', kind: 'Spellcasting', description: 'The lich can magically store one spell of 5th level or lower in its bones, casting it later at no cost.'),
      _t(name: 'Incorporeal Movement', kind: 'Movement', description: 'The creature can move through other creatures and objects as if they were Difficult Terrain. It takes 5 (1d10) Force damage if it ends its turn inside an object.'),
      _t(name: 'Divine Awareness', kind: 'Passive', description: 'The creature knows when it hears a lie.'),
      _t(name: 'Iron Scent', kind: 'Passive', description: 'The rust monster can pinpoint the location of ferrous metal within 30 feet of it.'),
      _t(name: 'Ooze Cube', kind: 'Passive', description: 'The cube takes up its entire space. Other creatures can enter the space, but a creature that does so is subjected to the cube\'s Engulf and has Disadvantage on the saving throw. Creatures inside the cube can be seen but have Total Cover. A creature within 5 feet of the cube can take an action to pull a creature or object out, succeeding on a DC 12 Strength check. The cube can hold one Large creature or up to four Medium or smaller creatures.'),
      _t(name: 'Reflective Carapace', kind: 'Defensive', description: 'If the creature is targeted by a Magic Missile spell or a line spell, or if a spell attack roll is made against it, roll a d6. On a 1–5, the creature is unaffected. On a 6, the creature is unaffected and the effect is reflected back at the caster.'),
      _t(name: 'Tunneler', kind: 'Movement', description: 'The creature can burrow through solid rock, leaving a 10-foot-diameter tunnel in its wake.'),

      // ─── Player Character species traits (SRD 5.2.1 pp. 83–86) ──────────
      // Referenced from `species.dart` via `trait_refs`. Mechanically-typed
      // grants (resistances, senses, languages) live on the species fields;
      // these trait rows hold the narrative summary the editor cards render.
      _t(
        name: 'Dwarven Resilience',
        kind: 'Defensive',
        description:
            'Advantage on saving throws against the Poisoned condition, and Resistance to Poison damage.',
      ),
      _t(
        name: 'Stonecunning',
        kind: 'Other',
        description:
            'As a Bonus Action you gain Tremorsense with a range of 60 feet for 10 minutes. You must be on a stone surface or touching one. Uses = Proficiency Bonus per Long Rest.',
      ),
      _t(
        name: 'Forge Wise',
        kind: 'Other',
        description:
            'You have proficiency with two of the following Artisan\'s Tools of your choice: Jeweler\'s Tools, Mason\'s Tools, Smith\'s Tools, or Tinker\'s Tools.',
      ),
      _t(
        name: 'Trance',
        kind: 'Defensive',
        description:
            'You don\'t need to sleep, and magic can\'t put you to sleep. You can finish a Long Rest in 4 hours of meditation. After a Trance you gain proficiency with one weapon or tool of your choice for the next 24 hours.',
      ),
      _t(
        name: 'Keen Senses (Elf)',
        kind: 'Sense',
        description:
            'You have proficiency in the Insight, Perception, or Survival skill (your choice).',
      ),
      _t(
        name: 'Elven Lineage',
        kind: 'Other',
        description:
            'You are part of an Elven lineage (Drow, High Elf, or Wood Elf), granting additional traits and innate spells.',
      ),
      _t(
        name: 'Halfling Lucky',
        kind: 'Passive',
        description:
            'When you roll a 1 on the d20 of a d20 Test, you can reroll the die and must use the new roll.',
      ),
      _t(
        name: 'Naturally Stealthy',
        kind: 'Passive',
        description:
            'You can take the Hide action when you have only a creature that is at least one size larger than you as cover.',
      ),
      _t(
        name: 'Brave',
        kind: 'Defensive',
        description:
            'You have Advantage on saving throws against being Frightened.',
      ),
      _t(
        name: 'Halfling Nimbleness',
        kind: 'Movement',
        description:
            'You can move through the space of any creature that is a size larger than you, though that space is Difficult Terrain for you.',
      ),
      _t(
        name: 'Resourceful',
        kind: 'Other',
        description:
            'You gain Heroic Inspiration whenever you finish a Long Rest.',
      ),
      _t(
        name: 'Skilled (Human)',
        kind: 'Other',
        description:
            'You gain proficiency in three skills of your choice.',
      ),
      _t(
        name: 'Versatile (Human)',
        kind: 'Other',
        description:
            'You gain an Origin feat of your choice (see Chapter 5: Feats).',
      ),
      _t(
        name: 'Gnomish Cunning',
        kind: 'Defensive',
        description:
            'You have Advantage on Intelligence, Wisdom, and Charisma saving throws.',
      ),
      _t(
        name: 'Powerful Build',
        kind: 'Passive',
        description:
            'You count as one size larger when determining your carrying capacity and the weight you can push, drag, or lift. You have Advantage on any ability check you make to end the Grappled condition.',
      ),
      _t(
        name: 'Large Form',
        kind: 'Other',
        description:
            'Starting at character level 5, you can change your size to Large as a Bonus Action if you are in a big enough space. For 10 minutes you have Advantage on Strength checks, and your Speed increases by 10 feet. Uses = PB per Long Rest.',
      ),
      _t(
        name: 'Giant Ancestry',
        kind: 'Other',
        description:
            'You are descended from giants. Choose one ancestry boon (Cloud / Fire / Frost / Hill / Stone / Storm) which grants you an additional special action or resistance.',
      ),
      _t(
        name: 'Otherworldly Presence',
        kind: 'Other',
        description:
            'You know the Thaumaturgy cantrip. When you cast it with this trait, the spell uses Charisma as the spellcasting ability.',
      ),
      _t(
        name: 'Fiendish Legacy',
        kind: 'Other',
        description:
            'You have a Fiendish Legacy (Abyssal, Chthonic, or Infernal), granting you damage resistance and innate spells keyed to that legacy.',
      ),
      _t(
        name: 'Draconic Ancestry',
        kind: 'Other',
        description:
            'Choose a kind of dragon ancestry (Black, Blue, Brass, Bronze, Copper, Gold, Green, Red, Silver, or White). Your Breath Weapon and Damage Resistance are determined by that ancestry.',
      ),
      _t(
        name: 'Damage Resistance (Dragonborn)',
        kind: 'Defensive',
        description:
            'You have Resistance to the damage type associated with your Draconic Ancestry.',
      ),

      // ─── Player Character class traits (passive features) ────────────────
      _t(
        name: 'Unarmored Defense (Barbarian)',
        kind: 'Defensive',
        description:
            'While you are not wearing armor, your Armor Class equals 10 + your Dex modifier + your Con modifier. A Shield doesn\'t conflict with this trait.',
      ),
      _t(
        name: 'Unarmored Defense (Monk)',
        kind: 'Defensive',
        description:
            'While you are not wearing armor and not using a Shield, your AC equals 10 + your Dex modifier + your Wis modifier.',
      ),
      _t(
        name: 'Reckless Attack',
        kind: 'Passive',
        description:
            'When you make your first attack on your turn, you can decide to attack recklessly. You gain Advantage on melee Strength-based attack rolls during this turn, but attack rolls against you have Advantage until the start of your next turn.',
      ),
      _t(
        name: 'Danger Sense',
        kind: 'Defensive',
        description:
            'You have Advantage on Dex saving throws against effects you can see while you are not Incapacitated.',
      ),
      _t(
        name: 'Weapon Mastery',
        kind: 'Passive',
        description:
            'You can use the Mastery property of two kinds of Simple or Martial Melee weapons. You can swap one of your choices on a Long Rest.',
      ),
      _t(
        name: 'Jack of All Trades',
        kind: 'Passive',
        description:
            'You can add half your Proficiency Bonus (rounded down) to any ability check you make that doesn\'t already use your Proficiency Bonus.',
      ),
      _t(
        name: 'Expertise',
        kind: 'Passive',
        description:
            'Choose two of your skill proficiencies. Your Proficiency Bonus is doubled for ability checks using those skills.',
      ),
      _t(
        name: 'Sneak Attack (Rogue)',
        kind: 'Passive',
        description:
            'Once per turn, you can deal extra 1d6 damage to one creature you hit with a Finesse or Ranged weapon attack if you have Advantage on the roll, or if another enemy of the target is within 5 feet of it. Damage scales with Rogue level.',
      ),
      _t(
        name: 'Cunning Action (Rogue)',
        kind: 'Other',
        description:
            'On each of your turns, you can use a Bonus Action to take the Dash, Disengage, or Hide action.',
      ),
      _t(
        name: 'Martial Arts',
        kind: 'Passive',
        description:
            'Your practiced martial techniques give you the following benefits while you are unarmed or wielding only Monk weapons and not wearing armor or a Shield: you can use Dexterity instead of Strength for the attack and damage rolls; your unarmed strike die is a Martial Arts die (d6 at L1, scales up); you can make one Unarmed Strike as a Bonus Action when you take the Attack action.',
      ),
      _t(
        name: 'Arcane Recovery',
        kind: 'Spellcasting',
        description:
            'Once per day when you finish a Short Rest, you can recover expended spell slots whose combined level is no more than half your Wizard level (rounded up), and none of which can be 6th level or higher.',
      ),
      _t(
        name: 'Spellcasting Focus',
        kind: 'Spellcasting',
        description:
            'You can use a spellcasting focus (e.g. arcane focus, druidic focus, or holy symbol) in place of Material components.',
      ),
      _t(
        name: 'Divine Order',
        kind: 'Other',
        description:
            'You are committed to a divine role (Protector or Thaumaturge). Protector: gain training in Martial weapons + Heavy armor. Thaumaturge: gain Religion proficiency and learn one extra Cleric cantrip.',
      ),
      _t(
        name: 'Druidic',
        kind: 'Other',
        description:
            'You know Druidic, the secret language of druids. You can speak and write Druidic, and you can use it to leave hidden messages that automatically take 1 hour to discover.',
      ),
      _t(
        name: 'Pact Magic',
        kind: 'Spellcasting',
        description:
            'Your patron grants you the ability to cast spells. You know two cantrips and two 1st-level spells. You regain all expended Pact Magic spell slots after a Short or Long Rest.',
      ),
      _t(
        name: 'Eldritch Invocations',
        kind: 'Other',
        description:
            'You learn Eldritch Invocations — special magical secrets that augment your abilities. You learn additional Invocations and can replace one on each Warlock level-up.',
      ),
      _t(
        name: 'Favored Enemy',
        kind: 'Passive',
        description:
            'You always have Hunter\'s Mark prepared. You can cast it without expending a spell slot a number of times per Long Rest equal to your Proficiency Bonus, and use any spell slot to cast it at higher levels.',
      ),
      _t(
        name: 'Lay on Hands (Pool)',
        kind: 'Spellcasting',
        description:
            'You have a pool of healing power equal to your Paladin level × 5 HP. From the pool you can spend points to heal a willing creature you touch, or expend 5 points to end one disease or Poisoned condition. The pool refreshes on a Long Rest.',
      ),
      _t(
        name: 'Innate Sorcery',
        kind: 'Spellcasting',
        description:
            'Your innate magical talent grants you Sorcery Points equal to your Sorcerer level (refreshed on a Long Rest) and access to Metamagic options as you gain levels.',
      ),
    ];
