# Bildirim Banner + Resim — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Admin bildirimine dosyadan seçilen opsiyonel banner (+ opsiyonel link) ve gövdeye linkli/linksiz resim blokları ekleyebilsin.

**Architecture:** Resimler yeni public Supabase Storage bucket'ı `notification-images`'a yüklenir (`post-images` kalıbı). Veri `notifications.blocks` JSONB'sinde yeni `image` blok tipi olarak durur; banner `banner: true` işaretli ilk bloktur. Tablo ve RPC'ler değişmez.

**Tech Stack:** Flutter/Dart, supabase_flutter Storage, file_picker, url_launcher, Postgres RLS.

**Spec:** [docs/superpowers/specs/2026-11-26-notification-images-design.md](../specs/2026-11-26-notification-images-design.md)

## Global Constraints

- Bucket: `notification-images`, `public = true`, `file_size_limit = 10485760` (10 MB), `allowed_mime_types = ['image/jpeg','image/png','image/webp']`.
- Storage INSERT / DELETE yalnız `public.is_admin()`; SELECT yalnız kendi klasörü (`(storage.foldername(name))[1] = auth.uid()::text`) — 058 ile aynı.
- Obje yolu: `{adminUid}/{millisecondsSinceEpoch}_{blockId}.{ext}`.
- Link geçerli = boş, ya da `Uri.tryParse` sonucu scheme `http`/`https` ve host boş değil.
- Banner her zaman bildirim (detay) penceresinin **tam genişliğinde**: dialog padding'inin dışında, kenardan kenara, en üstte.
- Flutter: `~/flutter-3.47/bin/flutter` (PATH'teki 3.44.6 değil). Komutlar `flutter_app/`'ten.
- ram-guard: her test/analyze öncesi `free -m`; yalnız ilgili test dosyası, `--concurrency=1`; tam suite asla.
- `dart format` mevcut dosyalarda çalıştırılmaz.
- Her kullanıcı stringi 4 arb'de (en → tr → de → fr), sonra `flutter gen-l10n`.
- Commit / push yalnız kullanıcı açıkça isterse.

## Review Focus

1. `javascript:`, `ftp://`, şemasız `example.com` linki → gönderim engellenir, hata gösterilir (Task 2 testi `isValidLink`).
2. 10 MB'tan büyük dosya seçilirse yüklemeden önce reddedilir, kullanıcı dostu mesaj (Task 4: `pickImage` boyut kontrolü; Task 2 testi `kNotificationImageMaxBytes`).
3. Resimler yüklendi ama `admin_create_notification` patladı → yüklenenler silinir, dialog açık kalır (Task 4 Step 4 akışı).
4. Resim URL'i 404 / offline → çökme yok, `notifImageLoadFailed` yer tutucusu (Task 3: `errorBuilder`).
5. Eski / resimsiz bildirim JSON'u → aynen parse edilir, `banner == null`, `bodyBlocks == blocks` (Task 2 testi).
6. Büyük harfli uzantı (`PHOTO.PNG`) → `image/png` (Task 2 testi `notificationImageMime`).

---

### Task 1: Migration 110 — `notification-images` bucket

**Files:**
- Create: `supabase/migrations/110_notification_images.sql`
- Create: `supabase/scripts/verify_110.sql`
- Modify: `vault/10-Files/backend/migrations-security.md`, `vault/90-Meta/Vault-Changelog.md`

**Interfaces:**
- Produces: bucket `notification-images`; politikalar `"notification-images admin insert"`, `"notification-images admin delete"`, `"notification-images owner read"`.

- [ ] **Step 1: verify_110.sql yaz** — `verify_104.sql` kalıbıyla (BEGIN … ROLLBACK, sonda `110 OK`). Assert'ler:
  - bucket var, `public = true`, `file_size_limit = 10485760`, mime dizisi tam olarak üç tip.
  - admin claims ile `storage.objects`'e `('notification-images', '<adminUid>/x.png')` insert **başarılı**.
  - admin olmayan authenticated kullanıcıyla aynı insert **RLS hatası** verir.
  - admin olmayan kullanıcı admin'in objesini DELETE edemez (0 satır).
- [ ] **Step 2: Çalıştır, düşmesini gör** — memory `local-migration-verify` akışı (docker `postgres:16-alpine` + stub, 001→109 uygula, sonra `verify_110.sql`). Beklenen: bucket yok hatası.
- [ ] **Step 3: 110_notification_images.sql yaz** — 004'teki `INSERT … ON CONFLICT (id) DO UPDATE` bucket kalıbı + `DROP POLICY IF EXISTS` / `CREATE POLICY` (idempotent); sonda `NOTIFY pgrst, 'reload schema';`. Başlık yorumu 069 stilinde Türkçe.
- [ ] **Step 4: Zinciri baştan çalıştır** — 001→110 + tüm `verify_*.sql`. Beklenen: hata yok, her script `NNN OK`.
- [ ] **Step 5: Vault** — migrations-security notuna 110 satırı (bucket + politikalar), `updated:` tarihi; changelog'a bir satır.

### Task 2: Domain — `ImageBlock`, banner, link/mime yardımcıları

**Files:**
- Modify: `flutter_app/lib/domain/entities/app_notification.dart`
- Test: `flutter_app/test/domain/entities/app_notification_test.dart` (yeni)

**Interfaces:**
- Produces:
  - `class ImageBlock extends NotificationBlock { final String url; final String path; final String? link; final bool banner; }` — `toJson()` → `{'id','type':'image','url','path', if link != null 'link', if banner 'banner': true}`.
  - `NotificationBlock.fromJson` `case 'image'` → `ImageBlock` (`link` boş string → null).
  - `AppNotification.banner` → `ImageBlock?` (ilk blok `ImageBlock` ve `banner == true` ise).
  - `AppNotification.bodyBlocks` → `List<NotificationBlock>` (banner hariç).
  - `bool isValidNotificationLink(String s)` (top-level; boş string → true).
  - `String? notificationImageMime(String ext)` (top-level; `jpg|jpeg`→`image/jpeg`, `png`, `webp`, büyük/küçük harf duyarsız, diğerleri null).
  - `const int kNotificationImageMaxBytes = 10 * 1024 * 1024;`

- [ ] **Step 1: Testleri yaz**

```dart
test('image block round-trips with link and banner', () {
  final j = {'id': 'b1', 'type': 'image', 'url': 'https://x/a.png',
             'path': 'u/1_b1.png', 'link': 'https://dmt.app', 'banner': true};
  final b = NotificationBlock.fromJson(j) as ImageBlock;
  expect(b.link, 'https://dmt.app');
  expect(b.banner, isTrue);
  expect(b.toJson(), j);
});
test('image block without link omits link and banner keys', () {
  final b = NotificationBlock.fromJson(
      {'id': 'b2', 'type': 'image', 'url': 'u', 'path': 'p', 'link': ''}) as ImageBlock;
  expect(b.link, isNull);
  expect(b.toJson().containsKey('link'), isFalse);
  expect(b.toJson().containsKey('banner'), isFalse);
});
test('banner is first image block flagged banner; bodyBlocks excludes it', () { /* blocks: [banner img, markdown, img] → banner != null, bodyBlocks.length == 2 */ });
test('legacy notification has no banner and bodyBlocks == blocks', () { /* only markdown+poll */ });
test('isValidNotificationLink', () {
  expect(isValidNotificationLink(''), isTrue);
  expect(isValidNotificationLink('https://a.b/c'), isTrue);
  expect(isValidNotificationLink('http://a.b'), isTrue);
  expect(isValidNotificationLink('javascript:alert(1)'), isFalse);
  expect(isValidNotificationLink('ftp://a.b'), isFalse);
  expect(isValidNotificationLink('example.com'), isFalse);
  expect(isValidNotificationLink('https://'), isFalse);
});
test('notificationImageMime', () {
  expect(notificationImageMime('PNG'), 'image/png');
  expect(notificationImageMime('jpeg'), 'image/jpeg');
  expect(notificationImageMime('webp'), 'image/webp');
  expect(notificationImageMime('gif'), isNull);
  expect(kNotificationImageMaxBytes, 10485760);
});
```

- [ ] **Step 2: Çalıştır, düşsün** — `~/flutter-3.47/bin/flutter test test/domain/entities/app_notification_test.dart --concurrency=1` → derleme hatası (ImageBlock yok).
- [ ] **Step 3: Implement** — yukarıdaki imzalar. `hasInteractive` değişmez.
- [ ] **Step 4: Test geçsin** — aynı komut → PASS.
- [ ] **Step 5: Analyze** — `flutter analyze lib/domain/entities/app_notification.dart lib/presentation/dialogs/notification_inbox_dialog.dart`: inbox'taki exhaustive `switch (b)` yeni alt sınıf yüzünden hata verecek — Task 3'te kapanır; şimdilik `case ImageBlock(): break;` koyup geç (Task 3 değiştirir).

### Task 3: Görünüm — banner + resim bloğu

**Files:**
- Modify: `flutter_app/lib/presentation/widgets/notification_block_view.dart`
- Modify: `flutter_app/lib/presentation/dialogs/notification_inbox_dialog.dart` (`_NotificationRow`, `_NotificationDetailDialog.build`)

**Interfaces:**
- Consumes: Task 2 `ImageBlock`, `AppNotification.banner`, `bodyBlocks`; l10n `notifImageLoadFailed` (Task 4'te eklenir — bu task önce arb'ye o tek anahtarı ekler, 4 dil: en "Image could not be loaded", tr "Resim yüklenemedi", de "Bild konnte nicht geladen werden", fr "Impossible de charger l'image").
- Produces: `class ImageBlockView extends StatelessWidget { const ImageBlockView({required ImageBlock block, double? height, BorderRadius? radius, VoidCallback? onTapNoLink}); }`

- [ ] **Step 1: `ImageBlockView`** — `Image.network(block.url, fit: BoxFit.cover, width: double.infinity, height: height, errorBuilder: …)`; `errorBuilder` → ikon + `notifImageLoadFailed` metni içeren sabit yükseklikli kutu. `height == null` ise doğal oran (gövde resmi). Link varsa `InkWell` → `launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication)` (markdown linkleriyle aynı); link yoksa `onTapNoLink` (null ise tıklanmaz). `radius` varsa `ClipRRect`.
- [ ] **Step 2: Inbox kartı** — `_NotificationRow`: `banner != null` ise satır `Column`'unun üstüne `ImageBlockView(block: banner, height: 72, radius: üst köşeler palette.cbr, onTapNoLink: () => _open(context, ref))`, kartın tam genişliğinde (kartın iç padding'i yalnız alt satıra uygulanır). Linkli banner tıklanınca link açılır **ve** okunmamışsa `markRead` + `invalidate` (detay açılmaz).
- [ ] **Step 3: Detay penceresi** — dialog içeriği `Column`; banner varsa en üstte **padding dışında** tam genişlik `ImageBlockView(block: banner, height: 160, radius: üst köşeler palette.cbr)`, sonra mevcut `Padding(fromLTRB(20,18,12,8))` içeriği. Dialog'a `clipBehavior: Clip.antiAlias`. Blok döngüsü `notification.bodyBlocks` üzerinden; `case ImageBlock(): blockWidgets.add(ClipRRect(borderRadius: palette.cbr, child: ImageBlockView(block: b)))`.
- [ ] **Step 4: Doğrula** — `flutter gen-l10n`, sonra `flutter analyze lib/presentation/widgets/notification_block_view.dart lib/presentation/dialogs/notification_inbox_dialog.dart` → yeni uyarı yok.

### Task 4: Composer + yükleme/silme

**Files:**
- Modify: `flutter_app/lib/data/datasources/remote/admin_notifications_remote_ds.dart`
- Modify: `flutter_app/lib/presentation/dialogs/notification_composer_dialog.dart`
- Modify: `flutter_app/lib/presentation/screens/admin/notifications_admin_tab.dart:78-100` (`_delete`)
- Modify: `flutter_app/lib/presentation/l10n/app_{en,tr,de,fr}.arb`
- Modify: `vault/10-Files/data-layer/remote-datasources-index.md`

**Interfaces:**
- Consumes: Task 2 `ImageBlock`, `isValidNotificationLink`, `notificationImageMime`, `kNotificationImageMaxBytes`.
- Produces (`AdminNotificationsRemoteDataSource`):
  - `Future<({String path, String url})> uploadImage(Uint8List bytes, String ext, String blockId)` — yol Global Constraints'teki gibi, `FileOptions(contentType: notificationImageMime(ext)!, upsert: false)`, `getPublicUrl`.
  - `Future<void> removeImages(List<String> paths)` — boşsa no-op; hata `debugPrint` ile yutulur (best-effort).
  - `Future<void> delete(String id, {List<String> imagePaths = const []})` — önce RPC, sonra `removeImages(imagePaths)`.

- [ ] **Step 1: l10n anahtarları** (en / tr / de / fr):
  - `notifBlockImage`: Image / Resim / Bild / Image
  - `notifBannerAdd`: Add banner / Banner ekle / Banner hinzufügen / Ajouter une bannière
  - `notifBannerLabel`: Banner / Banner / Banner / Bannière
  - `notifImagePick`: Choose image / Resim seç / Bild wählen / Choisir une image
  - `notifImageLinkLabel`: Link (optional) / Link (opsiyonel) / Link (optional) / Lien (facultatif)
  - `notifImageLinkInvalid`: Links must start with http:// or https://. / Linkler http:// veya https:// ile başlamalı. / Links müssen mit http:// oder https:// beginnen. / Les liens doivent commencer par http:// ou https://.
  - `notifImageTooLarge`: Image is larger than 10 MB. / Resim 10 MB'tan büyük. / Bild ist größer als 10 MB. / L'image dépasse 10 Mo.
  - `notifImageMissing`: Choose an image or remove the block. / Bir resim seç ya da bloğu kaldır. / Wähle ein Bild oder entferne den Block. / Choisissez une image ou supprimez le bloc.
  
  Sonra `flutter gen-l10n`.
- [ ] **Step 2: DS metodları** — yukarıdaki üç imza; admin tab `_delete` → `delete(summary.id, imagePaths: summary.blocks.whereType<ImageBlock>().map((b) => b.path).toList())`.
- [ ] **Step 3: Draft modeli** — `_DraftBlock`'a `type == 'image'` + alanlar `Uint8List? bytes`, `String? ext`, `final TextEditingController link`; `bool banner`. Banner, `_blocks`'tan ayrı `_DraftBlock? _banner` alanında tutulur (sıralamaya girmez). `pickImage()`: `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg','jpeg','png','webp'], withData: true)`; `bytes.length > kNotificationImageMaxBytes` → `_error = notifImageTooLarge`, atanmaz. Önizleme `Image.memory(bytes, height: 120, fit: BoxFit.cover)`.
- [ ] **Step 4: Yayınlama akışı** (`_publish`):
  1. Başlık boşsa veya (banner + bloklar) boşsa → `notifComposerEmpty` (mevcut).
  2. Bytes'ı olmayan image draft → `notifImageMissing`; geçersiz link → `notifImageLinkInvalid`. İkisinde de hiçbir şey yüklenmez.
  3. Banner + image draft'ları sırayla `uploadImage`; dönen `{path,url}` ile `ImageBlock(...).toJson()` üretilir; banner JSON'u listenin **başına** konur (`banner: true`). Yüklenen yollar `uploaded` listesinde toplanır.
  4. `ds.create(title, blocks)`; herhangi bir adımda hata → `await ds.removeImages(uploaded)`, `_error` göster, dialog açık kalsın.
  Markdown/poll/input `toJson` yolu senkron kalır; image draft'ın `toJson`'ı yoktur (yükleme sonrası üretilir).
- [ ] **Step 5: UI** — başlık alanının altında banner bölümü: `_banner == null` → `OutlinedButton.icon(Icons.image_outlined, notifBannerAdd)`; doluysa önizleme + link alanı + resim değiştir + kaldır. Blok ekleme satırına dördüncü buton `notifBlockImage` (`_add('image')`); `_BlockEditor` `type == 'image'` için resim seç / önizleme / link alanı gösterir, `main` text alanını göstermez. `_typeLabel` → `'image' => l10n.notifBlockImage`.
- [ ] **Step 6: Doğrula** — `flutter analyze lib/data/datasources/remote/admin_notifications_remote_ds.dart lib/presentation/dialogs/notification_composer_dialog.dart lib/presentation/screens/admin/notifications_admin_tab.dart` temiz; Task 2 testi tekrar PASS.
- [ ] **Step 7: Vault** — remote-datasources-index'te admin notifications satırına `uploadImage/removeImages` + bucket; `updated:`; changelog satırı.

### Task 5: Elle doğrulama (kullanıcıyla)

- [ ] Migration 110'u Supabase SQL editöründe kullanıcı uygular.
- [ ] `flutter run -d linux` (dart-define'larla) → admin: linkli banner + linkli ve linksiz iki resim bloğu ile bildirim gönder; 10 MB+ dosya reddedilir; `example.com` linki reddedilir.
- [ ] Kullanıcı tarafı: kartta banner şeridi, banner tık → link açılır + okundu; detayda banner kenardan kenara; resim blokları sırada; linkli resim tarayıcı açar.
- [ ] Admin bildirimi siler → Storage'da dosyalar gider.
