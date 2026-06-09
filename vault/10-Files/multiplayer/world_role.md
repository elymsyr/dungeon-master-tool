---
type: file-note
domain: multiplayer
path: flutter_app/lib/domain/entities/online/world_role.dart
layer: domain
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `world_role.dart`

> [!abstract] Primary Purpose
> The `WorldRole` enum and its `WorldRoleX` extension — the canonical model for a user's authority in a world, gating DM-vs-player UI and visibility throughout the online stack.

## Inputs / Outputs
**Inputs**
- n/a (pure enum + extension)

**Outputs**
- Public API exposed: `enum WorldRole { dm, player, none }` and extension getters `isDm`, `isPlayer`, `isOnline`.

## Dependencies & Links
- Depends on: (none)
- Used by: [[world_member]], [[supabase_world_membership_service]], [[world_membership_provider]]
- Domain map: [[Multiplayer-and-Online]]
- System flow: [[Fog-of-War-and-Visibility]]

## Key Logic / Variables
- `dm` — full read/write administrator of the world.
- `player` — invited member: restricted visibility (fog/hidden tokens etc.) + their own claimed character.
- `none` — world is not online OR the user is not a member. This is the default for local-only worlds, in which case the entire UI renders in DM mode.
- Extension semantics: `isDm == (this == dm)`, `isPlayer == (this == player)`, `isOnline == (this != none)`.
- String parsing lives in the consumers (`_parseRole` switch in [[supabase_world_membership_service]] and [[world_membership_provider]]): `'dm'→dm`, `'player'→player`, anything else `→none`.

## Notes
- No JSON serialization here; role strings come straight off Supabase rows and are switch-mapped by callers.
