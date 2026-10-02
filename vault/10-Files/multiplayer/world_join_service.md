---
type: file-note
domain: multiplayer
path: flutter_app/lib/application/services/world_join_service.dart
layer: application
language: dart
status: stable
updated: 2026-10-02
tags: [file]
---

# `world_join_service.dart`

> [!abstract] Primary Purpose
> Coordinates the player "join with code" flow: redeem an invite, materialize a local Drift `worlds` shell (keyed by id), apply the world's card meta (`worlds.meta_json`), and link the built-in SRD pack so the joined world resolves correctly. **Content is NOT pulled here** (077): the player starts with an empty shell and everything else arrives as the DM shares it. Since Faz 5.5a the shell step stands alone (`materializeWorld`) so a player's second device rejoins from the hub without an invite code.

## Inputs / Outputs
**Inputs**
- Constructor deps: `WorldMembershipService membership`, `AppDatabase db`, `SupabaseClient supabase`, `CampaignRepository repository`.
- Supabase reads: `worlds` (`template_id, meta_json` via `maybeSingle`); `redeemInvite` RPC (through membership service); `world_members` (own `role = 'player'` rows embedding `worlds(world_name)`) for `listMemberWorlds`.
- Drift reads: `worlds` table (existing-by-id lookup; local ids to filter `listMemberWorlds`).

**Outputs**
- Public API: `joinWithCode(code)` → `(worldId, worldName)` = `redeemInvite` + `materializeWorld`; `materializeWorld(worldId, worldName)`; `listMemberWorlds()` → `[(id, name)]` of player memberships not on this device.
- Writes (Drift): `worldsDao.upsert` (new local world row); `repository.saveSettingsPatch(worldId, {'metadata': meta})` when the cloud row carries card meta.
- Side effects: installs + imports built-in SRD pack into the joined world when applicable.

## Dependencies & Links
- Depends on: [[world_meta_sync]], [[world_membership_service]], [[drift_database]], [[worlds_dao]], [[world_repository_impl]], [[srd_core_pack]], [[bundled_packs_bootstrap]]
- Used by: hub "Join with code" UI (caller invalidates hub list after); hub worlds tab "In the cloud, not on this device" section via `memberWorldsProvider` (`world_join_provider.dart`) → `materializeWorld`
- Domain map: [[Multiplayer-and-Online]]
- System flow: [[Sync-and-Realtime]], [[Share-Broadcast-Flow]]

## Key Logic / Variables
- Step order: `redeemInvite(code)` → `materializeWorld`: fetch `worlds.template_id`+`meta_json` (best-effort) → upsert local `worlds` row if no row with that id exists (an existing row keeps its local name) → apply card meta via `saveSettingsPatch` → link SRD pack.
- **Second device (Faz 5.5a)**: `redeem_world_invite` decrements `uses_left` even for an existing member, so re-entering the code would burn a use. `listMemberWorlds` lists player memberships whose world is not local; the hub runs `materializeWorld` directly. The DM's own worlds are not listed here — they come through `CloudPullService.listCloudOnlyWorlds` (full download). `onlineWorldIdsProvider` already knows the world from `world_members`, so the opened shell runs `applyInitialState` (shared cards, characters incl. the player's own, projection).
- Identity is the id (Faz 2.5): the old `" (2)"` name-clash suffixing is gone.
- **Card meta**: `decodeWorldMeta` ([[world_meta_sync]]) turns `meta_json` into the local `metadata` patch (description / tags / cover as a `dmt-public://` ref). Without it a joined world shows a nameplate and nothing else; later DM edits arrive over `worlds` CDC.
- **SRD link**: when effective `template_id == builtinDnd5eV2SchemaId`, runs `SrdCorePackageBootstrap(db).ensureInstalled()` then `SrdCoreBootstrap(db).ensureImported(...)` (idempotent via a `world_settings` flag) so synth resolves pristine Tier-0/Tier-1 entries.
- Content pull is NOT done here (077 dropped `worlds.state_json`): after `joinWithCode` the player sees the world card in the hub and receives content as the DM shares it — see [[Share-Broadcast-Flow]].

## Notes
- Meta fetch/apply and SRD-link failures are debug-logged and swallowed (non-fatal); the local world upsert failing rethrows.
