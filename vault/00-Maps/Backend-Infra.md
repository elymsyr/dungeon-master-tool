---
type: moc
domain: backend
updated: 2026-08-27
tags: [moc]
---

# Backend Infra — Map of Content

> [!summary] Scope
> Server side: Supabase Postgres (79 numbered migrations, RLS policies, RPC functions) + the Cloudflare R2 worker (asset/catalog/admin routes, JWT verify, RLS calls, rate limiting). The "Camera Host Services" analogue — everything the client talks to over the network.

## Key Files
- [[worker]] (`cloudflare/src/worker.ts`) — routes: `/assets/*`, `/catalog/*`, `/transient/*`, `/admin/*`.
- [[worker_jwt]] (`jwt.ts`) — Supabase token verification.
- [[worker_rls]] (`rls.ts`) — RPC calls for access/quota checks.
- [[worker_rate_limit]] (`rate_limit.ts`) — KV-backed leaky-bucket limits.
- [[wrangler_config]] (`wrangler.toml`) — R2 bucket, KV, env vars, limits.
- [[migrations-auth-social]] — 001–005 backups/assets/social/marketplace.
- [[migrations-online-worlds]] — 026 shared worlds + invites + realtime mirror.
- [[migrations-media-storage]] — 053/065 free-media bucket + transient LRU pool.
- [[migrations-security]] — 072/073 RLS hardening + revoke anon execute.
- [[rpc-reference]] — key RPCs: `transient_reserve/touch/evict_pop`, `get_user_total_storage_used`, `is_admin`, `delete_my_account` (083).
- Hesap silme: `/admin/purge-user` artık admin token'ın yanında **kendi JWT'siyle** de çağrılabilir; akışın tamamı [[account_deletion_service]].

## Data Flow
Client JWT → [[worker]] → [[worker_jwt]] verify → [[worker_rls]] RPC (ownership/quota) → R2 stream. Realtime: DM'in paylaşım kanalı (beş tablo) → client [[world_mirror_applier]] (see [[Share-Broadcast-Flow]]).

## Related Domains
- [[Sync-and-Realtime]] (CDC source) · [[Media-and-Assets]] (storage policy) · [[Multiplayer-and-Online]] (RLS, membership) · [[Deployment-and-Ops]].

## Source Docs
- `supabase/README.md`, `flutter_app/docs/security_media_supabase_r2_audit_may21.md`.
