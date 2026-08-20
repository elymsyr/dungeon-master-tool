---
type: file-note
domain: sync
path: flutter_app/lib/application/services/lan_sync/lan_sync_protocol.dart
layer: application
language: dart
status: active
updated: 2026-08-20
tags: [file]
---

# `lan_sync_protocol.dart`

> [!abstract] Primary Purpose
> LAN eşlemesinin tel formatı ve saf çekirdeği. Manifest/payload DTO'ları, LWW diff, HMAC imzalama, QR daveti, eşleşme DTO'ları ve presence paketi. Flutter/Drift bağımlılığı yok — testlenebilir kısım burada toplanır.

## Inputs / Outputs
**Inputs**
- Yok (saf Dart; yalnız `package:crypto`).

**Outputs**
- Public API: `LanItemType`, `LanItemRef`, `LanMediaEntry`, `LanItemPayload`, `LanSyncPlan`, `diffManifests`, `LanAuth`, `LanPairInvite`, `LanPairRequest`, `LanPairResponse`, `deriveSharedSecret`, `uidFingerprint`, `LanAnnounce`.

## Dependencies & Links
- Depends on: —
- Used by: [[lan_sync_server]], [[lan_sync_client]], [[lan_sync_session]]
- Domain map: [[Sync-and-Realtime]]
- System flow: [[LAN-Sync-Flow]]

## Key Logic / Variables
- `LanItemRef.updatedAt` **milisaniyeye yuvarlanır** — JSON round-trip'te mikrosaniye farkı iki tarafın "aynı" içeriği farklı sanmasına yol açardı. Kimlik `key = "<type>:<id>"`.
- `diffManifests(local:, peer:)` → `LanSyncPlan(pull, push, skipped)`. Peer-only → pull; local-only → push; ikisinde de varsa `updatedAt` yeni olan kazanır; eşitse `skipped++`. **Silme yayılmaz.**
- **İki anahtar kaynağı:** eşleşme anında `LanAuth.deriveSessionKey(secret, nonce) = sha256("dmt-lan:$secret:$nonce")` (QR token'ı ya da PIN); eşleşme sonrası `LanAuth.fromSharedSecret(base64)` — kalıcı sır.
- `deriveSharedSecret(clientHalf:, hostHalf:) = base64(sha256("$clientHalf|$hostHalf"))`. Sıra **sabit** (önce istemci) — iki taraf aynı sonucu bulur.
- `LanPairInvite.toQrText()` = `dmt2:` + base64url(json). Anahtarlar tek harfli (`i n a p t u`) — QR yoğunluğu düşük kalsın. `fromQrText` ön eki tutmayan ya da eksik alanlı her şeyi eler.
- `uidFingerprint(uid) = sha256("dmt-lan-uid:$uid")[0:8]` — ham `uid` broadcast'te dolaşmaz.
- İmza mesajı: `"$method|$path|$tsMs|$nonce|${sha256(body)}"` → `base64Url(HmacSha256)`. Başlık: `DMT-LAN <nonce>.<tsMs>.<sig>`.
- `verify` reddi: bozuk format, saat sapması > `clockSkew` (60 sn), tekrarlanan nonce (`_seenNonces`, `clockSkew*2` sonra budanır), imza uyuşmazlığı (sabit-zaman karşılaştırma).
- `LanAnnounce` (v2): port 45455, `protocolVersion = 2`. Yalnız `{deviceId, port, uidFingerprint}` — ne PIN, ne token, ne ham `uid`, cihaz adı bile yok (alıcı adı zaten eşleşme kaydından biliyor).

## Notes
- Query string bilinçli olarak protokolde yok: parametreler gövdede taşınır, böylece imzalanan `path` iki tarafta kodlama farkından ayrışamaz.
- Test: `test/application/services/lan_sync/lan_sync_protocol_test.dart` (diff + auth + QR daveti + ortak sır + announce).
