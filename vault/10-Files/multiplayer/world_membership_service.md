---
type: file-note
domain: multiplayer
path: flutter_app/lib/data/network/world_membership_service.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `world_membership_service.dart`

> [!abstract] Primary Purpose
> Abstract interface for all online-world membership and invite operations: publishing/unpublishing a world, minting/redeeming/revoking invite codes, and listing/removing/leaving members. Implemented online by `SupabaseWorldMembershipService` and offline by `NoOpWorldMembershipService`.

## Inputs / Outputs
**Inputs**
- Constructor deps: none (abstract)
- Domain types consumed: `WorldMember`, `WorldInvite`

**Outputs**
- Public API (the contract):
  - `publishWorld({worldId, worldName, templateId?, templateHash?, stateJson})` — make a world online (upsert `worlds` row; DM auto-added as member by trigger).
  - `unpublishWorld(worldId)` — delete the cloud world (cascade all mirror data).
  - `createInvite({worldId, expiresSeconds?, uses=1})` — legacy N-uses code.
  - `ensureInvite(worldId)` — idempotent single shareable code (returns existing or mints one).
  - `regenerateInvite(worldId)` — delete current code, mint a new one.
  - `redeemInvite(code)` → `(worldId, worldName)` — player joins.
  - `listMembers(worldId)` / `listInvites(worldId)`.
  - `removeMember({worldId, userId})` — DM kicks a member.
  - `leaveWorld(worldId)` — self leave (DM must `unpublishWorld` first).
  - `revokeInvite(code)`.

## Dependencies & Links
- Depends on: [[world_member]], [[world_invite]]
- Used by: [[supabase_world_membership_service]], [[world_membership_provider]], [[world_join_service]]
- Domain map: [[Multiplayer-and-Online]]

## Key Logic / Variables
- Pure interface — no logic. Authority/algorithm lives in the Supabase RPCs + RLS (see [[supabase_world_membership_service]]).
- Offline fallback: `NoOpWorldMembershipService` (separate file) returns empty/no-op for every method when Supabase is unconfigured or unauthenticated; consumers branch on `is NoOpWorldMembershipService`.

## Notes
- Prefer `ensureInvite` over `createInvite` for the single-shareable-code product flow.
