# Güvenlik & Optimizasyon Analizi — Media / R2 / Supabase

**Tarih:** 2026-05-21
**Kapsam:** Medya yükleme sistemi, Cloudflare Worker + R2, Supabase
migration'ları ve RLS politikaları.

## Yeniden Doğrulama — 2026-05-22

Audit'ten 1 gün sonra kod yeniden tarandı. **Tüm bulgular (M1–M7, S1–S8,
O1–O2) hâlâ geçerli — hiçbiri düzeltilmedi.** Önerilen `059`/`060`
migration'ları oluşturulmadı; en yüksek migration hâlâ `058`. Worker
(`worker.ts`, `rate_limit.ts`) audit anındaki durumla birebir aynı.

Bu arada commit `5968979` medya galerisini (`media_gallery_dialog.dart`,
`media_provider.dart`) kaldırıp yerine eager-upload servisleri ekledi:
`entity_image_upload.dart`, `map_image_upload.dart`, `media_bundler.dart`. Bu
değişiklik **sunucu saldırı yüzeyini değiştirmez** — aynı Worker `PUT /assets`
ve Supabase `free-media` yollarını kullanır. M4'teki "metadata insert'i istemci
yapar" durumu yeni eager-upload servislerinde de aynı; M4 hâlâ geçerli. Audit
server-tarafı odaklı olduğundan bulgular olduğu gibi durur.

İki bulguda hassaslaştırma:

- **S4** — ≥`005` migration'larındaki SECURITY DEFINER fonksiyonları çoğunlukla
  `SET search_path = public` içeriyor (`006`/`043`/`054` doğrulandı). Yalnız
  pre-`005` fonksiyonlar taranmalı → pratik önem MEDIUM→LOW.
- **S7** — 3 aday index'ten biri zaten **var**: `idx_world_characters_claim`
  (`039_unify_character_ownership.sql:57`). Kalan ikisi hâlâ yok.

## Mimari Özet

- **Supabase edge function YOK.** `supabase/functions/` dizini mevcut değil.
  Tüm sunucu-tarafı medya mantığı tek bir **Cloudflare Worker** + **R2 bucket**
  (`dmt-assets`) üzerinde. Migration sayısı: 58 (`001`–`058`).
- Worker akışı: `GET/PUT/DELETE /assets/{key}` → JWT doğrula (JWKS, RS256/ES256)
  → prefix/quota/MIME kontrol → R2. Metadata insert'i Flutter istemcisi yapar.
- İki depolama yolu: **sayılan** medya (R2, 50MB quota) ve **ücretsiz** medya
  (Supabase Storage `free-media` bucket, quota-dışı). Ayrıca **transient**
  (R2 `transient/` prefix, quota-dışı, R2 lifecycle ile auto-purge).
- Genel duruş **iyi**: JWT doğrulama doğru, RLS kapsamı tam (58 migration'da
  RLS açık olmayan tablo bulunmadı), path-prefix izolasyonu sağlam, SHA-256
  integrity download tarafında doğrulanıyor. Aşağıdakiler sertleştirme ve
  optimizasyon kalemleri — kritik/exploit-edilebilir açık bulunmadı.

## Bulgular

| # | Bulgu | Önem | Tip |
|---|-------|------|-----|
| M1 | Upload'ta magic-byte doğrulaması yok, sadece `Content-Type` header'ı | MEDIUM | Güvenlik |
| M2 | Worker'da `Content-Length` güvenilip stream byte sayısı doğrulanmıyor | MEDIUM | Güvenlik |
| M3 | `X-Content-SHA256` upload'ta sunucuda yeniden hesaplanmıyor | MEDIUM | İntegrity |
| M4 | Quota check TOCTOU + metadata insert başarısızsa orphan R2 objesi | MEDIUM | Tutarlılık |
| M5 | CORS `Access-Control-Allow-Origin: *` | LOW-MED | Güvenlik |
| M6 | DELETE endpoint'inde rate limit yok | LOW | Güvenlik |
| M7 | `X-Asset-Kind` header istemci kontrollü (limit 2→5MB yükseltir) | LOW | Güvenlik |
| S1 | `transient_shares` DB satırları hiç temizlenmiyor (TTL/cron yok) | MEDIUM | Tutarlılık |
| S2 | R2 lifecycle rule version control'de değil (`wrangler.toml`) | MEDIUM | Operasyon |
| S3 | Sınırsız RPC array param (`lineage_current_versions`, `get_all_users_summary`) | MEDIUM | DoS |
| S4 | Pre-027 SECURITY DEFINER fonksiyonlarında `search_path` audit'i gerek | MEDIUM | Güvenlik |
| S5 | quota invariant'ı yalnızca SQL yorumuyla korunuyor (test/CHECK yok) | MEDIUM | Süreç |
| S6 | `REPLICA IDENTITY FULL` write amplification (051/052/054) | MEDIUM | Perf |
| S7 | Eksik index'ler (sık sorgu pattern'leri) | MEDIUM | Perf |
| S8 | Worker rate limit: sabit saatlik pencere, burst koruması yok | LOW-MED | Güvenlik |
| O1 | Her R2 GET'te Supabase'e RLS RPC roundtrip (cache yok) | — | Optimizasyon |

## Detaylı Bulgular

### Medya Yükleme & Cloudflare R2

**M1 — Magic-byte doğrulaması yok.**
`cloudflare/src/worker.ts:252-258` yalnızca `Content-Type` header'ını
allowlist'e (`image/`, `audio/`, `application/gzip`, `application/octet-stream`)
karşı kontrol ediyor. Header istemci kontrollü; `octet-stream` pratikte her
şeyi geçirir. Saldırgan keyfi binary'i `Content-Type: image/png` ile
yükleyebilir. Etki sınırlı (Flutter app web değil, XSS yüzeyi yok) ama içerik
bütünlüğü zayıf.
*Düzeltme:* image/audio için ilk birkaç byte'ı sniff et (PNG/JPEG/GIF/WebP
imzaları); `octet-stream`'i yalnızca gerçek gzip backup yoluna daralt.

**M2 — `Content-Length` doğrulanmadan güveniliyor.**
`cloudflare/src/worker.ts:208-218` boyut kontrolünü sadece `Content-Length`
header'ından yapıp `worker.ts:269` `request.body` stream'ini R2'ya yazıyor;
gerçekte akan byte sayısı tekrar kontrol edilmiyor. Sahte küçük
`Content-Length` ile `maxBytes` aşılabilir.
*Düzeltme:* stream'i sayan bir `TransformStream` ile sar, limit aşılırsa abort
et; ya da R2 `put` sonrası `object.size` ile doğrula ve aşılırsa sil.

**M3 — SHA sunucuda yeniden hesaplanmıyor.**
`cloudflare/src/worker.ts:269-276` `X-Content-SHA256` header değerini olduğu
gibi R2 `customMetadata`'ya yazıyor. Hiç recompute edilmiyor. Kötü niyetli
istemci yanlış SHA depolayabilir → meşru indirenler SHA mismatch yaşar (kendi
asset'inin DoS'u). M2 ile birlikte değerlendir.
*Düzeltme:* M2'deki stream sarmalayıcıda SHA-256'yı da hesapla, header ile
karşılaştır, uyuşmazsa 400 dön.

**M4 — Quota TOCTOU + orphan R2 objeleri.**
Quota `cloudflare/src/worker.ts:222-250`'de kontrol edilip sonra R2'ya
yazılıyor; `community_assets` metadata insert'ini istemci ayrı yapıyor.
(a) Eşzamanlı iki upload aynı quota check'i geçebilir. (b) R2 put başarılı ama
metadata insert başarısızsa → R2'da quota'ya sayılmayan, izlenmeyen orphan obje
kalır.
*Düzeltme:* orphan toplayıcı (R2 list `{uid}/` vs `community_assets` diff,
24h+ yaşındakileri sil) cron/scheduled Worker; veya metadata insert'i Worker'a
taşıyıp atomik yap.

**M5 — CORS `*`.** `cloudflare/src/worker.ts:29`. Her origin çağırabilir; ama
her istek geçerli JWT istiyor, pratik etki düşük (mobil app).
*Düzeltme:* bilinen origin'lere daralt veya bilinçli karar olarak belgele.

**M6 — DELETE'te rate limit yok.**
`cloudflare/src/worker.ts:286-299` `handleDelete`'te `checkRateLimit` çağrısı
yok (GET/PUT'ta var). Etki düşük (sadece kendi prefix'i).
*Düzeltme:* DELETE'e de `'ul'` veya ayrı `'del'` bucket ekle.

**M7 — `X-Asset-Kind` istemci kontrollü.**
`cloudflare/src/worker.ts:203-207`. İstemci `battle_map` göndererek per-item
limiti 2MB→5MB çıkarabilir; yine `MAX_UPLOAD_BYTES` (10MB) tavanı ve quota
geçerli. Düşük etki — kabul edilebilir, sadece not.

### Supabase / Migration / RLS

**S1 — `transient_shares` satırları temizlenmiyor.**
`supabase/migrations/054_transient_share.sql` — R2 `transient/` objeleri
lifecycle ile silinir ama `transient_shares` tablo satırları yalnızca
world/user silinince cascade olur. R2 objesi purge edildikten sonra satır ölü
objeyi gösterir.
*Düzeltme:* `pg_cron` ile günlük `DELETE FROM transient_shares WHERE created_at
< now() - interval '7 days'` (pattern: `007_beta_program.sql` zaten
`cron.schedule` kullanıyor).

**S2 — R2 lifecycle rule version control'de yok.**
`cloudflare/wrangler.toml` — `transient/` auto-purge için lifecycle kuralı
yorumla bahsediliyor ama dosyada yok (dashboard'dan elle). Kural set
edilmemişse transient objeler sonsuza dek birikir → quota-dışı depolama
sınırsız büyür.
*Düzeltme:* lifecycle kuralını `wrangler.toml`/`r2.json` olarak codify et veya
`cloudflare/README.md`'de zorunlu adım yap.

**S3 — Sınırsız RPC array parametreleri.**
`lineage_current_versions(uuid[])` ve `get_all_users_summary()` LIMIT'siz.
İstemci 10k+ eleman geçirirse memory spike / timeout.
*Düzeltme:* `array_length > 100` ise `RAISE EXCEPTION`;
`get_all_users_summary`'ye `LIMIT` + pagination.

**S4 — Pre-027 SECURITY DEFINER fonksiyon audit'i.**
027'den önceki SECURITY DEFINER fonksiyonlar (quota/storage/listing) `SET
search_path` / `SET row_security` açısından doğrulanmalı. Yeniler doğru —
ör. `get_transient_access` (`054_transient_share.sql:60`) `SET search_path =
public` + `REVOKE ... FROM anon, authenticated` + `GRANT ... TO service_role`
ile temiz. Eskiler tek tek taranmalı.
*Düzeltme:* tüm SECURITY DEFINER fonksiyonlara `SET search_path = public`
ekleyen tek bir audit migration'ı (`059_...`).

**S5 — quota invariant'ı yalnızca yorumla korunuyor.**
`053_free_media_bucket.sql:9-11` ve `054_transient_share.sql:97-100`:
"`free_media_assets`/`transient_shares` hiçbir quota SUM'ına eklenmez" kuralı
yalnızca SQL yorumu. İleride bir geliştirici eklerse quota sessizce bozulur.
*Düzeltme:* `get_paid_storage_used()` adlı kanonik fonksiyon + bir regression
test (quota SUM'ında yasak tablo adlarını arayan pgTAP/SQL assert).

**S6 — `REPLICA IDENTITY FULL` write amplification.**
051/052/054 `world_members`, `entity_shares`, `transient_shares`'e FULL
verdi — her UPDATE/DELETE'te tam eski satır WAL'a yazılır. Realtime CDC
filtreleme için gerekliydi ama I/O maliyeti var. Güvenlik değil, perf.
`world_packages` ise muhtemelen FULL'dan yoksun (unshare DELETE event'i world
bağlamı taşımıyor olabilir).
*Düzeltme:* `world_packages`'a FULL ekle; diğerlerinde FULL yerine sadece
gerekli kolonları içeren index'li REPLICA IDENTITY değerlendir; kampanya
yoğunsa WAL büyümesini izle.

**S7 — Eksik index'ler.** Aday sık-sorgu pattern'leri:
- `world_characters (world_id) WHERE owner_id IS NULL` — claim-edilmemiş char.
  **Zaten var** → `idx_world_characters_claim` (`039_unify_character_ownership.sql:57`).
- `world_entities (world_id, created_at DESC)` — DM "tüm entity" görünümü. Yok.
- `marketplace_listings (lineage_id, is_current)` — drift kontrolü. Composite
  yok (yalnız tekil `idx_ml_lineage` + `idx_ml_current` var).

*Not:* yeni index'lerden önce `pg_indexes` ile son doğrulama yapılmalı.

**S8 — Rate limit: sabit saatlik pencere.**
`cloudflare/src/rate_limit.ts` `Math.floor(now/3_600_000)` bucket'ı — burst
koruması yok (60 upload 1 saniyede yapılıp saat sınırında 60 daha = saniyeler
içinde 120). KV free tier 1k yazma/gün limiti de risk.
*Düzeltme:* ikincil kısa pencere (ör. 10sn) sliding bucket veya token-bucket.

### Optimizasyon Fırsatları

**O1 — R2 GET başına Supabase RLS RPC roundtrip.**
Her `GET /assets/{key}` (`cloudflare/src/worker.ts:145-151`) `checkAssetAccess`'i
Supabase'e RPC ile çağırır. Aynı battle map'i 5 oyuncu açarsa 5 RPC.
*Optimizasyon:* erişim kararını `RATE_KV`'de kısa TTL (ör. 60-120sn) ile
cache'le `acl:{user}:{key}`; veya Cloudflare Cache API ile obje gövdesini
edge'de cache'le (RLS check'ten sonra).

**O2 — Public bucket'lar (`free-media`, `avatars`, `post-images`).**
`058_storage_select_owner_scoped.sql` `list()` enumeration'ı kapattı
(owner-scoped SELECT). İçerik hâlâ public URL ile RLS-free servis ediliyor —
portre/kapak için kabul edilebilir tasarım, URL `{uid}/{sha256}.{ext}` (sha
tahmin zor). Aksiyon: bilinçli tasarım kararı olarak `docs/`'ta belgele.

## Önerilen Düzeltme Yol Haritası

**Faz 1 — Upload integrity sertleştirme (Worker)** — M1, M2, M3
- `handleUpload`'a `TransformStream` tabanlı bir sayaç+SHA-256 hesaplayıcı
  ekle: akan byte'ları say (limit aşılırsa abort), SHA hesapla, `X-Content-
  SHA256` ile karşılaştır, ilk byte'lardan magic-byte sniff et.
- Dosya: `cloudflare/src/worker.ts` (yeni helper).

**Faz 2 — Worker hızlı düzeltmeler** — M5, M6, M7
- DELETE'e rate limit; CORS origin daraltma (veya doc); `X-Asset-Kind` notu.

**Faz 3 — Migration: temizlik & sınırlar** — S1, S3, S5
- `059_transient_cleanup_cron.sql`: `pg_cron` günlük transient purge.
- `lineage_current_versions` / `get_all_users_summary`'ye array/LIMIT sınırı.
- `get_paid_storage_used()` kanonik fonksiyon + invariant regression testi.

**Faz 4 — SECURITY DEFINER audit** — S4
- Tüm fonksiyonları tara, eksiklere `SET search_path = public` ekle
  (`060_security_definer_audit.sql`).

**Faz 5 — Perf** — S6, S7, S8, O1
- `world_packages` REPLICA IDENTITY FULL; aday index'leri `pg_indexes`
  doğrulamasından sonra ekle; Worker RLS-karar KV cache (O1); rate limit
  burst penceresi (S8).

**Faz 6 — Operasyon & dokümantasyon** — S2, M4, O2
- R2 lifecycle kuralını codify; orphan R2 toplayıcı (scheduled Worker);
  public bucket tasarım kararını belgele.

## Kritik Dosyalar

- `cloudflare/src/worker.ts` — upload/download/delete
- `cloudflare/src/rate_limit.ts` — rate limit
- `cloudflare/src/rls.ts` — RLS RPC köprüsü
- `cloudflare/wrangler.toml` — Worker config
- `supabase/migrations/053_free_media_bucket.sql`
- `supabase/migrations/054_transient_share.sql`
- `supabase/migrations/058_storage_select_owner_scoped.sql`
- `flutter_app/lib/data/network/asset_service.dart`

## Doğrulama

- **Worker:** `cd cloudflare && npx wrangler dev` → curl ile: küçük
  `Content-Length` + büyük gövde (M2), yanlış magic-byte `image/png` (M1),
  yanlış SHA (M3) → her biri 4xx dönmeli.
- **Migration:** yeni `059`/`060` migration'larını Supabase SQL Editor'da
  çalıştır; `pg_cron` job `cron.job` tablosunda görünmeli.
- **Quota invariant testi:** `get_paid_storage_used` regression test'i CI'da.
- **Perf:** index'lerden önce/sonra `EXPLAIN ANALYZE` ile ilgili sorgular.
- **Genel:** `flutter analyze` temiz.
