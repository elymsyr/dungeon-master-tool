---
type: file-note
domain: multiplayer
path: flutter_app/lib/domain/entities/online/world_invite.dart
layer: domain
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `world_invite.dart`

> [!abstract] Primary Purpose
> Freezed/JSON value object mirroring one `public.world_invites` row — a join code created by a DM that players redeem to join an online world.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none (plain immutable data class)
- Reads / Supabase / CDC / Events / Triggers: n/a (domain entity)

**Outputs**
- Providers / public API exposed: `WorldInvite` immutable class + `WorldInvite.fromJson` / `toJson`
- Writes / Supabase / Events: n/a

## Dependencies & Links
- Depends on: (none — pure data)
- Used by: [[supabase_world_membership_service]], [[world_membership_service]], [[world_membership_provider]], [[world_invites_dao]]
- Domain map: [[Multiplayer-and-Online]]

## Key Logic / Variables
- Fields: `code` (the redeemable string), `worldId`, `createdBy` (DM user id), `usesLeft` (int — remaining redemptions), `createdAt` (DateTime), `expiresAt` (nullable DateTime).
- Gotcha: like `WorldMember`, this domain class coexists with a same-named Drift row type generated from the `WorldInvites` table; `world_invites_dao.dart` works with the Drift row type, the network layer with this one.

## Notes
- The current product flow favors a single shareable code per world via `ensureInvite`; `usesLeft`/`expiresAt` remain from the older multi-use `createInvite` API.
