// SRD 5.2.1 Subclasses (pp. 28–82). One subclass per class is published in
// the SRD. Each is granted at level 3 (varies). Features summarized
// per-level; per-class deeper feature text lives in the parent class entity.

import '_helpers.dart';

Map<String, dynamic> _f(int level, String name, String description) =>
    {'level': level, 'name': name, 'description': description};

/// `_f` + explicit grant lists folded onto the PC at creation / level-up
/// via the wizard's `absorbFeatureRows` + editor's `absorbFeatureRowsInRange`.
Map<String, dynamic> _fg(
  int level,
  String name,
  String description, {
  List<Map<String, String>> actions = const [],
  List<Map<String, String>> bonusActions = const [],
  List<Map<String, String>> reactions = const [],
  List<Map<String, String>> traits = const [],
  List<Map<String, String>> feats = const [],
}) => {
      'level': level,
      'name': name,
      'description': description,
      if (actions.isNotEmpty) 'granted_action_refs': actions,
      if (bonusActions.isNotEmpty) 'granted_bonus_action_refs': bonusActions,
      if (reactions.isNotEmpty) 'granted_reaction_refs': reactions,
      if (traits.isNotEmpty) 'granted_trait_refs': traits,
      if (feats.isNotEmpty) 'granted_feat_refs': feats,
    };

List<Map<String, dynamic>> srdSubclasses() => [
      packEntity(
        slug: 'subclass',
        name: 'Path of the Berserker',
        description:
            'Barbarians who direct their Rage primarily toward violence. Path of untrammeled fury.',
        attributes: {
          'parent_class_ref': ref('class', 'Barbarian'),
          'granted_at_level': 3,
          'flavor_description':
              'Channel Rage into Violent Fury. Berserkers thrill in the chaos of battle as they let their Rage seize and empower them.',
          'features': [
            _fg(3, 'Frenzy',
                'When you Reckless Attack while Raging, deal extra damage to the first target you hit on your turn equal to a number of d6s = your Rage Damage bonus.',
                traits: [ref('trait', 'Frenzy')]),
            _fg(6, 'Mindless Rage',
                'Immune to Charmed and Frightened conditions while Raging. If Charmed/Frightened when entering Rage, the condition ends.',
                traits: [ref('trait', 'Mindless Rage')],
                feats: [ref('feat', 'Mindless Rage')]),
            _fg(10, 'Retaliation',
                'When you take damage from a creature within 5 feet, take a Reaction to make one melee attack against it.',
                reactions: [ref('creature-action', 'Retaliation')]),
            _fg(14, 'Intimidating Presence',
                'Bonus Action: each creature of your choice in a 30-ft Emanation makes a Wis save (DC 8 + Str + PB) or is Frightened for 1 minute (saves at end of each turn).',
                bonusActions: [ref('creature-action', 'Intimidating Presence')]),
          ],
        },
      ),
      packEntity(
        slug: 'subclass',
        name: 'College of Lore',
        description:
            'Bards who collect knowledge and weave subtle, witty magic.',
        attributes: {
          'parent_class_ref': ref('class', 'Bard'),
          'granted_at_level': 3,
          // Bonus Proficiencies (L3) — picked when the subclass is granted.
          // Surfaces as a `skillProficiency` pending choice on subclass pick.
          'bonus_skill_pick_count': 3,
          'flavor_description':
              'Bards of the College of Lore know something about most things. Their wit is as sharp as their wisdom is broad.',
          'features': [
            _f(3, 'Bonus Proficiencies',
                'Gain proficiency with three skills of your choice.'),
            _fg(3, 'Cutting Words',
                'Reaction when a creature within 60 feet makes an attack roll, ability check, or damage roll: subtract a Bardic Inspiration die from the result.',
                reactions: [ref('creature-action', 'Cutting Words')]),
            _f(6, 'Magical Discoveries',
                'Learn two spells of your choice from any class\'s spell list. They count as Bard spells.'),
            _f(14, 'Peerless Skill',
                'Roll a Bardic Inspiration die and add the result to a single ability check.'),
          ],
        },
      ),
      packEntity(
        slug: 'subclass',
        name: 'Life Domain',
        description:
            'Clerics devoted to gods of life, healing, and the protection of the innocent.',
        attributes: {
          'parent_class_ref': ref('class', 'Cleric'),
          'granted_at_level': 3,
          'flavor_description':
              'The Life Domain focuses on the vibrant positive energy that sustains all life. Its clerics are skilled healers.',
          'features': [
            _fg(3, 'Disciple of Life',
                'When you cast a level 1+ spell that restores HP, the target regains additional HP = 2 + the spell\'s level.',
                traits: [ref('trait', 'Disciple of Life')]),
            _f(3, 'Domain Spells',
                'You always have prepared a list of bonus spells, scaling with level (Bless, Cure Wounds, Lesser Restoration, Aid, Beacon of Hope, etc.).'),
            _fg(3, 'Preserve Life',
                'Channel Divinity: Magic action — restore 5 × Cleric level HP divided as you choose among creatures within 30 feet (none above half HP).',
                actions: [ref('creature-action', 'Preserve Life')]),
            _fg(6, 'Blessed Healer',
                'When you cast a level 1+ healing spell on others, you regain HP = 2 + the spell\'s level.',
                traits: [ref('trait', 'Blessed Healer')]),
            _f(17, 'Supreme Healing',
                'Whenever you would roll dice to restore HP, treat each die as the maximum value.'),
          ],
        },
      ),
      packEntity(
        slug: 'subclass',
        name: 'Circle of the Land',
        description:
            'Druids drawn to mystical sites such as sacred groves, who safeguard ancient knowledge and rites.',
        attributes: {
          'parent_class_ref': ref('class', 'Druid'),
          'granted_at_level': 3,
          'flavor_description':
              'Members of the Circle of the Land gather within sacred sites to perform rituals beneath the stars.',
          'features': [
            _fg(3, 'Land\'s Aid',
                'When you cast a Druid spell of level 1+, you can also restore 1d4 + spell level HP to one creature within 60 feet, or deal 1d4 + spell level Necrotic damage to a creature.',
                actions: [ref('creature-action', 'Land\'s Aid')]),
            _f(3, 'Circle Forms',
                'Wild Shape options expanded; you can transform into Beasts of CR ½.'),
            _fg(6, 'Land\'s Stride',
                'You ignore Difficult Terrain made of nonmagical plants. Magical Difficult Terrain caused by plants requires no save to pass through.',
                traits: [ref('trait', 'Land\'s Stride')]),
            _fg(10, 'Nature\'s Ward',
                'Immune to the Poisoned condition; gain Resistance to a damage type associated with your current land choice.',
                traits: [ref('trait', 'Nature\'s Ward')]),
            _fg(14, 'Nature\'s Sanctuary',
                'Magic Action: expend Wild Shape to summon protective trees and vines in a 15-foot Cube. You and allies gain Half Cover + your Nature\'s Ward resistance.',
                actions: [ref('creature-action', 'Nature\'s Sanctuary')]),
          ],
        },
      ),
      packEntity(
        slug: 'subclass',
        name: 'Champion',
        description:
            'Fighters who pursue physical perfection through martial training and refinement of body.',
        attributes: {
          'parent_class_ref': ref('class', 'Fighter'),
          'granted_at_level': 3,
          'flavor_description':
              'The Champion focuses on raw physical power honed to deadly perfection.',
          'features': [
            _fg(3, 'Improved Critical', 'Weapon attacks score a critical hit on a roll of 19 or 20.',
                traits: [ref('trait', 'Improved Critical')]),
            _fg(3, 'Remarkable Athlete',
                'Add half your PB (rounded up) to any Strength, Dexterity, or Constitution check that doesn\'t already include it.',
                traits: [ref('trait', 'Remarkable Athlete')]),
            _f(7, 'Additional Fighting Style',
                'Choose a second Fighting Style feat.'),
            _fg(10, 'Heroic Warrior', 'Heroic Inspiration whenever you don\'t already have it.',
                traits: [ref('trait', 'Heroic Warrior')]),
            _f(15, 'Superior Critical', 'Critical hits trigger on 18–20.'),
            _f(18, 'Survivor',
                'At the start of each of your turns, regain HP = 5 + Con mod if you have at least 1 HP and at most half your HP max.'),
          ],
        },
      ),
      packEntity(
        slug: 'subclass',
        name: 'Warrior of the Open Hand',
        description:
            'Monks who specialize in unarmed combat and channel flowing martial techniques.',
        attributes: {
          'parent_class_ref': ref('class', 'Monk'),
          'granted_at_level': 3,
          'flavor_description':
              'Open Hand monks are the ultimate masters of martial-arts combat, harnessing the body and mind in flowing harmony.',
          'features': [
            _fg(3, 'Open Hand Technique',
                'Whenever you hit with a Martial Arts strike, choose one effect: knock the target prone (Dex save), push the target up to 15 feet (Str save), or impose Disadvantage on its next save (Dex save).',
                traits: [ref('trait', 'Open Hand Technique')]),
            _fg(6, 'Wholeness of Body',
                'As a Bonus Action, restore HP equal to 2 × Monk level (cost 2 Focus). Once per Long Rest.',
                bonusActions: [ref('creature-action', 'Wholeness of Body')]),
            _f(11, 'Fleet Step',
                'Bonus Action: take Step of the Wind in addition to making an attack as part of the Attack action.'),
            _f(17, 'Quivering Palm',
                'When you hit with an Unarmed Strike, spend 4 Focus Points to plant lethal vibrations: target makes a Con save or takes 10d12 Force damage on activation.'),
          ],
        },
      ),
      packEntity(
        slug: 'subclass',
        name: 'Oath of Devotion',
        description:
            'Paladins who embody the most idealistic principles of justice, valor, and order.',
        attributes: {
          'parent_class_ref': ref('class', 'Paladin'),
          'granted_at_level': 3,
          'flavor_description':
              'The Oath of Devotion binds the paladin to ideals of honesty, courage, compassion, honor, duty, responsibility, and faith.',
          'features': [
            _fg(3, 'Sacred Weapon',
                'Channel Divinity: Bonus Action to imbue a weapon with positive energy for 1 minute. Add Cha mod to attacks, weapon emits Bright Light.',
                actions: [ref('creature-action', 'Sacred Weapon')]),
            _f(3, 'Domain Spells',
                'You always have prepared spells like Protection from Evil and Good, Lesser Restoration, Beacon of Hope, Dispel Magic, Guardian of Faith, Commune.'),
            _f(7, 'Aura of Devotion',
                'You and friendly creatures within 10 feet can\'t be Charmed while you\'re conscious.'),
            _f(15, 'Smite of Protection',
                'Allies in your Aura of Protection gain Half Cover.'),
            _f(20, 'Holy Nimbus',
                'Magic action: emit aura of sunlight for 10 minutes. Deal 10 Radiant damage to enemies that start their turn in the aura. Once per Long Rest.'),
          ],
        },
      ),
      packEntity(
        slug: 'subclass',
        name: 'Hunter',
        description:
            'Rangers who stalk the multiverse\'s most dangerous predators and protect civilization from monstrous foes.',
        attributes: {
          'parent_class_ref': ref('class', 'Ranger'),
          'granted_at_level': 3,
          'flavor_description':
              'A Hunter learns specialized techniques for fighting threats menacing the natural world.',
          'features': [
            _f(3, 'Hunter\'s Lore',
                'When you cast Hunter\'s Mark on a creature, learn whether it has Resistance/Immunity/Vulnerability to acid/cold/fire/lightning/thunder.'),
            _fg(3, 'Hunter\'s Prey',
                'Choose Colossus Slayer, Horde Breaker, or Giant Killer.',
                traits: [ref('trait', 'Hunter\'s Prey')]),
            _fg(7, 'Defensive Tactics',
                'Choose Escape the Horde, Multiattack Defense, or Steel Will.',
                traits: [ref('trait', 'Defensive Tactics')]),
            _f(11, 'Multiattack',
                'Choose Volley (ranged AoE) or Whirlwind Attack (melee AoE).'),
            _f(15, 'Superior Hunter\'s Defense',
                'Choose Evasion, Stand Against the Tide, or Uncanny Dodge.'),
          ],
        },
      ),
      packEntity(
        slug: 'subclass',
        name: 'Thief',
        description:
            'Rogues who hone skills of stealth, mobility, and the manipulation of magical implements.',
        attributes: {
          'parent_class_ref': ref('class', 'Rogue'),
          'granted_at_level': 3,
          'flavor_description':
              'Thieves are versed in the techniques of treasure-hunting, climbing, and reading languages and magic.',
          'features': [
            _fg(3, 'Fast Hands',
                'Bonus Action: Sleight of Hand check, use Thieves\' Tools, take the Use an Object action.',
                bonusActions: [ref('creature-action', 'Fast Hands')]),
            _f(3, 'Second-Story Work',
                'Climbing speed equal to your Speed; running long jump distance increases by Dex mod.'),
            _f(9, 'Supreme Sneak',
                'Spend 1 d6 of Sneak Attack to move with unaltered Stealth.'),
            _f(13, 'Use Magic Device',
                'Ignore class, race, level requirements when using a magic item or scroll.'),
            _f(17, 'Thief\'s Reflexes',
                'On the first round of combat, take two turns; the second occurs on Initiative count − 10.'),
          ],
        },
      ),
      packEntity(
        slug: 'subclass',
        name: 'Draconic Sorcery',
        description:
            'Sorcerers whose innate magic stems from a draconic bloodline.',
        attributes: {
          'parent_class_ref': ref('class', 'Sorcerer'),
          'granted_at_level': 3,
          'flavor_description':
              'Your innate magic stems from the blood of a powerful dragon — your latent power runs in your veins.',
          'features': [
            _fg(3, 'Draconic Resilience',
                'HP max increases by 3 and by 1 again whenever you gain a Sorcerer level. Your AC = 13 + Dex mod when not wearing armor.',
                traits: [ref('trait', 'Draconic Resilience')]),
            _f(3, 'Draconic Spells',
                'Choose a damage type from the Draconic Ancestors table; gain bonus prepared spells like Chromatic Orb, Dragon\'s Breath, Fly, Fireball.'),
            _fg(6, 'Elemental Affinity',
                'When casting a spell with your draconic damage type, add Cha mod to one damage roll. Spend 1 Sorcery Point to gain Resistance to that damage type for 1 hour.',
                traits: [ref('trait', 'Elemental Affinity')]),
            _fg(14, 'Dragon Wings',
                'Bonus Action: sprout dragon wings; gain a Fly Speed equal to your Speed for 1 hour.',
                bonusActions: [ref('creature-action', 'Dragon Wings')]),
            _fg(18, 'Dragon Companion',
                'Cast Summon Dragon without expending a slot once per Long Rest; you can dismiss the dragon as a Bonus Action.',
                traits: [ref('trait', 'Dragon Companion')]),
          ],
        },
      ),
      packEntity(
        slug: 'subclass',
        name: 'Fiend Patron',
        description:
            'Warlocks bound to a powerful fiend who has clawed its way to a station of greater devil or demon.',
        attributes: {
          'parent_class_ref': ref('class', 'Warlock'),
          'granted_at_level': 3,
          'flavor_description':
              'Your patron is a powerful denizen of the Lower Planes — Asmodeus, Baalzebul, or some demon prince.',
          'features': [
            _fg(3, 'Dark One\'s Blessing',
                'When you reduce a creature to 0 HP, gain temp HP = Cha mod + Warlock level.',
                traits: [ref('trait', 'Dark One\'s Blessing')]),
            _f(3, 'Fiend Spells',
                'Bonus prepared spells: Burning Hands, Command, Blindness/Deafness, Scorching Ray, Fireball, Stinking Cloud, Fire Shield, Wall of Fire, Insect Plague, Hallow.'),
            _fg(6, 'Dark One\'s Own Luck',
                'Add 1d10 to an ability check or saving throw after rolling but before the result. Once per Short or Long Rest.',
                traits: [ref('trait', 'Dark One\'s Own Luck')]),
            _fg(10, 'Fiendish Resilience',
                'After a Short or Long Rest, choose a damage type (other than Force); gain Resistance to it until you choose a different one.',
                traits: [ref('trait', 'Fiendish Resilience')]),
            _f(14, 'Hurl Through Hell',
                'When you hit a creature with an attack, use a Reaction to vanish it through Hell: at the start of your next turn it returns to its previous space (or nearest unoccupied) and takes 8d10 Psychic damage. Once per Long Rest.'),
          ],
        },
      ),
      packEntity(
        slug: 'subclass',
        name: 'Evoker',
        description:
            'Wizards who focus on magic that creates powerful elemental effects.',
        attributes: {
          'parent_class_ref': ref('class', 'Wizard'),
          'granted_at_level': 3,
          'flavor_description':
              'Evokers find magic in raw destructive forces — fire, frost, lightning, thunder.',
          'features': [
            _f(3, 'Evocation Savant',
                'When you choose a wizard spell to add to your spellbook on level-up, you can add a 2nd Evocation spell of the same level for free.'),
            _fg(3, 'Sculpt Spells',
                'When you cast an Evocation spell affecting an area, choose a number of creatures equal to 1 + the spell\'s level — those creatures automatically succeed on saves and take no damage.',
                traits: [ref('trait', 'Sculpt Spells')]),
            _f(6, 'Potent Cantrip',
                'When a creature succeeds on a save against your cantrip, it still takes half damage but no other effect.'),
            _f(10, 'Empowered Evocation',
                'Add Int mod to one damage roll of any wizard Evocation spell you cast.'),
            _f(14, 'Overchannel',
                'Cast a level 1–5 wizard spell at maximum damage; suffer Necrotic damage if used again before a Long Rest.'),
          ],
        },
      ),
    ];
