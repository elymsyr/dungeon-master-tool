# DMT Assets — Cloudflare Worker + R2

Dungeon Master Tool'un asset pipeline gatekeeper'ı. Private R2 bucket önüne
konan bir Cloudflare Worker; Supabase JWT'sini asimetrik doğrulayıp RLS
check + rate limit uyguladıktan sonra R2'dan stream eder.

Mimari detay: [../docs/ONLINE_REPORT.md](../docs/ONLINE_REPORT.md) §4.3, §7.3, §8.1.

---

## A. Cloudflare tarafı kurulum

### 1. Wrangler CLI
```bash
cd cloudflare
npm install
npx wrangler login
```

### 2. R2 bucket
```bash
npx wrangler r2 bucket create dmt-assets
```
Dashboard > R2 > `dmt-assets` > Settings: **public access KAPALI** kalmalı.
Custom domain bağlama. Erişim sadece Worker üzerinden.

### 3. KV namespace (rate limit counter)
```bash
npx wrangler kv:namespace create RATE_KV
```
Çıktıdaki `id` değerini [wrangler.toml](wrangler.toml) içindeki
`REPLACE_WITH_KV_NAMESPACE_ID` yerine yaz.

### 4. Environment değişkenleri

**Public (`[vars]`):** [wrangler.toml](wrangler.toml) içinde düzenle.
- `SUPABASE_URL` → `https://<project-ref>.supabase.co`
- Limitler (download/upload/hour, max upload bytes) istersen ayarla.

**Secret:**
```bash
npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY
```
Değer: Supabase Dashboard > Settings > API > `service_role` key.
⚠️ Bu key **asla** client'a verilmez, sadece Worker secret olarak yaşar.

### 5. Local test
```bash
npx wrangler dev
# Başka terminalde:
curl -i http://localhost:8787/assets/test.png
# → 401 {"error":"missing_token"}
```
Daha ileri test için [B.6](#6-worker--supabase-bağlantısını-test-et) bölümüne bak.

### 6. Deploy
```bash
npx wrangler deploy
```
Çıktıdaki URL'yi (`https://dmt-assets.<subdomain>.workers.dev`) Flutter
`--dart-define=DMT_WORKER_URL=...` olarak kullanacaksın.

### 7. Maliyet izleme
Dashboard > Workers > Analytics → KV ops ve request count'u izle.

ONLINE_REPORT §10.2: KV free tier **1k write/gün**. Saatlik bucket pattern'i
sayesinde ortalama bir kullanıcı saatte 1 write yapar, ama 20+ aktif
paralel kullanıcıda limit tehlikeye girer. Bu noktada Workers Paid ($5/ay)
plana geç.

---

## B. Supabase tarafı kurulum

### 1. Migration'ları çalıştır
Dashboard > SQL Editor > New Query → iki migration'ı sırayla yapıştır + Run:
1. [../supabase/migrations/001_cloud_backups.sql](../supabase/migrations/001_cloud_backups.sql)
2. [../supabase/migrations/002_community_assets.sql](../supabase/migrations/002_community_assets.sql)

### 2. RLS doğrulaması
```sql
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'community_assets';
-- rowsecurity = true olmalı

SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'community_assets';
-- "Uploader manages own assets" satırı görünmeli
```

### 3. JWT signing algorithm kontrolü (kritik)
Dashboard > Settings > Auth > JWT Settings → **Algorithm: RS256** olmalı.

- **Yeni projeler (2024 sonrası):** Default olarak RS256. Değişiklik gerekmez.
- **Eski projeler (HS256):** "Rotate JWT signing keys" butonuyla RS256'ya
  migrate et. Migrasyon sonrası tüm mevcut oturumlar invalide olur; kullanıcılar
  tekrar giriş yapar.

Worker asimetrik doğrulama yaptığı için RS256 **zorunlu**. HS256'da Worker
JWKS'i fetch edemez.

### 4. Service role key
Dashboard > Settings > API > `service_role` section → "Reveal" → kopyala.
Bu değeri **sadece** Worker secret'ı olarak kullan (bkz. [A.4](#4-environment-değişkenleri)).

### 5. Test user
Dashboard > Authentication > Users > "Add user" → email/password ile oluştur.

### 6. Worker + Supabase bağlantısını test et

Test user ile JWT al (Flutter `supabase.auth.signInWithPassword()` çağrısı veya
[Supabase CLI](https://supabase.com/docs/reference/cli/supabase-auth) ile).

```bash
JWT='<user jwt>'
USER_ID='<aynı user uuid>'
WORKER_URL='https://dmt-assets.xxx.workers.dev'

# 1. 401 beklenir (token yok)
curl -i $WORKER_URL/assets/test.png

# 2. 403 beklenir (prefix mismatch)
curl -i -X PUT $WORKER_URL/assets/wrong-prefix/test.png \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: image/png" \
  -H "X-Content-SHA256: $(printf '0%.0s' {1..64})" \
  --data-binary @test.png

# 3. 200 beklenir — upload OK
SHA=$(sha256sum test.png | awk '{print $1}')
curl -i -X PUT "$WORKER_URL/assets/$USER_ID/test-campaign/$SHA.png" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: image/png" \
  -H "X-Content-SHA256: $SHA" \
  --data-binary @test.png

# 4. Metadata insert'i Flutter yapar; manuel test için:
# SQL Editor'dan community_assets tablosuna elle satır ekle,
# sonra download test et:
curl -i "$WORKER_URL/assets/$USER_ID/test-campaign/$SHA.png" \
  -H "Authorization: Bearer $JWT"
```

### 7. Rate limit testi
Yukarıdaki GET'i arka arkaya 21 defa çağır → 21. istekte **429** + `Retry-After` header.

---

## C. Flutter tarafı kullanım

### 1. Compile-time config
```bash
cd flutter_app
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ... \
  --dart-define=DMT_WORKER_URL=https://dmt-assets.xxx.workers.dev
```

`DMT_WORKER_URL` verilmezse `assetServiceProvider` **null** döner
(offline fallback).

### 2. AssetService kullanımı
```dart
final asset = ref.read(assetServiceProvider);
if (asset == null) {
  // offline — R2 erişimi yok
  return;
}

final uri = await asset.uploadAsset(
  File('/path/to/map.png'),
  campaignId: 'my-campaign',
);
// uri = Uri.parse('dmt-asset://{userId}/my-campaign/{sha256}.png')

// Başka kullanıcıda:
final file = await asset.downloadAsset(uri.host + uri.path);
// Dosya ${cacheDir}/r2/assets/{sha256}.bin yolunda, hash doğrulanmış.
```

### 3. Cache temizleme
```dart
await asset.evictCache(r2Key);
final bytes = await asset.cacheSizeBytes();
```

---

## Endpoint özeti

| Method | Path | Auth | Açıklama |
|---|---|---|---|
| `GET` | `/assets/{key}` | Bearer JWT | RLS check + rate limit + R2 stream |
| `PUT` | `/assets/{userId}/...` | Bearer JWT | Prefix check + MIME + quota check + R2 put |
| `DELETE` | `/assets/{userId}/...` | Bearer JWT | Prefix check + R2 delete |
| `OPTIONS` | `/*` | — | CORS preflight |

**Hata kodları:**
- `401` — missing / invalid / expired token
- `403` — no_access (RLS) veya prefix_mismatch
- `404` — route_not_found veya asset_not_found
- `413` — too_large (Content-Length > MAX_UPLOAD_BYTES=10 MB) veya
  quota_exceeded (combined >USER_QUOTA_BYTES=50 MB)
- `415` — unsupported_media_type
- `429` — rate_limited (`Retry-After` header)
- `502` — access_check_failed veya quota_check_failed (Supabase RPC hatası)

---

## Sprint 9 notu

Şu an RLS policy sadece `uploader_id = auth.uid()` üzerinden çalışır. Sprint 9'da
`session_participants` tablosu eklenince [002_community_assets.sql](../supabase/migrations/002_community_assets.sql)
içindeki TODO yorumlarını takip ederek policy ve `get_asset_access` fonksiyonunu
session katılımcılarını da kapsayacak şekilde genişlet.
