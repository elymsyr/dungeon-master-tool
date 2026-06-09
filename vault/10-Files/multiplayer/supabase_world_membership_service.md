---
type: file-note
domain: multiplayer
path: flutter_app/lib/data/network/supabase_world_membership_service.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `supabase_world_membership_service.dart`

> [!abstract] Primary Purpose
> Supabase-backed implementation of `WorldMembershipService`. A thin transport layer — all authorization is enforced by RLS policies and SECURITY DEFINER RPCs defined in the online-worlds migrations; this class just marshals params, calls RPCs / table ops, and parses results.

## Inputs / Outputs
**Inputs**
- Constructor deps: `SupabaseClient client`.
- Reads (Supabase tables): `worlds`, `world_members`, `world_invites`, `profiles`.

**Outputs**
- Supabase RPC called: `publish_world`, `create_world_invite`, `ensure_world_invite`, `regenerate_world_invite`, `redeem_world_invite`.
- Supabase table writes: `worlds` delete (unpublish), `world_members` delete (removeMember/leaveWorld), `world_invites` delete (revokeInvite).
- Returns domain `WorldMember` / `WorldInvite` lists and `(worldId, worldName)` records.

## Dependencies & Links
- Depends on: [[world_membership_service]], [[world_member]], [[world_invite]], [[world_role]]
- Used by: [[world_membership_provider]] (via `worldMembershipServiceProvider`)
- Domain map: [[Multiplayer-and-Online]]
- Spec / reference: [[migrations-online-worlds]], [[rpc-reference]]

## Key Logic / Variables
- `_uid` getter throws `StateError` if no auth session — every method assumes an authenticated user.
- **publishWorld**: entire flow delegated to `publish_world` RPC (migration 029): SECURITY DEFINER + row_security off, atomically upserts `worlds` + `world_members`, tolerates orphan rows, throws a clear error if a different account owns the world. PostgrestExceptions are debug-logged (code/msg/details/hint) then rethrown.
- **unpublishWorld**: PostgREST `delete().eq('id',…).select('id')`; if 0 rows returned, re-checks via `maybeSingle` — absent row = idempotent success, present row = throw `StateError` ("RLS rejected — not owner"). This prevents the local delete flow from being undone by a later refresh.
- **redeemInvite**: uppercases + trims code before calling `redeem_world_invite`; returns first row's `world_id`/`world_name`.
- **listMembers**: NO PostgREST embedded join (no FK between `world_members` and `profiles`, both reference `auth.users`). Does two queries — `world_members` then `profiles` filtered by `.inFilter('user_id', userIds)` — and merges client-side into `WorldMember`.
- `_parseRole`: `'dm'→dm`, `'player'→player`, else `none`.
- Invite codes are normalized to UPPERCASE for revoke/redeem.

## Notes
- This file is the canonical place to discover which RPCs back each membership operation; cross-check arg names against [[rpc-reference]].
