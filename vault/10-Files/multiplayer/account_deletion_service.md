---
type: file-note
domain: multiplayer
path: flutter_app/lib/application/services/account_deletion_service.dart
layer: application
language: dart
status: stable
updated: 2026-08-27
tags: [file]
---

# `account_deletion_service.dart`

> [!abstract] Primary Purpose
> Kullanıcının kendi hesabını ve ona bağlı **tüm** veriyi tek eylemde silmesi (uygulama mağazalarının ve GDPR'ın istediği "hesabı sil" düğmesi). İki public fonksiyon: `deleteCloudAccountData(WidgetRef) → uid` (storage + R2 + RPC) ve `finishAccountDeletion(WidgetRef, uid)` (sign-out + yerel ağaç). Silinecek şeyin listesi burada tutulmaz — `auth.users` satırı düştüğünde public şema FK cascade'leri ile gider; bu dosya yalnızca **cascade'in ulaşamadığı** iki yeri (Supabase Storage objeleri, Cloudflare R2 objeleri) ve **yerel** ağacı elle temizler.

## Inputs / Outputs
**Inputs**
- `Supabase.instance.client` — `currentUser` + `currentSession.accessToken` (ikisi de yoksa `StateError`).
- `AppPaths.dataRoot`, `String.fromEnvironment('DMT_WORKER_URL')`.
- Provider'lar: [[user_session_provider]] (`deactivate`), [[auth_provider]] (`signOut`).

**Outputs**
- Supabase Storage: `avatars`, `post-images`, `shared-payloads`, `free-media` bucket'larında `{uid}/` klasörünün silinmesi (kullanıcının kendi owner-delete RLS'i ile).
- Worker `POST /admin/purge-user` (kendi JWT'si ile) → R2'de `{uid}/` + `transient/{uid}/`.
- RPC `delete_my_account()` → `auth.users` satırı.
- Yerel `dataRoot/users/{uid}/` ağacının silinmesi + oturum kapatma.

## Dependencies & Links
- Depends on: [[auth_provider]], [[user_session_provider]], [[worker]], [[rpc-reference]] (`delete_my_account`, migration **083** + **084** düzeltmesi).
- Used by: [[delete_account_dialog]] ← `settings_tab.dart` (Settings sekmesinin **en altındaki** danger zone; oturum açıkken görünür).
- Domain map: [[Multiplayer-and-Online]] · [[Backend-Infra]]

## Key Logic / Variables
- **Sıra sözleşmesi:** bulut objeleri → RPC → sign-out → yerel ağaç.
- **Neden iki fonksiyon:** `signOut` hub listener'ı üzerinden landing'e navigate ediyor. Tek fonksiyon olduğunda çağıranın ilerleme dialog'u o sırada hâlâ açıktı ve dispose edilen Navigator'da pop edilince `!_debugLocked` assert'i düşüyordu. Dialog artık iki çağrının **arasında** kapanıyor. Hesap satırı düştükten sonra kullanıcının JWT'si ile yapılabilecek hiçbir temizlik kalmaz; storage/R2 sonraya bırakılırsa sahipsiz kalır.
- 1–3 arasındaki hata **yukarı fırlar** (dialog snackbar'da gösterir, kullanıcı tekrar dener — hiçbiri kısmi silme bırakmaz: obje silme idempotent, RPC hiç çalışmamıştır). 4'teki yerel silme hatası **yutulur** — hesap zaten yok.
- **DB önce kapatılır:** `deactivate()` `activeUserIdProvider`'ı null'a çeker, `appDatabaseProvider` yeniden kurulurken eski `AppDatabase` kapanır; ancak ondan sonra `users/{uid}` dizini silinebilir (Windows açık dosyayı sildirmez). `signOut` sonrası hub listener'ının tekrar çağırdığı `deactivate` zararsız/idempotent.
- Bucket taraması **tek seviye**: bugün her yükleyici `{uid}/{sha}.{ext}` yazıyor (bkz. [[free_media_service]] `path = '${user.id}/$sha$ext'`). İç içe path'li yeni bir bucket eklenirse burası recursive olmalı — kodda `ponytail:` yorumu ile işaretli.
- `DMT_WORKER_URL` derlenmemişse R2 adımı atlanır (o build zaten R2 kullanmıyor).

### Cascade varsayımının iki istisnası (084, gerçek hesapla test)
083'ün "her şey CASCADE" varsayımı iki kolonda yanlıştı — ikisi de **SET NULL** ve ikisi de NULL'ı kabul etmeyen bir kural altında. `world_characters.owner_id` SET NULL olunca dünyasız karakter `(NULL, NULL)`'a düşüp `chk_world_chars_not_both_null`'ı deviriyor (`23514` — ilk gerçek silme denemesi tam burada durdu); `admin_audit_log.admin_id` ise NOT NULL olduğu için admin bir hesapta `23502` verirdi. İkisi de RPC içinde **silinerek** çözüldü; kolon tanımlarına dokunulmadı, çünkü SET NULL davranışı ("karakter serbest bırakıldı", "admin kaydı anonimleşti") başka akışlarda doğru.

## Notes
- Ban ile ilişkisi: `banned_users` satırı da cascade ile gider, yani banlı kullanıcı hesabını silip yeniden kayıt olabilir. Ban e-posta değil `user_id` bazlı olduğu için bu mevcut durumun devamı; 083 başlığında not düşüldü.
- Onay tek dialog, yazarak doğrulama yok — ürün kararı: "tek tuş yeterli".
