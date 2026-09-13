---
type: file-note
domain: multiplayer
path: flutter_app/lib/application/providers/shared_entity_provider.dart
layer: application
language: dart
status: active
updated: 2026-09-14
tags: [file]
---

# `shared_entity_provider.dart`

> [!abstract] Primary Purpose
> DM'in "bu kart oyuncuya gitsin" işaretinin **tek kaynağı**. `world_settings.settings_json` içindeki `shared_entities` id listesini okur/yazar. Bulut satırı (`entity_shares`) artık bu setin bir projeksiyonu; set dünya offline'ken de tutulur, böylece DM dünyayı kurarken ileride neyin paylaşılacağını önden seçebilir. Deseni [[pinned_entity_provider|pinned_entities]] ile bire bir aynı: tipli kolon değil blob anahtarı, yani marketplace publish → download ve LAN dünya senkronunda bedavaya taşınır.

## Inputs / Outputs
**Inputs**
- Providers watched: `activeCampaignProvider`, `campaignRevisionProvider`.
- Reads: aktif kampanyanın `_data[shared_entities]` blob'u.
- Geçiş yolu için: `activeCampaignIdProvider`, `onlineWorldIdsProvider`, `currentWorldRoleProvider`, `worldEntitySharesProvider`.

**Outputs**
- `sharedEntityIdsProvider` → `Set<String>`.
- `kSharedEntitiesKey` = `'shared_entities'`.
- Writes: `ActiveCampaignNotifier.saveSettingsPatch({shared_entities: [...]})`.

## Dependencies & Links
- Depends on: [[campaign_provider]], [[role_provider]]
- Used by: [[entity_share_prepare]], [[entity_provider]], `entity_card.dart`, `entity_sidebar.dart`
- Domain map: [[Multiplayer-and-Online]]
- System flow: [[Share-Broadcast-Flow]]

## Key Logic / Variables
- `setShared(id, bool)` — set'i günceller + blob'a yazar. Bulut satırını YAZMAZ; onu `EntitySharer.setShared` yapar.
- `_persist` `campaign.data`'yı elde günceller — `saveSettingsPatch` in-memory aynayı ellemiyor, yoksa revision bump eski listeyi diriltirdi (pinned ile aynı tuzak).
- **Tek seferlik geçiş** `_adoptCloudShares()`: anahtar yokken dünya online + rol DM ise buluttaki `entity_shares` id'leri bir kez yerele alınır. Kaldırılan tier tohumuyla paylaşılmış kartlar aksi halde DM'e "paylaşılmamış" görünür ve kapatılamazdı. Offline dünyada hiçbir şey yazılmaz (anahtarın yokluğu = boş liste).
- Kart silindiğinde işaret blob'da kalabiliyor; `seedShareIds` bunu dünyada duran kartlarla kesiştirerek eler.

## Notes
- Filtre ve satır ikonu (`Icons.public`) bu seti okur — dünya offline olsa da.
