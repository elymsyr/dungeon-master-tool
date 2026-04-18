# D&D 5e Mechanics Reference (SRD 5.2.1)

> **Status:** Living document. Normative reference for all engine code.
> **Source:** System Reference Document 5.2.1 (SRD 5.2.1).
> **Audience:** Engineers implementing the DnD 5e engine inside the Dungeon Master Tool.

---

## 0. Attribution & License

This work includes material from the System Reference Document 5.2.1 ("SRD 5.2.1") by Wizards of the Coast LLC, available at <https://www.dndbeyond.com/srd>. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at <https://creativecommons.org/licenses/by/4.0/legalcode>.

This document is "compatible with fifth edition" / "5E compatible." No additional attribution to Wizards or its parent or affiliates is implied.

The structured summaries below are derivative of SRD 5.2.1 and inherit the CC BY 4.0 license. Page numbers in parentheses (e.g., *p. 14*) refer to the SRD 5.2.1 PDF located at `docs/SRD_CC_v5.2.1.pdf` in this repository.

**Scope of this document:** game *mechanics* (rules and procedures). Per-spell, per-monster, per-item *content* lists live in package data files, not here.

---

## 1. Core Resolution: The D20 Test (pp. 5-8)

Every uncertain action resolves with a **D20 Test**. There are three flavors, all sharing one formula.

```
Total = 1d20 + AbilityModifier + (ProficiencyBonus if relevant) + CircumstantialModifiers
Outcome:
  Total ≥ TargetNumber → success
  Total < TargetNumber → failure
```

| D20 Test Type | Target Number | Used For |
|---|---|---|
| **Ability Check** | DC (Difficulty Class) | Skill use, generic challenges |
| **Saving Throw** | DC | Avoid/resist an effect |
| **Attack Roll** | AC (Armor Class) | Hit a target with weapon, spell, or unarmed strike |

### 1.1 Procedure

1. **Roll 1d20.** Always want high.
2. **Add modifiers** (ability mod, prof bonus, situational).
3. **Compare** total to DC or AC.

### 1.2 Natural 20 / Natural 1 (attack rolls only)

- **Natural 20** → automatic hit + Critical Hit (regardless of AC or modifiers).
- **Natural 1** → automatic miss (regardless of modifiers or AC).

Critical Hit damage rule: see §11.4.

### 1.3 Advantage / Disadvantage (p. 7-8)

- **Advantage:** roll 2d20, take higher.
- **Disadvantage:** roll 2d20, take lower.
- **Don't stack.** Multiple sources of Advantage still mean 2d20-take-higher (not 3d20).
- **Cancellation.** Any number of Advantage with any number of Disadvantage = flat 1d20. No partial cancellation.

### 1.4 Heroic Inspiration (p. 8)

- A PC can hold at most **one** Inspiration.
- Spend Inspiration: reroll any one die you just rolled (after seeing result, before consequences).
- If a roll has Adv/Disadv, reroll only one of the two d20s.
- GM grants for in-character play; some species/features grant baseline (e.g., Human gains it on Long Rest finish).

### 1.5 Difficulty Class table (p. 6)

| Task Difficulty | DC |
|---|---|
| Very easy | 5 |
| Easy | 10 |
| Medium | 15 |
| Hard | 20 |
| Very hard | 25 |
| Nearly impossible | 30 |

### 1.6 Round Down rule (p. 5)

When dividing or multiplying in the game, **round down** unless a rule explicitly says round up.

---

## 2. The Six Abilities & Modifiers (pp. 5-6)

Six abilities define every creature: **Strength, Dexterity, Constitution, Intelligence, Wisdom, Charisma**.

### 2.1 Score range

- 1 to 30. PC max normally 20 (raise above only via specific feature).
- 30 is the highest possible.

### 2.2 Modifier formula

```
Modifier = floor((Score - 10) / 2)
```

Quick lookup:

| Score | Mod | Score | Mod |
|---|---|---|---|
| 1 | -5 | 16-17 | +3 |
| 2-3 | -4 | 18-19 | +4 |
| 4-5 | -3 | 20-21 | +5 |
| 6-7 | -2 | 22-23 | +6 |
| 8-9 | -1 | 24-25 | +7 |
| 10-11 | +0 | 26-27 | +8 |
| 12-13 | +1 | 28-29 | +9 |
| 14-15 | +2 | 30 | +10 |

### 2.3 What each ability measures

| Ability | Measures | Common Check Examples |
|---|---|---|
| Strength | Physical might | Lift, push, pull, break |
| Dexterity | Agility, reflexes, balance | Move nimbly, quickly, quietly |
| Constitution | Health, stamina | Push body beyond limits |
| Intelligence | Reasoning, memory | Reason, remember |
| Wisdom | Perceptiveness, fortitude | Notice things, judge |
| Charisma | Confidence, poise, charm | Influence, entertain, deceive |

---

## 3. Proficiency Bonus (PB) (p. 8)

Reflects training. Added to D20 Tests when proficient (skill, save, weapon, tool, spell save DC, spell attack).

### 3.1 PB by Level / CR

| Level or CR | PB | Level or CR | PB |
|---|---|---|---|
| 1-4 | +2 | 17-20 | +6 |
| 5-8 | +3 | 21-24 | +7 |
| 9-12 | +4 | 25-28 | +8 |
| 13-16 | +5 | 29-30 | +9 |

### 3.2 Stacking rule

- **PB applied at most once** per D20 Test.
- Even if proficient in two relevant skills (e.g., Athletics and Acrobatics), PB doesn't double.
- **Expertise** doubles PB for that one skill check (max once: can't double-double).
- PB can be **multiplied or halved** (Expertise = ×2; Half-Proficiency = ×0.5 round down) before adding, but multiplied/halved at most once per use.

---

## 4. Skills (pp. 8-9, 189)

18 skills. Each tied to a default ability.

| Skill | Ability | Domain |
|---|---|---|
| Acrobatics | DEX | Stay on feet, acrobatic stunts |
| Animal Handling | WIS | Calm/train animals |
| Arcana | INT | Spells, magic items, planes |
| Athletics | STR | Jump, swim, climb, force |
| Deception | CHA | Lies, disguise |
| History | INT | Events, people, civilizations |
| Insight | WIS | Read intentions |
| Intimidation | CHA | Threaten, awe |
| Investigation | INT | Books, deduction |
| Medicine | WIS | Diagnose, cause of death |
| Nature | INT | Terrain, plants, beasts |
| Perception | WIS | Notice (sight, sound, smell) |
| Performance | CHA | Act, music, dance |
| Persuasion | CHA | Honest convincing |
| Religion | INT | Gods, rites, holy symbols |
| Sleight of Hand | DEX | Pickpocket, conceal |
| Stealth | DEX | Move unseen |
| Survival | WIS | Tracks, foraging, weather |

### 4.1 Without proficiency

A character without skill proficiency still rolls; just no PB. (e.g., Untrained Athletics check = d20 + STR mod, no PB.)

### 4.2 Passive Perception (p. 186)

```
Passive Perception = 10 + WIS(Perception) check modifier
  +5 if rolling that check would have Advantage
  -5 if Disadvantage
```

Used by GM to determine what a creature notices without rolling.

### 4.3 Areas of Knowledge (p. 189)

Used for the **Study action**:

| Skill | Areas |
|---|---|
| Arcana | Spells, magic items, eldritch symbols, planes, certain creatures (Aberrations, Constructs, Elementals, Fey) |
| History | Historic events/people, civilizations, ancient creatures (Giants, Humanoids) |
| Investigation | Traps, ciphers, riddles, gadgetry |
| Nature | Terrain, flora, weather, certain creatures (Beasts, Dragons, Oozes, Plants) |
| Religion | Deities, rites, symbols, cults, certain creatures (Celestials, Fiends, Undead) |

---

## 5. Saving Throws (p. 7)

Six save types, one per ability. Each class grants proficiency in 2 saves.

| Save | Resists |
|---|---|
| STR | Direct physical force |
| DEX | Dodging out of harm's way |
| CON | Toxic hazards, ongoing damage |
| INT | Illusion, mental intrusion |
| WIS | Mental assault, charm |
| CHA | Identity, soul attacks |

### 5.1 Spell Save DC

```
Spell save DC = 8 + caster's spellcasting ability modifier + caster's PB
```

### 5.2 Saving Throws and Damage (p. 16)

- Failed save with damage spell: full damage (often).
- Successful save: half damage (round down) — if the spell description allows.
- AoE damage roll: roll **once**, apply to all targets.

---

## 6. Action Economy (pp. 9-10)

On your turn you have:

- **1 Action**
- **1 Bonus Action** (only if a feature grants you one to take)
- **1 Reaction** per round (can be used on any creature's turn)
- **Movement** up to your Speed (split freely around action/bonus)
- **1 free Object Interaction** (extra interactions cost the **Utilize** action)
- **Free Communication** (brief utterances, gestures)

### 6.1 The 13 Standard Actions

| Action | Summary |
|---|---|
| **Attack** | Make 1 attack with weapon or Unarmed Strike (or more with Extra Attack feature) |
| **Dash** | Gain extra movement equal to Speed (after modifiers) |
| **Disengage** | No Opportunity Attacks against you for the rest of the turn |
| **Dodge** | Until next turn: attacks vs you have Disadv (if you can see attacker), DEX saves with Adv. Lost if Incapacitated or Speed 0. |
| **Help** | Assist ally's ability check (give Adv on next check, expires start of your next turn) OR distract enemy within 5 ft (give one ally Adv on next attack vs that enemy) |
| **Hide** | DC 15 DEX(Stealth) check while Heavily Obscured / behind 3⁄4 or Total Cover, out of LOS. Success: gain Invisible condition while hidden. |
| **Influence** | Urge a monster (DC = 15 or monster's INT, whichever higher; modified by attitude). |
| **Magic** | Cast a spell with Action casting time, OR use a magic item, OR use a magical feature. |
| **Ready** | Prepare a triggered action; release as Reaction. Spell readied: cast normally, expending slot, hold concentration up to your next turn. |
| **Search** | WIS check; skill (Insight/Medicine/Perception/Survival) per target detection. |
| **Study** | INT check; skill (Arcana/History/Investigation/Nature/Religion) per target knowledge. |
| **Utilize** | Use a non-magical object that requires an action (lever, complex device). |
| **Attack [action subtypes]** | Equipping/unequipping one weapon counts as part of Attack action. |

### 6.2 Bonus Action rules

- Take only one Bonus Action per turn.
- Available **only when a feature grants you a Bonus Action option**.
- Choose timing during your turn (unless feature specifies).
- Anything that bars Action can also bar Bonus Action.

### 6.3 Reaction rules

- 1 per round; refreshes at start of your turn.
- Most common Reaction: **Opportunity Attack** (see §10.4).
- Reaction occurs immediately after trigger unless its description says otherwise.
- If a Reaction interrupts another's turn, that creature continues after the Reaction.

### 6.4 One Thing at a Time (p. 10)

You can take only one Action at a time. In social/exploration too — can't simultaneously Search and Help with Utilize.

---

## 7. Combat Flow (pp. 13-14)

A combat **round** = ~6 in-game seconds. During a round, every participant takes one **turn**.

### 7.1 Combat Step by Step

1. **Establish positions.** GM places combatants based on stated locations.
2. **Roll Initiative.**
3. **Take turns** in Initiative order (highest to lowest).
4. Repeat the round until combat ends.

### 7.2 Initiative

```
Initiative roll = 1d20 + DEX modifier
  Add Adv if relevant feature (e.g., Alert grants +PB)
```

- GM rolls one Initiative for a group of identical monsters.
- **Ties:** GM decides among monster ties; players among PC ties; GM decides PC vs monster ties.
- **Surprise:** if a combatant is surprised when combat starts, they have **Disadvantage on Initiative**.

### 7.3 On Your Turn

- Move up to Speed (breakable: e.g., 10 ft → action → 20 ft).
- Take 1 Action + (optionally) 1 Bonus Action.
- Free object interaction + communication.

### 7.4 Doing Nothing

You may forgo move, action, etc. Common alternative: take Dodge or Ready to delay.

### 7.5 Ending Combat

When one side defeated (killed/knocked out/surrendered/fled), or both sides agree to stop.

---

## 8. Movement & Positioning (pp. 14-15, 178-186)

### 8.1 Speed

- Determined by species (typical 30 ft for Medium humanoids).
- Special speeds: **Burrow Speed**, **Climb Speed**, **Fly Speed**, **Swim Speed**.
- When using a non-Speed movement type, you choose at start of move; can switch during move (subtract distance already used from the new speed).

### 8.2 Grid Combat (p. 13 sidebar)

- 1 square = 5 ft.
- Speed translates: 30 ft Speed = 6 squares.
- Entering an unoccupied square (orthogonal or diagonal) = 1 square cost.
- Difficult Terrain square = 2 squares cost.
- Diagonals can't cross corners of walls/large trees/etc.
- **Range** = count squares from a square adjacent to one creature to a square adjacent to the other (shortest route).

### 8.3 Difficult Terrain (p. 181)

- Each foot moved costs +1 foot (i.e., 1 ft moved consumes 2 ft of speed).
- **Not cumulative.** Multiple sources still only double.
- Triggers: non-ally non-Tiny creature in space, large furniture, heavy snow/ice/rubble/undergrowth, shin-to-waist liquid, narrow opening (1 size smaller), slope ≥20°.

### 8.4 Creature Size & Space (p. 14)

| Size | Space (Feet) | Squares |
|---|---|---|
| Tiny | 2.5 × 2.5 | 4 per square |
| Small | 5 × 5 | 1 |
| Medium | 5 × 5 | 1 |
| Large | 10 × 10 | 4 (2×2) |
| Huge | 15 × 15 | 9 (3×3) |
| Gargantuan | 20 × 20 | 16 (4×4) |

### 8.5 Moving Around Other Creatures

- Can pass through space of: ally, Incapacitated creature, Tiny, or 2+ size categories different.
- Other creature's space = Difficult Terrain unless Tiny or your ally.
- Can't end move in occupied space; if forced, gain **Prone**.

### 8.6 Breaking Up Movement

You can split move around action/bonus action/reaction. e.g., 10 ft → Attack → 20 ft.

### 8.7 Dropping Prone (p. 14)

Free on your turn (no action, no movement) — but Speed must be > 0.

### 8.8 Climbing & Swimming (pp. 178, 189)

- 1 ft of climbing/swimming costs +1 ft (2 ft in Difficult Terrain).
- **Climb Speed** / **Swim Speed** removes that extra cost.

### 8.9 Crawling (p. 179)

While crawling: each foot of movement costs +1 foot (+2 in Difficult Terrain).

### 8.10 Jumping (pp. 183-184)

- **Long Jump:** horizontal feet up to STR score (with 10-ft running start; standing = half). Each foot of jump costs 1 foot of movement. Land in Difficult Terrain → DC 10 DEX(Acro) save or Prone.
- **High Jump:** vertical feet up to 3 + STR mod (10-ft start; standing = half). Reach distance up to height + 1.5× height with arms.

### 8.11 Falling (p. 182)

- 1d6 Bludgeoning per 10 ft fallen, max 20d6.
- Land **Prone** unless damage avoided.
- May use Reaction for DC 15 STR(Athletics) or DEX(Acro) check while falling into liquid → halve damage.

### 8.12 Flying (p. 182)

- Use Fly Speed to move through air.
- If Incapacitated or Prone or Fly Speed reduced to 0 → fall (unless can hover).

---

## 9. Vision & Light (p. 11)

### 9.1 Light levels

- **Bright Light:** see normally. Sources: torches, lanterns, fires, sun, full moon.
- **Dim Light:** Lightly Obscured area. Twilight, dawn, full-moon outdoors.
- **Darkness:** Heavily Obscured area.

### 9.2 Obscuration

- **Lightly Obscured:** Wisdom (Perception) checks based on sight have Disadvantage.
- **Heavily Obscured:** **Blinded** condition while trying to see.

### 9.3 Special Senses

| Sense | Range | Effect |
|---|---|---|
| **Blindsight** | spec | See without sight; sees through Total Cover, in Darkness, when Blinded; sees Invisible creatures |
| **Darkvision** | spec | Treat Dim Light as Bright; Darkness as Dim Light; only shades of gray in Darkness |
| **Tremorsense** | spec | Pinpoint creatures/moving objects in contact with same surface (or liquid) |
| **Truesight** | spec | See normally in magical/non-magical Darkness; see Invisible; see through Visual Illusions (auto-succeed save); pierce Transformations; see into Ethereal Plane |

---

## 10. Attacking (pp. 14-15)

### 10.1 Attack roll structure

1. **Choose a target** within range.
2. **Determine modifiers** (cover, advantage/disadvantage, penalties).
3. **Resolve:** roll 1d20 + ability mod + PB (if proficient with weapon/spell). Compare to AC.

### 10.2 Ability modifier per attack type

| Attack Type | Ability |
|---|---|
| Melee weapon | STR (or DEX with Finesse) |
| Ranged weapon | DEX |
| Spell attack | Caster's spellcasting ability (varies by class) |
| Unarmed Strike | STR + PB |

### 10.3 Cover (p. 15)

| Degree | Bonus | Provided By |
|---|---|---|
| **Half Cover** | +2 AC, +2 DEX saves | Object covers half target |
| **Three-Quarters Cover** | +5 AC, +5 DEX saves | Object covers 3⁄4 target |
| **Total Cover** | Cannot target directly | Object fully covers target |

- Cover only applies if attack/effect originates **on opposite side** of cover.
- Multiple covers: only **most protective** applies — not additive.

### 10.4 Opportunity Attacks (p. 15)

- **Trigger:** a creature you can see leaves your reach using its movement, action, bonus action, or any speed.
- **Take Reaction:** make 1 melee attack with weapon or Unarmed Strike.
- **Avoidance:** Disengage action, Teleportation, or being moved without using your own movement (e.g., shoved).

### 10.5 Reach

- Default melee reach = 5 ft.
- **Reach property** weapon adds +5 ft (and applies to OAs).
- Some monsters have natural reach >5 ft (noted in stat block).

### 10.6 Ranged Attacks (p. 15)

- **Range** = single number, OR (normal/long).
- Beyond normal but within long: **Disadvantage** on attack roll.
- Beyond long: cannot attack.
- **Ranged in close combat:** within 5 ft of an enemy who can see you and isn't Incapacitated → ranged attack rolls have **Disadvantage**.

### 10.7 Unseen Attackers / Targets (p. 14 sidebar)

- Attack vs target you can't see: **Disadvantage**. If wrong square targeted, miss.
- Attack rolls **against** a creature that can't see you: **Advantage**.
- Hidden attacker reveals location on hit or miss.

### 10.8 Underwater Combat (p. 16)

- Melee weapon w/o Swim Speed and not Piercing: attack roll has Disadvantage.
- Ranged weapon: auto-miss past normal range; Disadvantage within normal range.
- All creatures underwater have **Resistance to Fire** damage.

### 10.9 Mounted Combat (p. 15)

- Mount a willing creature 1+ size larger within 5 ft: cost half Speed.
- **Controlled mount** (trained): mount's Initiative changes to match yours; only Dash/Disengage/Dodge actions for mount.
- **Independent mount** keeps own Initiative.
- **Falling off:** if mount moved against rider's will, DC 10 DEX save or fall + Prone within 5 ft of mount. Same save if rider knocked Prone or mount Prone.

---

## 11. Damage (pp. 16-17)

### 11.1 Damage roll

```
DamageRoll = WeaponDie(s) + AbilityModifier (where applicable) + extras (e.g., Sneak Attack)
```

Spell damage is per the spell description. Don't add ability mod to spell damage unless the spell says so.

### 11.2 Damage Types (p. 180)

13 types:

```
Acid, Bludgeoning, Cold, Fire, Force, Lightning, Necrotic, Piercing,
Poison, Psychic, Radiant, Slashing, Thunder
```

### 11.3 Resistance / Vulnerability / Immunity (p. 17)

| | Effect |
|---|---|
| **Resistance** | Damage halved (round down) |
| **Vulnerability** | Damage doubled |
| **Immunity** | Damage = 0 |

- Multiple Resistance instances vs same type: only count once.
- Same for Vulnerability.

### 11.4 Critical Hit (p. 16)

- Roll attack damage **dice twice** (incl. Sneak Attack and other extra dice). Sum + modifiers.
- Modifiers (mod, +1 weapon bonus, etc.) added once.

### 11.5 Order of Application

When applying modifiers/resist/vuln to damage:

```
1. Adjustments (bonuses, penalties, multipliers like aura -5)
2. Resistance (halve)
3. Vulnerability (double)
```

Example: 28 Fire damage, Resistance to all + Vulnerability to Fire, magic aura -5:
- (1) 28 - 5 = 23
- (2) 23 / 2 = 11 (round down)
- (3) 11 × 2 = 22

### 11.6 AoE damage rule (p. 16)

When a single damaging effect hits multiple targets via saves, **roll damage once** and apply to all (each makes own save → full or half).

### 11.7 Saving Throw Damage (p. 16)

Failed save = full damage; successful save = **half damage (round down)** — unless the spell says otherwise.

### 11.8 Damage Threshold (p. 180)

Some creatures/objects: ignore all damage from a single attack/effect that doesn't meet or exceed the threshold. If damage ≥ threshold → take all damage.

---

## 12. Hit Points & Death (pp. 16-18)

### 12.1 HP basics

- Maximum HP = sum of class base + CON mod each level.
- **Bloodied** = current HP ≤ 1⁄2 max HP. No mechanical effect on its own; some abilities trigger.

### 12.2 Level 1 HP

```
L1 HP = ClassBaseHP + CON mod
  Barbarian: 12 + CON
  Fighter/Paladin/Ranger: 10 + CON
  Bard/Cleric/Druid/Monk/Rogue/Warlock: 8 + CON
  Sorcerer/Wizard: 6 + CON
```

### 12.3 HP per Level After 1

- Roll Hit Die + CON (min 1), OR take fixed value (typically die-average + 1) per class table.

```
Fixed values:
  Barbarian: 7 + CON (d12)
  Fighter/Paladin/Ranger: 6 + CON (d10)
  Bard/Cleric/Druid/Monk/Rogue/Warlock: 5 + CON (d8)
  Sorcerer/Wizard: 4 + CON (d6)
```

### 12.4 Dropping to 0 HP — PCs

PC drops to 0 → **Unconscious** condition. Then:

#### Death Saving Throws (p. 17)

Each turn at 0 HP, roll 1d20 (no modifiers):

- **≥ 10:** success
- **< 10:** failure
- **Natural 20:** regain 1 HP (cancels DSTs).
- **Natural 1:** counts as **two failures**.
- **Damage at 0 HP:** 1 failure. **Critical Hit damage:** 2 failures. Damage ≥ max HP: instant death.

3 successes → **Stable** (Unconscious; DST stops).
3 failures → **die**.
Successes/failures don't need to be consecutive; both reset on regaining HP or becoming Stable.

#### Stabilizing (p. 18)

- Help action with successful **DC 10 WIS(Medicine)** check → Stable.
- Stable creature: still Unconscious. Regains 1 HP after **1d4 hours**.
- Damage to Stable creature → loses Stable, resumes DSTs.

#### Knocking Out (p. 17 sidebar)

Melee attack reducing creature to 0 HP: attacker may choose to instead leave creature at **1 HP + Unconscious**, who then begins a Short Rest.

### 12.5 Dropping to 0 HP — Monsters

Monsters die at 0 HP (GM may treat any monster as PC for narrative reasons).

Special exception: HP max reduced to 0 (life-drain) → die.

**Massive Damage:** at any HP, if damage taken from a single blow ≥ HP max, character dies instantly even if not yet at 0.

### 12.6 Healing (p. 17)

- Various magic heals (`Cure Wounds`, `Potion of Healing`).
- Restoring HP can't exceed max.
- Excess healing is lost.

### 12.7 Temporary HP (p. 18)

- Buffer; lost before real HP.
- **Don't stack:** when granted new temp HP, choose which set to keep (don't add).
- **Aren't healing:** can't be added to current HP; healing doesn't grant temp HP.
- Last until depleted or finishing a Long Rest.
- Receiving temp HP at 0 HP doesn't restore consciousness.

---

## 13. Rests (pp. 185, 187)

### 13.1 Short Rest (p. 187)

- Duration: **1 hour** of low activity (eat, drink, read, watch).
- Must start with ≥ 1 HP.
- **Spend Hit Dice** to heal: each spent die = (HD roll + CON mod, min 1) HP. Decide one die at a time.
- Recharges some "per Short Rest" features.
- **Interruptions:** rolling Initiative, casting non-cantrip, taking damage.

### 13.2 Long Rest (p. 185)

- Duration: **8 hours** = 6 sleep + 2 light activity (reading, talking, eating, watch).
- During sleep: **Unconscious**.
- Must wait 16 hours after a Long Rest to start another.
- Must start with ≥ 1 HP.

#### Benefits

- Regain all HP.
- Regain spent Hit Dice up to **half class max** (round up).
- Restore reduced ability scores, restore HP max if reduced.
- Reduce Exhaustion by 1 level.
- Restore all spell slots.
- Recharge "per Long Rest" features.

#### Interruptions

- Rolling Initiative, casting any spell, taking damage, 1+ hour of walking/exertion.
- If interrupted but ≥ 1 hour rest before interruption: gain Short Rest benefits.
- Resume immediately after interruption: rest takes 1 additional hour per interruption.

---

## 14. Conditions (pp. 178-191)

15 conditions. Don't stack with self (creature has it or doesn't), except **Exhaustion** which is cumulative 0-6.

### 14.1 List

| Condition | Effect summary |
|---|---|
| **Blinded** | Can't see; auto-fail sight checks. Attacks vs you have Adv; your attacks have Disadv. |
| **Charmed** | Can't attack the charmer or target with damaging abilities. Charmer has Adv on social checks vs you. |
| **Deafened** | Can't hear; auto-fail hearing checks. |
| **Exhaustion (1-6)** | Cumulative. D20 Tests reduced by **2 × level**. Speed reduced by **5 ft × level**. Die at level 6. |
| **Frightened** | Disadv on checks/attacks while source in line of sight. Can't willingly move closer to source. |
| **Grappled** | Speed 0. Disadv attacks vs targets other than grappler. Movable by grappler at +1 ft cost (unless smaller by 2+). |
| **Incapacitated** | No action/bonus/reaction. Concentration broken. Can't speak. Disadv on Initiative if rolling. |
| **Invisible** | Heavily Obscured for finding. Adv on Initiative. Concealed (immune to "see" requirement effects). Attacks vs you Disadv; your attacks Adv (unless target somehow sees you). |
| **Paralyzed** | Incapacitated + Speed 0 + auto-fail STR/DEX saves. Attacks vs you Adv. Auto-Crit if attacker within 5 ft. |
| **Petrified** | Transformed to stone (×10 weight, no aging). Incapacitated + Speed 0. Attacks vs you Adv. Auto-fail STR/DEX saves. **Resistance to all damage.** Immunity to Poison. |
| **Poisoned** | Disadv on attacks and ability checks. |
| **Prone** | Can only crawl or stand-up (½ Speed). Disadv on attack rolls. Attacks vs you within 5 ft Adv; beyond 5 ft Disadv. |
| **Restrained** | Speed 0. Attacks vs you Adv; your attacks Disadv. Disadv on DEX saves. |
| **Stunned** | Incapacitated. Auto-fail STR/DEX saves. Attacks vs you Adv. |
| **Unconscious** | Incapacitated, Prone, drop carried items. Speed 0. Attacks vs you Adv. Auto-fail STR/DEX saves. Auto-Crit if attacker within 5 ft. Unaware of surroundings. |

### 14.2 Stacking rule

- Stacking is binary except Exhaustion: a creature has a condition or doesn't. Re-applying does nothing extra.

---

## 15. Hiding & Detection (pp. 11, 183, 186-187)

### 15.1 Hide action (p. 183)

- DC 15 DEX (Stealth) check.
- Required environment: **Heavily Obscured** OR behind **3⁄4 Cover** OR **Total Cover**, AND out of any enemy's line of sight.
- On success: gain **Invisible** condition while hidden.
- Note your check total — that is the DC for a creature using Perception to find you.
- **Stop being hidden** if: you make a sound louder than a whisper, an enemy finds you, you make an attack roll, you cast a Verbal spell.

### 15.2 Search action (p. 187)

WIS check, suggested skills:
- Insight → state of mind
- Medicine → cause of death/illness
- Perception → concealed creature/object
- Survival → tracks/foraging

### 15.3 Passive Perception

See §4.2.

---

## 16. Character Creation (pp. 19-22)

### 16.1 Five Steps

1. **Choose a Class.** (12 options)
2. **Determine Origin** = Background + Species + 2 Languages.
3. **Determine Ability Scores.** (Standard Array OR Random OR Point Buy).
4. **Choose Alignment.**
5. **Fill Details.** HP, AC, Initiative, attacks, proficiencies.

### 16.2 Class Overview (p. 19)

| Class | Likes... | Primary Ability | Complexity |
|---|---|---|---|
| Barbarian | Battle | STR | Average |
| Bard | Performing | CHA | High |
| Cleric | Gods | WIS | Average |
| Druid | Nature | WIS | High |
| Fighter | Weapons | STR or DEX | Low |
| Monk | Unarmed combat | DEX + WIS | High |
| Paladin | Defense | STR + CHA | Average |
| Ranger | Survival | DEX + WIS | Average |
| Rogue | Stealth | DEX | Low |
| Sorcerer | Power | CHA | High |
| Warlock | Occult lore | CHA | High |
| Wizard | Spellbooks | INT | Average |

### 16.3 Background (p. 19)

- Provides 3 ability boosts (+2 / +1 OR +1 / +1 / +1; max raise above 20 disallowed).
- Grants **1 Origin Feat**.
- Grants **2 skill proficiencies**.
- Grants **1 tool proficiency** (specific or chosen from Artisan's Tools).
- Provides starting equipment package A/B (one option = items + GP, other option = 50 GP).

### 16.4 Species (p. 20)

- Determines: Creature Type (typically Humanoid for SRD species), Size, Speed, Special Traits.
- See §21 for full species list.

### 16.5 Languages (p. 20)

- Every PC knows **Common** + 2 standard languages of choice.

**Standard:** Common, Common Sign, Draconic, Dwarvish, Elvish, Giant, Gnomish, Goblin, Halfling, Orc.
**Rare:** Abyssal, Celestial, Deep Speech, Druidic, Infernal, Primordial (incl. Aquan/Auran/Ignan/Terran dialects), Sylvan, Thieves' Cant, Undercommon.

### 16.6 Ability Score Generation (p. 21)

Three methods (GM picks, or by group):

#### A. Standard Array

Use **15, 14, 13, 12, 10, 8** in any assignment.

#### B. Random Generation

Roll **4d6, drop lowest** → ability total. Repeat **6 times**.

#### C. Point Buy (27 points)

| Score | Cost | Score | Cost |
|---|---|---|---|
| 8 | 0 | 12 | 4 |
| 9 | 1 | 13 | 5 |
| 10 | 2 | 14 | 7 |
| 11 | 3 | 15 | 9 |

Distribute 27 points; min 8, max 15 before background bonus.

#### Standard Array suggestion by class (p. 21)

| Class | STR | DEX | CON | INT | WIS | CHA |
|---|---|---|---|---|---|---|
| Barbarian | 15 | 13 | 14 | 10 | 12 | 8 |
| Bard | 8 | 14 | 12 | 13 | 10 | 15 |
| Cleric | 14 | 8 | 13 | 10 | 15 | 12 |
| Druid | 8 | 12 | 14 | 13 | 15 | 10 |
| Fighter | 15 | 14 | 13 | 8 | 10 | 12 |
| Monk | 12 | 15 | 13 | 10 | 14 | 8 |
| Paladin | 15 | 10 | 13 | 8 | 12 | 14 |
| Ranger | 12 | 15 | 13 | 8 | 14 | 10 |
| Rogue | 12 | 15 | 13 | 14 | 10 | 8 |
| Sorcerer | 10 | 13 | 14 | 8 | 12 | 15 |
| Warlock | 8 | 14 | 13 | 12 | 10 | 15 |
| Wizard | 8 | 12 | 13 | 15 | 14 | 10 |

#### Adjust per Background

After picking scores, apply background's +2/+1 OR +1/+1/+1 (no score above 20).

### 16.7 Alignment (p. 21)

Two axes: **Lawful/Neutral/Chaotic** × **Good/Neutral/Evil** = 9 alignments. Plus **Unaligned** for non-sapient creatures.

### 16.8 Step 5: Fill Details (p. 22)

Calculate and record:

```
Saving Throws (per class proficiency)        = ability mod + PB
Skills proficient                            = ability mod + PB
Passive Perception                           = 10 + WIS(Perception)
Hit Points                                   = (see §12.2)
Hit Dice                                     = 1 die at L1 (per class HD type)
Initiative                                   = DEX modifier
Armor Class                                  = (see §19)
Melee attack bonus                           = STR mod + PB (if proficient)
Ranged attack bonus                          = DEX mod + PB (if proficient)
Weapon damage                                = die + same ability mod
Spell save DC                                = 8 + spell ability mod + PB
Spell attack bonus                           = spell ability mod + PB
Spell slots, cantrips, prepared              = per class table
```

---

## 17. Multiclassing (pp. 24-25)

### 17.1 Prerequisites

To gain a level in a new class: **score ≥ 13** in the **primary ability of both** current and new class.

### 17.2 Hit Points & Hit Dice

- Gain HP per new class as if leveling up (not Lvl 1 HP).
- Pool same HD types together; track different types separately.

### 17.3 Proficiency Bonus

Based on **total character level**, not per-class level.

### 17.4 Proficiencies When Adding a Class

Only a subset of new class's starting profs (per class description; not all).

### 17.5 Class Features

Get features at each new class level, with these special rules:

#### Extra Attack

- Doesn't stack across classes.
- Cap = highest single-class Extra Attack count (Fighter L20 = 4 attacks; multiclass Fighter+Ranger ≠ 5).

#### Spellcasting (Multiclass Spellcaster Slots)

```
Multiclass spell-slot caster level =
  (Bard + Cleric + Druid + Sorcerer + Wizard levels)
  + ½ (Paladin + Ranger levels)        round down
  + (full Wizard levels)
  + (full Warlock - NOT included; uses Pact Magic separately)
```

(Note: Warlock's Pact Magic is **separate** from Spellcasting.)

Use this combined level on the **Multiclass Spellcaster: Spell Slots per Spell Level** table:

| Lvl | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 2 | – | – | – | – | – | – | – | – |
| 2 | 3 | – | – | – | – | – | – | – | – |
| 3 | 4 | 2 | – | – | – | – | – | – | – |
| 4 | 4 | 3 | – | – | – | – | – | – | – |
| 5 | 4 | 3 | 2 | – | – | – | – | – | – |
| 6 | 4 | 3 | 3 | – | – | – | – | – | – |
| 7 | 4 | 3 | 3 | 1 | – | – | – | – | – |
| 8 | 4 | 3 | 3 | 2 | – | – | – | – | – |
| 9 | 4 | 3 | 3 | 3 | 1 | – | – | – | – |
| 10 | 4 | 3 | 3 | 3 | 2 | – | – | – | – |
| 11 | 4 | 3 | 3 | 3 | 2 | 1 | – | – | – |
| 12 | 4 | 3 | 3 | 3 | 2 | 1 | – | – | – |
| 13 | 4 | 3 | 3 | 3 | 2 | 1 | 1 | – | – |
| 14 | 4 | 3 | 3 | 3 | 2 | 1 | 1 | – | – |
| 15 | 4 | 3 | 3 | 3 | 2 | 1 | 1 | 1 | – |
| 16 | 4 | 3 | 3 | 3 | 2 | 1 | 1 | 1 | – |
| 17 | 4 | 3 | 3 | 3 | 2 | 1 | 1 | 1 | 1 |
| 18 | 4 | 3 | 3 | 3 | 3 | 1 | 1 | 1 | 1 |
| 19 | 4 | 3 | 3 | 3 | 3 | 2 | 1 | 1 | 1 |
| 20 | 4 | 3 | 3 | 3 | 3 | 2 | 2 | 1 | 1 |

#### Spells Prepared

Calculated per class as if single-classed at that class level.

#### Pact Magic + Spellcasting Interaction

Pact slots and Spellcasting slots can be used to cast each other's spells (subject to spell preparation rules).

#### Armor Class

Multiple "alternate AC" features (Unarmored Defense + Draconic Resilience etc.) → choose **only one** active at a time.

---

## 18. Level Advancement & Tiers of Play (pp. 22-24)

### 18.1 XP Table

| Level | XP | PB | Level | XP | PB |
|---|---|---|---|---|---|
| 1 | 0 | +2 | 11 | 85,000 | +4 |
| 2 | 300 | +2 | 12 | 100,000 | +4 |
| 3 | 900 | +2 | 13 | 120,000 | +5 |
| 4 | 2,700 | +2 | 14 | 140,000 | +5 |
| 5 | 6,500 | +3 | 15 | 165,000 | +5 |
| 6 | 14,000 | +3 | 16 | 195,000 | +5 |
| 7 | 23,000 | +3 | 17 | 225,000 | +6 |
| 8 | 34,000 | +3 | 18 | 265,000 | +6 |
| 9 | 48,000 | +4 | 19 | 305,000 | +6 |
| 10 | 64,000 | +4 | 20 | 355,000 | +6 |

### 18.2 On Level Up

1. Choose class (existing or multiclass).
2. Gain HP (HD roll or fixed value, +CON mod, min 1). If CON mod increases at this level via ASI, retroactively add 1 HP per past level.
3. Record new class features.
4. Adjust PB if it bumped (levels 5/9/13/17).
5. Apply Ability Score Improvement / Feat (if class table grants this level).

### 18.3 Tiers of Play (p. 24)

| Tier | Levels | Description |
|---|---|---|
| 1 | 1-4 | Apprentice adventurers; local threats |
| 2 | 5-10 | Full-fledged; iconic spells (Fireball, Lightning Bolt, Raise Dead); city/kingdom threats |
| 3 | 11-16 | Special among adventurers; reality-altering spells; regional threats |
| 4 | 17-20 | Pinnacle of class features; world/multiverse-fate stakes |

### 18.4 Starting at Higher Levels (p. 24)

| Starting Level | Bonus Equipment & Money | Magic Items |
|---|---|---|
| 2-4 | normal starting | 1 Common |
| 5-10 | 500 GP + 1d10×25 GP + normal | 1 Common, 1 Uncommon |
| 11-16 | 5,000 GP + 1d10×250 GP + normal | 2 Common, 3 Uncommon, 1 Rare |
| 17-20 | 20,000 GP + 1d10×250 GP + normal | 2 Common, 4 Uncommon, 3 Rare, 1 Very Rare |

### 18.5 Bonus Feats at Lvl 20 (p. 24 sidebar)

Optional rule: 1 Epic Boon-eligible feat per 30,000 XP earned above 355,000.

---

## 19. Class Structure Reference (pp. 28-82, structural only)

Per-class feature listings live in **package data**. This section only documents the structural shape every class follows.

### 19.1 Class Data Shape

```
Class {
  name                    : String
  primaryAbility          : Set<Ability>             // 1 or 2 abilities
  hitDie                  : DieType                   // d6/d8/d10/d12
  savingThrowProficiencies: Set<Ability>             // exactly 2
  skillProficiencyChoices : SkillChoice              // "choose N from list"
  weaponProficiencies     : List<WeaponCategory>     // Simple, Martial, specific
  toolProficiencies       : List<ToolType>           // optional
  armorTraining           : Set<ArmorCategory>       // Light/Medium/Heavy/Shield (or None)
  startingEquipmentOptions: List<EquipmentBundle>    // A / B / C
  features                : Map<int level, List<Feature>>
  subclassChoiceLevel     : int                       // typically 3
  subclasses              : List<Subclass>
  // For casters:
  spellList               : List<SpellRef>
  cantripsKnownByLevel    : Map<int, int>
  preparedSpellsByLevel   : Map<int, int>
  spellSlotsByLevel       : Map<int, List<int>>      // [L1slots, L2slots, ...]
}
```

### 19.2 Class Level Table — Common Columns

Every class level table has:

| Always Present | Caster-Only |
|---|---|
| Level (1-20) | Cantrips Known |
| Proficiency Bonus | Prepared Spells (or Spells Known) |
| Class Features (list per row) | Spell Slots per Level (1-9) |

Class-specific columns add per-class resources (Rages, Hit Dice subtype, Bardic Inspiration, Channel Divinity, Sorcery Points, Pact Magic Slots, Ki/Focus Points, Rage Damage, Weapon Mastery count, Martial Arts die, Unarmored Movement, etc.)

### 19.3 Subclass Pattern

- Player chooses a subclass at a defined level (typically lvl 3 for most; lvl 1 for some, lvl 2 for some).
- Subclass grants features at additional class levels (typically 3, 6 or 7, 10, 14 or 15, 18).
- Each feature interlocks with class core resources.

### 19.4 Three Sample Class Tables (Documentation Only)

To illustrate structure (per pp. 28-30, 47-48, 77-78). Per-feature *content* belongs in package data.

#### 19.4.1 Barbarian (Hit Die: d12, primary STR)

- Saves: STR, CON.
- Armor: Light, Medium, Shields.
- Weapons: Simple, Martial.
- Skill choices: 2 from {Animal Handling, Athletics, Intimidation, Nature, Perception, Survival}.
- Subclass at level 3.
- Class-specific resources: **Rages** (per long rest count), **Rage Damage** (bonus), **Weapon Mastery** count.
- Notable mechanics: Rage (Bonus Action; resistance to BPS damage; STR Adv on checks/saves; +damage; can't cast/concentrate; ends if turn passes without specified extension).

#### 19.4.2 Fighter (Hit Die: d10, primary STR or DEX)

- Saves: STR, CON.
- Armor: Light, Medium, Heavy, Shields.
- Weapons: Simple, Martial.
- Skill choices: 2 from {Acrobatics, Animal Handling, Athletics, History, Insight, Intimidation, Persuasion, Perception, Survival}.
- Subclass at level 3.
- Class-specific resources: **Second Wind** uses, **Action Surge** uses, **Indomitable** uses, **Weapon Mastery** count.
- Notable mechanics: Fighting Style feat at L1; Extra Attack at L5 (+1 attack), L11 (Two Extra), L20 (Three Extra).

#### 19.4.3 Wizard (Hit Die: d6, primary INT)

- Saves: INT, WIS.
- Armor: None.
- Weapons: Simple.
- Skill choices: 2 from {Arcana, History, Insight, Investigation, Medicine, Nature, Religion}.
- Subclass at level 3.
- Spell slots: full caster (matches the "full caster" template: 2 L1 slots @ L1, scaling to 4-3-3-3-3-2-2-1-1 by L20).
- Cantrips known: 3 → 4 (L4) → 5 (L10).
- Prepared spells: 4 (L1) → 25 (L20).
- Class resources: **Spellbook**, **Arcane Recovery** (Short Rest, recover spell slots up to ½ class lvl, max L5).
- Notable mechanics: Ritual Adept (cast any ritual from spellbook even if not prepared); Memorize Spell (Short Rest swap); Spell Mastery (L18, 1 L1 + 1 L2 cast at-will); Signature Spells (L20, 2 L3 spells free 1×/Short Rest).

---

## 20. Origins: Backgrounds (p. 83)

Each background provides:

```
Background {
  name                : String
  abilityBoosts       : List<Ability>            // 3 abilities; player picks +2/+1 or +1/+1/+1
  originFeat          : Feat
  skillProficiencies  : List<Skill>              // exactly 2
  toolProficiency     : ToolType                  // 1 (specific or chosen)
  equipmentOptionA    : List<Item> + GoldAmount
  equipmentOptionB    : 50 GP
}
```

### 20.1 SRD Backgrounds

| Background | Abilities | Origin Feat | Skills | Tool |
|---|---|---|---|---|
| Acolyte | INT, WIS, CHA | Magic Initiate (Cleric) | Insight, Religion | Calligrapher's Supplies |
| Criminal | DEX, CON, INT | Alert | Sleight of Hand, Stealth | Thieves' Tools |
| Sage | CON, INT, WIS | Magic Initiate (Wizard) | Arcana, History | Calligrapher's Supplies |
| Soldier | STR, DEX, CON | Savage Attacker | Athletics, Intimidation | Choose 1 Gaming Set |

---

## 21. Origins: Species (pp. 83-86)

Each species provides:

```
Species {
  name             : String
  creatureType     : CreatureType   // Humanoid for all SRD species
  size             : SizeOption      // typically Medium; some Small or "Small/Medium choice"
  baseSpeed        : feet
  specialTraits    : List<Trait>
  lineageOptions   : List<Lineage>?  // some species
}
```

### 21.1 SRD Species List (9 total)

| Species | Size | Speed | Notable Traits | Lineage Options |
|---|---|---|---|---|
| **Dragonborn** | Medium (5-7 ft) | 30 | Draconic Ancestry (10 dragons → damage type), Breath Weapon (15-ft Cone OR 30-ft Line; DC 8+CON+PB; 1d10 lvl 1, scales 5/11/17), Damage Resistance (matches ancestry), Darkvision 60, Draconic Flight (lvl 5; Bonus Action wings, Speed = Speed for 10 min, 1/long rest) | — |
| **Dwarf** | Medium (4-5 ft) | 30 | Darkvision 120, Dwarven Resilience (Poison resistance + Adv vs Poisoned), Dwarven Toughness (+1 HP/level), Stonecunning (Bonus Action 60-ft Tremorsense for 10 min while on stone, PB uses/long rest) | — |
| **Elf** | Medium (5-6 ft) | 30 | Darkvision 60, Elven Lineage (Drow/High/Wood — see below), Fey Ancestry (Adv vs Charmed), Keen Senses (Insight/Perception/Survival prof), Trance (Long Rest = 4 hrs in trance) | Drow / High / Wood |
| **Gnome** | Small (3-4 ft) | 30 | Darkvision 60, Gnomish Cunning (Adv on INT/WIS/CHA saves), Gnomish Lineage (Forest/Rock) | Forest / Rock |
| **Goliath** | Medium (7-8 ft) | 35 | Giant Ancestry (6 boon options — Cloud's Jaunt, Fire's Burn, Frost's Chill, Hill's Tumble, Stone's Endurance, Storm's Thunder; PB uses/long rest), Large Form (lvl 5; Bonus Action become Large 10 min, +Adv STR checks, +10 ft Speed, 1/long rest), Powerful Build (Adv vs Grappled end; counts 1 size larger for carrying) | — |
| **Halfling** | Small (2-3 ft) | 30 | Brave (Adv vs Frightened), Halfling Nimbleness (move through space of larger creatures), Luck (reroll natural 1 on D20 Test, must use new), Naturally Stealthy (Hide while obscured by creature 1+ size larger) | — |
| **Human** | Medium or Small (chosen) | 30 | Resourceful (Heroic Inspiration on Long Rest), Skillful (1 skill prof), Versatile (Origin Feat) | — |
| **Orc** | Medium (6-7 ft) | 30 | Adrenaline Rush (Bonus Action Dash + temp HP = PB; PB uses/short or long rest), Darkvision 120, Relentless Endurance (drop to 1 HP instead of 0; 1/long rest) | — |
| **Tiefling** | Medium or Small (chosen) | 30 | Darkvision 60, Fiendish Legacy (Abyssal/Chthonic/Infernal — see below), Otherworldly Presence (Thaumaturgy cantrip via legacy ability) | Abyssal / Chthonic / Infernal |

### 21.2 Lineage Tables

#### Elven Lineages

| Lineage | L1 | L3 | L5 |
|---|---|---|---|
| Drow | Darkvision range → 120 ft; *Dancing Lights* cantrip | *Faerie Fire* | *Darkness* |
| High Elf | *Prestidigitation* cantrip; swap on Long Rest with another Wizard cantrip | *Detect Magic* | *Misty Step* |
| Wood Elf | Speed +5 ft (35 ft); *Druidcraft* cantrip | *Longstrider* | *Pass without Trace* |

Spellcasting ability: chosen INT/WIS/CHA when picking lineage.

#### Gnomish Lineages

| Lineage | Traits |
|---|---|
| Forest Gnome | *Minor Illusion* cantrip; *Speak with Animals* always prepared, free 1× per long rest (or via slots) |
| Rock Gnome | *Mending* + *Prestidigitation* cantrips; Tinker (10 min Prestidigitation → Tiny clockwork device, AC 5, 1 HP, 8 hr lifetime, 3 simultaneous) |

#### Tiefling Fiendish Legacies

| Legacy | L1 | L3 | L5 |
|---|---|---|---|
| Abyssal | Resistance to Poison; *Poison Spray* cantrip | *Ray of Sickness* | *Hold Person* |
| Chthonic | Resistance to Necrotic; *Chill Touch* cantrip | *False Life* | *Ray of Enfeeblement* |
| Infernal | Resistance to Fire; *Fire Bolt* cantrip | *Hellish Rebuke* | *Darkness* |

Spellcasting ability: chosen INT/WIS/CHA when picking legacy. *Thaumaturgy* uses same ability via Otherworldly Presence.

#### Goliath Giant Ancestries

| Ancestry | Benefit |
|---|---|
| Cloud Giant | Cloud's Jaunt (Bonus Action teleport up to 30 ft) |
| Fire Giant | Fire's Burn (+1d10 Fire on weapon hit) |
| Frost Giant | Frost's Chill (+1d6 Cold on weapon hit + Speed -10 ft) |
| Hill Giant | Hill's Tumble (Large or smaller hit by attack → Prone) |
| Stone Giant | Stone's Endurance (Reaction; 1d12 + CON reduction to incoming damage) |
| Storm Giant | Storm's Thunder (Reaction; if creature within 60 ft damages you → 1d8 Thunder back) |

---

## 22. Feats (pp. 87-88)

### 22.1 Categories

```
FeatCategory ::= Origin | General | FightingStyle | EpicBoon
```

- **Origin** feats: prerequisite for backgrounds; granted at character creation.
- **General** feats: prerequisite Level 4+; gained via class's ASI feature.
- **FightingStyle** feats: prerequisite "Fighting Style feature" (Fighter L1, Paladin L2, Ranger L2).
- **EpicBoon** feats: prerequisite Level 19+; granted by class Epic Boon feature.

### 22.2 Feat Data Shape

```
Feat {
  name           : String
  category       : FeatCategory
  prerequisites  : List<Prerequisite>     // level, ability score, class, feature, skill, etc.
  benefits       : List<Benefit>           // includes ASI, special rules
  repeatable     : Boolean                  // true allows multiple takings
}
```

### 22.3 Repeatable Feats

Some feats have a **Repeatable** subsection: can take more than once, each taking provides the benefit (often picking a different option).

### 22.4 SRD Feats Catalog (overview)

- **Origin:** Alert, Magic Initiate, Savage Attacker, Skilled (Repeatable).
- **General:** Ability Score Improvement (Repeatable; +2 to one ability or +1 to two; max 20), Grappler (others detailed in full SRD).
- **Fighting Style:** Archery, Defense, Great Weapon Fighting, Two-Weapon Fighting (others detailed in full SRD).
- **Epic Boon:** Combat Prowess, Dimensional Travel, Fate, Irresistible Offense, Spell Recall, Night Spirit, Truesight (each grants +1 to one ability up to 30 + a major ability).

---

## 23. Equipment

### 23.1 Coins (p. 89)

| Coin | Value in GP |
|---|---|
| Copper Piece (CP) | 1/100 |
| Silver Piece (SP) | 1/10 |
| Electrum Piece (EP) | 1/2 |
| Gold Piece (GP) | 1 |
| Platinum Piece (PP) | 10 |

Weight: 50 coins ≈ 1 lb.

### 23.2 Weapons (pp. 89-91)

#### Categorization

```
Category   : Simple | Martial
Type       : Melee | Ranged
```

#### Properties

| Property | Effect |
|---|---|
| **Ammunition** | Requires correct ammo; drawing is part of attack; 1 min to recover ½ used. |
| **Finesse** | Player chooses STR or DEX for both attack and damage rolls; same mod for both. |
| **Heavy** | Disadv on attack rolls if STR or DEX < 13 (melee=STR, ranged=DEX). |
| **Light** | Eligible for off-hand bonus action attack with another Light weapon; no ability mod to off-hand damage unless negative. |
| **Loading** | Only 1 shot per Action / Bonus Action / Reaction. |
| **Range (X/Y)** | Normal X / long Y feet; Disadv beyond X; can't shoot beyond Y. |
| **Reach** | +5 ft melee reach (and OAs). |
| **Thrown** | Can throw as ranged attack; melee Thrown uses melee ability mod. |
| **Two-Handed** | Both hands required to attack. |
| **Versatile (X)** | One-handed: normal die. Two-handed: die X. |

#### Mastery Properties

Mastery requires **Weapon Mastery** feature (Barbarian L1, Fighter L1, Paladin L1, Ranger L1; some others). Each weapon has exactly one mastery.

| Mastery | Effect |
|---|---|
| **Cleave** | On melee hit: extra attack roll vs second creature within 5 ft (no ability mod to damage unless negative). 1×/turn. |
| **Graze** | On miss: deal damage equal to ability modifier (same type as weapon). |
| **Nick** | When making the Light off-hand attack, take it as part of the Attack action (not Bonus). 1×/turn. |
| **Push** | On hit: push Large or smaller target 10 ft straight away. |
| **Sap** | On hit: target Disadv on its next attack roll before start of your next turn. |
| **Slow** | On hit + damage: target's Speed -10 ft until start of your next turn (cap -10 from this property per round). |
| **Topple** | On hit: target CON save (DC 8 + ability mod + PB) or **Prone**. |
| **Vex** | On hit + damage: Adv on your next attack roll vs same target before end of your next turn. |

#### Weapon Reference Table (full SRD list, structural reference)

```
Simple Melee:    Club, Dagger, Greatclub, Handaxe, Javelin, Light Hammer, Mace, Quarterstaff, Sickle, Spear
Simple Ranged:   Dart, Light Crossbow, Shortbow, Sling
Martial Melee:   Battleaxe, Flail, Glaive, Greataxe, Greatsword, Halberd, Lance, Longsword, Maul, Morningstar, Pike, Rapier, Scimitar, Shortsword, Trident, Warhammer, War Pick, Whip
Martial Ranged:  Blowgun, Hand Crossbow, Heavy Crossbow, Longbow, Musket, Pistol
```

(Exact damage / properties / mastery / weight / cost values live in the weapons package data.)

### 23.3 Armor (p. 92)

#### Armor Categories

```
Light  | Medium | Heavy | Shield
```

#### Don/Doff Times

| Category | Don | Doff |
|---|---|---|
| Light | 1 min | 1 min |
| Medium | 5 min | 1 min |
| Heavy | 10 min | 5 min |
| Shield | Utilize action | Utilize action |

#### AC Formulas

```
Light Armor AC          = base + DEX mod
Medium Armor AC         = base + min(DEX mod, +2)
Heavy Armor AC          = base (no DEX)
Shield                  = +2 AC (only one shield at a time; only one armor at a time)
Unarmored Defense       = 10 + DEX + (CON or WIS or CHA, per class feature)   // pick ONE base AC formula
```

#### Armor Stealth

Some armor types impose Disadvantage on DEX(Stealth).

#### Armor Strength Requirement

Heavy armor with STR requirement: if your STR < req, your Speed reduces by 10 ft.

#### Armor Training

Without training in the armor you wear (or shield):
- Disadv on all D20 Tests using STR or DEX.
- Cannot cast spells.
Without shield training:
- No AC bonus from shield.

#### Armor Reference Table

```
Light:    Padded(11+DEX, stealth disadv), Leather(11+DEX), Studded(12+DEX)
Medium:   Hide(12+DEX), Chain Shirt(13+DEX), Scale Mail(14+DEX, stealth), Breastplate(14+DEX), Half Plate(15+DEX, stealth)
Heavy:    Ring Mail(14, stealth), Chain Mail(16, STR 13, stealth), Splint(17, STR 15, stealth), Plate(18, STR 15, stealth)
Shield:   +2 AC
```

(Exact weights/costs in armor package data.)

### 23.4 Tools (pp. 93-94)

```
Tool {
  name              : String
  ability           : Ability        // for tool ability check
  utilizeAction     : { description, DC }
  craftableItems    : List<ItemRef>
  variants          : List<Tool>?    // e.g., Gaming Set: dice/playing cards/3-dragon-ante
}
```

#### Categories

- **Artisan's Tools:** 16 types — Alchemist's Supplies, Brewer's Supplies, Calligrapher's Supplies, Carpenter's Tools, Cartographer's Tools, Cobbler's Tools, Cook's Utensils, Glassblower's Tools, Jeweler's Tools, Leatherworker's Tools, Mason's Tools, Painter's Supplies, Potter's Tools, Smith's Tools, Tinker's Tools, Weaver's Tools, Woodcarver's Tools.
- **Other Tools:** Disguise Kit, Forgery Kit, Gaming Set, Herbalism Kit, Musical Instrument, Navigator's Tools, Poisoner's Kit, Thieves' Tools.

#### Tool + Skill Stacking

If you have **both** tool proficiency and skill proficiency on the same check → **Advantage** on the check.

### 23.5 Adventuring Gear (pp. 94-99)

Long alphabetical list of gear (Acid, Alchemist's Fire, Caltrops, Healer's Kit, Holy Water, Manacles, Net, Oil, Potion of Healing, Spell Scroll, etc.). Items with unique mechanics include damage formulas, save DCs, Utilize actions, etc.

Notable mechanics-heavy items (full text in package data):

- **Healer's Kit (5 GP, 10 uses):** Utilize → stabilize Unconscious creature without WIS(Medicine) check.
- **Potion of Healing (50 GP):** Bonus Action drink/administer; regain 2d4+2 HP.
- **Spell Scroll (Cantrip 30 GP / Level 1 50 GP):** any spellcasting class on its list reads → cast at lowest level. DC 13, attack +5. Disintegrates on use.
- **Component Pouch / Arcane Focus / Druidic Focus / Holy Symbol:** stand-in for material components without listed cost.
- **Manacles, Net, Caltrops, Ball Bearings, Oil, Acid, Alchemist's Fire, Holy Water:** thrown attack forms with their own DCs and damage.

### 23.6 Mounts & Vehicles (pp. 100-101)

- Animals (Camel, Elephant, Horse Draft/Riding, Mastiff, Mule, Pony, Warhorse) with carrying capacity and cost.
- Tack/Harness/Drawn Vehicles (Carriage, Cart, Chariot, Sled, Wagon, Saddles).
- Saddle types: Riding, Military (Adv on stay-mounted checks), Exotic (required for aquatic/flying mounts).
- Barding: armor for mounts (4× cost, 2× weight).
- Mount cargo: pulls 5× base carrying capacity.

#### Large Vehicles (Airborne/Waterborne)

| Ship | Speed | Crew | Passengers | Cargo (T) | AC | HP | Damage Threshold | Cost |
|---|---|---|---|---|---|---|---|---|
| Airship | 8 mph | 10 | 20 | 1 | 13 | 300 | — | 40,000 GP |
| Galley | 4 mph | 80 | — | 150 | 15 | 500 | 20 | 30,000 GP |
| Keelboat | 1 mph | 1 | 6 | 0.5 | 15 | 100 | 10 | 3,000 GP |
| Longship | 3 mph | 40 | 150 | 10 | 15 | 300 | 15 | 10,000 GP |
| Rowboat | 1.5 mph | 1 | 3 | — | 11 | 50 | — | 50 GP |
| Sailing Ship | 2 mph | 20 | 20 | 100 | 15 | 300 | 15 | 10,000 GP |
| Warship | 2.5 mph | 60 | 60 | 200 | 15 | 500 | 20 | 25,000 GP |

Ship Repair: 1 HP / day / 20 GP (halved in city).

### 23.7 Lifestyle Expenses (p. 101)

Per-day cost: Wretched (free), Squalid (1 SP), Poor (2 SP), Modest (1 GP), Comfortable (2 GP), Wealthy (4 GP), Aristocratic (10 GP).

### 23.8 Hirelings (p. 102)

| Service | Cost |
|---|---|
| Skilled hireling | 2 GP/day (minimum) |
| Untrained hireling | 2 SP/day |
| Messenger | 2 CP/mile |

### 23.9 Spellcasting Services (p. 102)

| Spell Level | Availability | Cost |
|---|---|---|
| Cantrip | Village/town/city | 30 GP |
| 1 | Village/town/city | 50 GP |
| 2 | Village/town/city | 200 GP |
| 3 | Town/city | 300 GP |
| 4-5 | Town/city | 2,000 GP |
| 6-8 | City only | 20,000 GP |
| 9 | City only | 100,000 GP |

(Plus material component costs.)

### 23.10 Crafting Nonmagical Items (p. 103)

```
RawMaterialsCost   = ½ purchase cost (round down)
TimeRequired       = ceil(purchase cost in GP / 10) days, 8 hrs/day
TimePerWorker      = TimeRequired / number of workers (must each have proficiency in required tool)
```

### 23.11 Brewing Potions of Healing (p. 103)

- Requires **Herbalism Kit** proficiency.
- 1 day (8 hrs) work + 25 GP raw materials → 1 *Potion of Healing*.

### 23.12 Scribing Spell Scrolls (p. 103)

- Requires **Arcana** OR **Calligrapher's Supplies** proficiency.
- Spell prepared each day of inscription; consumed material components consumed only on completion.
- Scroll uses scribe's spell save DC and spell attack bonus.

| Spell Lvl | Time | Cost |
|---|---|---|
| Cantrip | 1 day | 15 GP |
| 1 | 1 day | 25 GP |
| 2 | 3 days | 100 GP |
| 3 | 5 days | 150 GP |
| 4 | 10 days | 1,000 GP |
| 5 | 25 days | 1,500 GP |
| 6 | 40 days | 10,000 GP |
| 7 | 50 days | 12,500 GP |
| 8 | 60 days | 15,000 GP |
| 9 | 120 days | 50,000 GP |

---

## 24. Spellcasting (pp. 104-107)

### 24.1 Spell Levels

- 0 (cantrip) through 9.
- Level represents power tier.

### 24.2 Spell Slots (p. 104)

- Slot of level N → cast spell of level ≤ N.
- Casting a level-M spell using a level-N slot (N > M) = **upcast** (effect may scale).
- Slots restored on **Long Rest** (Wizard's Arcane Recovery on Short Rest is exception; Warlock Pact Magic on Short Rest).

### 24.3 Cantrips (p. 104)

- Cast at-will; no slot.
- Damage cantrips scale at character levels 5, 11, 17 (more dice).

### 24.4 Spell Preparation (p. 104)

When you can change prepared spells:

| Class | Change When |
|---|---|
| Bard | Gain a level |
| Cleric | Finish Long Rest |
| Druid | Finish Long Rest |
| Paladin | Finish Long Rest |
| Ranger | Finish Long Rest |
| Sorcerer | Gain a level |
| Warlock | Gain a level |
| Wizard | Finish Long Rest |

Number prepared = per class table.

### 24.5 Always-Prepared Spells

- Some features grant always-prepared spells (don't count against prepared list).

### 24.6 Casting Time (p. 105)

```
CastingTime ::= Action | BonusAction | Reaction(trigger) | Minutes(N) | Hours(N) | Ritual
```

**One-Spell-Per-Turn Rule:** can't cast a leveled spell with Action and another leveled spell with Bonus Action on the same turn. Cantrips exempt (so Bonus Action cantrip + Action leveled spell is fine, and so is Action cantrip + Bonus Action leveled spell).

### 24.7 Reaction & Bonus Action Triggers

- Reaction-cast spell: trigger defined in spell.
- Bonus Action spell: also triggered per spell.

### 24.8 Longer Casting Times

- Maintain Concentration throughout.
- Take Magic action each turn.
- Concentration broken or interruption → spell fails, slot **not** expended.

### 24.9 Ritual Casting (p. 187)

- Ritual-tagged spells can be cast as Ritual: +10 min casting time, doesn't expend slot.
- Ritual spell **must be prepared** (or, for Wizard with Ritual Adept, in spellbook even if not prepared).

### 24.10 Casting in Armor (p. 104 sidebar)

- Need armor training to cast in that armor; otherwise too hampered.

### 24.11 Components (pp. 105-106)

- **V (Verbal):** chanting (must speak; gagged/Silenced creature can't).
- **S (Somatic):** gesture (need free hand).
- **M (Material):** specific item (use **Component Pouch** OR **Spellcasting Focus** for non-priced components; consumed materials must be present in stated quantity/cost).

### 24.12 Duration (p. 106)

```
Duration ::= Instantaneous | TimeSpan(rounds/min/hours/days) | Concentration up to TimeSpan
```

#### Concentration

- **Maintain only one Concentration spell** at a time.
- **Breaks on:**
  - Starting another Concentration spell (or activating another Concentration effect).
  - Failing a CON save when taking damage:
    ```
    CON save DC = max(10, half damage taken)   capped at 30
    ```
  - Becoming **Incapacitated** or **dying**.
- End voluntarily anytime (no action).

### 24.13 Range (p. 106)

```
Range ::= Distance(feet) | Touch | Self
```

### 24.14 Targets & Effects (p. 106)

- **Clear path** required to target.
- **Self-target** allowed when "creature of your choice" (unless Hostile-only).
- **Invalid target** → spell does nothing but slot still expended (and target appears to have succeeded a save if any).

### 24.15 Areas of Effect (pp. 178-188)

```
AoE ::= Cone(length) | Cube(side) | Cylinder(radius, height) | Emanation(distance) | Line(length, width) | Sphere(radius)
```

Each shape's geometry per glossary:

#### Cone (p. 179)

- Origin point + chosen direction.
- Width at any point along length = distance from origin (i.e., 15-ft Cone is 15 ft wide at 15 ft from origin).
- Length given by spell.
- Origin point not included unless creator decides.

#### Cube (p. 179)

- Origin = any face of the Cube.
- Side length = effect specifies.
- Origin not included unless creator decides.

#### Cylinder (p. 180)

- Origin = center of top or bottom of cylinder.
- Radius and height per effect.
- Origin **is** included.

#### Emanation (p. 181)

- Extends from a creature/object in all directions.
- Moves with origin (unless instantaneous or stationary).
- Origin not included unless creator decides.

#### Line (p. 184)

- Origin → straight path along length, covers width.
- Origin not included unless creator decides.

#### Sphere (p. 188)

- Origin → all directions outward.
- Radius per effect.
- Origin **is** included.

#### General AoE Rules

- **Total Cover blocks the line of effect:** if all straight lines from origin to a location are blocked by Total Cover, that location is excluded.
- Creator placing AoE at unseen point + obstruction: point of origin manifests on near side of obstruction.

### 24.16 Saving Throws & Attack Rolls (p. 106)

```
Spell Save DC          = 8 + caster's spell ability mod + caster's PB
Spell Attack Modifier  =     caster's spell ability mod + caster's PB
```

### 24.17 Combining Spell Effects (p. 106)

- Different spells stack while durations overlap.
- Same spell cast multiple times on same target: only the most potent effect applies (e.g., two *Bless* don't double the bonus).
- If equally potent, the most recent applies for its duration.

### 24.18 Schools of Magic (p. 105)

8 schools (no rules on their own; some features reference):

```
Abjuration | Conjuration | Divination | Enchantment | Evocation
Illusion   | Necromancy  | Transmutation
```

---

## 25. Magic Items (pp. 102-103, 204-208)

### 25.1 Categories (p. 204)

```
Category ::= Armor | Potion | Ring | Rod | Scroll | Staff | Wand | Weapon | WondrousItem
```

### 25.2 Rarity (p. 205)

```
Rarity ::= Common | Uncommon | Rare | VeryRare | Legendary | Artifact
```

| Rarity | Value |
|---|---|
| Common | 100 GP |
| Uncommon | 400 GP |
| Rare | 4,000 GP |
| Very Rare | 40,000 GP |
| Legendary | 200,000 GP |
| Artifact | priceless |

(Halve consumable items other than Spell Scroll. Spell Scroll value = 2× scribe cost.)

### 25.3 Identifying (p. 102)

- Casting *Identify* spell reveals properties.
- Or focus on item during a Short Rest while in physical contact: at end, learn properties (not curses).
- Some items have hints (etched command word, suggestive design, etc.).

### 25.4 Activating (p. 206)

- Default: **Magic action** to activate (some are passive when worn/wielded).
- Some require **Command Word** (spoken/signed; fails in magical silence).
- Consumable items used up on activation.
- Spells cast from items: lowest level + caster level; no slot/components unless stated; user must concentrate if needed; user's spellcasting ability mod = +0 if user has no caster ability, but PB applies.

### 25.5 Charges (p. 206)

- Some items have charges spent to activate.
- **"The Next Dawn":** common recharge phrase; GM determines time-equivalent in worlds without dawn.

### 25.6 Cursed Items (p. 206)

- Description specifies if cursed; usually not revealed by Identify.
- Attunement to a cursed item can't be ended voluntarily until curse broken (*Remove Curse* etc.).

### 25.7 Magic Item Resilience (p. 206)

- ≥ as durable as a non-magical item of its kind.
- Most magic items (other than Potions/Scrolls) have **Resistance to all damage**.
- Artifacts: only destroyable via specific quest method.

### 25.8 Attunement (p. 102)

- Some items require **Attunement** before granting magic properties.
- **Attunement requires a Short Rest** focused only on that item while in physical contact.
- Required activities: weapon practice (weapon), meditation (wand), or appropriate analog.
- Failure on interrupted Short Rest.

#### Attunement Limits

- Max **3 magic items** attuned at a time.
- Can't attune to multiple copies of the same item.
- **Attunement Prerequisites:** if item requires class membership, must satisfy. If item requires spellcaster, must be able to cast at least one spell using own features.

#### Ending Attunement

- No longer satisfy prerequisites.
- Item > 100 ft away for ≥ 24 hours.
- Die.
- Another creature attunes to the item (if compatible).
- Voluntarily during a Short Rest focused on the item (unless cursed).

### 25.9 Wearing & Wielding (p. 102)

- Worn items snap to size of wearer (most magic garments adjust); GM may rule exceptions (anatomical mismatches).
- Limit: 1 of any "single slot" item type at a time (one armor, one shield, one item of headwear, one cloak, one footwear pair, one bracers pair, etc.).
- Paired items (boots, gloves): only work if both worn.

### 25.10 Crafting Magic Items (pp. 206-207)

- Requires **Arcana** proficiency (and helpers must too).
- Required tool per item category:

| Category | Required Tool |
|---|---|
| Armor | Leatherworker's / Smith's / Weaver's Tools (per armor) |
| Potion | Alchemist's Supplies / Herbalism Kit |
| Ring | Jeweler's Tools |
| Rod | Woodcarver's Tools |
| Scroll | Calligrapher's Supplies |
| Staff | Woodcarver's Tools |
| Wand | Woodcarver's Tools |
| Weapon | Leatherworker's / Smith's / Woodcarver's (per weapon) |
| Wondrous Item | Tinker's Tools or tool to make underlying item |

#### Time & Cost

| Rarity | Days | Cost |
|---|---|---|
| Common | 5 | 50 GP |
| Uncommon | 10 | 200 GP |
| Rare | 50 | 2,000 GP |
| Very Rare | 125 | 20,000 GP |
| Legendary | 250 | 100,000 GP |

(Time/cost halved for consumables other than Spell Scroll.)

#### Raw Materials

- Available 75% in cities, 25% in other settlements.
- Item incorporating purchasable item (e.g., +1 Plate Armor): pay full purchase cost OR craft underlying item separately too.

### 25.11 Sentient Magic Items (pp. 207-208)

- Have INT/WIS/CHA scores.
- Have alignment.
- Communicate (emotions, telepathy, speech).
- Have senses (sight/Darkvision range).
- Have a Special Purpose (Aligned, Bane, Creator Seeker, Destiny Seeker, Destroyer, Glory Seeker, Lore Seeker, Protector, Soulmate Seeker, Templar).
- **Conflict:** if bearer acts against item's alignment/purpose → CHA save (DC 12 + item's CHA mod). On fail, item makes demands; if refused, item can suppress properties OR attempt to dominate (Charisma save again; if fails, bearer Charmed for 1d12 hours).

---

## 26. Monsters / Stat Block Format (pp. 188-189, 254-257)

### 26.1 Stat Block Structure

```
StatBlock {
  // Header
  name              : String
  size              : Size
  creatureType      : CreatureType
  descriptiveTags   : List<String>?       // optional, no rules
  alignment         : Alignment            // suggested

  // Combat Highlights
  ac                : int
  initiative        : { modifier, score }   // score = 10 + modifier; can be used in lieu of rolling
  hp                : { value, hitDice, conContribution }
  speed             : { walking, burrow?, climb?, fly?, swim? }

  // Ability Scores
  abilityScores     : { STR, DEX, CON, INT, WIS, CHA } each with modifier and saveModifier

  // Other Details
  skills            : List<{skill, modifier}>?
  resistances       : List<DamageType>?
  vulnerabilities   : List<DamageType>?
  immunities        : { damage: List<DamageType>, conditions: List<Condition> }?
  gear              : List<ItemRef>?         // retrievable equipment
  senses            : { passivePerception, blindsight?, darkvision?, tremorsense?, truesight? }
  languages         : List<Language>         // "None" allowed
  cr                : ChallengeRating
  xp                : int                    // per CR
  pb                : int                    // per CR

  // Behaviors
  traits            : List<Trait>?           // always-on or conditional
  actions           : List<Action>           // monster-specific actions
  bonusActions      : List<BonusAction>?
  reactions         : List<Reaction>?
  legendaryActions  : List<LegendaryAction>?
}
```

### 26.2 Creature Types (p. 254)

```
Aberration | Beast      | Celestial | Construct | Dragon
Elemental  | Fey        | Fiend     | Giant     | Humanoid
Monstrosity| Ooze       | Plant     | Undead
```

### 26.3 Hit Dice by Size (p. 255)

| Size | Hit Die | Avg HP per Die |
|---|---|---|
| Tiny | d4 | 2.5 |
| Small | d6 | 3.5 |
| Medium | d8 | 4.5 |
| Large | d10 | 5.5 |
| Huge | d12 | 6.5 |
| Gargantuan | d20 | 10.5 |

`HP = (HD count × HD avg) + (HD count × CON modifier)` (round down).

### 26.4 Initiative

```
Initiative score = 10 + Initiative modifier
```

GM may use the score directly without rolling.

### 26.5 CR → XP table (p. 256)

| CR | XP | CR | XP |
|---|---|---|---|
| 0 | 0 or 10 | 11 | 7,200 |
| 1/8 | 25 | 12 | 8,400 |
| 1/4 | 50 | 13 | 10,000 |
| 1/2 | 100 | 14 | 11,500 |
| 1 | 200 | 15 | 13,000 |
| 2 | 450 | 16 | 15,000 |
| 3 | 700 | 17 | 18,000 |
| 4 | 1,100 | 18 | 20,000 |
| 5 | 1,800 | 19 | 22,000 |
| 6 | 2,300 | 20 | 25,000 |
| 7 | 2,900 | 21 | 33,000 |
| 8 | 3,900 | 22 | 41,000 |
| 9 | 5,000 | 23 | 50,000 |
| 10 | 5,900 | 24 | 62,000 |
| | | 25 | 75,000 |
| | | 26 | 90,000 |
| | | 27 | 105,000 |
| | | 28 | 120,000 |
| | | 29 | 135,000 |
| | | 30 | 155,000 |

### 26.6 Action / Damage Notation (p. 256)

```
Hit:        damage and effects on hit
Miss:       effects on miss
Hit or Miss: effects regardless

Damage:     "X (YdZ + W)" form — use either static X or dice expression, never both
Save:       "DC X <Ability> save" + "fail/success" effects
            "Half damage only" on success = half + ignore other effects
```

### 26.7 Multiattack (p. 257)

- Single Attack action consisting of multiple attacks (per stat block).
- Use Multiattack on any turn except those using a more powerful ability.

### 26.8 Spellcasting (p. 257)

- Stat block lists spells, casting ability, save DC, attack bonus.
- Spells cast at lowest level unless noted.
- Spell components: stat block notes if monster ignores material components.
- Long-cast (≥ 1 minute) spells: monster casts in 1 Action unless noted.

### 26.9 Limited Usage Notation (p. 257)

```
X/Day            — finite uses per Long Rest
Recharge X-Y     — at start of each turn, roll d6; recharge if roll within X-Y
                   (also recharges on Short or Long Rest)
Recharge after a Short or Long Rest
```

### 26.10 Legendary Actions (p. 257)

- Take immediately after another creature's turn ends.
- Only one Legendary Action at a time, and only after another's turn.
- Refresh at start of monster's turn.
- Can't take while Incapacitated / unable to take actions.

### 26.11 Running a Monster (p. 255 sidebar)

- Use limited-use special abilities (e.g., recharging breath weapon) **as quickly and often as possible** to ensure CR-appropriate threat.
- Use Multiattack on any turn not using a more powerful ability.
- Use Bonus Actions / Reactions / Legendary Actions as often as possible.

---

## 27. Exploration

### 27.1 Travel Pace (p. 12)

| Pace | Per Minute | Per Hour | Per Day | Side Effect |
|---|---|---|---|---|
| Fast | 400 ft | 4 mi | 30 mi | Disadv on WIS(Perception/Survival) |
| Normal | 300 ft | 3 mi | 24 mi | Disadv on DEX(Stealth) |
| Slow | 200 ft | 2 mi | 18 mi | Adv on WIS(Perception/Survival) |

### 27.2 Travel Pace by Terrain (p. 192)

| Terrain | Max Pace | Encounter Distance | Foraging DC | Navigation DC | Search DC |
|---|---|---|---|---|---|
| Arctic | Fast* | 6d6 × 10 ft | 20 | 10 | 10 |
| Coastal | Normal | 2d10 × 10 ft | 10 | 5 | 15 |
| Desert | Normal | 6d6 × 10 ft | 20 | 10 | 10 |
| Forest | Normal | 2d8 × 10 ft | 10 | 15 | 15 |
| Grassland | Fast | 6d6 × 10 ft | 15 | 5 | 15 |
| Hill | Normal | 2d10 × 10 ft | 15 | 10 | 15 |
| Mountain | Slow | 4d10 × 10 ft | 20 | 15 | 20 |
| Swamp | Slow | 2d8 × 10 ft | 10 | 15 | 20 |
| Underdark | Normal | 2d6 × 10 ft | 20 | 10 | 20 |
| Urban | Normal | 2d6 × 10 ft | 20 | 15 | 15 |
| Waterborne | Special† | 6d6 × 10 ft | 15 | 10 | 15 |

*Arctic Fast pace requires appropriate equipment (skis).
†Waterborne pace = vehicle's speed.

### 27.3 Travel Variants (p. 192)

- **Good Roads:** +1 step Maximum Pace (Slow→Normal, Normal→Fast).
- **Slower Travelers:** if any group member's Speed ≤ ½ normal, group must move at Slow.
- **Extended Travel:** beyond 8 hours/day = each additional hour, CON save (DC 10 + 1/extra hour) or 1 Exhaustion level.
- **Special Movement (Wind Walk, Carpet of Flying):** Speed ÷ 10 = mph; Normal pace mi/day = mph × 8; Fast = ×4/3; Slow = ×2/3.

### 27.4 Hazards

| Hazard | Effect |
|---|---|
| **Burning** (p. 178) | 1d4 Fire / turn. Action + Prone + roll on ground extinguishes. Dousing/submerging also extinguishes. |
| **Dehydration** (p. 181) | Per-day water needs by size; <½ requirement = +1 Exhaustion at day's end. Can't remove Dehydration Exhaustion until full water consumed. |
| **Falling** (p. 182) | 1d6 Bludgeoning per 10 ft (max 20d6) + Prone. Reaction save halves damage if into liquid. |
| **Malnutrition** (p. 185) | Per-day food needs by size; <½ requirement = save (DC 10) or +1 Exhaustion. 5 days no food = auto +1 Exhaustion at end of day 5 and each subsequent day. |
| **Suffocation** (p. 189) | Hold breath = (CON mod) min, min 30 sec. Out of breath: +1 Exhaustion at end of each turn. Can breathe again → remove all suffocation Exhaustion. |

### 27.5 Environmental Effects (p. 195)

- **Deep Water (>100 ft):** no Swim Speed → CON save (DC 10) per hour or +1 Exhaustion.
- **Extreme Cold (≤ 0°F):** CON save (DC 10) per hour or +1 Exhaustion. Cold Resistance/Immunity auto-succeeds.
- **Extreme Heat (≥ 100°F):** CON save end of each hour without water; DC 5, +1 each additional hour. Medium/Heavy armor → Disadv. Fire Resistance/Immunity auto-succeeds.
- **Frigid Water:** safe for (CON score) minutes; each min after = CON save (DC 10) or +1 Exhaustion. Cold-adapted creatures auto-succeed.
- **Heavy Precipitation:** Lightly Obscured area; Disadv on WIS(Perception). Heavy rain extinguishes flames.
- **High Altitude (≥ 10,000 ft):** travel hours count as 2 hours. Acclimation in 30+ days; can't acclimate above 20,000 ft (unless native).
- **Slippery Ice:** Difficult Terrain. First time enter / start turn: DC 10 DEX save or Prone.
- **Strong Wind:** Disadv on ranged attack rolls. Extinguishes flames; disperses fog. Flying creature must land at end of turn or fall. Sandstorm imposes Disadv on Perception.
- **Thin Ice:** weight tolerance 3d10 × 10 lbs per 10-ft square. Exceeds → ice breaks → frigid water.

### 27.6 Difficult Terrain

See §8.3.

### 27.7 Vehicles (in travel)

Vehicles use mph from Equipment data, not pace.

---

## 28. Social Interaction (pp. 10-11)

### 28.1 Influence Action

Mechanics for swaying NPC behavior. Process:

1. Describe approach.
2. GM determines NPC attitude:
   - **Willing:** request aligns with NPC desires → no check needed.
   - **Unwilling:** counter to NPC alignment → no check, request refused.
   - **Hesitant:** make ability check.
3. **Influence Check** (if Hesitant): GM picks check based on roleplay, default DC = 15 OR NPC's INT score, whichever higher.
4. Success: NPC complies (in their preferred way).
5. Fail: must wait 24 hrs (or duration GM sets) before urging same way again.

### 28.2 Influence Check Skill Options

| Skill | Interaction |
|---|---|
| Charisma (Deception) | Deceive understanding NPC |
| Charisma (Intimidation) | Intimidate |
| Charisma (Performance) | Amuse |
| Charisma (Persuasion) | Persuade understanding NPC |
| Wisdom (Animal Handling) | Coax Beast/Monstrosity |

### 28.3 Attitudes (pp. 178, 182, 184)

- **Friendly:** Adv on influence checks vs them.
- **Indifferent:** default monster attitude; standard influence rules.
- **Hostile:** Disadv on influence checks vs them.

---

## 29. Gameplay Toolbox (DM Mechanics) (pp. 192-203)

### 29.1 Curses (p. 193)

#### Bestow Curse Reference

- Cast via **Bestow Curse** spell; ended via **Remove Curse**.
- Curse durations equate to spell levels:
  - 1 minute ≈ Level 3 spell
  - Until dispelled ≈ Level 9 spell

#### Curse Forms

```
CurseForm ::= BestowCurse | CursedCreature | CursedMagicItem | NarrativeCurse | EnvironmentalCurse
```

- **Cursed Magic Item:** see §25.6.
- **Narrative Curse:** custom; ending tied to symbolic act.
- **Environmental Curse (e.g., Demonic Possession):** save (DC 15) or possessed; controlled creature behavior altered, save at end of each turn (DC 15) to regain control. *Dispel Evil and Good* removes.

### 29.2 Magical Contagions (p. 194)

```
Contagion {
  name           : String
  type           : Magical Contagion
  spreadVector   : (skin contact / inhalation / etc.)
  save           : { ability, DC }
  incubation     : duration
  effects        : List<Effect>
  rest&Recuperation: 3 days no Long-Rest-interrupt activity → DC 15 CON save → end with Adv for 24 hrs
  fightingTheContagion: { saveSchedule, successesNeeded }
  spread         : { trigger, save }
}
```

Sample contagions: Cackle Fever (DC 13 CON; symptoms include fits of laughter on damage), Sewer Plague (Fatigue + reduced healing), Sight Rot (Blinded + spreads via skin contact).

### 29.3 Environmental Effects (p. 195)

See §27.5.

### 29.4 Fear & Mental Stress (p. 196)

#### Fear Effects

- Use **Frightened** as baseline.
- WIS save (DC by terror level): DC 10 mild, 15 moderate, 20 severe.
- Frightened creature repeats save at end of each turn → ends on success.

#### Mental Stress

- Psychic damage typically.
- Can use INT/WIS/CHA save instead of WIS (GM picks).
- Half damage on success.

#### Sample Mental Stress Effects

| Example | Save DC | Psychic Damage |
|---|---|---|
| Hallucinogenic substance | 10 | 1d6 |
| Touching fiendish idol | 15 | 3d6 |
| Magical trap into Far Realm | 20 | 9d6 |

#### Prolonged Effects

- **Short-Term:** Frightened/Incapacitated/Stunned for 1d10 minutes (suppressed by *Calm Emotions*; removed by *Lesser Restoration*).
- **Long-Term:** Disadv on some/all ability checks for 1d10 × 10 hours.
- **Indefinite:** lasts until removed by *Greater Restoration*.

### 29.5 Poison (pp. 197-198)

#### Types

```
PoisonType ::= Contact | Ingested | Inhaled | Injury
```

- **Contact:** smeared on object; touching exposed skin triggers.
- **Ingested:** swallow full dose for full effect; partial dose = reduced (Adv on save / half damage).
- **Inhaled:** 5-ft Cube of gas/powder; affects all in cube; holding breath ineffective (affects mucus membranes too).
- **Injury:** Bonus Action coat weapon or ammunition; potent until delivered or washed.

#### Harvesting

- DC 20 INT(Nature) check using **Poisoner's Kit** on dead/Incapacitated venomous creature.
- 1d6 minutes effort.
- Success: 1 dose. Fail by 5+: subjected to creature's poison.

### 29.6 Traps (pp. 199-201)

```
Trap {
  name            : String
  severity        : Nuisance | Deadly
  levelRange      : (1-4) | (5-10) | (11-16) | (17-20)
  trigger         : Description (pressure plate, trip wire, opening container, etc.)
  duration        : Instantaneous | Rounds(N) | Resets
  effect          : Effect
  detect          : { skill, DC }
  disarm          : { skill, DC, optional Iron Spike, etc. }
  scaling         : per-tier damage and DC table
}
```

#### Trap Damage Scaling

For deadly traps scaling at higher levels:

| Levels | Bludgeoning Damage | Save DC |
|---|---|---|
| 5-10 | 22 (4d10) | 15 |
| 11-16 | 55 (10d10) | 17 |
| 17-20 | 99 (18d10) | 19 |

Pit depth scaling:

| Levels | Pit Depth | Damage |
|---|---|---|
| 5-10 | 30 ft | 10 (3d6) |
| 11-16 | 60 ft | 21 (6d6) |
| 17-20 | 120 ft | 42 (12d6) |

### 29.7 Combat Encounters (pp. 202-203)

#### Encounter Building

```
TotalXPBudget = (xp per character at party level) × number of characters
SpendCreatures: pick monsters whose summed XP ≤ budget
```

#### XP Budget per Character (per level)

| Lvl | Low | Moderate | High | Lvl | Low | Moderate | High |
|---|---|---|---|---|---|---|---|
| 1 | 50 | 75 | 100 | 11 | 1,900 | 2,900 | 4,100 |
| 2 | 100 | 150 | 200 | 12 | 2,200 | 3,700 | 4,700 |
| 3 | 150 | 225 | 400 | 13 | 2,600 | 4,200 | 5,400 |
| 4 | 250 | 375 | 500 | 14 | 2,900 | 4,900 | 6,200 |
| 5 | 500 | 750 | 1,100 | 15 | 3,300 | 5,400 | 7,800 |
| 6 | 600 | 1,000 | 1,400 | 16 | 3,800 | 6,100 | 9,800 |
| 7 | 750 | 1,300 | 1,700 | 17 | 4,500 | 7,200 | 11,700 |
| 8 | 1,000 | 1,700 | 2,100 | 18 | 5,000 | 8,700 | 14,200 |
| 9 | 1,300 | 2,000 | 2,600 | 19 | 5,500 | 10,700 | 17,200 |
| 10 | 1,600 | 2,300 | 3,100 | 20 | 6,400 | 13,200 | 22,000 |

#### Difficulty Tiers

- **Low:** rare scary moments; resources used; usually no casualties.
- **Moderate:** could go badly absent healing; one or more PCs may drop.
- **High:** could be lethal for one or more.

#### Troubleshooting

- **Many creatures:** more creatures than 2/PC = include fragile ones to balance damage burst risk.
- **Powerful creatures:** if creature CR > party level, single hit may down a PC (e.g., Ogre CR 2 vs L1 Wizard).
- **Unusual features:** if monster has feature lower-level PCs can't counter, consider not using.
- **CR 0 creatures:** use sparingly (or use swarms instead).
- **Number of stat blocks:** keep to 2-3 per encounter for runnability.

---

## 30. Glossary of Game Terms (alphabetical)

This glossary summarizes terms used in mechanics. Each term links back to the primary section where the rule is defined; see SRD pp. 176-191 for the canonical glossary.

| Term | One-line definition | Section |
|---|---|---|
| AC (Armor Class) | Target number for an attack roll. | §10, §19, §23.3 |
| Action | One action taken per turn from the standard list or features. | §6 |
| Advantage | Roll 2d20, take higher. | §1.3 |
| Aligned | Sentient item alignment-matched purpose. | §25.11 |
| Alignment | Ethical/moral 9-grid + Unaligned. | §16.7 |
| Ally | Party member, friend, or designated. | §10.4 |
| Area of Effect | Cone, Cube, Cylinder, Emanation, Line, Sphere. | §24.15 |
| Attack Roll | D20 + mod + PB ≥ AC. | §1, §10 |
| Attitude | Friendly / Indifferent / Hostile NPC stance. | §28.3 |
| Attunement | Bonded magic item; max 3, Short Rest focus. | §25.8 |
| Background | Origin component: 3 ability boosts + feat + 2 skills + tool + gear. | §16.3, §20 |
| Blinded | Condition: can't see, auto-fail sight checks, attack interactions. | §14 |
| Bloodied | HP ≤ ½ max. | §12.1 |
| Bonus Action | Extra action available only when granted. | §6.2 |
| Burrow Speed | Move through earth. | §8.1 |
| Cantrip | Level 0 spell, no slot cost. | §24.3 |
| Carrying Capacity | STR × 15 lbs (Med). | §27 (drag/lift = ×30). |
| Challenge Rating | Monster threat tier. | §26 |
| Charmed | Condition: can't attack charmer; charmer Adv on social. | §14 |
| Climb Speed | Move while climbing without extra cost. | §8.1 |
| Concentration | Maintain a spell; CON save on damage. | §24.12 |
| Condition | Temporary game state. | §14 |
| Cover | Half/Three-Quarters/Total. | §10.3 |
| Crawling | +1 ft cost per ft. | §8.9 |
| Creature | Any in-game being. | §26.2 |
| Creature Type | 14 types from Aberration to Undead. | §26.2 |
| Critical Hit | Nat 20; double damage dice. | §1.2, §11.4 |
| D20 Test | Roll a d20 and apply mods. | §1 |
| Damage | Loss of HP or Object HP. | §11 |
| Damage Roll | Dice + mods. | §11.1 |
| Damage Threshold | Ignore damage below threshold. | §11.8 |
| Damage Types | 13 named types. | §11.2 |
| Darkness | Heavily Obscured area. | §9 |
| Darkvision | See Dim Light as Bright; Darkness as Dim. | §9.3 |
| Dash | Action: extra movement = Speed. | §6.1 |
| Dead | 0 HP + revival required. | §12.4 |
| Deafened | Can't hear; auto-fail hearing. | §14 |
| Death Saving Throw | 1d20 ≥ 10 success/<10 fail at 0 HP. | §12.4 |
| Difficult Terrain | +1 ft cost. | §8.3 |
| Difficulty Class (DC) | Target number for checks/saves. | §1.5 |
| Dim Light | Lightly Obscured. | §9 |
| Disadvantage | Roll 2d20, take lower. | §1.3 |
| Disengage | Action: no OAs this turn. | §6.1 |
| Dodge | Action: attacks vs Disadv, DEX saves Adv. | §6.1 |
| Emanation | AoE moving with origin. | §24.15 |
| Encounter | Scene of social/exploration/combat. | §28, §29.7 |
| Enemy | Combatant against your side. | (combat) |
| Exhaustion | Cumulative 1-6; -2/level on D20 Tests, -5 ft/level Speed; 6 = die. | §14 |
| Expertise | Doubled PB on a skill. | §3.2 |
| Experience Points | Earned via challenges; level threshold. | §18.1 |
| Falling | 1d6/10 ft, max 20d6, +Prone. | §8.11 |
| Flying | Use Fly Speed. | §8.12 |
| Fly Speed | Travel through air. | §8.1 |
| Friendly | Helpful attitude. | §28.3 |
| Frightened | Disadv if source visible; can't approach. | §14 |
| Grappled | Speed 0; Disadv on attacks vs others. | §14 |
| Grappling | Unarmed Strike option for Grappled. | §28 |
| Hazard | Environmental danger (Burning, Falling, etc.). | §27.4 |
| Healing | Restore HP. | §12.6 |
| Heavily Obscured | Treated as Blinded for vision. | §9 |
| Help | Action: grant ally Adv on next check / one ally Adv on attack. | §6.1 |
| Heroic Inspiration | One-shot reroll. | §1.4 |
| Hide | Action: DC 15 DEX(Stealth) check. | §15.1 |
| High Jump | Vertical: 3 + STR mod feet (with run). | §8.10 |
| Hit Points | Capacity to take damage. | §12 |
| Hit Point Dice | Class-based die for HP gain & Short Rest healing. | §12, §13.1 |
| Hostile | Hindering attitude. | §28.3 |
| Hover | Stay aloft without moving. | §8.12 |
| Illusions | Magical false sensory effects. | (spells) |
| Immunity | Take 0 damage of type / unaffected by condition. | §11.3, §14 |
| Improvised Weapon | Object used as weapon; 1d4 dmg, no PB. | (combat) |
| Incapacitated | No actions; concentration broken; speech blocked. | §14 |
| Indifferent | Default attitude. | §28.3 |
| Influence | Action: try to sway NPC. | §28 |
| Initiative | DEX-based combat order. | §7.2 |
| Invisible | Concealed; attack interactions. | §14 |
| Jumping | Long Jump or High Jump. | §8.10 |
| Knocking Out | Reduce melee target to 1 HP + Unconscious instead. | §12.4 |
| Lightly Obscured | Disadv on sight Perception. | §9 |
| Line | AoE rectangular path. | §24.15 |
| Long Jump | Horizontal: STR feet (with run). | §8.10 |
| Long Rest | 8-hour rest; full HP, slot recovery. | §13.2 |
| Magic [Action] | Cast a spell or activate magic item / feature. | §6.1, §24 |
| Magical Effect | Created by spell, magic item, or rule-labeled magic. | (general) |
| Monster | GM-controlled creature. | §26 |
| Multiattack | Single Action with multiple attacks (monsters). | §26.7 |
| Object | Inanimate distinct thing. | §11.8 |
| Occupied Space | Has creature or fully-blocking object. | §8.5 |
| Opportunity Attack | Reaction: melee attack on creature leaving reach. | §10.4 |
| Paralyzed | Incapacitated + Speed 0 + auto-fail STR/DEX + auto-Crit ≤ 5 ft. | §14 |
| Passive Perception | 10 + WIS(Perception) mod. | §4.2 |
| Per Day | Refreshes on Long Rest. | §13.2 |
| Petrified | Stone; ×10 weight; Resistance all dmg; Poison Immunity. | §14 |
| Player Character | PC controlled by player. | §16 |
| Poisoned | Disadv on attacks and ability checks. | §14 |
| Possession | Effect controls a creature. | §29.1 |
| Proficiency | +PB to relevant rolls. | §3 |
| Prone | Restricted movement; attack adv/disadv per range. | §14 |
| Reach | Distance for melee attack. | §10.5 |
| Reaction | 1/round, on triggers. | §6.3 |
| Ready | Action: prep triggered Reaction. | §6.1 |
| Resistance | Half damage. | §11.3 |
| Restrained | Speed 0, attack interactions. | §14 |
| Ritual | Spell cast +10 min, no slot. | §24.9 |
| Round Down | Always except where noted. | §1.6 |
| Save | = Saving Throw. | §5 |
| Saving Throw | D20 + ability + (PB) ≥ DC. | §5 |
| Search | Action: WIS check. | §6.1, §15.2 |
| Shape-Shifting | Form change per spec. | (general) |
| Short Rest | 1-hour; spend Hit Dice to heal. | §13.1 |
| Simultaneous Effects | Triggering creature decides order. | (combat) |
| Size | Tiny–Gargantuan. | §8.4 |
| Skill | Specialty bound to ability. | §4 |
| Speed | Movement per turn. | §8.1 |
| Spell | Magical effect described in Spells. | §24 |
| Spell Attack | D20 + spell mod + PB ≥ AC. | §10.2 |
| Spellcasting Focus | Stand-in for components without listed cost. | §24.11 |
| Stable | At 0 HP but no DSTs needed. | §12.4 |
| Stat Block | Monster game data. | §26 |
| Study | Action: INT check. | §6.1 |
| Stunned | Incapacitated + auto-fail STR/DEX + Adv vs you. | §14 |
| Suffocation | Out-of-breath Exhaustion. | §27.4 |
| Surprise | Disadv on Initiative. | §7.2 |
| Swimming | +1 ft cost; Swim Speed removes. | §8.8 |
| Swim Speed | No-extra-cost swim. | §8.1 |
| Target | Creature/object subject of effect. | §24.14 |
| Telepathy | Mental communication w/in range. | §9.3 |
| Teleportation | Instant relocation. | (spells) |
| Temporary HP | Buffer; non-stacking; lost on Long Rest. | §12.7 |
| Tremorsense | Pinpoint ground/liquid contacts. | §9.3 |
| Truesight | See through Darkness/Invisibility/Illusion. | §9.3 |
| Unarmed Strike | Body-based attack: damage / grapple / shove. | §6, §10 |
| Unconscious | Incapacitated + Prone + auto-Crit ≤ 5 ft. | §14 |
| Unoccupied Space | No creatures/blocking objects. | §8.5 |
| Utilize | Action: use non-magical object needing an action. | §6.1 |
| Vulnerability | Double damage. | §11.3 |
| Weapon | Simple or Martial item. | §23.2 |
| Weapon Attack | Attack roll using weapon. | §10 |

---

*End of mechanics reference. Subsequent docs (`01-domain-model-spec.md` onward) will translate these rules into Dart domain types and engine procedures.*
