---
type: file-note
domain: backend
path: cloudflare/src/worker.ts
layer: backend
language: typescript
status: stable
updated: 2026-09-23
tags: [file]
---

# `worker.ts`

> [!abstract] Primary Purpose
> The `dmt-assets` Cloudflare Worker — the single HTTP gateway in front of the R2 bucket. It authenticates every asset request with a Supabase JWT, enforces RLS via service-role RPCs, applies per-minute rate limits and per-kind/quota size limits, and streams objects in/out of R2. It also hosts the public first-party content catalog (`/catalog/*`), the world-media **signing** route (`/world-media/sign`, Faz 5d — bytes never pass through the Worker) and admin maintenance routes (evict-sweep, full/per-user R2 purge). The Worker never writes the `community_assets` metadata row — the Flutter client does that.

## Inputs / Outputs
**Inputs**
- Bindings (`Env`): `R2_BUCKET` (R2), three platform rate limiters `CATALOG_RL` / `DL_RL` / `UL_RL` (shared `RateLimiter` interface), `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `ADMIN_TOKEN` (secret), `MAX_UPLOAD_BYTES`; Faz 5d: `R2_BUCKET_NAME` (var) + `R2_ACCOUNT_ID` / `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` (secret) — S3 API imzası.
- Request headers: `Authorization: Bearer <supabase jwt>`, `X-Asset-Kind`, `X-Content-SHA256`, `Content-Length`, `Content-Type`.
- Calls into `jwt.ts` (`verifyJwt`), `rls.ts` (`checkAssetAccess`, `checkPubUploadAllowed`, `popEvictQueue`, `worldMediaSignPut`, `worldMediaSignGet`), `presign.ts` (`presignR2`).
- Indirectly reads Supabase RPCs `get_asset_access`, `get_pub_upload_allowed`, `r2_evict_pop`, `world_media_sign_put`, `world_media_sign_get` (all service-role only).

**Outputs**
- R2 object stream (GET), R2 put (PUT), R2 delete (DELETE / purge).
- JSON status responses (`jsonResponse`), `429` rate-limited responses with `Retry-After`.
- Admin endpoints return purge/sweep counts.

## Dependencies & Links
- Depends on: [[worker_jwt]], [[worker_rls]], [[rpc-reference]], [[migrations-media-storage]]
- Used by: [[entity_image_upload]], [[free_media_service]], `beta_purge_with_cleanup` edge fn (kaldırıldı), [[wrangler_config]]
- Domain map: [[Backend-Infra]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[migrations-security]]

## Key Logic / Variables
- **Routing** (`handleRequest`): `OPTIONS`→CORS 204; `/admin/evict-sweep`, `/admin/purge-all` (admin-gated POST), `/admin/purge-user` (admin token **or** self JWT); `/world-media/sign` (JWT POST); `/catalog/{key}` (public GET, admin PUT/DELETE); `/assets/{key}` (JWT-gated GET/PUT/DELETE). Key sanitized against `..`, leading `/`, `//`. JWT'yi `authenticate()` çözer (`/assets` ve imza ucu ortak).
- **Auth**: `/assets/*` requires `Bearer` JWT verified by `verifyJwt`; `payload.sub` becomes `userId`. Admin routes use `checkAdminAuth` — constant `ADMIN_TOKEN` Bearer (rejects if token < 16 chars).
- **Download** (`handleDownload`): rate-limit (`DL_RL`, key = userId) → RLS. `pub/...` (pinned marketplace medyası) JWT dışında kapı tutmaz — listing'ler zaten anon taranabiliyor; `worlds/...` bu yoldan **hiç** servis edilmez (403 — imzalı URL'le R2'den); all other keys use `checkAssetAccess(userId, r2Key)`. On allow, streams R2 object with `Cache-Control: private, max-age=604800` and `X-Content-SHA256`.
- **Upload** (`handleUpload`): yazılabilir **tek** prefix `pub/{sha}{ext}` (transient 5d'de kalktı; dünya medyası imzalı URL'le doğrudan R2'ye). Başka her key `410 counted_tier_retired` döner (sayılan katman Phase D'den beri emekli; GET hâlâ çalışıyor, eski kopyalar insin diye). `pub/{sha}.{ext}` içerik-adresli olduğu için key'de userId yok; onun yerine (a) key'in sha'sı `X-Content-SHA256` ile birebir eşleşmeli (`400 pub_key_sha_mismatch`, yoksa rezerve edilen sha başka bir key'e yazılabilirdi) ve (b) `checkPubUploadAllowed` ile rezervasyon doğrulanır (`403 pub_not_reserved`). Cap'ler `pub_asset_reserve` RPC'sinde (099'dan beri toplam tavan dünya medyasıyla ortak). Rate-limit (`UL_RL`, key = userId). Size limit = `KIND_MAX_BYTES[X-Asset-Kind] ?? MAX_UPLOAD_BYTES`. Kota kontrolü **yok** — kullanıcı başına kalıcı depolama kotası kaldırıldı; kalan tavanlar havuz tarafında (`transient_reserve`, `pub_asset_reserve`). MIME allowlist: `image/*`, `audio/*`, plus exact `application/gzip`, `application/octet-stream`. `X-Content-SHA256` must be 64 hex chars. Stores `customMetadata`: uploader, sha256, `pinned:'true'`.
- **`KIND_MAX_BYTES`** (yalnız `pub/` PUT'u): portrait/cover = 4 MB; entity/extra/mind-map görselleri = 5 MB; `battle_map` = 10 MB; `world_audio` = 10 MB; `world_pdf` = 20 MB. Must stay in sync with Flutter `MediaKind` — ve dünya medyası için 099'un `world_media_max_bytes`'ı ile aynı sayılar.
- **World-media signing** (`handleWorldMediaSign`, Faz 5d): `POST /world-media/sign {op: 'put'|'get', world_id?, shas}` — JWT → rate limit (put `UL_RL`, get `DL_RL`; **istek başına** bir jeton, 100 sha) → **tek** RPC (`world_media_sign_put` sahiplik + rezervasyon, `world_media_sign_get` üyelik + onay) → her satır için `presignR2` (1 sa). PUT imzası `content-length` + `content-type`'ı bağlar: R2 farklı boyuttaki gövdeyi imza uyuşmazlığıyla reddeder, dosya limiti worker'sız zorlanır. İzni olmayan sha yanıt haritasında yoktur (hata değil). Kimlik bilgisi eksikse `503 presign_not_configured`. `presign.ts` bağımlılıksız SigV4 (WebCrypto HMAC); `npm run check` onu AWS'nin yayımlanmış test vektörüyle doğrular.
- **Catalog** (`handleCatalog`): GET is public, per-IP rate-limited via the **platform `CATALOG_RL` binding** (300/min). 2026-09-21'den beri `dl`/`ul` de aynı yolda — KV sayacı ve `rate_limit.ts` tamamen silindi, bkz. [[wrangler_config]]. `manifest.json` cached 120 s; versioned payloads `public, max-age=31536000, immutable`. PUT/DELETE need `ADMIN_TOKEN`. Objects live under `catalog/` prefix.
- **Delete** (`handleDelete`): `pub/` **reddedilir** (`403 pinned_delete_forbidden`) — pinned objeler paylaşımlı, silimi refcount belirler. Diğerlerinde prefix eşleşmesi.
- **Cron** (`scheduled()`, `wrangler.toml [triggers]`, hourly): calls the same `sweepEvictQueue(env, 500)` body the HTTP trigger uses. The sweep body was extracted out of the handler precisely so the two share it. Errors are logged (`evict_sweep_cron_failed`) and swallowed — a failed tick just retries next hour.
- **Maintenance**: `handleEvictSweep` (`/admin/evict-sweep`) pops up to 500 (clamp) rows from `r2_evict_pop` (090/099: bayat satır kuyruktan düşer ama obje hâlâ canlıysa worker'a DÖNMEZ, yani yeniden pinlenmiş / yeniden yüklenmiş obje silinmez), deletes `row.r2_key` — `pub/` refcount düşüşleri ve `worlds/` satır silmeleri. `handleAdminPurgeAll` cursor-paginates R2 (5 pages × 1000/invocation, batch-200 parallel delete), `?dry=1` counts only, returns `next_cursor`. `handleAdminPurgeUser` sweeps the `{userId}/` prefix (UUID rough-validated `[0-9a-fA-F-]{20,64}`); dünya medyası hesap silinince worlds CASCADE → `world_media` → kuyruk yoluyla gider. Auth burada iki kapılı: `ADMIN_TOKEN` **veya** `sub == body.user_id` olan bir kullanıcı JWT'si — hesap silme akışı istemciden çağırdığı için (admin token'ı istemciye inmez), başkasının prefix'i `403 forbidden`. Body önce parse edilir ki JWT'nin `sub`'ı doğrulanacak id ile karşılaştırılabilsin. Çağıran: [[account_deletion_service]].

## Notes
- Worker is the enforcement point for the **pinned** pool and the **permission** gate of world media (bytes of the latter go straight to R2 via presigned URLs); the **free** tier goes directly to Supabase Storage and never touches this Worker (see [[migrations-media-storage]]).
- DB↔R2 consistency on purge is the caller's responsibility; orphan `community_assets`/`free_media_assets` rows must be cleared by migration/RPC first.
- Worker NOT deployed to production per memory notes (catalog initiative deferred).
