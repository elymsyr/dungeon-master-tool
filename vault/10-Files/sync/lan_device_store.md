---
type: file-note
domain: sync
path: flutter_app/lib/application/services/lan_sync/lan_device_store.dart
layer: application
language: dart
status: active
updated: 2026-08-20
tags: [file]
---

# `lan_device_store.dart`

> [!abstract] Primary Purpose
> Bu kurulumun kalıcı cihaz kimliği + eşleşmiş cihaz kayıtları. LAN sync v2'nin "bir kez eşleş, hep hatırla" davranışının dayanağı. Kayıtlar `lan_paired_devices` yan tablosunda; şema `AppDatabase.beforeOpen`'daki raw DDL ile idempotent kurulur — **codegen yok, schemaVersion bump yok**.

## Inputs / Outputs
**Inputs**
- Constructor: `AppDatabase` (→ `lanDeviceStoreProvider`, `appDatabaseProvider`'ı izler).
- `SharedPreferences` — `lan_sync_device_id` anahtarı.
- `Platform.localHostname` — cihaz adı.

**Outputs**
- Public API: `deviceId()`, `deviceName`, `list()`, `byId()`, `count()`, `upsert()`, `touchSeen()`, `remove()`, `newSecretHalf()`.
- Model: `PairedDevice` (+ `isOnline`, `address`).
- Writes: `lan_paired_devices` (raw `customStatement`).

## Dependencies & Links
- Depends on: [[drift_database]]
- Used by: [[lan_sync_server]], [[lan_sync_client]] (`forDevice`), `lan_sync_provider`
- Domain map: [[Sync-and-Realtime]], [[Data-Layer]]
- System flow: [[LAN-Sync-Flow]]

## Key Logic / Variables
- **Hesap izolasyonu bedava:** DB `AppPaths.dataRoot/users/{uid}/db/dmt.sqlite` altında, dolayısıyla eşleşme listesi hesaba bağlı. Başka hesaba girilince liste boş gelir.
- **`deviceId` hesaptan bağımsız:** `shared_preferences`'ta durur, ilk çağrıda uuid v4 üretilir. Kullanıcı çıkış yapıp girse de karşı taraf aynı cihazı görür.
- `upsert` `ON CONFLICT(device_id) DO UPDATE` — ad, adres ve sır güncellenir; yeniden eşleşme eski kaydı bozmaz.
- `touchSeen(id, address)` presence yolu: `last_address` + `last_seen_at`. `PairedDevice.isOnline` = son 15 sn (`onlineWindow`).
- `newSecretHalf()` = 32 rastgele bayt (base64). `/pair` el sıkışmasında iki taraf birer tane üretir; ortak sır `deriveSharedSecret` ile hesaplanır ([[lan_sync_protocol]]).
- Tablo deseni `reference_graph.dart` ile aynı: yan tablo + düz servis sınıfı + `customSelect`/`customStatement`.

## Notes
- Erişim DAO üzerinden değil çünkü tablo Drift codegen'de tanımlı değil — bu, `asset_refs` / `sync_telemetry` gibi diğer yan tabloların da izlediği bilinçli yol.
