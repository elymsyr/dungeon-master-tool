---
type: file-note
domain: multiplayer
path: flutter_app/lib/application/providers/world_membership_provider.dart
layer: application
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `world_membership_provider.dart`

> [!abstract] Primary Purpose
> Riverpod providers for online-world membership: selects the real-vs-NoOp membership service, and exposes a granular, CDC-driven roster cache plus invite-code providers consumed by the DM hub and player roster widgets.

## Inputs / Outputs
**Inputs**
- Providers watched: `authProvider` (presence of session), `connectivityProvider` (via `guardedNetwork`), `SupabaseConfig.isConfigured`.
- Constructor deps (`WorldMembersNotifier`): `Ref`, `WorldMembershipService`, nullable `SupabaseClient`, `worldId`.
- Supabase reads: `profiles` (batched, in `_ProfileBatchLoader`); `listMembers`/`listInvites`/`ensureInvite` via the service.
- CDC events consumed: `applyJoin(row)` (INSERT/UPDATE) and `applyLeave(userId)` (DELETE) — fed externally by the world-members realtime subscription.

**Outputs**
- Providers exposed:
  - `worldMembershipServiceProvider` → `WorldMembershipService` (Supabase impl if configured+authed, else `NoOpWorldMembershipService`).
  - `worldMembersProvider.family(worldId)` → `StateNotifierProvider` of `AsyncValue<List<WorldMember>>` (auto-bootstraps on create).
  - `worldInvitesProvider.family(worldId)` → `FutureProvider<List<WorldInvite>>`.
  - `worldActiveInviteCodeProvider.autoDispose.family(worldId)` → `FutureProvider<String?>` (the single shareable code via `ensureInvite`; returns null on error).

## Dependencies & Links
- Depends on: [[world_membership_service]], [[supabase_world_membership_service]], [[world_member]], [[world_invite]], [[world_role]], [[auth_provider]]
- Used by: [[world_join_service]] (service provider); DM hub + player roster UI
- Domain map: [[Multiplayer-and-Online]]
- System flow: [[CDC-Sync-Flow]], [[Sync-and-Realtime]]

## Key Logic / Variables
- **WorldMembersNotifier**: bootstrap-once cache. `bootstrap({force})` fetches `listMembers` once (guarded by `_bootstrapped`; `force` bypasses for re-subscribe / world reopen); on offline error logs and stays. After bootstrap, CDC events mutate the in-memory list in O(1) rather than re-fetching the whole roster:
  - `applyJoin`: skips rows for other worlds, fetches profile (batched), upserts member by `userId` (replace if present else add).
  - `applyLeave`: removes by `userId`; no-op if absent.
  - `clear()` resets `_bootstrapped=false` + empties; `refresh()` resets flag and re-bootstraps.
- **_ProfileBatchLoader (R4 optimization)**: coalesces profile fetches in a **16ms window** into a single `profiles.inFilter('user_id', ids)` query, so a multi-person realtime burst issues one query instead of N. Resolved profiles are session-cached (subsequent join/update events for the same user hit the cache; name changes only refresh via `bootstrap(force:true)` on resubscribe). Pending completers are completed with `null` on dispose.
- NoOp service short-circuits: `worldMembersProvider` → `[]`, `worldInvitesProvider` → `[]`, `worldActiveInviteCodeProvider` → `null`.
- `worldActiveInviteCodeProvider` is `autoDispose` so closing the Save & Sync dialog clears a possibly-null-cached code before an offline→online transition.

## Notes
- The roster is intentionally NOT mirrored through Drift here; it is an in-memory cloud cache. Drift persistence of members lives in [[world_members_dao]] for the offline-first sync path.
