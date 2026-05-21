# Medya Depolama Redesign — 2 Cihaz Test Planı

Tarih: 2026-05-21
Kapsam: Online backup / medya depolama yeniden tasarımı (Faz 0-7).
Plan dosyası: `~/.claude/plans/online-backup-zelli-ini-de-i-tirece-iz-hidden-puzzle.md`

## Tamamlanan DB işleri

3 migration yazıldı:

| Migration | Ne | Faz |
|---|---|---|
| **053** `free_media_bucket.sql` | `free-media` bucket + `free_media_assets` tablo — quota'ya **sayılmaz** | Faz 1 |
| **054** `transient_share.sql` | `transient_shares` tablo + `get_transient_access` RPC | Faz 6 backend |
| **055** `online_count_limits.sql` | 4 sayı limiti — `world_characters` trigger + `publish_world`/`publish_personal_package` count check | Faz 7 backend |

Client SHIPPED: Faz 0-4 + karakter portre bug fix.
Client KALAN: Faz 5 galeri, Faz 6 client transient, Faz 7 client pre-check.

---

## ÖN KOŞUL: migration deploy kontrol

Test öncesi 053/054/055 Supabase'e sırayla uygulanmalı. Uygulanmadıysa client
graceful-degrade eder → medya local kalır → **Test 1-4 başarısız** olur.

Doğrulama sorgusu:

```sql
select id from storage.buckets where id = 'free-media';
select to_regclass('public.free_media_assets'), to_regclass('public.transient_shares');
select proname from pg_proc where proname in
  ('get_transient_access','max_online_characters_per_user');
```

3 sorgu da satır dönerse migration'lar uygulanmış.

---

## Test ortamı

- İki cihaz, aynı hesap login.
- Cihaz A = desktop (uploader).
- Cihaz B = mobil (okuyucu).
- Her testten sonra online sync tamamlanmasını bekle.

---

## Test senaryoları

### Test 1 — Karakter portresi cross-device (bug fix)

**Adımlar:**
1. A: karaktere portre resmi ekle → kaydet → online sync bekle.
2. B: aynı karakteri aç.

**Beklenen:**
- B'de portre karakter editör başlığında görünür.
- Eskiden kırık / boş görünüyordu (raw `Image.file` bug'ı).

**DB doğrulama:**
- `free_media_assets` tablosunda 1 satır, `storage_path = {uid}/{sha}.{ext}`.
- Karakter payload `imagePath = dmt-public://...` ref içerir.

---

### Test 2 — World / package kapak cross-device

**Adımlar:**
1. A: dünyaya kapak resmi seç → online yap.
2. B: dünya listesini + dünya detayını aç.

**Beklenen:**
- B'de kapak hem kart listesinde hem detayda görünür.

**DB doğrulama:**
- `free_media_assets` satır eklenir.
- `metadata.cover_image_path = dmt-public://...` ref içerir.

---

### Test 3 — Free medya quota'ya sayılmaz (KRİTİK)

**Adımlar:**
1. Upload öncesi: `select get_user_total_storage_used('{uid}');` — değeri not et.
2. A: portre + 2 kapak resmi yükle.
3. Aynı sorguyu tekrar çalıştır.

**Beklenen:**
- İki değer **birebir aynı**. Free medya 50MB quota'ya değmez.

---

### Test 4 — SHA dedupe (free medya)

**Adımlar:**
1. A: bir karaktere portre X yükle.
2. A: başka bir karaktere **aynı** dosya X'i yükle.

**Beklenen:**
- `free_media_assets`'te X için tek satır (ikinci upload skip edilir).
- `storage.objects` içinde tek obje.

---

### Test 5 — Per-kind boyut limiti (Faz 2)

**Adımlar:**
1. A: 3MB resim entity karta eklemeyi dene (counted, limit 2MB).
2. A: 6MB resim battle map'e eklemeyi dene (limit 5MB).
3. A: 2MB entity resmi + 5MB battle map yükle.

**Beklenen:**
- 3MB / 6MB: client hızlı red + Worker 413.
- 2MB entity / 5MB battle map: geçer.

---

### Test 6 — Sayı limitleri (Faz 7 — server enforcement)

> Faz 7 client pre-check yok → buton disable olmaz, ama server bloklar.
> Net hata mesajı da Faz 7 client işi — şu an UI ham Postgres hatası gösterir.

**Adımlar:**
1. 10 dünya online yap → 11.'yi dene.
2. 10 paket publish → 11.'yi dene.
3. Bir dünyaya 10 karakter ekle → 11.'yi dene.
4. Mevcut bir dünyayı / paketi 10/10 doluyken yeniden publish et (UPDATE).

**Beklenen:**
- 1-3: 11.'de Postgres `check_violation` hatası, işlem reddedilir.
- 4: yeniden publish (UPDATE) 10/10'da **çalışmalı** — sayım sadece yeni kayıt için.

---

### Test 7 — Counted medya cross-device (entity resmi)

**Adımlar:**
1. A: world entity kartına resim ekle → online sync.
2. B: o entity'yi aç.

**Beklenen:**
- B'de resim görünür (R2 download).
- `community_assets` tablosunda satır eklenir.
- `get_user_total_storage_used` **artar** (sayılan medya).

---

## Test EDİLEMEZ (client kalan iş)

| Özellik | Durum | Sebep |
|---|---|---|
| **Transient paylaşım** (Faz 6) | Backend hazır (migration 054 + Worker) | `TransientShareService` + projection client yok → UI'dan tetiklenemez |
| **Medya galerisi** Free/Counts rozet + per-item boyut | Yok | Faz 5 client yapılmadı |
| **"İkinci ekrana paylaş"** action | Yok | Faz 5 client yapılmadı |
| **10/10 buton disable + net hata mesajı** | Yok | Faz 7 client pre-check yapılmadı; server bloklar ama UI ham hata gösterir |
| **Mind map resmi routing** | Yok | Faz 5 kapsamında |

---

## Deploy durumu

- Worker: `wrangler deploy` yapıldı (Version `672652cd`).
- R2: `transient/` prefix lifecycle kuralı `transient-purge` (1 gün) eklendi.
- Migration 053/054/055: **doğrulanmadı** — yukarıdaki ön koşul sorgusuyla kontrol et.
