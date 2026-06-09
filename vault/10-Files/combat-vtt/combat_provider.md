---
type: file-note
domain: combat-vtt
path: flutter_app/lib/application/providers/combat_provider.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `combat_provider.dart`

> [!abstract] Primary Purpose
> Riverpod `StateNotifier` that owns all live combat state for the active world: the list of `Encounter`s, the active encounter id, an append-capped event log, free-form session notes, AND every battle-map field (token positions/sizes, hidden tokens, fog, annotations, measurements, strokes, vector scene, grid settings). It is the single mutation entrypoint for the combat/VTT tab. Persistence is row-level: it writes ONLY the `combat_state` key inside `world_settings.settings_json` via a debounced patch, never a full world save.

## Inputs / Outputs
**Inputs**
- Providers watched (in the provider factory): `activeCampaignProvider`, `campaignRevisionProvider`, `worldInitialSyncSettledProvider` (all three force notifier rebuild so the `_loaded` gate is re-evaluated on cross-device sync settle).
- Constructor deps (lazy closures): `entityProvider` (entity map), `worldSchemaProvider` (`EncounterConfig`), `characterListProvider` (player chars), `activeCampaignProvider.notifier.data` (campaign map incl. `combat_state`), `eventBusProvider`, a `saveSettingsPatch` closure, `characterListProvider.notifier.update` (HP write-back), and an `_isLoadWithoutDataSafe` gate closure.
- Reads (DAOs / Drift tables): none directly — reads in-memory campaign data map `data['combat_state']`.
- Supabase / CDC subscribed: none directly (goes through campaign provider + pending write buffer).
- Events consumed: none.
- Triggers: constructor calls `_loadFromCampaign()`; provider rebuild on the 3 watched revisions.

**Outputs**
- Public API: `combatProvider` (`StateNotifierProvider<CombatNotifier, CombatState>`). Methods: `createEncounter/switchEncounter/deleteEncounter/renameEncounter`, `addCombatantFromEntity/addCombatantForCharacter/addDirectRow/addAllPlayers/deleteCombatant/clearAll`, `nextTurn/rollInitiatives`, `modifyHp/setStat/addCondition/removeCondition/updateConditionDuration`, `updateSessionNotes/addLog`, `undo/redo`, `saveMapData/toggleTokenHidden/saveFogAndAnnotation/updateGridSettings`, `getSessionState/loadSessionState`.
- Writes (Drift tables): indirectly — patches `world_settings.settings_json['combat_state']`.
- Supabase pushed / RPC: indirectly via `activeCampaignProvider.notifier.saveSettingsPatch` (debounced).
- Events emitted (`EventBus`): `sessionCombatantAdded`, `sessionTurnAdvanced`, `sessionCombatantUpdated` (HP change), each tagged with `campaignId`.

## Dependencies & Links
- Depends on: [[campaign_provider]], [[character_draft]], [[entity]], [[pending_write_buffer]], [[battle_map_snapshot_builder]], [[world_schema]]
- Used by: [[grid_canvas]], [[battlemap_marks_protocol]], [[projection_output]]
- Domain map: [[Combat-and-VTT]]
- System flow: [[Fog-of-War-and-Visibility]]
- Spec / reference: [[SRD-5.2.1]]

## Key Logic / Variables
- `_loaded` gate (critical anti-data-loss invariant): write paths (`_saveAndNotify`, `createEncounter`) are no-ops until `_loadFromCampaign` consumes real campaign data OR `_isLoadWithoutDataSafe()` confirms safety (world offline → safe; online + `worldInitialSyncSettledProvider` contains worldId → safe; online + sync pending → defer, stays false). Prevents the session-screen auto-create-encounter post-frame from clobbering cloud `combat_state` with an empty payload during the cross-device pre-sync window.
- `_saveAndNotify` → `_saveSettingsPatch({'combat_state': session})`. The factory routes this through `pendingWriteBufferProvider.schedule(key: 'settings:$worldId:combat_state', kind: WriteKind.combatTick)` — coalesced (timer-reset) read-merge-write; `combatTick` debounce ≈ 500ms. No global `markDirty`, so the old `world_entities` delete+insertAll cycle never fires for combat ticks (F3 row-level).
- `_eventLogCap = 500`: `_log` trims oldest entries beyond cap.
- Combatant snapshot is a deep COPY of source stats — it never reads back from the live entity. Handles both v1 schema (`combat_stats` sub-map) and v2 flat schema (`hp_average`/`ac`/`initiative_modifier`/`initiative_score`). Characters preserve live current HP; non-char entities start at full HP.
- HP/AC write-back: `_syncCharacterFields` mirrors edits onto the source character entity — writes BOTH flat top-level keys (`hp`/`max_hp`/`ac`) AND the nested `combat_stats` sub-map (skipping the nested write caused the card HP to drift behind the header bar).
- Initiative: `_rollInitFromSpec` = `1d20 + _evalDiceSpec(spec)`. `_diceSpecRegex` = `([+-])?(\d*)d(\d+)|([+-])?(\d+)` — parses arbitrary mixes like `1d20+3`, `+2+1d6-1`. Monsters with flat `initiative_score >= 0` skip the dice (fixed init); players always roll. Sort is descending by init.
- `combatCapableSlugs`: category slugs where `allowedInSections.contains('encounter')`. Characters are always addable regardless of slug.
- `nextTurn`: increments turnIndex, wraps to round+1; on a new round, decrements all condition durations and drops expired ones.
- `getSessionState`: forced JSON round-trip (`jsonDecode(jsonEncode(...))`) because freezed `Encounter.toJson` lacks `explicitToJson` — without it nested `Combatant`/`CombatCondition` stay as object refs and `loadSessionState` crashes.
- `loadSessionState`: legacy heal — rebuilds a minimal `stats` map from typed `hp/maxHp/ac/init` fields when an older save dropped the per-combatant `stats` snapshot.
- Battle-map writes: `saveMapData` (mapPath/token positions/sizes/hiddenTokenIds), `saveFogAndAnnotation` (fogData/annotation/measurements/strokes/`sceneVectorJson` — null leaves unchanged, '' clears), `updateGridSettings` (gridSize/visible/snap/feetPerCell/diagonalRule/showAllHp/hideTokenHud), `toggleTokenHidden` (hidden tokens filtered out of player projection by snapshot builder, ghosted on DM map).

## Notes
- Combat state lives entirely inside `combat_state` in `world_settings.settings_json` — it does NOT use [[combat_dao]] (that DAO is for a separate normalized encounters/combatants table family that this provider does not touch).
- Related audits: HP "~3 HP" canonical-helper bug fix; eventLog cap 500 perf quick-win (Tier-1 May24).
