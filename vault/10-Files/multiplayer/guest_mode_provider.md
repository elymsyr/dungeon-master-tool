---
type: file-note
domain: multiplayer
path: flutter_app/lib/application/providers/guest_mode_provider.dart
layer: application
language: dart
status: stable
updated: 2026-08-15
tags: [file]
---

# `guest_mode_provider.dart`

> [!abstract] Primary Purpose
> Audit fazı **O1**: "hesapsız kullanıyorum" seçimini kalıcı hale getirir. Misafir modu **ikinci bir çevrimdışı uygulama değildir** — Supabase define'ları olmadan derlenmiş bir build'in zaten içinde olduğu durumun ta kendisidir (`AppPaths.setUser(null)`, global veri kökü, yerel Drift DB). Bu notifier yalnızca kullanıcının o durumu *seçtiğini* hatırlar; olmasa landing her açılışta yeniden hesap sorardı.

## Inputs / Outputs
**Inputs**
- Providers watched: yok.
- Reads: `SharedPreferences` anahtarı `guest_mode`.

**Outputs**
- Providers exposed: `guestModeProvider` → `StateNotifierProvider<GuestModeNotifier, bool>`.
- Public API: `load()` (depolanan seçimi oku, state'e yaz, döndür), `enter()` (seç + kalıcılaştır), `clear()` (giriş yapıldı — seçim silinir).
- Writes: aynı SharedPreferences anahtarı.

## Dependencies & Links
- Depends on: `shared_preferences`.
- Used by: [[landing_screen]] (tek çağıran: initState'te `load`, butonda `enter`, oturum açılınca `clear`).
- Domain map: [[Multiplayer-and-Online]]
- Spec / reference: `flutter_app/docs/open5e_content_audit.md` §6 Stage O · O1

## Key Logic / Variables
- `prefsKey = 'guest_mode'`; varsayılan `false`.
- Çevrimdışı girişin kendisi bu dosyada değil: `landing_screen._enterOffline()` → [[user_session_provider]]`.deactivate()` → `AppPaths.setUser(null)` + provider invalidation, ardından `/hub`. Supabase'siz build ile misafir **aynı** metodu çağırır.
- Otomatik atlama **açılış başına bir kez**: `landing_screen`'deki modül düzeyi `_guestAutoEntryUsed` bayrağı olmasa, hub'daki "Sign in" butonu `/`'a gittiğinde misafir anında hub'a geri sekerdi ve auth formuna bir daha ulaşamazdı.
- `test/application/providers/guest_mode_provider_test.dart` (3 vaka) kalıcılığı pinler.

## Notes
- **O3 (2026-08-15) o boşluğu kapattı:** terfi artık `clear()`'ın yanında değil, `UserSessionNotifier.activate` içinde [[guest_promotion_service]] ile yapılıyor — Drift veritabanı da (kapalıyken, WAL çifti dahil) kopyalanıyor, medya ağaçlarına `characters/` de eklendi. `clear()` hâlâ yalnız bayrağı siler; doğru yerde durur, çünkü terfi oturumun açılmasına bağlı, seçimin unutulmasına değil.
- **O4 (2026-08-15)** bayrağın *arkasındaki* alanın ne olduğunu tanımladı: bir hesap misafir ağacını talep ettiyse ([[guest_promotion_service]]), tekrar misafir olarak girmek artık **boş** bir çalışma alanına girmektir — eski içerik arşivde durur ama misafir oturumu onu görmez. Bayrak hâlâ sadece "kullanıcı bunu seçti"yi hatırlar; "o veriler kimin" sorusunun cevabı talep dosyasında.
