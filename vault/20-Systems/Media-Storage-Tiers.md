---
type: system
domain: media
updated: 2026-06-09
tags: [system]
---

# Media Storage Tiers

> [!summary] What this is
> Three storage tiers with different quota/lifecycle rules. Choosing the right tier per asset is the core media policy. Owned by [[Media-and-Assets]]; backends in [[Backend-Infra]].

## Participants
- [[free_media_service]] — free tier reads.
- [[entity_image_upload]] — counted tier uploads.
- [[worker]] / [[worker_rls]] — R2 routes + quota/access checks.
- [[entity_media_cleanup_service]] — GC on delete.

## Tiers
| Tier | Backend | Quota-counted | Lifecycle |
|---|---|---|---|
| **Free** | Supabase Storage `free-media` bucket | **No** | Permanent; portraits + world/package covers; ≤2 MB/file |
| **Counted** | Cloudflare R2 `{userId}/{sha}.{ext}` | **Yes** (100 MB/user) | Permanent; user-uploaded maps/SFX/art |
| **Transient** | Cloudflare R2 `transient/{userId}/{sha}.{ext}` | **No** (LRU, 10 GB global) | Auto-evicted by `last_used_at`; multiplayer shared assets |

## Flow
1. Upload → pick tier by kind (per-kind size caps: portrait/cover 4 MB, battle map 10 MB, default 20 MB ceiling).
2. Counted: `checkAssetQuota` RPC before PUT; `get_user_total_storage_used` sums counted + backups (excludes free).
3. Transient: `transient_reserve` (capacity + LRU evict), `transient_touch` on download (LRU refresh), worker `/transient/evict-sweep` pops queue.
4. Delete entity/world/package → [[entity_media_cleanup_service]] removes cloud copy (local cache kept).

## Key Constants / Invariants
- Free media **intentionally excluded** from quota (migration 053 invariant).
- Per-user transient cap 100 MB; global pool 10 GB LRU. Rate: 20 DL/h, 60 UL/h per user.

## Related
- MoCs: [[Media-and-Assets]], [[Backend-Infra]]
- Source Docs: `flutter_app/docs/security_media_supabase_r2_audit_may21.md`
