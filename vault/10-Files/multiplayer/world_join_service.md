---
type: file-note
domain: multiplayer
path: flutter_app/lib/application/services/world_join_service.dart
layer: application
language: dart
status: stable
updated: 2026-09-13
tags: [file]
---

# `world_join_service.dart`

> [!abstract] Primary Purpose
> Coordinates the player "join with code" flow: redeem an invite, materialize a local Drift `Campaign`/`worlds` row (resolving name clashes), apply the world's card meta (`worlds.meta_json`), and link the built-in SRD pack so the joined world resolves correctly. **Content is NOT pulled here** (077): the player starts with an empty shell and everything else arrives as the DM shares it.

## Inputs / Outputs
**Inputs**
- Constructor deps: `WorldMembershipService membership`, `AppDatabase db`, `SupabaseClient supabase`, `CampaignRepository repository`.
- Supabase reads: `worlds` (`template_id, meta_json` via `maybeSingle`); `redeemInvite` RPC (through membership service).
- Drift reads: `worlds` table (existing-by-id and name-clash lookups).

**Outputs**
- Public API: `joinWithCode(code)` → `(worldId, worldName)`.
- Writes (Drift): `worldsDao.upsert` (new local world row); `repository.saveSettingsPatch(localName, {'metadata': meta})` when the cloud row carries card meta.
- Side effects: installs + imports built-in SRD pack into the joined world when applicable.

## Dependencies & Links
- Depends on: [[world_meta_sync]], [[world_membership_service]], [[drift_database]], [[worlds_dao]], [[world_repository_impl]], [[srd_core_pack]], [[bundled_packs_bootstrap]]
- Used by: hub "Join with code" UI (caller invalidates hub list after)
- Domain map: [[Multiplayer-and-Online]]
- System flow: [[Sync-and-Realtime]], [[Share-Broadcast-Flow]]

## Key Logic / Variables
- Step order: `redeemInvite(code)` → fetch `worlds.template_id`+`meta_json` (best-effort) → resolve local name → upsert local `worlds` row → apply card meta via `saveSettingsPatch` → link SRD pack.
- **Name-clash resolution (critical)**: `repository.save` keys by world *name*. If no local row exists with the same id but a different local campaign already uses `res.worldName`, it suffixes `" (2)"`, `" (3)"`… up to 99 attempts, then falls back to `"$name-${worldId[0:8]}"`. This avoids overwriting the player's unrelated local data.
- **Card meta**: `decodeWorldMeta` ([[world_meta_sync]]) turns `meta_json` into the local `metadata` patch (description / tags / cover as a `dmt-public://` ref). Without it a joined world shows a nameplate and nothing else; later DM edits arrive over `worlds` CDC.
- **SRD link**: when effective `template_id == builtinDnd5eV2SchemaId`, runs `SrdCorePackageBootstrap(db).ensureInstalled()` then `SrdCoreBootstrap(db).ensureImported(...)` (idempotent via a `world_settings` flag) so synth resolves pristine Tier-0/Tier-1 entries.
- Content pull is NOT done here (077 dropped `worlds.state_json`): after `joinWithCode` the player sees the world card in the hub and receives content as the DM shares it — see [[Share-Broadcast-Flow]].

## Notes
- Meta fetch/apply and SRD-link failures are debug-logged and swallowed (non-fatal); the local world upsert failing rethrows.
