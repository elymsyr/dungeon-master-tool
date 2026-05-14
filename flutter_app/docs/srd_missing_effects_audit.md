# SRD Missing Mechanical Effects Audit

_2026-05-14 — focuses on **mechanical effects** that should affect the PC sheet but don't yet (or are narrative-only). Companion to `srd_5e_mechanic_audit.md`._

Shipped in this commit:

- **`PendingChoiceKind.subclass`** — every class triggers a `!` badge on the `subclass_refs` tile at L3 when no subclass is selected. Resolves via a subclass picker filtered by `parent_class_ref`.
- **`PendingChoiceKind.weaponMastery`** — `weapon_mastery_count_bonus` deltas from auto-granted class feats queue a `!` on the new `weapon_masteries` tile (added to PC schema as a relation list of weapons with a mastery property).

## Remaining gaps — Direct effects (no UI choice, just stat changes)

### Senses & Darkvision range

| Source | SRD says | Current state | Fix |
|--------|----------|---------------|-----|
| Drow Elf | Darkvision 120 ft (replaces base 60 ft) | `granted_modifiers: []` | Either author "Darkvision 120 ft" sense entity + reference it, OR extend `sense_grant` effect with `range_ft` payload and add resolver pass that picks max range per sense |
| Half-Orc / Orc | Darkvision 60 ft (base) | already encoded via top-level `granted_senses` | ✓ |
| Tiefling | Darkvision 60 ft | encoded ✓ | — |

### Size morphs

| Source | Current | Fix |
|--------|---------|-----|
| Goliath L5 Large Form | trait `Large Form` is narrative | Add `size_override` effect (new effect kind) consumed by resolver, OR keep narrative — size morph is short-duration and player-triggered, so deferring is reasonable |

### Speed overrides / equals-speed

| Source | Current |
|--------|---------|
| Tabaxi (not in SRD 2024) | n/a |
| Wood Elf +5 ft | `speed_bonus: 5` ✓ |
| Goliath base 35 ft | `speed_ft: 35` ✓ |

### Damage resistances/vulnerabilities

| Source | Current |
|--------|---------|
| Stout Halfling Poison resistance | `granted_damage_resistances: [Poison]` ✓ (verify resolver applies it) |
| Dwarf Poison resistance | encoded ✓ |
| Tiefling Fire resistance (variant by ancestry — not in 2024 SRD) | n/a |

### Skill / tool / language deferrable picks (NOT YET WIRED)

| Source | Count | Domain | Status |
|--------|-------|--------|--------|
| College of Lore L3 Bonus Proficiencies | 3 skills | any | needs `PendingChoiceKind.skillProficiency` resolver (enum exists, body is a stub) |
| Barbarian Primal Knowledge (not in 2024 SRD?) | 1 skill | barbarian list | check if SRD 5.2.1 retains it |
| Linguist Origin feat | 3 languages | any | currently narrative |

## How the new pending kinds plug in

- `PendingChoiceKind.subclass`: triggered when `LevelUpPlan.isSubclassLevel` is true and the editor passes `hasSubclass: false`. Resolves by writing the picked subclass id to `subclass_refs` (the existing PC field).
- `PendingChoiceKind.weaponMastery`: triggered by `LevelUpPlan.weaponMasteryCountDelta > 0`. Resolves by appending picked weapon ids to `weapon_masteries` (new PC field).
- `PendingChoiceKind.skillProficiency`: enum added, dialog body is a stub. Not yet emitted by `pendingChoicesFromPlan` — feature row scanning for SRD picks ("Choose 3 skills from X") needs design.

The chip rendering and view-mode click pattern from the prior round still applies: `pendingChoiceFieldHints(kind)` maps each kind to PC schema field keys that get the `!` badge in `_PendingBadgeRow`.
