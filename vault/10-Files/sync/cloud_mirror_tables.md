---
type: file-note
domain: sync
path: flutter_app/lib/application/services/cloud_mirror_tables.dart
layer: application
language: dart
status: active
updated: 2026-09-22
tags: [file]
---

# `cloud_mirror_tables.dart`

> [!abstract] Primary Purpose
> Yerel Drift tablosu ↔ bulut ayna tablosu eşlemesinin **tek** bildirimi. [[cloud_push_service]] soldan sağa, [[cloud_pull_service]] sağdan sola okuyor. İki ayrı harita tutmak, birine kolon eklenip ötekine unutulduğunda sessizce veri kaybettiren tam da o hata — Faz 5a'da bu yüzden `cloud_push_service.dart`'tan ayrıldı.

## Inputs / Outputs
**Outputs** — `MirrorTable`, `MirrorOwner`, `mirrorTables` (12 dünya tablosu), `packageTables` (3 paket tablosu), `localTableOf` (bulut → yerel ad).

`world_combatants` listelerde **yok**: yerel `combatants`'ta `world_id` yok (encounter üzerinden gelir) ve durum etkileri bulutta ayrı satır değil kolon. İki tarafta da elle ele alınıyor (`_collectCombatants` / `_writeCombatant`), `localTableOf`'ta ayrıca eşleniyor.

## Dependencies & Links
- Used by: [[cloud_push_service]], [[cloud_pull_service]]
- Domain map: [[Sync-and-Realtime]]
- Spec / reference: `docs/online-sync-redesign.md` §2.2, §4.6–§4.8; [[migrations-cloud-mirror]].

## Key Logic / Variables
Bir `MirrorTable` sekiz bayrakla iki yönü birden tarif ediyor. Kolon adları çoğunlukla iki tarafta aynı (Drift SQL'i snake_case üretiyor), o yüzden gövde bir isim listesi + dönüşüm bayrakları:

| Alan | Ne |
|---|---|
| `cols` / `dateCols` | aynalanan kolonlar; `dateCols` unix saniye ↔ ISO |
| `boolCols` | SQLite 0/1 ↔ Postgres `boolean` |
| `jsonCols` | yerelde TEXT ↔ bulutta `jsonb` |
| `mediaCols` | yerel yol ↔ `dmt-content://{sha}` |
| `rename` | ayrışan kolon adı (yerel → bulut) |
| `scope` | push taramasının kapsam kolonu: `world_id` / `package_id` / `id` |
| `owner` | `owner_id` kaynağı: satırın kendisi / NULL (DM'in mind map'i) / oturumdaki kullanıcı |
| `sinceAll` | damga yok sayılsın mı — FK hedefi olan ebeveyn satır (`user_packages`) |
| `key` | **yerel** birincil anahtar; pull gelen satırı bununla buluyor (`id`, 1:1'de `world_id`, `installed_packages`'ta bileşik) |

## Notes
- Yeni bir kolon aynalanacaksa **tek** yer burası; iki servis de otomatik öğrenir. İstisna: bulut tarafındaki DDL (migration) ve varsa dönüşüm bayrağı.
- `packages` satırı `sinceAll: true` — çocuklarının FK hedefi, bulutta yoksa çocuklar reddedilir. Her turun boşa yazması migration 096'nın echo guard'ıyla revizyon artırmaz oldu.
