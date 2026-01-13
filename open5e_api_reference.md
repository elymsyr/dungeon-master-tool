# Open5e API Reference

This document provides a reference for the Open5e API endpoints, generated from live API responses.

## Manifest

### Manifest List

**Description**

`list`: Returns a list of manifest.

**Request**

`GET /v1/manifest/`

**Response Headers**

```
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept
```

**Response Body**

```json
{
    "count": 0,
    "next": null,
    "previous": null,
    "results": []
}
```

---

## Spells

### Spells List

**Description**

`list`: Returns a list of spells.
`retrieve`: Returns a specific spell by slug.

**Request**

`GET /v1/spells/`

**Response Headers**

```
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept
```

**Response Body**

```json
{
    "count": 1435,
    "next": "https://api.open5e.com/v1/spells/?format=json&limit=1&page=2",
    "previous": null,
    "results": [
        {
            "slug": "abhorrent-apparition",
            "name": "Abhorrent Apparition",
            "desc": "You imbue a terrifying visage onto a gourd and toss it ahead of you to a spot of your choosing within range. Each creature within 15 feet of that spot takes 6d8 psychic damage and becomes frightened of you for 1 minute; a successful Wisdom saving throw halves the damage and negates the fright. A creature frightened in this way repeats the saving throw at the end of each of its turns, ending the effect on itself on a success.\n",
            "higher_level": "If you cast this spell using a spell slot of 5th level or higher, the damage increases by 1d8 for each slot level above 4th.",
            "page": "",
            "range": "60 feet",
            "target_range_sort": 60,
            "components": "M",
            "requires_verbal_components": false,
            "requires_somatic_components": false,
            "requires_material_components": true,
            "material": "a gourd with a face carved on it",
            "can_be_cast_as_ritual": false,
            "ritual": "no",
            "duration": "Instantaneous",
            "concentration": "no",
            "requires_concentration": false,
            "casting_time": "1 action",
            "level": "4th-level",
            "level_int": 4,
            "spell_level": 4,
            "school": "illusion",
            "dnd_class": "Bard, Sorcerer, Wizard",
            "spell_lists": [
                "bard",
                "sorcerer",
                "wizard"
            ],
            "archetype": "",
            "circles": "",
            "document__slug": "dmag",
            "document__title": "Deep Magic 5e",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "https://koboldpress.com/kpstore/product/deep-magic-for-5th-edition-hardcover/"
        }
    ]
}
```

---

## Spell List

### Spell List List

**Description**

`list`: Returns a list of spell list.
`retrieve`: Returns a specific spell list by slug.

**Request**

`GET /v1/spelllist/`

**Response Headers**

```
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept
```

**Response Body**

```json
{
    "count": 7,
    "next": "https://api.open5e.com/v1/spelllist/?format=json&limit=1&page=2",
    "previous": null,
    "results": [
        {
            "slug": "bard",
            "name": "bard",
            "desc": "",
            "spells": [
                "abhorrent-apparition",
                "accelerate",
                "adjust-position",
                "agonizing-mark",
                "ale-dritch-blast",
                "ally-aegis",
                "alter-arrows-fortune",
                "analyze-device",
                "anchoring-rope",
                "animal-friendship",
                "animal-messenger",
                "animate-objects",
                "anticipate-attack",
                "anticipate-weakness",
                "arcane-sword",
                "armored-heart",
                "ashen-memories",
                "auspicious-warning",
                "avoid-grievous-injury",
                "awaken",
                "bad-timing",
                "bane",
                "batsense",
                "beguiling-gift",
                "bestow-curse",
                "binding-oath",
                "black-goats-blessing",
                "bleating-call",
                "blindnessdeafness",
                "calm-emotions",
                "charm-person",
                "clairvoyance",
                "comprehend-languages",
                "compulsion",
                "confusion",
                "cure-wounds",
                "dancing-lights",
                "detect-magic",
                "detect-thoughts",
                "dimension-door",
                "disguise-self",
                "dispel-magic",
                "dominate-monster",
                "dominate-person",
                "door-of-the-far-traveler",
                "dream",
                "enhance-ability",
                "enthrall",
                "ethereal-stairs",
                "etherealness",
                "exchanged-knowledge",
                "extract-foyson",
                "eye-bite",
                "eyebite",
                "faerie-fire",
                "fear",
                "feather-fall",
                "feeblemind",
                "find-the-flaw",
                "find-the-path",
                "forcecage",
                "foresight",
                "freedom-of-movement",
                "geas",
                "gift-of-azathoth",
                "glibness",
                "glyph-of-warding",
                "greater-invisibility",
                "greater-restoration",
                "guards-and-wards",
                "hallucinatory-terrain",
                "healing-word",
                "heat-metal",
                "heroism",
                "hideous-laughter",
                "hold-monster",
                "hold-person",
                "hypnagogia",
                "hypnic-jerk",
                "hypnotic-pattern",
                "identify",
                "illusory-script",
                "invisibility",
                "irresistible-dance",
                "jotuns-jest",
                "knock",
                "legend-lore",
                "lesser-restoration",
                "light",
                "locate-animals-or-plants",
                "locate-creature",
                "locate-object",
                "lokis-gift",
                "longstrider",
                "machine-speech",
                "mage-hand",
                "magic-mouth",
                "magnificent-mansion",
                "major-image",
                "mass-cure-wounds",
                "mass-suggestion",
                "mending",
                "message",
                "mind-blank",
                "mind-maze",
                "minor-illusion",
                "mirage-arcane",
                "mirror-realm",
                "mislead",
                "modify-memory",
                "nondetection",
                "obfuscate-object",
                "overclock",
                "planar-binding",
                "plant-growth",
                "polymorph",
                "power-word-kill",
                "power-word-stun",
                "pratfall",
                "prestidigitation",
                "programmed-illusion",
                "project-image",
                "raise-dead",
                "read-memory",
                "regenerate",
                "resurrection",
                "scrying",
                "see-invisibility",
                "seeming",
                "sending",
                "shadows-brand",
                "shatter",
                "silence",
                "silent-image",
                "sleep",
                "soothsayers-shield",
                "soul-of-the-machine",
                "speak-with-animals",
                "speak-with-dead",
                "speak-with-plants",
                "stinking-cloud",
                "subliminal-aversion",
                "suggestion",
                "summon-old-ones-avatar",
                "symbol",
                "teleport",
                "teleportation-circle",
                "thunderwave",
                "timeless-engine",
                "tiny-hut",
                "tongues",
                "true-polymorph",
                "true-seeing",
                "true-strike",
                "unseen-servant",
                "vicious-mockery",
                "winding-key",
                "wotans-rede",
                "write-memory",
                "zone-of-truth"
            ],
            "document__slug": "o5e",
            "document__title": "Open5e Original Content",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "open5e.com"
        }
    ]
}
```

---

## Monsters

### Monsters List

**Description**

`list`: Returns a list of monsters.
`retrieve`: Returns a specific monster by slug.

**Request**

`GET /v1/monsters/`

**Response Headers**

```
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept
```

**Response Body**

```json
{
    "count": 3207,
    "next": "https://api.open5e.com/v1/monsters/?format=json&limit=1&page=2",
    "previous": null,
    "results": [
        {
            "slug": "a-mi-kuk",
            "desc": "Crimson slime covers this ungainly creature. Its tiny black eyes sit in an abnormally large head, and dozens of sharp teeth fill its small mouth. Its limbs end in large, grasping claws that look strong enough to crush the life out of a bear._  \n**Hidden Terror.** The dreaded a-mi-kuk is a terrifying creature that feasts on any who venture into the bleak and icy expanses of the world. A-mi-kuks prowl the edges of isolated communities, snatching those careless enough to wander too far from camp. They also submerge themselves beneath frozen waters, coming up from below to grab and strangle lone fishermen.  \n**Fear of Flames.** A-mi-kuks have a deathly fear of fire, and anyone using fire against one has a good chance of making it flee in terror, even if the fire-user would otherwise be outmatched. A-mi-kuks are not completely at the mercy of this fear, however, and lash out with incredible fury if cornered by someone using fire against them.  \n**Unknown Origins.** A-mi-kuks are not natural creatures and contribute little to the ecosystems in which they live. The monsters are never seen together, and some believe them to be a single monster, an evil spirit made flesh that appears whenever a group of humans has angered the gods. A-mi-kuks have no known allies and viciously attack any creatures that threaten them, regardless of the foe\u2019s size or power.",
            "name": "A-mi-kuk",
            "size": "Huge",
            "type": "Aberration",
            "subtype": "",
            "group": null,
            "alignment": "chaotic evil",
            "armor_class": 14,
            "armor_desc": "natural armor",
            "hit_points": 115,
            "hit_dice": "10d12+50",
            "speed": {
                "swim": 40,
                "burrow": 20,
                "walk": 30
            },
            "strength": 21,
            "dexterity": 8,
            "constitution": 20,
            "intelligence": 7,
            "wisdom": 14,
            "charisma": 10,
            "strength_save": null,
            "dexterity_save": null,
            "constitution_save": null,
            "intelligence_save": null,
            "wisdom_save": null,
            "charisma_save": null,
            "perception": 5,
            "skills": {
                "athletics": 10,
                "perception": 5,
                "stealth": 2
            },
            "damage_vulnerabilities": "",
            "damage_resistances": "acid; bludgeoning, piercing, and slashing from nonmagical attacks",
            "damage_immunities": "cold",
            "condition_immunities": "paralyzed, restrained",
            "senses": "darkvision 60 ft., tremorsense 30 ft., passive Perception 15",
            "languages": "understands Common but can\u2019t speak",
            "challenge_rating": "7",
            "cr": 7.0,
            "actions": [
                {
                    "name": "Multiattack",
                    "desc": "The a-mi-kuk makes two attacks: one with its bite and one with its grasping claw."
                },
                {
                    "name": "Bite",
                    "desc": "Melee Weapon Attack: +8 to hit, reach 5 ft., one target. Hit: 12 (2d6 + 5) piercing damage.",
                    "attack_bonus": 8,
                    "damage_dice": "2d6+5"
                },
                {
                    "name": "Grasping Claw",
                    "desc": "Melee Weapon Attack: +8 to hit, reach 10 ft., one target. Hit: 18 (3d8 + 5) bludgeoning damage, and the target is grappled (escape DC 16). The a-mi-kuk has two grasping claws, each of which can grapple only one target at a time.",
                    "attack_bonus": 8,
                    "damage_dice": "3d8+5"
                },
                {
                    "name": "Strangle",
                    "desc": "The a-mi-kuk strangles one creature grappled by it. The target must make a DC 16 Strength saving throw. On a failure, the target takes 27 (6d8) bludgeoning damage, can't breathe, speak, or cast spells, and begins suffocating. On a success, the target takes half the bludgeoning damage and is no longer grappled. Until this strangling grapple ends (escape DC 16), the target takes 13 (3d8) bludgeoning damage at the start of each of its turns. The a-mi-kuk can strangle up to two Medium or smaller targets or one Large target at a time."
                }
            ],
            "bonus_actions": null,
            "reactions": null,
            "legendary_desc": "",
            "legendary_actions": null,
            "special_abilities": [
                {
                    "name": "Hold Breath",
                    "desc": "The a-mi-kuk can hold its breath for 30 minutes."
                },
                {
                    "name": "Fear of Fire",
                    "desc": "The a-mi-kuk is afraid of fire, and it won't move toward any fiery or burning objects. If presented forcefully with a flame, or if it is dealt fire damage, the a-mi-kuk must succeed on a DC 13 Wisdom saving throw or become frightened until the end of its next turn. After it has been frightened by a specific source of fire (such as the burning hands spell), the a-mi-kuk can't be frightened by that same source again for 24 hours."
                },
                {
                    "name": "Icy Slime",
                    "desc": "The a-mi-kuk's body is covered in a layer of greasy, ice-cold slime that grants it the benefits of freedom of movement. In addition, a creature that touches the a-mi-kuk or hits it with a melee attack while within 5 feet of it takes 7 (2d6) cold damage from the freezing slime. A creature grappled by the a-mi-kuk takes this damage at the start of each of its turns."
                }
            ],
            "spell_list": [],
            "page_no": 15,
            "environments": [],
            "img_main": null,
            "document__slug": "tob2",
            "document__title": "Tome of Beasts 2",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "https://koboldpress.com/kpstore/product/tome-of-beasts-2-for-5th-edition/",
            "v2_converted_path": "/v2/creatures/tob2_a-mi-kuk/"
        }
    ]
}
```

---

## Documents

### Documents List

**Description**

`list`: Returns a list of documents.
`retrieve`: Returns a specific document by slug.

**Request**

`GET /v1/documents/`

**Response Headers**

```
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept
```

**Response Body**

```json
{
    "count": 17,
    "next": "https://api.open5e.com/v1/documents/?format=json&limit=1&page=2",
    "previous": null,
    "results": [
        {
            "title": "Open5e Original Content",
            "slug": "o5e",
            "url": "open5e.com",
            "license": "Open Gaming License",
            "desc": "Open5e Original Content",
            "author": "Ean Moody and Open Source Contributors from github.com/open5e-api",
            "organization": "Open5e",
            "version": "1.0",
            "copyright": "Open5e.com Copyright 2019.",
            "license_url": "http://open5e.com/legal",
            "v2_related_key": "open5e"
        }
    ]
}
```

---

## Backgrounds

### Backgrounds List

**Description**

`list`: Returns a list of backgrounds.
`retrieve`: Returns a specific background by slug.

**Request**

`GET /v1/backgrounds/`

**Response Headers**

```
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept
```

**Response Body**

```json
{
    "count": 42,
    "next": "https://api.open5e.com/v1/backgrounds/?format=json&limit=1&page=2",
    "previous": null,
    "results": [
        {
            "name": "Acolyte",
            "desc": "You have spent your life in the service of a temple to a specific god or pantheon of gods. You act as an intermediary between the realm of the holy and the mortal world, performing sacred rites and offering sacrifices in order to conduct worshipers into the presence of the divine. You are not necessarily a cleric-performing sacred rites is not the same thing as channeling divine power.\n\nChoose a god, a pantheon of gods, or some other quasi-divine being from among those listed in \"Fantasy-Historical Pantheons\" or those specified by your GM, and work with your GM to detail the nature of your religious service. Were you a lesser functionary in a temple, raised from childhood to assist the priests in the sacred rites? Or were you a high priest who suddenly experienced a call to serve your god in a different way? Perhaps you were the leader of a small cult outside of any established temple structure, or even an occult group that served a fiendish master that you now deny.",
            "slug": "acolyte",
            "skill_proficiencies": "Insight, Religion",
            "tool_proficiencies": null,
            "languages": "Two of your choice",
            "equipment": "A holy symbol (a gift to you when you entered the priesthood), a prayer book or prayer wheel, 5 sticks of incense, vestments, a set of common clothes, and a pouch containing 15 gp",
            "feature": "Shelter of the Faithful",
            "feature_desc": "As an acolyte, you command the respect of those who share your faith, and you can perform the religious ceremonies of your deity. You and your adventuring companions can expect to receive free healing and care at a temple, shrine, or other established presence of your faith, though you must provide any material components needed for spells. Those who share your religion will support you (but only you) at a modest lifestyle.\n\nYou might also have ties to a specific temple dedicated to your chosen deity or pantheon, and you have a residence there. This could be the temple where you used to serve, if you remain on good terms with it, or a temple where you have found a new home. While near your temple, you can call upon the priests for assistance, provided the assistance you ask for is not hazardous and you remain in good standing with your temple.",
            "suggested_characteristics": "Acolytes are shaped by their experience in temples or other religious communities. Their study of the history and tenets of their faith and their relationships to temples, shrines, or hierarchies affect their mannerisms and ideals. Their flaws might be some hidden hypocrisy or heretical idea, or an ideal or bond taken to an extreme.\n\n**Suggested Acolyte Characteristics (table)**\n\n| d8 | Personality Trait                                                                                                  |\n|----|--------------------------------------------------------------------------------------------------------------------|\n| 1  | I idolize a particular hero of my faith, and constantly refer to that person's deeds and example.                  |\n| 2  | I can find common ground between the fiercest enemies, empathizing with them and always working toward peace.      |\n| 3  | I see omens in every event and action. The gods try to speak to us, we just need to listen                         |\n| 4  | Nothing can shake my optimistic attitude.                                                                          |\n| 5  | I quote (or misquote) sacred texts and proverbs in almost every situation.                                         |\n| 6  | I am tolerant (or intolerant) of other faiths and respect (or condemn) the worship of other gods.                  |\n| 7  | I've enjoyed fine food, drink, and high society among my temple's elite. Rough living grates on me.                |\n| 8  | I've spent so long in the temple that I have little practical experience dealing with people in the outside world. |\n\n| d6 | Ideal                                                                                                                  |\n|----|------------------------------------------------------------------------------------------------------------------------|\n| 1  | Tradition. The ancient traditions of worship and sacrifice must be preserved and upheld. (Lawful)                      |\n| 2  | Charity. I always try to help those in need, no matter what the personal cost. (Good)                                  |\n| 3  | Change. We must help bring about the changes the gods are constantly working in the world. (Chaotic)                   |\n| 4  | Power. I hope to one day rise to the top of my faith's religious hierarchy. (Lawful)                                   |\n| 5  | Faith. I trust that my deity will guide my actions. I have faith that if I work hard, things will go well. (Lawful)    |\n| 6  | Aspiration. I seek to prove myself worthy of my god's favor by matching my actions against his or her teachings. (Any) |\n\n| d6 | Bond                                                                                     |\n|----|------------------------------------------------------------------------------------------|\n| 1  | I would die to recover an ancient relic of my faith that was lost long ago.              |\n| 2  | I will someday get revenge on the corrupt temple hierarchy who branded me a heretic.     |\n| 3  | I owe my life to the priest who took me in when my parents died.                         |\n| 4  | Everything I do is for the common people.                                                |\n| 5  | I will do anything to protect the temple where I served.                                 |\n| 6  | I seek to preserve a sacred text that my enemies consider heretical and seek to destroy. |\n\n| d6 | Flaw                                                                                          |\n|----|-----------------------------------------------------------------------------------------------|\n| 1  | I judge others harshly, and myself even more severely.                                        |\n| 2  | I put too much trust in those who wield power within my temple's hierarchy.                   |\n| 3  | My piety sometimes leads me to blindly trust those that profess faith in my god.              |\n| 4  | I am inflexible in my thinking.                                                               |\n| 5  | I am suspicious of strangers and expect the worst of them.                                    |\n| 6  | Once I pick a goal, I become obsessed with it to the detriment of everything else in my life. |",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd"
        }
    ]
}
```

---

## Planes

### Planes List

**Description**

`list`: Returns a list of planes.
`retrieve`: Returns a specific plane by slug.

**Request**

`GET /v1/planes/`

**Response Headers**

```
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept
```

**Response Body**

```json
{
    "count": 8,
    "next": "https://api.open5e.com/v1/planes/?format=json&limit=1&page=2",
    "previous": null,
    "results": [
        {
            "slug": "astral-plane",
            "name": "Astral Plane",
            "desc": "The **Astral Plane** is the realm of thought and dream, where visitors travel as disembodied souls to reach the planes of the divine and demonic. It is a great, silvery sea, the same above and below, with swirling wisps of white and gray streaking among motes of light resembling distant stars. Erratic whirlpools of color flicker in midair like spinning coins. Occasional bits of solid matter can be found here, but most of the Astral Plane is an endless, open domain.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Transitive Planes"
        }
    ]
}
```

---

## Sections

### Sections List

**Description**

`list`: Returns a list of sections.
`retrieve`: Returns a specific section by slug.

**Request**

`GET /v1/sections/`

**Response Headers**

```
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept
```

**Response Body**

```json
{
    "count": 45,
    "next": "https://api.open5e.com/v1/sections/?format=json&limit=1&page=2",
    "previous": null,
    "results": [
        {
            "slug": "abilities",
            "name": "Abilities",
            "desc": "Six abilities provide a quick description of every creature's physical and mental characteristics:\n\n- **Strength**, measuring physical power\n - **Dexterity**, measuring agility\n - **Constitution**, measuring endurance \n - **Intelligence**, measuring reasoning and memory \n - **Wisdom**, measuring perception and insight \n - **Charisma**, measuring force of personality\n\n\nIs a character muscle-bound and insightful? Brilliant and charming? Nimble and hardy? Ability scores define these qualities---a creature's assets as well as weaknesses.\n\nThe three main rolls of the game---the ability check, the saving throw, and the attack roll---rely on the six ability scores. The book's introduction describes the basic rule behind these rolls: roll a d20, add an ability modifier derived from one of the six ability scores, and compare the total to a target number\n\n## Ability Scores and Modifiers\n\n Each of a creature's abilities has a score, a number that defines the magnitude of that ability. An ability score is not just a measure of innate capabilities, but also encompasses a creature's training and competence in activities related to that ability.\n\nA score of 10 or 11 is the normal human average, but adventurers and many monsters are a cut above average in most abilities. A score of 18 is the highest that a person usually reaches. Adventurers can have scores as high as 20, and monsters and divine beings can have scores as high as 30.\n\nEach ability also has a modifier, derived from the score and ranging from -5 (for an ability score of 1) to +10 (for a score of 30). The Ability Scores and Modifiers table notes the ability modifiers for the range of possible ability scores, from 1 to 30.\n\n  To determine an ability modifier without consulting the table, subtract 10 from the ability score and then divide the total by 2 (round down).\n\n Because ability modifiers affect almost every attack roll, ability check, and saving throw, ability modifiers come up in play more often than their associated scores.\n\n## Advantage and Disadvantage\n\nSometimes a special ability or spell tells you that you have advantage or disadvantage on an ability check, a saving throw, or an attack roll.\nWhen that happens, you roll a second d20 when you make the roll. Use the higher of the two rolls if you have advantage, and use the lower roll if you have disadvantage. For example, if you have disadvantage and roll a 17 and a 5, you use the 5. If you instead have advantage and roll those numbers, you use the 17.\n\nIf multiple situations affect a roll and each one grants advantage or imposes disadvantage on it, you don't roll more than one additional d20.\nIf two favorable situations grant advantage, for example, you still roll only one additional d20.\n\nIf circumstances cause a roll to have both advantage and disadvantage, you are considered to have neither of them, and you roll one d20. This is true even if multiple circumstances impose disadvantage and only one grants advantage or vice versa. In such a situation, you have neither advantage nor disadvantage.\n\nWhen you have advantage or disadvantage and something in the game, such as the halfling's Lucky trait, lets you reroll the d20, you can reroll only one of the dice. You choose which one. For example, if a halfling has advantage or disadvantage on an ability check and rolls a 1 and a 13, the halfling could use the Lucky trait to reroll the 1.\n\nYou usually gain advantage or disadvantage through the use of special abilities, actions, or spells. Inspiration can also give a character advantage. The GM can also decide that circumstances influence a roll in one direction or the other and grant advantage or impose disadvantage as a result.\n\n## Proficiency Bonus  \nCharacters have a proficiency bonus determined by level. Monsters also have this bonus, which is incorporated in their stat blocks. The bonus is used in the rules on ability checks, saving throws, and attack rolls.\n\nYour proficiency bonus can't be added to a single die roll or other number more than once. For example, if two different rules say you can add your proficiency bonus to a Wisdom saving throw, you nevertheless add the bonus only once when you make the save.\n\nOccasionally, your proficiency bonus might be multiplied or divided (doubled or halved, for example) before you apply it. For example, the rogue's Expertise feature doubles the proficiency bonus for certain ability checks. If a circumstance suggests that your proficiency bonus applies more than once to the same roll, you still add it only once and multiply or divide it only once.\n\nBy the same token, if a feature or effect allows you to multiply your proficiency bonus when making an ability check that wouldn't normally benefit from your proficiency bonus, you still don't add the bonus to the check. For that check your proficiency bonus is 0, given the fact that multiplying 0 by any number is still 0. For instance, if you lack proficiency in the History skill, you gain no benefit from a feature that lets you double your proficiency bonus when you make Intelligence (History) checks.\n\nIn general, you don't multiply your proficiency bonus for attack rolls or saving throws. If a feature or effect allows you to do so, these same rules apply.\n\n## Ability Checks  \nAn ability check tests a character's or monster's innate talent and training in an effort to overcome a challenge. The GM calls for an ability check when a character or monster attempts an action (other than an attack) that has a chance of failure. When the outcome is uncertain, the dice determine the results.\n\nFor every ability check, the GM decides which of the six abilities is relevant to the task at hand and the difficulty of the task, represented by a Difficulty Class.\n\nThe more difficult a task, the higher its DC. The Typical Difficulty Classes table shows the most common DCs.\n\nTo make an ability check, roll a d20 and add the relevant ability modifier. As with other d20 rolls, apply bonuses and penalties, and compare the total to the DC. If the total equals or exceeds the DC, the ability check is a success---the creature overcomes the challenge at hand. Otherwise, it's a failure, which means the character or monster makes no progress toward the objective or makes progress combined with a setback determined by the GM.\n\n### Contests  \nSometimes one character's or monster's efforts are directly opposed to another's. This can occur when both of them are trying to do the same thing and only one can succeed, such as attempting to snatch up a magic ring that has fallen on the floor. This situation also applies when one of them is trying to prevent the other one from accomplishing a goal---for example, when a monster tries to force open a door that an adventurer is holding closed. In situations like these, the outcome is determined by a special form of ability check, called a contest.\n\nBoth participants in a contest make ability checks appropriate to their efforts. They apply all appropriate bonuses and penalties, but instead of comparing the total to a DC, they compare the totals of their two checks. The participant with the higher check total wins the contest.\nThat character or monster either succeeds at the action or prevents the other one from succeeding.\n\nIf the contest results in a tie, the situation remains the same as it was before the contest. Thus, one contestant might win the contest by default. If two characters tie in a contest to snatch a ring off the floor, neither character grabs it. In a contest between a monster trying to open a door and an adventurer trying to keep the door closed, a tie means that the door remains shut.\n\n### Skills\n\n Each ability covers a broad range of capabilities, including skills that a character or a monster can be proficient in. A skill represents a specific aspect of an ability score, and an individual's proficiency in a skill demonstrates a focus on that aspect. (A character's starting skill proficiencies are determined at character creation, and a monster's skill proficiencies appear in the monster's stat block.)  For example, a Dexterity check might reflect a character's attempt to pull off an acrobatic stunt, to palm an object, or to stay hidden. Each of these aspects of Dexterity has an associated skill: Acrobatics, Sleight of Hand, and Stealth, respectively. So a character who has proficiency in the Stealth skill is particularly good at Dexterity checks related to sneaking and hiding.\n\nThe skills related to each ability score are shown in the following list. (No skills are related to Constitution.) See an ability's description in the later sections of this section for examples of how to use a skill associated with an ability.\n\n**Strength**\n\n- Athletics\n\n**Dexterity**\n- Acrobatics\n- Sleight of Hand\n- Stealth\n\n**Intelligence**\n\n- Arcana\n- History\n- Investigation\n- Nature\n- Religion\n\n**Wisdom**\n\n- Animal Handling\n- Insight\n- Medicine\n- Perception\n- Survival\n\n**Charisma**\n\n- Deception\n- Intimidation\n- Performance\n- Persuasion\n\n\nSometimes, the GM might ask for an ability check using a specific skill---for example, Make a Wisdom (Perception) check. At other times, a player might ask the GM if proficiency in a particular skill applies to a check. In either case, proficiency in a skill means an individual can add his or her proficiency bonus to ability checks that involve that skill. Without proficiency in the skill, the individual makes a normal ability check.\n\nFor example, if a character attempts to climb up a dangerous cliff, the GM might ask for a Strength (Athletics) check. If the character is proficient in Athletics, the character's proficiency bonus is added to the Strength check. If the character lacks that proficiency, he or she just makes a Strength check.\n\n#### Variant: Skills with Different Abilities  \nNormally, your proficiency in a skill applies only to a specific kind of ability check. Proficiency in Athletics, for example, usually applies to Strength checks. In some situations, though, your proficiency might reasonably apply to a different kind of check. In such cases, the GM might ask for a check using an unusual combination of ability and skill, or you might ask your GM if you can apply a proficiency to a different check. For example, if you have to swim from an offshore island to the mainland, your GM might call for a Constitution check to see if you have the stamina to make it that far. In this case, your GM might allow you to apply your proficiency in Athletics and ask for a Constitution (Athletics) check. So if you're proficient in Athletics, you apply your proficiency bonus to the Constitution check just as you would normally do for a Strength (Athletics) check. Similarly, when your half-orc barbarian uses a display of raw strength to intimidate an enemy, your GM might ask for a Strength (Intimidation) check, even though Intimidation is normally associated with Charisma.\n\n### Passive Checks  \nA passive check is a special kind of ability check that doesn't involve any die rolls. Such a check can represent the average result for a task done repeatedly, such as searching for secret doors over and over again, or can be used when the GM wants to secretly determine whether the characters succeed at something without rolling dice, such as noticing a hidden monster.\n\nHere's how to determine a character's total for a passive check:  > 10 + all modifiers that normally apply to the check  If the character has advantage on the check, add 5. For disadvantage, subtract 5. The game refers to a passive check total as a **score**.\n\nFor example, if a 1st-level character has a Wisdom of 15 and proficiency in Perception, he or she has a passive Wisdom (Perception) score of 14.\n\nThe rules on hiding in the Dexterity section below rely on passive checks, as do the exploration rules.\n\n### Working Together  \nSometimes two or more characters team up to attempt a task. The character who's leading the effort---or the one with the highest ability modifier---can make an ability check with advantage, reflecting the help provided by the other characters. In combat, this requires the Help action.\n\nA character can only provide help if the task is one that he or she could attempt alone. For example, trying to open a lock requires proficiency with thieves' tools, so a character who lacks that proficiency can't help another character in that task. Moreover, a character can help only when two or more individuals working together would actually be productive. Some tasks, such as threading a needle, are no easier with help.\n\n#### Group Checks  \nWhen a number of individuals are trying to accomplish something as a group, the GM might ask for a group ability check. In such a situation, the characters who are skilled at a particular task help cover those who aren't.\n\nTo make a group ability check, everyone in the group makes the ability check. If at least half the group succeeds, the whole group succeeds.\nOtherwise, the group fails.\n\nGroup checks don't come up very often, and they're most useful when all the characters succeed or fail as a group. For example, when adventurers are navigating a swamp, the GM might call for a group Wisdom (Survival) check to see if the characters can avoid the quicksand, sinkholes, and other natural hazards of the environment. If at least half the group succeeds, the successful characters are able to guide their companions out of danger. Otherwise, the group stumbles into one of these hazards.\n\nEvery task that a character or monster might attempt in the game is covered by one of the six abilities. This section explains in more detail what those abilities mean and the ways they are used in the game.\n\n### Strength  \nStrength measures bodily power, athletic training, and the extent to which you can exert raw physical force.\n\n#### Strength Checks  \nA Strength check can model any attempt to lift, push, pull, or break something, to force your body through a space, or to otherwise apply brute force to a situation. The Athletics skill reflects aptitude in certain kinds of Strength checks.\n\n##### Athletics  \nYour Strength (Athletics) check covers difficult situations you encounter while climbing, jumping, or swimming. Examples include the following activities:  - You attempt to climb a sheer or slippery cliff, avoid hazards while   scaling a wall, or cling to a surface while something is trying to   knock you off.\n- You try to jump an unusually long distance or pull off a stunt   midjump.\n- You struggle to swim or stay afloat in treacherous currents,   storm-tossed waves, or areas of thick seaweed. Or another creature   tries to push or pull you underwater or otherwise interfere with   your swimming.\n\n##### Other Strength Checks  \nThe GM might also call for a Strength check when you try to accomplish tasks like the following:  - Force open a stuck, locked, or barred door - Break free of bonds - Push through a tunnel that is too small - Hang on to a wagon while being dragged behind it - Tip over a statue - Keep a boulder from rolling\n\n\n#### Attack Rolls and Damage\n\nYou add your Strength modifier to your attack roll and your damage roll when attacking with a melee weapon such as a mace, a battleaxe, or a javelin. You use melee weapons to make melee attacks in hand-to-hand combat, and some of them can be thrown to make a ranged attack.\n\n#### Lifting and Carrying  \nYour Strength score determines the amount of weight you can bear. The following terms define what you can lift or carry.\n\n**Carrying Capacity.** Your carrying capacity is your Strength score multiplied by 15. This is the weight (in pounds) that you can carry, which is high enough that most characters don't usually have to worry about it.\n\n**Push, Drag, or Lift.** You can push, drag, or lift a weight in pounds up to twice your carrying capacity (or 30 times your Strength score).\nWhile pushing or dragging weight in excess of your carrying capacity, your speed drops to 5 feet.\n\n**Size and Strength.** Larger creatures can bear more weight, whereas Tiny creatures can carry less. For each size category above Medium, double the creature's carrying capacity and the amount it can push, drag, or lift. For a Tiny creature, halve these weights.\n\n#### Variant: Encumbrance  \nThe rules for lifting and carrying are intentionally simple. Here is a variant if you are looking for more detailed rules for determining how a character is hindered by the weight of equipment. When you use this variant, ignore the Strength column of the Armor table.\n\nIf you carry weight in excess of 5 times your Strength score, you are **encumbered**, which means your speed drops by 10 feet.\n\nIf you carry weight in excess of 10 times your Strength score, up to your maximum carrying capacity, you are instead **heavily encumbered**, which means your speed drops by 20 feet and you have disadvantage on ability checks, attack rolls, and saving throws that use Strength, Dexterity, or Constitution.\n\n### Dexterity \nDexterity measures agility, reflexes, and balance.\n\n#### Dexterity Checks\n\nA Dexterity check can model any attempt to move nimbly, quickly, or quietly, or to keep from falling on tricky footing. The Acrobatics, Sleight of Hand, and Stealth skills reflect aptitude in certain kinds of Dexterity checks.\n\n##### Acrobatics  \nYour Dexterity (Acrobatics) check covers your attempt to stay on your feet in a tricky situation, such as when you're trying to run across a sheet of ice, balance on a tightrope, or stay upright on a rocking ship's deck. The GM might also call for a Dexterity (Acrobatics) check to see if you can perform acrobatic stunts, including dives, rolls, somersaults, and flips.\n\n##### Sleight of Hand  \nWhenever you attempt an act of legerdemain or manual trickery, such as planting something on someone else or concealing an object on your person, make a Dexterity (Sleight of Hand) check. The GM might also call for a Dexterity (Sleight of Hand) check to determine whether you can lift a coin purse off another person or slip something out of another person's pocket.\n\n##### Stealth  \nMake a Dexterity (Stealth) check when you attempt to conceal yourself from enemies, slink past guards, slip away without being noticed, or sneak up on someone without being seen or heard.\n\n##### Other Dexterity Checks  \nThe GM might call for a Dexterity check when you try to accomplish tasks like the following:  - Control a heavily laden cart on a steep descent - Steer a chariot around a tight turn - Pick a lock - Disable a trap - Securely tie up a prisoner - Wriggle free of bonds - Play a stringed instrument - Craft a small or detailed object  **Hiding**  The GM decides when circumstances are appropriate for hiding. When you try to hide, make a Dexterity (Stealth) check. Until you are discovered or you stop hiding, that check's total is contested by the Wisdom (Perception) check of any creature that actively searches for signs of your presence.\n\nYou can't hide from a creature that can see you clearly, and you give away your position if you make noise, such as shouting a warning or knocking over a vase.\n\nAn invisible creature can always try to hide. Signs of its passage might still be noticed, and it does have to stay quiet.\n\nIn combat, most creatures stay alert for signs of danger all around, so if you come out of hiding and approach a creature, it usually sees you.\nHowever, under certain circumstances, the GM might allow you to stay hidden as you approach a creature that is distracted, allowing you to gain advantage on an attack roll before you are seen.\n\n**Passive Perception.** When you hide, there's a chance someone will notice you even if they aren't searching. To determine whether such a creature notices you, the GM compares your Dexterity (Stealth) check with that creature's passive Wisdom (Perception) score, which equals 10  - the creature's Wisdom modifier, as well as any other bonuses or   penalties. If the creature has advantage, add 5. For disadvantage,   subtract 5. For example, if a 1st-level character (with a proficiency   bonus of +2) has a Wisdom of 15 (a +2 modifier) and proficiency in   Perception, he or she has a passive Wisdom (Perception) of 14.\n\n**What Can You See?** One of the main factors in determining whether you can find a hidden creature or object is how well you can see in an area, which might be **lightly** or **heavily obscured**, as explained in the-environment.\n\n#### Attack Rolls and Damage\n\nYou add your Dexterity modifier to your attack roll and your damage roll when attacking with a ranged weapon, such as a sling or a longbow. You can also add your Dexterity modifier to your attack roll and your damage roll when attacking with a melee weapon that has the finesse property, such as a dagger or a rapier.\n\n#### Armor Class  \nDepending on the armor you wear, you might add some or all of your Dexterity modifier to your Armor Class.\n\n#### Initiative  \nAt the beginning of every combat, you roll initiative by making a Dexterity check. Initiative determines the order of creatures' turns in combat.\n\n### Constitution  \nConstitution measures health, stamina, and vital force.\n\n#### Constitution Checks  \nConstitution checks are uncommon, and no skills apply to Constitution checks, because the endurance this ability represents is largely passive rather than involving a specific effort on the part of a character or monster. A Constitution check can model your attempt to push beyond normal limits, however.\n\nThe GM might call for a Constitution check when you try to accomplish tasks like the following:  - Hold your breath - March or labor for hours without rest - Go without sleep - Survive without food or water - Quaff an entire stein of ale in one go  #### Hit Points  \nYour Constitution modifier contributes to your hit points. Typically, you add your Constitution modifier to each Hit Die you roll for your hit points.\n\nIf your Constitution modifier changes, your hit point maximum changes as well, as though you had the new modifier from 1st level. For example, if you raise your Constitution score when you reach 4th level and your Constitution modifier increases from +1 to +2, you adjust your hit point maximum as though the modifier had always been +2. So you add 3 hit points for your first three levels, and then roll your hit points for 4th level using your new modifier. Or if you're 7th level and some effect lowers your Constitution score so as to reduce your Constitution modifier by 1, your hit point maximum is reduced by 7.\n\n### Intelligence\n\nIntelligence measures mental acuity, accuracy of recall, and the ability to reason.\n\n#### Intelligence Checks  \nAn Intelligence check comes into play when you need to draw on logic, education, memory, or deductive reasoning. The Arcana, History, Investigation, Nature, and Religion skills reflect aptitude in certain kinds of Intelligence checks.\n\n##### Arcana  \nYour Intelligence (Arcana) check measures your ability to recall lore about spells, magic items, eldritch symbols, magical traditions, the planes of existence, and the inhabitants of those planes.\n\n##### History  \nYour Intelligence (History) check measures your ability to recall lore about historical events, legendary people, ancient kingdoms, past disputes, recent wars, and lost civilizations.\n\n##### Investigation\n\nWhen you look around for clues and make deductions based on those clues, you make an Intelligence (Investigation) check. You might deduce the location of a hidden object, discern from the appearance of a wound what kind of weapon dealt it, or determine the weakest point in a tunnel that could cause it to collapse. Poring through ancient scrolls in search of a hidden fragment of knowledge might also call for an Intelligence (Investigation) check.\n\n##### Nature  \nYour Intelligence (Nature) check measures your ability to recall lore about terrain, plants and animals, the weather, and natural cycles.\n\n##### Religion\n\nYour Intelligence (Religion) check  measures your ability to recall lore about deities, rites and prayers, religious hierarchies, holy symbols, and the practices of secret cults.\n\n##### Other Intelligence Checks  \nThe GM might call for an Intelligence check when you try to accomplish tasks like the following:  - Communicate with a creature without using words - Estimate the value of a precious item - Pull together a disguise to pass as a city guard - Forge a document - Recall lore about a craft or trade - Win a game of skill\n\n#### Spellcasting Ability  \nWizards use Intelligence as their spellcasting ability, which helps determine the saving throw DCs of spells they cast.\n\n### Wisdom  \nWisdom reflects how attuned you are to the world around you and represents perceptiveness and intuition.\n\n#### Wisdom Checks  \nA Wisdom check might reflect an effort to read body language, understand someone's feelings, notice things about the environment, or care for an injured person. The Animal Handling, Insight, Medicine, Perception, and Survival skills reflect aptitude in certain kinds of Wisdom checks.\n\n##### Animal Handling  \nWhen there is any question whether you can calm down a domesticated animal, keep a mount from getting spooked, or intuit an animal's intentions, the GM might call for a Wisdom (Animal Handling) check. You also make a Wisdom (Animal Handling) check to control your mount when you attempt a risky maneuver.\n\n##### Insight  \nYour Wisdom (Insight) check decides whether you can determine the true intentions of a creature, such as when searching out a lie or predicting someone's next move. Doing so involves gleaning clues from body language, speech habits, and changes in mannerisms.\n\n##### Medicine  \nA Wisdom (Medicine) check lets you try to stabilize a dying companion or diagnose an illness.\n\n##### Perception  \nYour Wisdom (Perception) check lets you spot, hear, or otherwise detect the presence of something. It measures your general awareness of your surroundings and the keenness of your senses. For example, you might try to hear a conversation through a closed door, eavesdrop under an open window, or hear monsters moving stealthily in the forest. Or you might try to spot things that are obscured or easy to miss, whether they are orcs lying in ambush on a road, thugs hiding in the shadows of an alley, or candlelight under a closed secret door.\n\n##### Survival  \nThe GM might ask you to make a Wisdom (Survival) check to follow tracks, hunt wild game, guide your group through frozen wastelands, identify signs that owlbears live nearby, predict the weather, or avoid quicksand and other natural hazards.\n\n##### Other Wisdom Checks  \nThe GM might call for a Wisdom check when you try to accomplish tasks like the following:  - Get a gut feeling about what course of action to follow - Discern whether a seemingly dead or living creature is undead  #### Spellcasting Ability  \nClerics, druids, and rangers use Wisdom as their spellcasting ability, which helps determine the saving throw DCs of spells they cast.\n\n### Charisma\n\nCharisma measures your ability to interact effectively with others. It includes such factors as confidence and eloquence, and it can represent a charming or commanding personality.\n\n#### Charisma Checks\n\nA Charisma check might arise when you try to influence or entertain others, when you try to make an impression or tell a convincing lie, or when you are navigating a tricky social situation. The Deception, Intimidation, Performance, and Persuasion skills reflect aptitude in certain kinds of Charisma checks.\n\n##### Deception\n\nYour Charisma (Deception) check determines whether you can convincingly hide the truth, either verbally or through your actions. This deception can encompass everything from misleading others through ambiguity to telling outright lies. Typical situations include trying to fast-talk a guard, con a merchant, earn money through gambling, pass yourself off in a disguise, dull someone's suspicions with false assurances, or maintain a straight face while telling a blatant lie.\n\n##### Intimidation  \nWhen you attempt to influence someone through overt threats, hostile actions, and physical violence, the GM might ask you to make a Charisma (Intimidation) check. Examples include trying to pry information out of a prisoner, convincing street thugs to back down from a confrontation, or using the edge of a broken bottle to convince a sneering vizier to reconsider a decision.\n\n##### Performance  \nYour Charisma (Performance) check determines how well you can delight an audience with music, dance, acting, storytelling, or some other form of entertainment.\n\n##### Persuasion  \nWhen you attempt to influence someone or a group of people with tact, social graces, or good nature, the GM might ask you to make a Charisma (Persuasion) check. Typically, you use persuasion when acting in good faith, to foster friendships, make cordial requests, or exhibit proper etiquette. Examples of persuading others include convincing a chamberlain to let your party see the king, negotiating peace between warring tribes, or inspiring a crowd of townsfolk\n\n##### Other Charisma Checks\n\nThe GM might call for a Charisma check when you try to accomplish tasks like the following:\n\n- Find the best person to talk to for news, rumors, and gossip\n- Blend into a crowd to get the sense of key topics of conversation\n\n\n#### Spellcasting Ability\n\nBards, paladins, sorcerers, and warlocks use Charisma as their spellcasting ability, which helps determine the saving throw DCs of spells they cast.",
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd",
            "parent": "Gameplay Mechanics"
        }
    ]
}
```

---

## Feats

### Feats List

**Description**

`list`: Returns a list of feats.
`retrieve`: Returns a specific feat by slug.

**Request**

`GET /v1/feats/`

**Response Headers**

```
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept
```

**Response Body**

```json
{
    "count": 91,
    "next": "https://api.open5e.com/v2/feats/?format=json&limit=1&page=2",
    "previous": null,
    "results": [
        {
            "url": "https://api.open5e.com/v2/feats/a5e-ag_ace-driver/?format=json",
            "key": "a5e-ag_ace-driver",
            "has_prerequisite": true,
            "benefits": [
                {
                    "desc": "You gain an expertise die on ability checks made to drive or pilot a vehicle."
                },
                {
                    "desc": "While piloting a vehicle, you can use your reaction to take the Brake or Maneuver vehicle actions."
                },
                {
                    "desc": "A vehicle you load can carry 25% more cargo than normal."
                },
                {
                    "desc": "Vehicles you are piloting only suffer a malfunction when reduced to 25% of their hit points, not 50%. In addition, when the vehicle does suffer a malfunction, you roll twice on the maneuver table and choose which die to use for the result."
                },
                {
                    "desc": "Vehicles you are piloting gain a bonus to their Armor Class equal to half your proficiency bonus."
                },
                {
                    "desc": "When you Brake, you can choose to immediately stop the vehicle without traveling half of its movement speed directly forward."
                }
            ],
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/?format=json"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/?format=json"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "name": "Ace Driver",
            "desc": "You are a virtuoso of driving and piloting vehicles, able to push them beyond their normal limits and maneuver them with fluid grace through hazardous situations. You gain the following benefits:",
            "prerequisite": "Proficiency with a type of vehicle",
            "type": "GENERAL"
        }
    ]
}
```

---

## Conditions

### Conditions List

**Description**

`list`: Returns a list of conditions.
`retrieve`: Returns a specific condition by slug.

**Request**

`GET /v1/conditions/`

**Response Headers**

```
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept
```

**Response Body**

```json
{
    "count": 21,
    "next": "https://api.open5e.com/v2/conditions/?format=json&limit=1&page=2",
    "previous": null,
    "results": [
        {
            "url": "https://api.open5e.com/v2/conditions/a5e-ag_bloodied/?format=json",
            "key": "a5e-ag_bloodied",
            "document": {
                "name": "Adventurer's Guide",
                "key": "a5e-ag",
                "type": "SOURCE",
                "display_name": "Adventurer's Guide",
                "publisher": {
                    "name": "EN Publishing",
                    "key": "en-publishing",
                    "url": "https://api.open5e.com/v2/publishers/en-publishing/?format=json"
                },
                "gamesystem": {
                    "name": "Advanced 5th Edition",
                    "key": "a5e",
                    "url": "https://api.open5e.com/v2/gamesystems/a5e/?format=json"
                },
                "permalink": "https://a5esrd.com/a5esrd"
            },
            "icon": null,
            "descriptions": [
                {
                    "desc": "* A creature is bloodied when reduced to half its hit points or less.",
                    "document": "a5e-ag",
                    "gamesystem": "a5e"
                }
            ],
            "name": "Bloodied"
        }
    ]
}
```

---

## Races

### Races List

**Description**

`list`: Returns a list of races.
`retrieve`: Returns a specific race by slug.

**Request**

`GET /v1/races/`

**Response Headers**

```
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept
```

**Response Body**

```json
{
    "count": 20,
    "next": "https://api.open5e.com/v1/races/?format=json&limit=1&page=2",
    "previous": null,
    "results": [
        {
            "name": "Alseid",
            "slug": "alseid",
            "desc": "## Alseid Traits\nYour alseid character has certain characteristics in common with all other alseid.",
            "asi_desc": "***Ability Score Increase.*** Your Dexterity score increases by 2, and your Wisdom score increases by 1.",
            "asi": [
                {
                    "attributes": [
                        "Dexterity"
                    ],
                    "value": 2
                },
                {
                    "attributes": [
                        "Wisdom"
                    ],
                    "value": 1
                }
            ],
            "age": "***Age.*** Alseid reach maturity by the age of 20. They can live well beyond 100 years, but it is unknown just how old they can become.",
            "alignment": "***Alignment.*** Alseid are generally chaotic, flowing with the unpredictable whims of nature, though variations are common, particularly among those rare few who leave their people.",
            "size": "***Size.*** Alseid stand over 6 feet tall and weigh around 300 pounds. Your size is Medium.",
            "size_raw": "Medium",
            "speed": {
                "walk": 40
            },
            "speed_desc": "***Speed.*** Alseid are fast for their size, with a base walking speed of 40 feet.",
            "languages": "***Languages.*** You can speak, read, and write Common and Elvish.",
            "vision": "***Darkvision.*** Accustomed to the limited light beneath the forest canopy, you have superior vision in dark and dim conditions. You can see in dim light within 60 feet of you as if it were bright light, and in darkness as if it were dim light. You can't discern color in darkness, only shades of gray.",
            "traits": "***Alseid Weapon Training.*** You have proficiency with spears and shortbows.\n\n***Light Hooves.*** You have proficiency in the Stealth skill.\n\n***Quadruped.*** The mundane details of the structures of humanoids can present considerable obstacles for you. You have to squeeze when moving through trapdoors, manholes, and similar structures even when a Medium humanoid wouldn't have to squeeze. In addition, ladders, stairs, and similar structures are difficult terrain for you.\n\n***Woodfriend.*** When in a forest, you leave no tracks and can automatically discern true north.",
            "subraces": [],
            "document__slug": "toh",
            "document__title": "Tome of Heroes",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
        }
    ]
}
```

---

## Classes

### Classes List

**Description**

`list`: Returns a list of classes.
`retrieve`: Returns a specific classe by slug.

**Request**

`GET /v1/classes/`

**Response Headers**

```
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept
```

**Response Body**

```json
{
    "count": 12,
    "next": "https://api.open5e.com/v1/classes/?format=json&limit=1&page=2",
    "previous": null,
    "results": [
        {
            "name": "Barbarian",
            "slug": "barbarian",
            "desc": "### Rage \n \nIn battle, you fight with primal ferocity. On your turn, you can enter a rage as a bonus action. \n \nWhile raging, you gain the following benefits if you aren't wearing heavy armor: \n \n* You have advantage on Strength checks and Strength saving throws. \n* When you make a melee weapon attack using Strength, you gain a bonus to the damage roll that increases as you gain levels as a barbarian, as shown in the Rage Damage column of the Barbarian table. \n* You have resistance to bludgeoning, piercing, and slashing damage. \n \nIf you are able to cast spells, you can't cast them or concentrate on them while raging. \n \nYour rage lasts for 1 minute. It ends early if you are knocked unconscious or if your turn ends and you haven't attacked a hostile creature since your last turn or taken damage since then. You can also end your rage on your turn as a bonus action. \n \nOnce you have raged the number of times shown for your barbarian level in the Rages column of the Barbarian table, you must finish a long rest before you can rage again. \n \n### Unarmored Defense \n \nWhile you are not wearing any armor, your Armor Class equals 10 + your Dexterity modifier + your Constitution modifier. You can use a shield and still gain this benefit. \n \n### Reckless Attack \n \nStarting at 2nd level, you can throw aside all concern for defense to attack with fierce desperation. When you make your first attack on your turn, you can decide to attack recklessly. Doing so gives you advantage on melee weapon attack rolls using Strength during this turn, but attack rolls against you have advantage until your next turn. \n \n### Danger Sense \n \nAt 2nd level, you gain an uncanny sense of when things nearby aren't as they should be, giving you an edge when you dodge away from danger. \n \nYou have advantage on Dexterity saving throws against effects that you can see, such as traps and spells. To gain this benefit, you can't be blinded, deafened, or incapacitated. \n \n### Primal Path \n \nAt 3rd level, you choose a path that shapes the nature of your rage. Choose the Path of the Berserker or the Path of the Totem Warrior, both detailed at the end of the class description. Your choice grants you features at 3rd level and again at 6th, 10th, and 14th levels. \n \n### Ability Score Improvement \n \nWhen you reach 4th level, and again at 8th, 12th, 16th, and 19th level, you can increase one ability score of your choice by 2, or you can increase two ability scores of your choice by 1. As normal, you can't increase an ability score above 20 using this feature. \n \n### Extra Attack \n \nBeginning at 5th level, you can attack twice, instead of once, whenever you take the Attack action on your turn. \n \n### Fast Movement \n \nStarting at 5th level, your speed increases by 10 feet while you aren't wearing heavy armor. \n \n### Feral Instinct \n \nBy 7th level, your instincts are so honed that you have advantage on initiative rolls. \n \nAdditionally, if you are surprised at the beginning of combat and aren't incapacitated, you can act normally on your first turn, but only if you enter your rage before doing anything else on that turn. \n \n### Brutal Critical \n \nBeginning at 9th level, you can roll one additional weapon damage die when determining the extra damage for a critical hit with a melee attack. \n \nThis increases to two additional dice at 13th level and three additional dice at 17th level. \n \n### Relentless Rage \n \nStarting at 11th level, your rage can keep you fighting despite grievous wounds. If you drop to 0 hit points while you're raging and don't die outright, you can make a DC 10 Constitution saving throw. If you succeed, you drop to 1 hit point instead. \n \nEach time you use this feature after the first, the DC increases by 5. When you finish a short or long rest, the DC resets to 10. \n \n### Persistent Rage \n \nBeginning at 15th level, your rage is so fierce that it ends early only if you fall unconscious or if you choose to end it. \n \n### Indomitable Might \n \nBeginning at 18th level, if your total for a Strength check is less than your Strength score, you can use that score in place of the total. \n \n### Primal Champion \n \nAt 20th level, you embody the power of the wilds. Your Strength and Constitution scores increase by 4. Your maximum for those scores is now 24.",
            "hit_dice": "1d12",
            "hp_at_1st_level": "12 + your Constitution modifier",
            "hp_at_higher_levels": "1d12 (or 7) + your Constitution modifier per barbarian level after 1st",
            "prof_armor": "Light armor, medium armor, shields",
            "prof_weapons": "Simple weapons, martial weapons",
            "prof_tools": "None",
            "prof_saving_throws": "Strength, Constitution",
            "prof_skills": "Choose two from Animal Handling, Athletics, Intimidation, Nature, Perception, and Survival",
            "equipment": "You start with the following equipment, in addition to the equipment granted by your background: \n \n* (*a*) a greataxe or (*b*) any martial melee weapon \n* (*a*) two handaxes or (*b*) any simple weapon \n* An explorer's pack and four javelins",
            "table": "| Level  | Proficiency Bonus | Features                      | Rages     | Rage Damage | \n|--------|-------------------|-------------------------------|-----------|-------------| \n| 1st    | +2                | Rage, Unarmored Defense       | 2         | +2          | \n| 2nd    | +2                | Reckless Attack, Danger Sense | 2         | +2          | \n| 3rd    | +2                | Primal Path                   | 3         | +2          | \n| 4th    | +2                | Ability Score Improvement     | 3         | +2          | \n| 5th    | +3                | Extra Attack, Fast Movement   | 3         | +2          | \n| 6th    | +3                | Path feature                  | 4         | +2          | \n| 7th    | +3                | Feral Instinct                | 4         | +2          | \n| 8th    | +3                | Ability Score Improvement     | 4         | +2          | \n| 9th    | +4                | Brutal Critical (1 die)       | 4         | +3          | \n| 10th   | +4                | Path feature                  | 4         | +3          | \n| 11th   | +4                | Relentless                    | 4         | +3          | \n| 12th   | +4                | Ability Score Improvement     | 5         | +3          | \n| 13th   | +5                | Brutal Critical (2 dice)      | 5         | +3          | \n| 14th   | +5                | Path feature                  | 5         | +3          | \n| 15th   | +5                | Persistent Rage               | 5         | +3          | \n| 16th   | +5                | Ability Score Improvement     | 5         | +4          | \n| 17th   | +6                | Brutal Critical (3 dice)      | 6         | +4          | \n| 18th   | +6                | Indomitable Might             | 6         | +4          | \n| 19th   | +6                | Ability Score Improvement     | 6         | +4          | \n| 20th   | +6                | Primal Champion               | Unlimited | +4          | ",
            "spellcasting_ability": "",
            "subtypes_name": "Primal Paths",
            "archetypes": [
                {
                    "name": "Path of the Berserker",
                    "slug": "path-of-the-berserker",
                    "desc": "For some barbarians, rage is a means to an end- that end being violence. The Path of the Berserker is a path of untrammeled fury, slick with blood. As you enter the berserker's rage, you thrill in the chaos of battle, heedless of your own health or well-being. \n \n##### Frenzy \n \nStarting when you choose this path at 3rd level, you can go into a frenzy when you rage. If you do so, for the duration of your rage you can make a single melee weapon attack as a bonus action on each of your turns after this one. When your rage ends, you suffer one level of exhaustion (as described in appendix A). \n \n##### Mindless Rage \n \nBeginning at 6th level, you can't be charmed or frightened while raging. If you are charmed or frightened when you enter your rage, the effect is suspended for the duration of the rage. \n \n##### Intimidating Presence \n \nBeginning at 10th level, you can use your action to frighten someone with your menacing presence. When you do so, choose one creature that you can see within 30 feet of you. If the creature can see or hear you, it must succeed on a Wisdom saving throw (DC equal to 8 + your proficiency bonus + your Charisma modifier) or be frightened of you until the end of your next turn. On subsequent turns, you can use your action to extend the duration of this effect on the frightened creature until the end of your next turn. This effect ends if the creature ends its turn out of line of sight or more than 60 feet away from you. \n \nIf the creature succeeds on its saving throw, you can't use this feature on that creature again for 24 hours. \n \n##### Retaliation \n \nStarting at 14th level, when you take damage from a creature that is within 5 feet of you, you can use your reaction to make a melee weapon attack against that creature.",
                    "document__slug": "wotc-srd",
                    "document__title": "5e Core Rules",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd"
                },
                {
                    "name": "Path of the Juggernaut",
                    "slug": "path-of-the-juggernaut",
                    "desc": "Honed to assault the lairs of powerful threats to their way of life, or defend against armed hordes of snarling goblinoids, the juggernauts represent the finest of frontline destroyers within the primal lands and beyond.\n\n##### Thunderous Blows\nStarting when you choose this path at 3rd level, your rage instills you with the strength to batter around your foes, making any battlefield your domain. Once per turn while raging, when you damage a creature with a melee attack, you can force the target to make a Strength saving throw (DC 8 + your proficiency bonus + your Strength modifier). On a failure, you push the target 5 feet away from you, and you can choose to immediately move 5 feet into the target\u2019s previous position. ##### Stance of the Mountain\nYou harness your fury to anchor your feet to the earth, shrugging off the blows of those who wish to topple you. Upon choosing this path at 3rd level, you cannot be knocked prone while raging unless you become unconscious.\n\n##### Demolishing Might\nBeginning at 6th level, you can muster destructive force with your assault, shaking the core of even the strongest structures. All of your melee attacks gain the siege property (your attacks deal double damage to objects and structures). Your melee attacks against creatures of the construct type deal an additional 1d8 weapon damage.\n\n##### Overwhelming Cleave\nUpon reaching 10th level, you wade into armies of foes, great swings of your weapon striking many who threaten you. When you make a weapon attack while raging, you can make another attack as a bonus action with the same weapon against a different creature that is within 5 feet of the original target and within range of your weapon.\n\n##### Unstoppable\nStarting at 14th level, you can become \u201cunstoppable\u201d when you rage. If you do so, for the duration of the rage your speed cannot be reduced, and you are immune to the frightened, paralyzed, and stunned conditions. If you are frightened, paralyzed, or stunned, you can still take your bonus action to enter your rage and suspend the effects for the duration of the rage. When your rage ends, you suffer one level of exhaustion (as described in appendix A, PHB).",
                    "document__slug": "taldorei",
                    "document__title": "Critical Role: Tal\u2019Dorei Campaign Setting",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://https://greenronin.com/blog/2017/09/25/ronin-round-table-integrating-wizards-5e-adventures-with-the-taldorei-campaign-setting/"
                },
                {
                    "name": "Path of Booming Magnificence",
                    "slug": "path-of-booming-magnificence",
                    "desc": "Barbarians who walk the Path of Booming Magnificence strive to be as lions among their people: symbols of vitality, majesty, and courage. They serve at the vanguard, leading their allies at each charge and drawing their opponents' attention away from more vulnerable members of their group. As they grow more experienced, members of this path often take on roles as leaders or in other integral positions.\n\n##### Roar of Defiance\nBeginning at 3rd level, you can announce your presence by unleashing a thunderous roar as part of the bonus action you take to enter your rage. Until the beginning of your next turn, each creature of your choice within 30 feet of you that can hear you has disadvantage on any attack roll that doesn't target you.\n  Until the rage ends, if a creature within 5 feet of you that heard your Roar of Defiance deals damage to you, you can use your reaction to bellow at them. Your attacker must succeed on a Constitution saving throw or take 1d6 thunder damage. The DC is equal to 8 + your proficiency bonus + your Charisma modifier. The damage you deal with this feature increases to 2d6 at 10th level. Once a creature takes damage from this feature, you can't use this feature on that creature again during this rage.\n\n##### Running Leap\nAt 3rd level, while you are raging, you can leap further. When you make a standing long jump, you can leap a number of feet equal to your Strength score. With a 10-foot running start, you can long jump a number of feet equal to twice your Strength score.\n\n##### Lion's Glory\nStarting at 6th level, when you enter your rage, you can choose a number of allies that can see you equal to your Charisma modifier (minimum 1). Until the rage ends, when a chosen ally makes a melee weapon attack, the ally gains a bonus to the damage roll equal to the Rage Damage bonus you gain, as shown in the Rage Damage column of the Barbarian table. Once used, you can't use this feature again until you finish a long rest.\n\n##### Resonant Bellow\nAt 10th level, your roars can pierce the fog of fear. As a bonus action, you can unleash a mighty roar, ending the frightened condition on yourself and each creature of your choice within 60 feet of you and who can hear you. Each creature that ceases to be frightened gains 1d12 + your Charisma modifier (minimum +1) temporary hit points for 1 hour. Once used, you can't use this feature again until you finish a short or long rest.\n\n##### Victorious Roar\nAt 14th level, you exult in your victories. When you hit with at least two attacks on the same turn, you can use a bonus action to unleash a victorious roar. One creature you can see within 30 feet of you must make a Wisdom saving throw with a DC equal to 8 + your proficiency bonus + your Charisma modifier. On a failure, the creature takes psychic damage equal to your barbarian level and is frightened until the end of its next turn. On a success, it takes half the damage and isn't frightened.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Path of Hellfire",
                    "slug": "path-of-hellfire",
                    "desc": "Devils have long been known to grant power to mortals as part of a pact or bargain. While this may take the form of unique magic or boons, those who follow the Path of Hellfire are gifted with command over the fires of the Lower Planes, which they channel for short periods to become powerful and furious fighting machines.\n  While some of these barbarians are enlisted to support the devils' interests as soldiers or enforcers, some escape their devilish fates, while others still are released after their term of service.\n\n#####Hellish Aspect\nBeginning at 3rd level, when you enter your rage, you take on minor fiendish aspects. The way these aspects manifest is up to you and can include sprouting horns from your head, changing the color of your skin, growing fangs or a tail, or other small physical changes. Though infused with fiendish power, you aren't a fiend. While raging, you have resistance to fire damage, and the first creature you hit on each of your turns with a weapon attack takes 1d6 extra fire damage. This damage increases to 2d6 at 10th level.\n\n#####Hell's Vengeance\nAt 6th level, you can use your hellfire to punish enemies. If an ally you can see within 60 feet of you takes damage while you are raging, you can use your reaction to surround the attacker with hellfire, dealing fire damage equal to your proficiency bonus to it.\n\n#####Hellfire Shield\nStarting at 10th level, when you enter your rage, you can surround yourself with flames. This effect works like the fire shield spell, except you are surrounded with a warm shield only and it ends when your rage ends. Once used, you can't use this feature again until you finish a short or long rest.\n\n#####Devilish Essence\nAt 14th level, while raging, you have advantage on saving throws against spells and other magical effects, and if you take damage from a spell, you can use your reaction to gain temporary hit points equal to your barbarian level.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Path of Mistwood",
                    "slug": "path-of-mistwood",
                    "desc": "The first barbarians that traveled the path of mistwood were elves who expanded upon their natural gifts to become masters of the forests. Over time, members of other races who saw the need to protect and cherish the green places of the world joined and learned from them. Often these warriors haunt the woods alone, only seen when called to action by something that would despoil their home.\n\n##### Bonus Proficiency\nAt 3rd level, you gain proficiency in the Stealth skill. If you are already proficient in Stealth, you gain proficiency in another barbarian class skill of your choice.\n\n##### Mistwood Defender\nStarting at 3rd level, you can use the Reckless Attack feature on ranged weapon attacks with thrown weapons, and, while you aren't within melee range of a hostile creature that isn't incapacitated, you can draw and throw a thrown weapon as a bonus action.\n  In addition, when you make a ranged weapon attack with a thrown weapon using Strength while raging, you can add your Rage Damage bonus to the damage you deal with the thrown weapon.\n\n##### From the Mist\nBeginning at 6th level, mist and fog don't hinder your vision. In addition, you can cast the misty step spell, and you can make one attack with a thrown weapon as part of the same bonus action immediately before or immediately after you cast the spell. You can cast this spell while raging. You can use this feature a number of times equal to your proficiency bonus, and you regain all expended uses when you finish a long rest.\n\n##### Mist Dance\nStarting at 10th level, when you use the Attack action while raging, you can make one attack against each creature within 5 feet of you in place of one of your attacks. You can use this feature a number of times equal to your proficiency bonus, and you regain all expended uses when you finish a long rest.\n\n##### War Band's Passage\nStarting at 14th level, when you use your From the Mist feature to cast misty step, you can bring up to two willing creatures within 5 feet of you along with you, as long as each creature isn't carrying more than its carrying capacity. Attacks against you and any creatures you bring with you have disadvantage until the start of your next turn.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Path of the Dragon",
                    "slug": "path-of-the-dragon",
                    "desc": "Few creatures embody the power and majesty of dragons. By walking the path of the dragon, you don't solely aspire to emulate these creatures\u2014you seek to become one. The barbarians who follow this path often do so after surviving a dragon encounter or are raised in a culture that worships them. Dragons tend to have a mixed view of the barbarians who choose this path. Some dragons, in particular the metallic dragons, view such a transformation as a flattering act of admiration. Others may recognize or even fully embrace them as useful to their own ambitions. Still others view this path as embarrassing at best and insulting at worst, for what puny, two-legged creature can ever hope to come close to the natural ferocity of a dragon? When choosing this path, consider what experiences drove you to such a course. These experiences will help inform how you deal with the judgment of dragons you encounter in the world.\n\n##### Totem Dragon\nStarting when you choose this path at 3rd level, you choose which type of dragon you seek to emulate. You can speak and read Draconic, and you are resistant to the damage type of your chosen dragon.\n\n| Dragon | Damage Type | \n|---------------------|-------------| \n| Black or Copper | Acid | \n| Blue or Bronze | Lightning | \n| Brass, Gold, or Red | Fire | \n| Green | Poison | \n| Silver or White | Cold |\n\n##### Wyrm Teeth\nAt 3rd level, your jaws extend and become dragon-like when you enter your rage. While raging, you can use a bonus action to make a melee attack with your bite against one creature you can see within 5 feet of you. You are proficient with the bite. When you hit with it, your bite deals piercing damage equal to 1d8 + your Strength modifier + damage of the type associated with your totem dragon equal to your proficiency bonus.\n\n##### Legendary Might\nStarting at 6th level, if you fail a saving throw, you can choose to succeed instead. Once you use this feature, you can't use it again until you finish a long rest. When you reach 14th level in this class, you can use this feature twice between long rests.\n\n##### Aspect of the Dragon\nAt 10th level, you take on additional draconic features while raging. When you enter your rage, choose one of the following aspects to manifest.\n\n***Dragon Heart.*** You gain temporary hit points equal to 1d12 + your barbarian level. Once you manifest this aspect, you must finish a short or long rest before you can manifest it again.\n\n***Dragon Hide.*** Scales sprout across your skin. Your Armor Class increases by 2.\n\n***Dragon Sight.*** Your senses become those of a dragon. You have blindsight out to a range of 60 feet.\n\n***Dragon Wings.*** You sprout a pair of wings that resemble those of your totem dragon. While the wings are present, you have a flying speed of 30 feet. You can't manifest your wings while wearing armor unless it is made to accommodate them, and clothing not made to accommodate your wings might be destroyed when you manifest them.\n\n##### Wyrm Lungs\nAt 14th level, while raging, you can use an action to make a breath weapon attack. You exhale your breath in a 60-foot cone. Each creature in the area must make a Dexterity saving throw (DC equal to 8 + your proficiency bonus + your Constitution modifier), taking 12d8 damage of the type associated with your totem dragon on a failed save, or half as much damage on a successful one. Once you use this feature, you can't use it again until you finish a long rest.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Path of the Herald",
                    "slug": "path-of-the-herald",
                    "desc": "In northern lands, the savage warriors charge into battle behind chanting warrior-poets. These wise men and women collect the histories, traditions, and accumulated knowledge of the people to preserve and pass on. Barbarians who follow the Path of the Herald lead their people into battle, chanting the tribe's sagas and spurring them on to new victories while honoring the glory of the past.\n\n##### Oral Tradition\nWhen you adopt this path at 3rd level, you gain proficiency in History and Performance. If you already have proficiency in one of these skills, your proficiency bonus is doubled for ability checks you make using that skill.\n\n##### Battle Fervor\nStarting when you choose this path at 3rd level, when you enter a rage, you can expend one additional daily use of rage to allow a number of willing creatures equal to half your proficiency bonus (minimum of 1) within 30 feet of you to enter a rage as well. A target must be able to see and hear you to enter this rage. Each target gains the benefits and restrictions of the barbarian Rage class feature. In addition, the rage ends early on a target if it can no longer see or hear you.\n\n##### Lorekeeper\nAs a historian, you know how much impact the past has on the present. At 6th level, you can enter a trance and explore your people's sagas to cast the augury, comprehend languages, or identify spell, but only as a ritual. After you cast a spell in this way, you can't use this feature again until you finish a short or long rest.\n\n##### Bolstering Chant\nAt 10th level, when you end your rage as a bonus action, you regain a number of hit points equal to your barbarian level *x* 3. Alternatively, if you end your rage and other creatures are also raging due to your Battle Fervor feature, you and each creature affected by your Battle Fervor regains a number of hit points equal to your barbarian level + your Charisma modifier.\n\n##### Thunderous Oratory\nAt 14th level, while you are raging, your attacks deal an extra 2d6 thunder damage. If a creature is raging due to your Battle Fervor feature, its weapon attacks deal an extra 1d6 thunder damage. In addition, when you or a creature affected by your Battle Fervor scores a critical hit with a melee weapon attack, the target must succeed on a Strength saving throw (DC equal to 8 + your proficiency bonus + your Charisma modifier) or be pushed up to 10 feet away and knocked prone in addition to any extra damage from the critical hit.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Path of the Inner Eye",
                    "slug": "path-of-the-inner-eye",
                    "desc": "The barbarians who follow the Path of the Inner Eye elevate their rage beyond anger to glimpse premonitions of the future.\n\n##### Anticipatory Stance\nWhen you choose this path at 3rd level, you can't be surprised unless you are incapacitated, and attacks against you before your first turn have disadvantage. If you take damage before your first turn, you can enter a rage as a reaction, gaining resistance to bludgeoning, piercing, and slashing damage from the triggering attack.\n  When you reach 8th level in this class, you get 1 extra reaction on each of your turns. This extra reaction can be used only for features granted by the Path of the Inner Eye, such as Insightful Dodge or Preemptive Parry. When you reach 18th level in this class, this increases to 2 extra reactions on each of your turns.\n\n##### Insightful Dodge\nBeginning at 6th level, when you are hit by an attack while raging, you can use your reaction to move 5 feet. If this movement takes you beyond the range of the attack, the attack misses instead. You can use this feature a number of times equal to your proficiency bonus. You regain all expended uses when you finish a long rest.\n\n##### Foretelling Tactics\nStarting at 10th level, when you hit a creature with a weapon attack while raging, up to two creatures of your choice who can see and hear you can each use a reaction to immediately move up to half its speed toward the creature you hit and make a single melee or ranged weapon attack against that creature. This movement doesn't provoke opportunity attacks. Once you use this feature, you can't use it again until you finish a short or long rest.\n\n##### Preemptive Parry\nAt 14th level, if you are raging and a creature you can see within your reach hits another creature with a weapon attack, you can use your reaction to force the attacker to reroll the attack and use the lower of the two rolls. If the result is still a hit, reduce the damage dealt by your weapon damage die + your Strength modifier.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                },
                {
                    "name": "Path of Thorns",
                    "slug": "path-of-thorns",
                    "desc": "Path of Thorns barbarians use ancient techniques developed by the druids of old that enable them to grow thorns all over their body. The first barbarians of this path fought alongside these druids to defend the natural order. In the centuries since, the knowledge of these techniques has spread, allowing others access to this power.\n  Though named for the thorns that covered the first barbarians to walk this path, current followers of this path can display thorns, spines, or boney growths while raging.\n\n##### Blossoming Thorns\nBeginning at 3rd level, when you enter your rage, hard, sharp thorns emerge over your whole body, turning your unarmed strikes into dangerous weapons. When you hit with an unarmed strike while raging, your unarmed strike deals piercing damage equal to 1d4 + your Strength modifier, instead of the bludgeoning damage normal for an unarmed strike. In addition, while raging, when you use the Attack action with an unarmed strike on your turn, you can make one unarmed strike as a bonus action.\n  The unarmed strike damage you deal while raging increases when you reach certain levels in this class: to 1d6 at 8th level and to 1d8 at 14th level.\n\n##### Thorned Grasp\nAlso at 3rd level, when you use the Attack action to grapple a creature while raging, the target takes 1d4 piercing damage if your grapple check succeeds, and it takes 1d4 piercing damage at the start of each of your turns, provided you continue to grapple the creature and are raging. When you reach 10th level in this class, this damage increases to 2d4.\n\n##### Nature's Blessing\nAt 6th level, the thorns you grow while raging become more powerful and count as magical for the purpose of overcoming resistance and immunity to nonmagical attacks and damage. When you are hit by a melee weapon attack by a creature within 5 feet of you while raging, that creature takes 1d4 piercing damage. When you reach 10th level in this class, this damage increases to 2d4.\n  Alternatively, while raging, you can use your reaction to disarm a creature that hits you with a melee weapon while within 5 feet of you by catching its weapon in your thorns instead of the attacker taking damage from your thorns. The attacker must succeed on a Strength saving throw (DC equal to 8 + your Constitution modifier + your proficiency bonus) or drop the weapon it used to attack you. The weapon lands at its feet. The attacker must be wielding a weapon for you to use this reaction.\n\n##### Toxic Infusion\nStarting at 10th level, when you enter your rage or as a bonus action while raging, you can infuse your thorns with toxins for 1 minute. While your thorns are infused with toxins, the first creature you hit on each of your turns with an unarmed strike must succeed on a Constitution saving throw (DC equal to 8 + your Constitution modifier + your proficiency bonus) or be poisoned until the end of its next turn.\n  You can use this feature a number of times equal to your proficiency bonus. You regain all expended uses when you finish a long rest.\n\n##### Thorn Barrage\nAt 14th level, you can use an action to shoot the thorns from your body while raging. Each creature within 10 feet of you must make a Dexterity saving throw (DC equal to 8 + your Constitution modifier + your proficiency bonus), taking 4d6 piercing damage on a failed save, or half as much damage on a successful one.\n  You can use this feature a number of times equal to your proficiency bonus. You regain all expended uses when you finish a long rest.",
                    "document__slug": "toh",
                    "document__title": "Tome of Heroes",
                    "document__license_url": "http://open5e.com/legal",
                    "document__url": "https://koboldpress.com/kpstore/product/tome-of-heroes-for-5th-edition/"
                }
            ],
            "document__slug": "wotc-srd",
            "document__title": "5e Core Rules",
            "document__license_url": "http://open5e.com/legal",
            "document__url": "http://dnd.wizards.com/articles/features/systems-reference-document-srd"
        }
    ]
}
```

---

## Magic Items

### Magic Items List

**Description**

`list`: Returns a list of magic items.
`retrieve`: Returns a specific magic item by slug.

**Request**

`GET /v1/magicitems/`

**Response Headers**

```
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept
```

**Response Body**

```json
{
    "count": 1618,
    "next": "https://api.open5e.com/v1/magicitems/?format=json&limit=1&page=2",
    "previous": null,
    "results": [
        {
            "slug": "aberrant-agreement",
            "name": "Aberrant Agreement",
            "type": "Scroll",
            "desc": "This long scroll bears strange runes and seals of eldritch powers. When you use an action to present this scroll to an aberration whose Challenge Rating is equal to or less than your level, the binding powers of the scroll compel it to listen to you. You can then attempt to strike a bargain with the aberration, negotiating a service from it in exchange for a reward. The aberration is under no compulsion to strike the bargain; it is compelled only to parley long enough for you to present a bargain and allow for negotiations. If you or your allies attack or otherwise attempt to harm the aberration, the truce is broken, and the creature can act normally. If the aberration refuses the offer, it is free to take any actions it wishes. Should you and the aberration reach an agreement that is satisfactory to both parties, you must sign the agreement and have the aberration do likewise (or make its mark, if it has no form of writing). The writing on the scroll changes to reflect the terms of the agreement struck. The magic of the charter holds both you and the aberration to the agreement until its service is rendered and the reward paid, at which point the scroll blackens and crumbles to dust. An aberration's thinking is alien to most humanoids, and vaguely worded contracts may result in unintended consequences, as the creature may have different thoughts as to how to best meet the goal. If either party breaks the bargain, that creature immediately takes 10d6 psychic damage, and the charter is destroyed, ending the contract.",
            "rarity": "rare",
            "requires_attunement": "",
            "document__slug": "vom",
            "document__title": "Vault of Magic",
            "document__url": "https://koboldpress.com/kpstore/product/vault-of-magic-for-5th-edition/"
        }
    ]
}
```

---

## Weapons

### Weapons List

**Description**

`list`: Returns a list of weapons.
`retrieve`: Returns a specific weapon by slug.

**Request**

`GET /v1/weapons/`

**Response Headers**

```
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept
```

**Response Body**

```json
{
    "count": 75,
    "next": "https://api.open5e.com/v2/weapons/?format=json&limit=1&page=2",
    "previous": null,
    "results": [
        {
            "url": "https://api.open5e.com/v2/weapons/srd-2024_battleaxe/?format=json",
            "key": "srd-2024_battleaxe",
            "document": {
                "name": "System Reference Document 5.2",
                "key": "srd-2024",
                "type": "SOURCE",
                "display_name": "5e 2024 Rules",
                "publisher": {
                    "name": "Wizards of the Coast",
                    "key": "wizards-of-the-coast",
                    "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/?format=json"
                },
                "gamesystem": {
                    "name": "5th Edition 2024",
                    "key": "5e-2024",
                    "url": "https://api.open5e.com/v2/gamesystems/5e-2024/?format=json"
                },
                "permalink": "https://dnd.wizards.com/resources/systems-reference-document"
            },
            "properties": [
                {
                    "property": {
                        "name": "Topple",
                        "type": "Mastery",
                        "url": "/v2/weaponproperties/srd-2024_topple-mastery/",
                        "desc": "If you hit a creature with this weapon, you can force the creature to make a Constitution saving throw (DC 8 plus the ability modifier used to make the attack roll and your Proficiency Bonus). On a failed save, the creature has the Prone condition."
                    },
                    "detail": null
                },
                {
                    "property": {
                        "name": "Versatile",
                        "type": null,
                        "url": "/v2/weaponproperties/srd-2024_versatile-wp/",
                        "desc": "A Versatile weapon can be used with one or two hands. A damage value in parentheses appears with the property. The weapon deals that damage when used with two hands to make a melee attack."
                    },
                    "detail": "1d10"
                }
            ],
            "damage_type": {
                "name": "Slashing",
                "key": "slashing",
                "url": "https://api.open5e.com/v2/damagetypes/slashing/?format=json"
            },
            "distance_unit": "feet",
            "name": "Battleaxe",
            "damage_dice": "1d8",
            "range": 0.0,
            "long_range": 0.0,
            "is_simple": false,
            "is_improvised": false
        }
    ]
}
```

---

## Armor

### Armor List

**Description**

`list`: Returns a list of armor.
`retrieve`: Returns a specific armor by slug.

**Request**

`GET /v1/armor/`

**Response Headers**

```
Allow: GET, HEAD, OPTIONS
Content-Type: application/json
Vary: Accept
```

**Response Body**

```json
{
    "count": 25,
    "next": "https://api.open5e.com/v2/armor/?format=json&limit=1&page=2",
    "previous": null,
    "results": [
        {
            "url": "https://api.open5e.com/v2/armor/srd-2024_breastplate/?format=json",
            "key": "srd-2024_breastplate",
            "ac_display": "14 + Dex modifier (max 2)",
            "category": "medium",
            "document": {
                "name": "System Reference Document 5.2",
                "key": "srd-2024",
                "type": "SOURCE",
                "display_name": "5e 2024 Rules",
                "publisher": {
                    "name": "Wizards of the Coast",
                    "key": "wizards-of-the-coast",
                    "url": "https://api.open5e.com/v2/publishers/wizards-of-the-coast/?format=json"
                },
                "gamesystem": {
                    "name": "5th Edition 2024",
                    "key": "5e-2024",
                    "url": "https://api.open5e.com/v2/gamesystems/5e-2024/?format=json"
                },
                "permalink": "https://dnd.wizards.com/resources/systems-reference-document"
            },
            "name": "Breastplate",
            "grants_stealth_disadvantage": false,
            "strength_score_required": null,
            "ac_base": 14,
            "ac_add_dexmod": true,
            "ac_cap_dexmod": 2
        }
    ]
}
```

---

