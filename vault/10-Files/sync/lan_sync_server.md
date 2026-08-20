---
type: file-note
domain: sync
path: flutter_app/lib/application/services/lan_sync/lan_sync_server.dart
layer: application
language: dart
status: active
updated: 2026-08-20
tags: [file]
---

# `lan_sync_server.dart`

> [!abstract] Primary Purpose
> Host tarafı: **uygulama açıkken** yaşayan LAN sunucusu. v2'de yaşam döngüsü dialog'a değil oturuma bağlı — giriş yapılmış ve en az bir eşleşmiş cihaz varsa (ya da panel açıksa) dinler; eşleşmesi olmayan kullanıcıda hiç soket açılmaz. UDP ile presence duyurusu yapar, HTTP ile içerik + eşleşme servis eder.

## Inputs / Outputs
**Inputs**
- Constructor: `session`, `store` ([[lan_device_store]]), `currentUid` (hesap kapısı için).
- `HttpServer.bind(anyIPv4, 0)` (ephemeral port), `RawDatagramSocket` (broadcast).

**Outputs**
- Public API: `start()`, `stop()`, `openForPairing()`, `closeForPairing()`, `pairInvite()`, `pairPin`, `pairNonce`, `port`, `isRunning`, `isOpenForPairing`, `localAddresses()`.
- Route'lar: `GET /hello` + `POST /pair` (imzasız/geçici anahtar), sonra kalıcı sır isteyenler: `GET /ping`, `POST /unpair`, `GET /manifest`, `GET|POST /item/{type}/{id}`, `POST /media`, `POST /media/have`, `POST /media/put`.
- Yazımlar: `/item` POST ve `/media/put` → [[lan_sync_session]] üzerinden yerel Drift + medya dizini; `/pair` ve `/unpair` → [[lan_device_store]].

## Dependencies & Links
- Depends on: [[lan_sync_protocol]], [[lan_sync_session]], [[lan_device_store]]
- Used by: `lan_sync_provider.dart` (`LanSyncController.syncHostLifecycle`), [[startup_sync_gate]]
- Domain map: [[Sync-and-Realtime]]
- System flow: [[LAN-Sync-Flow]]

## Key Logic / Variables
- **Sabit port 45456.** `SocketException` (aynı makinede ikinci instance) → ephemeral'a düşer; doğru adres presence beacon'ı ile yayılır.
- **İki katmanlı auth.** `/pair` yalnız `isOpenForPairing` iken ve `_pairingAuths()`'tan biri tutarsa; diğer her uç `X-DMT-Device` → saklı `shared_secret`. `_deviceAuths` cache'i nonce replay penceresini cihaz ömrü boyunca yaşatır.
- **Hesap kapısı.** `/pair` gelen `uid`'yi `currentUid()` ile karşılaştırır; tutmazsa `403 account_mismatch`, kayıt yazılmaz.
- **El sıkışma.** Host `newSecretHalf()` üretir, `deriveSharedSecret(clientHalf, hostHalf)` ile ortak sırrı hesaplayıp karşı cihazı `upsert` eder, kendi yarımını döner.
- `_rollPairToken()` — `pairToken` + nonce + PIN üçlüsünü yeniler. `openForPairing`'te bir kez, `_pairTokenTtl` (3 dk) periyodunda ve brute-force görülünce.
- `_notePairFailure` — IP başına 3 hata → 30 sn blok + sır yenileme. **Kurulmuş eşleşmeler etkilenmez.**
- `isPrivateAddress`: loopback, 10/8, 172.16-31/12, 192.168/16, 169.254/16, IPv6 fc00::/7 + fe80::/10 + IPv4-mapped. Başka her şey 403.
- Presence: 5 sn'de bir `LanAnnounce` broadcast; broadcast engelliyse sessizce geçilir — `/ping` ve elle adres yolu kalır.
- `/media/put` gelen baytların sha256'sını doğrular; tutmazsa 400, diske yazmaz.
- Her başarılı istekte `store.touchSeen(deviceId, remote:port)` — presence UDP'siz de tazelenir.

## Notes
- `localAddresses()` yalnız private IPv4 döndürür; UI bunları `ip:port` olarak gösterip kopyalatır.
- Yol geçişi savunması sunucuda değil `LanSyncSession.resolveMedia`'da — tek yerde, iki yön için.
- `/hello` `pairing: bool` de döner; istemci bunu `pairing_closed` hatasına çevirir, yoksa kullanıcıya yanıltıcı "cihaz yok" derdi.
