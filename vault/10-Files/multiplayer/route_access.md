---
type: file-note
domain: multiplayer
path: flutter_app/lib/presentation/router/route_access.dart
layer: presentation
language: dart
status: stable
updated: 2026-08-15
tags: [file]
---

# `route_access.dart`

> [!abstract] Primary Purpose
> Audit fazı **O1**'in çıktısı: go_router'ın redirect kararını saf, Flutter'sız bir fonksiyona çıkarır. Eski kural tek bir soru soruyordu — "Supabase oturumu var mı?" — ve yoksa `/` dışındaki **her** rotayı landing'e geri atıyordu; yani çevrimdışı kullanım kullanıcının seçebildiği bir mod değil, binary'nin nasıl derlendiğinin bir yan etkisiydi. Artık soru rota başına sorulur: **bu hedef gerçekten hesap gerektiriyor mu?**

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: yok — saf fonksiyonlar.
- Reads: çağıranın verdiği `supabaseConfigured`, `hasSession`, `location`.

**Outputs**
- Public API: `accountRequiredRoutePrefixes`, `routeRequiresAccount(String)`, `resolveRedirect({supabaseConfigured, hasSession, location})` → yönlendirilecek konum ya da null.

## Dependencies & Links
- Depends on: hiçbir şey (import yok — kasıtlı).
- Used by: [[app_router]] (`appRouter.redirect`), [[landing_screen]] (davranışın diğer ucu).
- Domain map: [[Multiplayer-and-Online]]
- Spec / reference: `flutter_app/docs/open5e_content_audit.md` §6 Stage O · O1

## Key Logic / Variables
- `accountRequiredRoutePrefixes = {'/profile', '/admin'}` — tek gerçek hesap-bağımlı ekranlar: `/profile/:userId` bir Supabase `profiles` satırı render eder, `/admin` `is_admin()` RPC'sini çağırır. Diğer her şey (`/hub`, `/main`, `/package`, `/character/*`, `/template/*`) yalnız yerel Drift veritabanını okur.
- `routeRequiresAccount` prefix eşleşmesini **yol segmenti** olarak yapar: `/profiles-of-monsters` kapıya takılmaz.
- `resolveRedirect` sırası: define yoksa hiç kapı yok → oturum varsa serbest → hesap-bağımlı rota ise `/` → aksi halde serbest. Landing (`/`) hiçbir durumda yönlendirilmez.
- **Neden ayrı dosya:** `SupabaseConfig.isConfigured` derleme zamanı define'ı; bir widget testi onu `true` yapamaz. Karar saf fonksiyona çıkarılmasa O1'in çıkış kriteri olan router testi yazılamazdı. `test/presentation/router/route_access_test.dart` (8 vaka).

## Notes
- O2 bunun üstüne "bu **yüzey** hesap ister mi" yüklemini kurdu (2026-08-15, [[account_gate]] — ölçülen 102 çağrı noktasının 48'i yüklemi zaten elle yazıyormuş); bu dosya yalnız **rota** düzeyini yanıtlar.
