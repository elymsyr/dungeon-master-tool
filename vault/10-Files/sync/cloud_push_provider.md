---
type: file-note
domain: sync
path: flutter_app/lib/application/providers/cloud_push_provider.dart
layer: application
language: dart
status: active
updated: 2026-09-22
tags: [file]
---

# `cloud_push_provider.dart`

> [!abstract] Primary Purpose
> Push turunu **ne zaman** koşacağına karar veren ince katman. `PendingWriteBuffer.tick`'i dinler, 3 sn sessizlikten sonra açık olanın turunu başlatır — önce dünya, sonra paket — ve üst üste binen istekleri tek ek tura toplar. Ayrıca turun girdilerini toplar: açık içeriğin kimliği ve şemadan türeyen `dm_only_keys` haritası.

## Inputs / Outputs
**Inputs**
- `pendingWriteBufferProvider.tick` (ValueNotifier) — tek tetikleyici.
- `activeCampaignProvider` — "açık içeriğin anahtarı"; pakette paket adı tutar, o durumda dünya turu satır bulamaz ve atlanır.
- `activePackageProvider` — açık paketin **adı**; id tablodan bulunur (`packagesDao.getByName`).
- `currentWorldRoleProvider` — DM değilse tur atlanır (ayna tabloları RLS'te DM-only).
- `worldSchemaProvider` — `dmOnly` / `private_` alan anahtarları.

**Outputs**
- `cloudPushServiceProvider` → [[cloud_push_service]] (Supabase yapılandırılmamışsa / oturum yoksa `null`).
- `cloudPushPumpProvider` → `CloudPushPump`; `push({full, worldId})` ve `pushPackage({full, packageName, packageId})` → `CloudPushResult`.

## Dependencies & Links
- Depends on: [[cloud_push_service]], [[pending_write_buffer]], [[shared_media_courier]].
- Used by: `main_screen.dart` ve `package_screen.dart` (açıkken keep-alive `ref.watch`), [[save_sync_indicator]] (dünya/paket ilk yayınında `full: true`).
- Domain map: [[Sync-and-Realtime]]
- Spec / reference: `docs/online-sync-redesign.md` §4.6 (Faz 4a), §4.7 (Faz 4b).

## Key Logic / Variables
- **İki katmanlı debounce:** tampon zaten 750–2000 ms bekliyor; buradaki 3 sn onun üstüne biniyor — kart düzenlerken her tuşta değil, eli çektikten sonra tek tur.
- **Keep-alive kalıbı:** `MainScreen` `ref.watch(cloudPushPumpProvider)` ile pompayı dünya açıkken hayatta tutuyor; aynı kalıp [[world_mirror_applier]] için de kullanılıyor.
- **Rol kapısı yalnız dünyada:** ayna tabloları RLS'te DM-only, o yüzden dünya turu rol çözülene kadar atlanır (bir sonraki tick yeniden dener, tarama idempotent). Paket turunda rol kontrolü **yok** — paket kullanıcı kapsamlı, RLS `owner_id`'ye bakıyor.
- **Tek kapı, iki tur:** `_guarded` aynı anda tek tur koşmasını sağlıyor; `_round()` dünyayı ve paketi sıra sıra deniyor, açık olmayan kendiliğinden atlanıyor.
