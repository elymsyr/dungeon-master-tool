---
type: file-note
domain: multiplayer
path: flutter_app/lib/application/providers/account_gate.dart
layer: application
language: dart
status: stable
updated: 2026-08-15
tags: [file]
---

# `account_gate.dart`

> [!abstract] Primary Purpose
> Audit fazı **O2**'nin çıktısı: "bu şey hesap ister mi" sorusunun tek yüklemi. O1 misafir modunu erişilebilir yapınca ortaya, kodun adlandırmadığı üçüncü bir durum çıktı — *configured build + oturum yok*. `SupabaseConfig.isConfigured` "bu binary online için derlendi mi" der, oturum okuması "biri giriş yapmış mı" der; ikisi de misafiri tarif etmez. Bu dosya üç durumu bir kez adlandırır ve hangi yüzeyin hesap istediğini **tablo** olarak tutar.

## Inputs / Outputs
**Inputs**
- Providers watched: [[auth_provider|authProvider]] (yalnız `accountGateProvider` içinde).
- Reads: `SupabaseConfig.isConfigured` (derleme zamanı define).

**Outputs**
- Saf API: `AccountAccess { offlineBuild, guest, signedIn }`, `resolveAccountAccess({supabaseConfigured, signedIn})`, `AppSurface` (her değerde `requiresAccount`), `SurfaceAccess { open, signInRequired, hidden }`, `resolveSurfaceAccess(surface, access)`.
- Provider API: `accountGateProvider`, `surfaceAccessProvider(AppSurface)`, `hasAccountProvider`.

## Dependencies & Links
- Depends on: [[auth_provider]], `core/config/supabase_config.dart`.
- Used by: [[account_gated_surface]] (çizim tarafı), `marketplace_panel`, `save_sync_indicator`, `save_info_section`, `packages_tab`, `social_tab`, `worlds_tab`, `package_screen`, `character_editor_screen`, `profile_menu_button`, `online_world_section`, `join_world_dialog`, `bug_report_dialog`.
- Kardeş karar: [[route_access]] — **rota** düzeyi (O1). Bu dosya **yüzey** düzeyi (O2).
- Domain map: [[Multiplayer-and-Online]]
- Spec / reference: `flutter_app/docs/open5e_content_audit.md` §6 Stage O · O2

## Key Logic / Variables
- `resolveAccountAccess`: define yoksa `offlineBuild` (oturum ne derse desin), varsa oturuma göre `guest` / `signedIn`.
- `resolveSurfaceAccess`: `requiresAccount` false ise **her durumda** `open`. True ise `signedIn → open`, `guest → signInRequired`, `offlineBuild → hidden` — misafire sorulur, auth akışı olmayan build'de ise saklanır (isteyecek bir hesap yok).
- Kapılı küme (§6 O2'nin saydığı altı): `marketplace`, `cloudBackup`, `worldSharing`, `profile`, `follows`, `notifications`, `admin`.
- **`firstPartyCatalog` bilerek kapısız.** Fazın kendi premisi katalog indirmesinin Worker'ın JWT zincirinden geçtiğini varsayıyordu; ölçüm tersini gösterdi — `cloudflare/src/worker.ts:331` `GET /catalog/{key}`'i **public, JWT yok** diye belgeliyor, `FirstPartyCatalogService` `Authorization` başlığı göndermiyor ve istek düşerse `assets/first_party/`'ye iniyor. JWT zinciri *kullanıcı asset* yolu (`asset_service.dart:_requireToken`). Kapılamak, sunucunun herkese verdiği içeriği misafirden almak olurdu.
- **Neden saf + provider ayrımı:** `isConfigured` derleme zamanı define'ı; `flutter test` define'sız koştuğu için gerçek kapı testte hep `offlineBuild` der. Tablo boolean alır, `accountGateProvider` de widget testinin misafir *olmak* için override ettiği dikiş yeridir (`test/application/providers/account_gate_test.dart`, 48 vaka).
- Ölçüm (2026-08-15): repoda **102** `isConfigured` çağrısı vardı; **48'i** zaten `!isConfigured || auth == null` yazıyordu, gerisi çıplak okuyordu. Presentation tarafı **27 çağrı / 15 dosya → 10 / 6**'ya indi; kalan altısı build düzeyinde okumalar (router, landing auth formu, player alt-penceresi, `startup_sync_gate`, hub sign-out listener).

## Notes
- `lib/application/providers/` içindeki ~21 dosya hâlâ yüklemi elle yazıyor. **Doğrular**, yani bu bir kusur değil tekrar. O3 (2026-08-15) o dosyaların yanından geçmedi — terfi `user_session_provider` + [[guest_promotion_service]] ile sınırlı kaldı — dolayısıyla toplama işi hâlâ sahipsiz; kendi başına bir 90-nokta süpürmesi olarak değil, o provider'lara dokunan ilk faz sırasında yapılmalı.
- Yeni bir yüzey eklerken: enum'a bir değer + `requiresAccount`. Test `_roadmapOnlineSurfaces` kümesiyle karşılaştırdığı için, kapılı bir yüzey eklemek audit dokümanını da güncellemeyi zorunlu kılar.
