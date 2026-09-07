---
type: system
domain: media
updated: 2026-09-07
tags: [system]
---

# Media Storage Tiers

> [!summary] What this is
> Three storage tiers with different quota/lifecycle rules. Choosing the right tier per asset is the core media policy. Owned by [[Media-and-Assets]]; backends in [[Backend-Infra]].
>
> **Geçiş sürüyor:** Counted tier kaldırılıyor, havuz `pinned`/`transient`
> olarak ikiye bölünüyor — bkz. [`docs/media-storage-redesign.md`](../../docs/media-storage-redesign.md).
> **Uygulanan:** havuz bütçeleri + `pub/` pinned sınıfı (088/089, aşağıda).
> **Uygulanmayan:** oturum kapısı (`session_started_at`, talep-üzerine akış),
> counted tier sökümü, admin Storage sekmesi — bu notun geri kalanı hâlâ
> kodun bugünkü hâli.

## Participants
- [[free_media_service]] — free tier reads.
- [[entity_image_upload]] — counted tier uploads.
- [[worker]] / [[worker_rls]] — R2 routes + quota/access checks.
- [[entity_media_cleanup_service]] — GC on delete.
- [[pdf_library_service]] — world PDF kütüphanesi (counted tier, `world_pdf`).

## Tiers
| Tier | Backend | Quota-counted | Lifecycle |
|---|---|---|---|
| **Free** | Supabase Storage `free-media` bucket | **No** | Permanent; portraits + world/package covers; ≤2 MB/file |
| **Counted** | Cloudflare R2 `{userId}/{sha}.{ext}` | **Yes** (100 MB/user) | Permanent; user-uploaded maps/SFX/art — *kaldırılacak* |
| **Transient** | Cloudflare R2 `transient/{userId}/{sha}.{ext}` | **No** (LRU, **5 GB** global, per-user cap YOK) | Auto-evicted by `last_used_at`; multiplayer shared assets |
| **Pinned** | Cloudflare R2 `pub/{sha}.{ext}` | **No** (5 GB havuz, 500 MB/yayıncı) | Eviction yok; `pub_asset_refs` refcount 0 olunca kuyruğa atılır (089) |
| **First-party art** | App bundle `assets/art/srd/` + R2 `catalog/art/{uuid}.webp` | **No** (kullanıcı yüklemesi değil) | Salt-okunur, sürümsüz; `cacheDir/art/` altında cache'lenir |

## Flow
1. Upload → pick tier by kind (per-kind size caps: portrait/cover 4 MB, battle map 10 MB, **world_pdf 50 MB**, bilinmeyen kind için 20 MB ceiling).
2. Counted: `checkAssetQuota` RPC before PUT; `get_user_total_storage_used` sums counted + backups (excludes free).
3. Transient: `transient_reserve` (capacity + LRU evict), `transient_touch` on download (LRU refresh), worker `/transient/evict-sweep` pops queue.
4. Pinned: `pub_asset_reserve` RPC (dedup + cap; `exists=true` → PUT atlanır) → Worker `pub/` PUT'unda `get_pub_upload_allowed` rezervasyonu doğrular. `pub_asset_release` / hesap silme ref'i düşürür; son ref gidince `trg_drop_orphan_pub_asset` objeyi evict kuyruğuna atar (aynı `/transient/evict-sweep` endpoint'i, `r2_key` kolonu üzerinden).
5. Delete entity/world/package → [[entity_media_cleanup_service]] removes cloud copy (local cache kept).

## Key Constants / Invariants
- Free media **intentionally excluded** from quota (migration 053 invariant).
- Per-kind limit **yetkilidir**: Worker `KIND_MAX_BYTES[kind] ?? MAX_UPLOAD_BYTES`. `world_pdf` (50 MB) ceiling'in üstünde olduğu için `Math.min` kaldırıldı; bilinmeyen kind hâlâ 20 MB ceiling'e düşer.
- `application/pdf` Worker MIME allowlist'inde (`ALLOWED_MIME_EXACT`).
- Transient: per-user cap **yok** (089); dosya başına 100 MB emniyet kapağı (`transient_max_file_bytes()`), global pool 5 GB LRU. Rate: 20 DL/h, 60 UL/h per user.
- Pinned havuzu `transient`ten **ayrı bütçelidir** (5 GB / 5 GB): tek havuz olsaydı pinned büyüdükçe LRU'nun yiyebileceği alan sıfıra iner, paylaşımlar sessizce patlardı.
- `pub/` DELETE Worker'da **yasak** — silimi refcount belirler, doğrudan DELETE başkasının listing'ini yok ederdi.
- Paylaşım gövdeleri R2'de değil Postgres'te: `entity_shares.payload_json` ≤ **512 KB** (CHECK), dünya başına ≤ **4000** satır (`max_shares_per_world()` + trigger, 088). `worlds` silimi satırları CASCADE'le düşürür (026).

## Related
- MoCs: [[Media-and-Assets]], [[Backend-Infra]]
- Source Docs: `flutter_app/docs/security_media_supabase_r2_audit_may21.md`
