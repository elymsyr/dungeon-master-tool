---
type: file-note
domain: chargen
path: flutter_app/lib/application/character_creation/pending_choices.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `pending_choices.dart`

> [!abstract] Primary Purpose
> Models deferred level-up / feat decisions that sit on the character sheet as resolvable `!` badges. Defines the `PendingChoice` value type + `PendingChoiceKind` enum, JSON encode/decode for the character's `pending_choices` field, and the translators that turn a `LevelUpPlan` (or a taken feat / subclass pick) into the set of decisions the player still owes.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none — value types + top-level functions.
- Reads: a character's raw `pending_choices` field (`readPendingChoices`), `LevelUpPlan` (`pendingChoicesFromPlan`), `List<Entity> feats` / `Entity feat` (`seedFeatChoicePendings` / `seedFeatFollowOns`), `Map<String,String> existingFeatChoices`.
- Supabase / CDC / events / triggers: none.

**Outputs**
- Public API: `PendingChoiceKind` (14 kinds), `PendingChoice` (+ `toMap`/`fromMap`), `readPendingChoices`, `encodePendingChoices`, `newPendingChoice`, `seedFeatChoicePendings`, `seedFeatFollowOns`, `pendingChoicesFromPlan`, `pendingChoiceLabel`, `pendingChoiceFieldHints`.

## Dependencies & Links
- Depends on: [[level_up_planner]] (`LevelUpPlan`), `entity.dart`, `dart:math`.
- Used by: the creation wizard commit (seeds initial `pending_choices`), the editor level-up flow + `PendingChoicesPanel` (renders badges + resolver dialogs).
- Domain map: [[Character-System]]
- System flow: [[Effect-DSL-Resolution]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
- `PendingChoiceKind` wire values (stored discriminator): asiOrFeat, fightingStyle, cantrips, spells, subclass, weaponMastery, skillProficiency, toolProficiency, languages, expertise, featAsi, divineOrder, featureOption, featChoice. `fromWire` reverses; malformed entries are dropped silently on decode (lose one badge, not the editor).
- `PendingChoice` carries `id`, `kind`, `level`, optional `classId`/`classLabel`, `count` (spells/cantrips/skills remaining), `maxSpellLevel`, `sourceEntityId` (e.g. the feat for `featAsi`/`featChoice`), `featureName`, `dismissed` (soft-dismiss; still surfaced in the Upgrades panel). IDs minted by `_newId` (`pc_<microsTime36>_<rand36>`).
- `pendingChoicesFromPlan`: maps `LevelUpPlan` flags → choices — subclass (only when `!hasSubclass`), asiOrFeat, fightingStyle, divineOrder, one `featureOption` per `featureOptionPicks` name, cantrips (`cantripsKnownDelta`), spells (`preparedSpellsDelta` + `maxSpellLevelAtNewLevel`), weaponMastery (`weaponMasteryCountDelta`).
- `seedFeatChoicePendings`: scans each feat's `choice_group` effects, emits one `featChoice` per under-filled group (remaining = `pick - alreadyPicked` from comma-joined `existingFeatChoices[<featId>:<groupId>]`); `pick_kind == 'ability'` skipped (handled by featAsi).
- `seedFeatFollowOns`: for one feat emits skillProficiency (`bonus_skill_pick_count`), expertise (`bonus_expertise_pick_count`), featAsi (`asi_amount > 0`, sourced to the feat), plus the feat's `choice_group` pendings. Shared by editor level-up + manual feat-edit paths so they never drift.
- `pendingChoiceLabel`: human label per kind (`"$classLabel L$level · ..."`). `pendingChoiceFieldHints`: which schema field tiles light the `!` badge per kind (e.g. asiOrFeat → `{stat_block, feats}`, spells/cantrips → `{spells_known}`, subclass → `{subclass_refs}`, weaponMastery → `{weapon_masteries}`).

## Notes
- The wizard maps results to `.toMap()` into seeded `pending_choices`; the editor merges `PendingChoice`s as follow-ons.
