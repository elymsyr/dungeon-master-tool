---
type: file-note
domain: sync
path: flutter_app/lib/application/services/lan_sync/lan_sync_client.dart
layer: application
language: dart
status: active
updated: 2026-08-20
tags: [file]
---

# `lan_sync_client.dart`

> [!abstract] Primary Purpose
> LAN eşlemesinin istemci yarısı: `/pair` el sıkışması, kalıcı sırla imzalı çağrılar ve arka plan presence dinleyicisi. v2'de **keşif yok** — istemci her zaman saklı bir eşleşme kaydından kurulur. Aktarımı hep istemci sürer (çekilecekleri `GET`, gönderilecekleri `POST`), böylece tek akış iki yönü de kapsar.

## Inputs / Outputs
**Inputs**
- Constructor: `host`, `port`, `auth`, `myDeviceId`, `myPort`. Genelde `LanSyncClient.forDevice(PairedDevice, …)` ile saklı kayıttan kurulur.
- `HttpClient` (6 sn bağlantı zaman aşımı); `LanPresenceListener` için `RawDatagramSocket`.

**Outputs**
- Public API: `forDevice()`, `ping()`, `unpair()`, `fetchManifest()`, `fetchItem()`, `pushItem()`, `missingMediaOnPeer()`, `uploadMedia()`, `fetchMedia()`, `close()`.
- `LanPairing.viaInvite()` / `.viaPin()` → `LanPairOutcome`; `LanPresenceListener`; `parseLanAddress()`.
- Hata: `LanSyncException(statusCode, body)` — `isAuthFailure` (401/429), `isAccountMismatch`, `isPairingClosed`.

## Dependencies & Links
- Depends on: [[lan_sync_protocol]], [[lan_device_store]]
- Used by: `lan_sync_provider.dart` (`pairWithQr` / `pairWithPin` / `syncAll` / `pingAll`)
- Domain map: [[Sync-and-Realtime]]
- System flow: [[LAN-Sync-Flow]]

## Key Logic / Variables
- Her istek üç başlık taşır: `Authorization` (HMAC), `X-DMT-Device` (kimim), `X-DMT-Port` (presence adresim doğru kaydedilsin).
- `_uri` `Uri.parse('http://host:port$path')` kullanır; `Uri(path:)` zaten kodlanmış bileşenleri ikinci kez kodlardı.
- İmza `method + path + body` üzerinden — protokolde query string yok.
- `LanPairing._handshake` tek gövde: geçici anahtarı `deriveSessionKey(secret, nonce)` ile kurar, kendi yarımını yollar, dönen yarımla `deriveSharedSecret` hesaplar.
- `viaInvite` davetteki adresleri sırayla dener, sonuna `127.0.0.1` ekler (aynı makinede test).
- `_hello` imzasız `GET /hello` → `(nonce, pairing)`. `pairing == false` ise `pairing_closed` fırlatılır — "cihaz yok" demek yanıltıcı olurdu.
- `LanPresenceListener` 45455'i `reuseAddress + reusePort` ile dinler; `reusePort` olmayan platformlarda (Windows, bazı Android) yalnız `reuseAddress` ile tekrar dener. Eşleşmemiş cihazların paketleri sessizce yok sayılır.
- Push medya akışı: `missingMediaOnPeer` → yalnız eksikler `uploadMedia` (base64 gövde) → `pushItem`.

## Notes
- Tek makinede iki instance ile test etmenin yolu elle `IP:port` + PIN: iki dinleyici aynı presence portunu paylaşamayabilir ve ikinci instance ephemeral HTTP portuna düşer.
- ponytail: base64 yükleme %33 şişme bırakır; büyük harita dosyalarında darboğaz olursa multipart ya da ham gövde + imzalı başlık yoluna geçilir.
