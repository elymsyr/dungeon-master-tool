---
type: file-note
domain: backend
path: supabase/migrations/072_security_hardening.sql, 073_revoke_anon_execute.sql, 074_lock_internal_helper.sql, 044_beta_exit_world_purge.sql, 063_beta_slot_cap_90.sql, 064_beta_full_reset.sql, 066_beta_access_requests.sql, 069_notifications.sql
layer: backend
language: sql
status: stable
updated: 2026-06-09
tags: [file]
---

# `Migrations — Security Hardening, Beta Gates & Broadcast`

> [!abstract] Primary Purpose
> Security/lockdown and beta-program governance. Pins `search_path` on volatile functions, strips `anon` EXECUTE from every `SECURITY DEFINER` RPC (closing Supabase linter findings 0028/0029 and per-uuid info-leak oracles), beta-gates online publishing while keeping JOIN open, manages slot caps / mass wipes / admin-approval request flow, and adds the admin broadcast notification system.

## Inputs / Outputs
**Inputs**
- Run in Supabase SQL Editor. Touch existing RPC grants + `beta_participants`, all `worlds`/`world_characters`/personal-package/asset tables.

**Outputs**
- Grant/attribute changes (072–074), `beta_requests` table (066), `notifications` / `notification_responses` / `notification_reads` (069).
- RPCs: `leave_beta`, `_leave_beta_for`, `request_beta`, `cancel_beta_request`, `admin_*_beta_request`, `admin_create_notification`, `list_notifications`, etc. (see [[rpc-reference]]).

## Dependencies & Links
- Depends on: [[migrations-auth-social]], [[migrations-online-worlds]], [[migrations-media-storage]]
- Used by: [[edge-beta-purge]], [[beta_enter_gate]], [[heartbeat_service]], [[rpc-reference]]
- Domain map: [[Backend-Infra]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[Multiplayer-and-Online]]

## Key Logic / Variables — per migration
- **072_security_hardening** — (A) Pins `SET search_path = public, pg_temp` on 10 volatile fns (the `*_cap`/`max_*` constants, `tg_bump_updated_at`, `compact_battlemap_marks`, etc.). (B) Loops `pg_proc` for all `public` `prosecdef=true` fns and `REVOKE EXECUTE ... FROM anon`. Bodies unchanged; admin RPCs already self-guard with `is_admin()` — this is defense-in-depth.
- **073_revoke_anon_execute** — Fixes 072 Part B being a no-op (anon inherits EXECUTE via PUBLIC). Captures current `authenticated`/`service_role` privilege with `has_function_privilege`, `REVOKE EXECUTE ... FROM PUBLIC`, then re-grants the captured roles — so only `anon` is actually closed.
- **074_lock_internal_helper** — (1) Strips all client-role EXECUTE from internal helper `_assert_admin_rate_limit()` (only called from inside other DEFINER fns, where EXECUTE is checked against the function owner). (2) Revokes `anon` EXECUTE on beta oracles `is_beta_active(uuid)` and `get_beta_status()` — both were per-uuid / free-slot info-leak oracles; `authenticated` retained (real users unaffected).
- **044_beta_exit_world_purge** — `leave_beta()` extended to cascade-delete owned worlds + `world_packages`. `publish_world` / `share_package_to_world` beta-gated (only beta-active users create/share online). World JOIN (`redeem_world_invite`, `claim_character`) stays OPEN for non-beta players.
- **063_beta_slot_cap_90** — `beta_slot_cap()` IMMUTABLE → 90 (was 200); `get_beta_status`/`join_beta` read it automatically. No row deletion here.
- **064_beta_full_reset** — One-shot IRREVERSIBLE mass wipe: extracts `leave_beta` body into `_leave_beta_for(uid)` (service_role), then a `DO` block runs it for every `beta_participants` user; clears `campaign-backups` + `free-media` storage objects. No-op on re-run.
- **066_beta_access_requests** — Beta is now admin-approval: `beta_requests` table (PK `user_id`, message ≤500). `_grant_beta_slot(uid)` helper holds slot allocation. `join_beta()` now creates a request (`requested|already|pending|not_signed_in`). `request_beta(msg)` (UPSERT), `cancel_beta_request()`, `admin_list_beta_requests()`, `admin_approve_beta_request`, `admin_reject_beta_request`.
- **069_notifications** — Admin broadcast: `notifications` (title + JSONB blocks: markdown/poll/input), `notification_responses` (one per user, poll/input answers), `notification_reads` (badge tracking). RLS: published → world-readable; writes only via DEFINER RPCs (`admin_create_notification`, `list_notifications`, `submit_notification_response`, `mark_notification_read`, `dismiss_read_notifications`, `admin_notification_responses`, ...). Both tables added to realtime publication.

## Notes
- Related but not in this group: 067 (`_purge_beta_user` shared body + `admin_revoke_beta`), 068 (beta quota 100 MB), 070 (14-day inactivity sweep). See [[rpc-reference]].
- Beta exit/purge of R2 + Storage is done by the [[edge-beta-purge]] edge function, which calls these RPCs and then sweeps Storage + the Worker `/admin/purge-user`.
