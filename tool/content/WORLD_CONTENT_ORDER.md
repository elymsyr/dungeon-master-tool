# World Content Addition Order

Bir dünyayı eklerken kategoriler bu sırayla yazılır — sıra bağımlılık
zinciridir, bir kategoriyi ancak bağımlıları tamamlanınca ekleyebilirsin.
Süreç: [README.md](README.md). Alan sözleşmeleri: [world-blueprint.md](world-blueprint.md),
[character-blueprint.md](character-blueprint.md).

## Tier 0 — Schema Lookups (uygulamada hazır)

`builtin/lookups.dart` içinde tanımlı: `ability`, `skill`, `condition`,
`damage-type`, `creature-type`, `language`, `alignment`, `size`,
`weapon-property`, `spell-school`, `sense`, `attitude`, `illumination`, …

Yeni bir şey yazma; **seed listesinde olan değeri birebir kullan.** Sık yapılan
hatalar:

| Yanlış | Doğru |
|---|---|
| `Dim Light` / `Bright Light` | `Dim` / `Bright` (`Darkness`) |
| `True Neutral` | `Neutral` (alignment) |
| `Neutral` (attitude) | `Indifferent` (`Friendly`/`Hostile`) |

Seed listesinde **olmayan** bir değer (ör. `Arabic`, `Persian` dili)
`world-blueprint.json`'da o kategori altında entity olarak tanımlanmalı, yoksa
`{_lookup}` zarfı hedefsiz kalır.

## Tier 1 — Schema Content (SRD pack veya custom)

Sıra: `species` → `subspecies` → `background` → `class` → `subclass` → `feat` →
`spell` → `trait` → `weapon` → `armor` → `tool` → equipment (`adventuring-gear`,
`ammunition`, `pack`, `mount`, `vehicle`, `trinket`) → `magic-item` → `monster` →
`creature-action` → `animal` → `starter-bundle`.

Üç durum, üçüncüsü yok:

1. SRD 5.2.1'de **birebir aynı isimle** var → blueprint'e **ekleme**, sadece
   referans ver (`{"lookup": "weapon", "match": "name", "value": "Longsword"}`);
   converter soft ref'e çevirir, okuma anında SRD'den çözülür.
2. SRD'de yok → kendi kategorisi altında entity olarak ekle; referans pack-içi
   hard ref olur.
3. Ne SRD'de ne blueprint'te → **build kırılır** (`--check`).

## Tier 2 — World Entities (`world-blueprint.json`)

| # | Kategori | Bağımlılık |
|---|---|---|
| 1 | `campaign` | — |
| 2 | `location` | (kendisi — `parent_location_ref`) |
| 3 | `lore` | — |
| 4 | `monster` | location |
| 5 | `npc` | location, class, species, background |
| 6 | `environmental-effect` | location |
| 7 | `trap` | location |
| 8 | `scene` | location, npc |
| 9 | `encounter` | location, npc, monster, trap |
| 10 | `quest` | location, npc, monster, encounter, trap, scene |

Diğer Tier-2 slug'ları (bağımsız, sıradan bağımsız eklenebilir): `poison`,
`curse`, `hireling`, `service`.

## Tier 3 — Player Characters (`blueprint.json`)

PC'ler `world-blueprint.json`'a **yazılmaz** — Database sekmesi
`player-character` kategorisini listelemez, oraya yazılan PC hiçbir ekranda
görünmez. Kurulum `blueprint.json`'daki PC'leri dünyanın **Characters**
sekmesine ownersız (unclaimed) karakter olarak yazar; `--check` çıktısı bunları
entity sayısının altında ayrı satırda gösterir.

Ref formatı zorunlu — `"class_refs": [{"lookup": "class", "match": "name",
"value": "Bard"}]`; flat `"class": "Bard"` ✗.

Kaynak sistemin sınıfı 5e'de yoksa (Shadowdark `Ras-Godai`, `Desert Rider`…)
en yakınına eşle **ve gerçek sınıfı `description` + `backstory`'ye yaz** — sayı
uydurmaktansa ham metin korunur.

## Tier 4 — Media & Packaging

`media/` altına dosyalar → `manifest.json` (`files` listesi dahil) →
`world-blueprint.json` → `blueprint.json` → `pubspec.yaml` asset deklarasyonu →
doğrulama + paketleme ([README § 5-6](README.md)).

## Her kategoriden sonra kontrol

- [ ] Tüm `*_ref` / `*_refs` hedefleri oluşturulmuş mu?
- [ ] Hedef kategori, alanın izinli listesinde mi?
- [ ] `mapping` içindeki her anahtar şemada var mı?
- [ ] `image_path` dosyası hem diskte hem `manifest.json` → `files` içinde mi?
- [ ] `source` ve `description` dolu mu?
