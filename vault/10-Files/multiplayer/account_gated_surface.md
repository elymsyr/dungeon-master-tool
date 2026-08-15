---
type: file-note
domain: multiplayer
path: flutter_app/lib/presentation/widgets/account_gated_surface.dart
layer: presentation
language: dart
status: stable
updated: 2026-08-15
tags: [file]
---

# `account_gated_surface.dart`

> [!abstract] Primary Purpose
> **O2**'nin çizim tarafı: [[account_gate]]'in verdiği `SurfaceAccess` kararını ekrana çeviren tek widget. Misafir, kapılı bir yüzeyin yerine giriş çağrısı (`SignInRequiredNotice`) görür; auth akışı olmayan build'de yüzey hiç görünmez.

## Inputs / Outputs
**Inputs**
- Providers watched: `surfaceAccessProvider(surface)` ([[account_gate]]).
- Constructor: `surface` (`AppSurface`), `builder` (`WidgetBuilder`), opsiyonel `message` (yüzeye özel lokalize satır) ve `hiddenBuilder`.

**Outputs**
- `open` → `builder(context)`; `signInRequired` → `SignInRequiredNotice`; `hidden` → `hiddenBuilder` ya da boş kutu.
- `SignInRequiredNotice` ayrıca tek başına da kullanılabiliyor (`packages_tab`, `join_world_dialog` kendi düzenlerinin içine gömüyor).

## Dependencies & Links
- Depends on: [[account_gate]], `go_router` (`context.go('/')`), `L10n`, `DmToolColors`.
- Used by: `marketplace_panel`, `save_sync_indicator` (Storage bloğu), `packages_tab`, `join_world_dialog`.
- Domain map: [[Multiplayer-and-Online]]
- Spec / reference: `flutter_app/docs/open5e_content_audit.md` §6 Stage O · O2

## Key Logic / Variables
- **`builder`, `Widget` değil — çıkış kriterinin taşıyıcısı bu.** O2 "misafir modda hiçbir Supabase client'ı kurulmaz" diyor; `Widget child` parametresi widget'ı karar verilmeden **önce** inşa ederdi. Builder ile yüzeyin widget'ları — ve onların izlediği provider'lar — yalnız `open` durumunda kurulur, test de builder'ın hiç çağrılmadığını iddia ederek bunu yapısal olarak kanıtlar.
- Giriş butonu `/`'e gider: O1 auth formunu orada bıraktı, hesap-bağımlı bir rota da misafiri aynı yere yolluyor ([[route_access]]).
- Yeni l10n anahtarları (en/tr/de/fr): `accountRequiredTitle`, `accountRequiredBody`, `accountRequiredSignIn`, `accountRequiredMarketplace`, `accountRequiredCloudBackup`, `accountRequiredOnlineSync`, `accountRequiredWorldSharing`.

## Notes
- `cloudBackupSignInPrompt` dört `.arb` dosyasında da vardı ama **hiçbir yerde render edilmiyordu**; Save & Sync dialog'unun Storage bloğu artık cloud-backup yüzeyi olarak bu widget'tan geçiyor.
- Marketplace paneli misafire `SizedBox.shrink()` döndürüyordu — pazar yeri onlar için var değildi, kapalı değil.
