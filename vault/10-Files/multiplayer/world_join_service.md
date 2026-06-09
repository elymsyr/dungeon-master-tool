---
type: file-note
domain: multiplayer
path: flutter_app/lib/application/services/world_join_service.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `world_join_service.dart`

> [!abstract] Primary Purpose
> Coordinates the player "join with code" flow: redeem an invite, pull the world's initial state snapshot from Supabase, materialize a local Drift `Campaign`/`worlds` row (resolving name clashes), and link the built-in SRD pack so the joined world resolves correctly before full entity sync arrives.

## Inputs / Outputs
**Inputs**
- Constructor deps: `WorldMembershipService membership`, `AppDatabase db`, `SupabaseClient supabase`, `CampaignRepository repository`.
- Supabase reads: `worlds` (`state_json`, `template_id` via `maybeSingle`); `redeemInvite` RPC (through membership service).
- Drift reads: `worlds` table (existing-by-id and name-clash lookups).

**Outputs**
- Public API: `joinWithCode(code)` → `(worldId, worldName)`.
- Writes (Drift): `worldsDao.upsert` (new local world row); `repository.save(localName, parsed)` (full campaign state when a snapshot exists).
- Side effects: installs + imports built-in SRD pack into the joined world when applicable.

## Dependencies & Links
- Depends on: [[world_membership_service]], [[drift_database]], [[worlds_dao]], [[world_repository_impl]], [[srd_core_pack]], [[bundled_packs_bootstrap]]
- Used by: hub "Join with code" UI (caller invalidates hub list after)
- Domain map: [[Multiplayer-and-Online]]
- System flow: [[Sync-and-Realtime]], [[CDC-Sync-Flow]]

## Key Logic / Variables
- Step order: `redeemInvite(code)` → fetch `worlds.state_json`+`template_id` (best-effort; parse only if non-empty and not `{}`) → resolve local name → upsert local `worlds` row → `repository.save` the snapshot → link SRD pack.
- **Name-clash resolution (critical)**: `repository.save` keys by world *name*. If no local row exists with the same id but a different local campaign already uses `res.worldName`, it suffixes `" (2)"`, `" (3)"`… up to 99 attempts, then falls back to `"$name-${worldId[0:8]}"`. This avoids overwriting the player's unrelated local data.
- Before saving the snapshot, `parsed['world_id']` and `parsed['world_name']` are forced to the resolved id/local label — server content is authoritative but the local row keys off the local id/name.
- **SRD link**: when effective `template_id == builtinDnd5eV2SchemaId`, runs `SrdCorePackageBootstrap(db).ensureInstalled()` then `SrdCoreBootstrap(db).ensureImported(...)` (idempotent via a `world_settings` flag) so synth resolves pristine Tier-0/Tier-1 entries.
- Entity / mind-map / character mirror pull is NOT done here (deferred to `WorldSyncService`, PR-O4); after `joinWithCode` the player just sees and can open the world in the hub.

## Notes
- Snapshot fetch and SRD-link failures are debug-logged and swallowed (non-fatal); local-save failure rethrows.
