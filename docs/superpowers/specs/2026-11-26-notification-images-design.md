# Bildirimlere banner + resim — kısa tasarım

**Tarih:** 2026-11-26 · **Durum:** onaylandı

## Amaç
Admin bildirim gönderirken (1) isteğe bağlı bir **banner** koyabilsin, tıklanınca
isteğe bağlı bir link açılsın; (2) bildirim gövdesine istediği kadar **resim**
bloğu ekleyebilsin, her biri linkli ya da linksiz. Resimler dosyadan seçilir.

**Hedef dışı:** URL yapıştırarak resim, resim kırpma/yeniden boyutlandırma,
galeri/carousel, resim başlığı (caption), mevcut bildirimi düzenleme.

## Yaklaşımlar
- **A — Supabase Storage public bucket `notification-images` (seçildi).**
  `post-images` kalıbının aynısı (`uploadBinary` → `getPublicUrl`, silmede
  `remove`). Tek migration, Worker'a dokunulmaz.
- B — R2 `notif/` prefix + Worker'da admin PUT / public GET. Medya tek yerde
  kalır ama yeni route + deploy gerekir; ara sıra gelen bildirim resmi için ağır.
- C — base64'ü blocks'a gömmek. `list_notifications` her seferinde tüm
  blocks'u çektiği için gelen kutusunu şişirir; elendi.

## Tasarım

**Backend — `supabase/migrations/110_notification_images.sql`**
- Bucket `notification-images`: `public = true`, 10 MB, `image/jpeg|png|webp`.
- `storage.objects` politikaları: INSERT / DELETE yalnız `public.is_admin()`;
  SELECT 058'deki gibi yalnız sahibin klasörü (`{uid}/...`) — içerik public URL
  ile RLS'siz servis edilir, listeleme kapalı kalır.
- `notifications` tablosu ve RPC'ler **değişmez** (veri `blocks` JSONB'de).

**Veri — yeni blok tipi** (`app_notification.dart`)
`{id, type:'image', url, path, link?, banner?}` → `ImageBlock`.
- `banner: true` olan blok en fazla bir tane ve listenin başında.
  `AppNotification.banner` getter'ı onu döner.
- Eski istemciler bilinmeyen tipi boş markdown olarak gösterir, kırılmaz.
- `NotificationBlock` sealed: yeni alt sınıf, blokları `switch` eden her yeri
  (detay, admin tab, yanıtlar dialog'u) derleme hatasıyla yakalatır — hepsi
  güncellenir; banner bloğu gövde listesinde tekrar çizilmez.

**Composer** (`notification_composer_dialog.dart`)
- Başlığın altında "Banner ekle" alanı: dosya seç (`file_picker`, mevcut
  dependency) + önizleme + opsiyonel link alanı + kaldır.
- Blok ekleme butonlarına "Resim" eklenir: dosya seç + önizleme + opsiyonel link.
- Seçilen baytlar draft'ta tutulur, **gönder'e basınca** yüklenir
  (`{adminUid}/{ts}_{blockId}.{ext}`), ardından `admin_create_notification`
  çağrılır. Create başarısız olursa yüklenenler silinir — iptal edilen taslakta
  da hiç yükleme olmadığı için yetim dosya kalmaz.
- Link boş değilse `http(s)://` ile başlamalı, değilse gönderim engellenir.

**Görünüm**
- Gelen kutusu kartı (`_NotificationRow`): banner varsa kartın üstünde ince
  şerit (sabit yükseklik, `BoxFit.cover`). Şeride tık → link varsa dış
  tarayıcıda açılır (+ okundu işaretlenir); kartın geri kalanı detayı açar.
  Linksiz banner'a tık kartla aynı davranır.
- Detay ekranı: banner **her zaman pencerenin tam genişliğinde** — dialog
  padding'inin dışında, kenardan kenara, en üstte (başlığın üstünde); `ImageBlock`'lar blok sırasında
  `ImageBlockView` ile gösterilir; linkliyse tıklanabilir (`launchUrl`,
  `LaunchMode.externalApplication` — markdown linkleriyle aynı).
- Yükleme hatasında küçük bir "resim yüklenemedi" yer tutucusu, çökme yok.

**Silme**
`admin_delete_notification` öncesi istemci, bildirimin `ImageBlock.path`'lerini
`storage.remove` ile siler (best-effort, `posts.delete` gibi).

**Diğer**
- Yeni stringler 4 `.arb` dosyasına (en/tr/de/fr).
- Vault: `vault/10-Files/backend/migrations-security.md` + changelog satırı.
- Test: `ImageBlock` / `banner` JSON round-trip birim testi.

## Builder'a kalan
Şerit yüksekliği, önizleme boyutu, ikonlar; migration'ın yerel doğrulaması
(docker postgres akışı).
