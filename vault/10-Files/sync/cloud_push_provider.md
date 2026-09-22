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
> Push turunu **ne zaman** koşacağına karar veren ince katman. `PendingWriteBuffer.tick`'i dinler, 3 sn sessizlikten sonra aktif dünyanın turunu başlatır; üst üste binen istekleri tek ek tura toplar. Ayrıca turun iki girdisini toplar: dünyanın kimliği (`activeCampaignProvider`) ve şemadan türeyen `dm_only_keys` haritası.

## Inputs / Outputs
**Inputs**
- `pendingWriteBufferProvider.tick` (ValueNotifier) — tek tetikleyici.
- `activeCampaignProvider` — "açık içeriğin anahtarı"; pakette paket adı tutar, o durumda servis satır bulamaz ve tur atlanır.
- `currentWorldRoleProvider` — DM değilse tur atlanır (ayna tabloları RLS'te DM-only).
- `worldSchemaProvider` — `dmOnly` / `private_` alan anahtarları.

**Outputs**
- `cloudPushServiceProvider` → [[cloud_push_service]] (Supabase yapılandırılmamışsa / oturum yoksa `null`).
- `cloudPushPumpProvider` → `CloudPushPump`; `push({full, worldId})` → `CloudPushResult`.

## Dependencies & Links
- Depends on: [[cloud_push_service]], [[pending_write_buffer]], [[shared_media_courier]].
- Used by: `main_screen.dart` (dünya açıkken keep-alive `ref.watch`), [[save_sync_indicator]] (ilk yayında `full: true`).
- Domain map: [[Sync-and-Realtime]]
- Spec / reference: `docs/online-sync-redesign.md` §4.6.

## Key Logic / Variables
- **İki katmanlı debounce:** tampon zaten 750–2000 ms bekliyor; buradaki 3 sn onun üstüne biniyor — kart düzenlerken her tuşta değil, eli çektikten sonra tek tur.
- **Keep-alive kalıbı:** `MainScreen` `ref.watch(cloudPushPumpProvider)` ile pompayı dünya açıkken hayatta tutuyor; aynı kalıp [[world_mirror_applier]] için de kullanılıyor.
- **Rol kapısı:** rol henüz çözülmediyse tur atlanır, bir sonraki tick yeniden dener — beklemeye gerek yok, tarama zaten idempotent.
