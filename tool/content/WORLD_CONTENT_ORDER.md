# World Content Addition Order

> Herhangi bir dünyayı (campaign/setting) uygulamaya eklerken takip edilecek sıralama.
> Bu sıra bağımlılık zincirine göredir — bir kategoriyi ancak bağımlı olduğu
> kategoriler tamamlandıktan sonra ekleyebilirsin.

## Genel Kural

Her kategoriyi ekledikten sonra **eksik kontrolü** yapılır. Bir sonraki kategoriye
geçmeden önce mevcut kategorinin tüm entity'leri tam ve doğru olmalıdır.

---

## Sıralama

### Tier 0 — Schema Lookups (Uygulama zaten var)

Bu kategoriler `builtin_dnd5e_v2_schema.dart` + `lookups.dart` içinde tanımlıdır.
Dünyaya özel bir şey eklemeden önce mevcut lookup'ların yeterli olup olmadığını kontrol et.

| Sıra | Kategori | Slug | Bağımlılık |
|------|----------|------|------------|
| — | Ability Scores | `ability` | — |
| — | Skills | `skill` | — |
| — | Conditions | `condition` | — |
| — | Damage Types | `damage-type` | — |
| — | Creature Types | `creature-type` | — |
| — | Languages | `language` | — |
| — | Alignments | `alignment` | — |
| — | Sizes | `size` | — |
| — | Weapon Properties | `weapon-property` | — |
| — | Spell Schools | `spell-school` | — |
| — | Senses | `sense` | — |
| — | (diğer lookup'lar) | ... | — |

**Kontrol:** `world-blueprint.json`'da veya `blueprint.json`'da referans verilen
her lookup değeri mevcut schema'da tanımlı mı?

---

### Tier 1 — Schema Content (SRD Pack veya custom ekleme)

Bu kategoriler SRD 5.2.1 pack'inde zaten tanımlıdır. Dünyaya özel içerik
eklenecekse (ör. Shadowdark-specific class, race, feat) önce buraya eklenir.

| Sıra | Kategori | Slug | Bağımlılık |
|------|----------|------|------------|
| 1.1 | Species (Race) | `species` | — |
| 1.2 | Subspecies | `subspecies` | species |
| 1.3 | Backgrounds | `background` | — |
| 1.4 | Classes | `class` | — |
| 1.5 | Subclasses | `subclass` | class |
| 1.6 | Feats | `feat` | — |
| 1.7 | Spells | `spell` | — |
| 1.8 | Traits | `trait` | — |
| 1.9 | Weapons | `weapon` | — |
| 1.10 | Armor | `armor` | — |
| 1.11 | Tools | `tool` | — |
| 1.12 | Equipment (gear, ammo, pack, mount, vehicle, trinket) | Various | — |
| 1.13 | Magic Items | `magic-item` | — |
| 1.14 | Monsters | `monster` | — |
| 1.15 | Creature Actions | `creature-action` | — |
| 1.16 | Animal | `animal` | — |
| 1.17 | Starter Bundle | `starter-bundle` | — |

**Kontrol:** Blueprint'teki `class_refs`, `species_ref`, `background_ref`,
`feat_refs`, `spell_refs` gibi referansların hepsi SRD pack'de mevcut mu?
Eksik varsa önce SRD'ye eklenir.

**Önemli:** Tier-1 entity'leri `world-blueprint.json`'a **DOĞRUDAN EKLENMEZ**.
Bunlar paket (package) seviyesinde yönetilir. World-blueprint'teki reference'lar
(sadece isim veya slug ile) SRD pack'deki entity'leri指向 eder.

---

### Tier 2 — World Entities (world-blueprint.json)

Bu entity'ler `world-blueprint.json`'a yazılır. Sıralama bağımlılık zincirine göredir.

| Sıra | Kategori | Slug | Bağımlılık | Açıklama |
|------|----------|------|------------|----------|
| **2.1** | **Campaign** | `campaign` | — | Dünyanın kendisi. Her şeyden önce oluşturulur. |
| **2.2** | **Location** | `location` | — | Mekanlar. NPC, encounter, trap, scene, quest bunlara referans verir. |
| **2.3** | **Lore** | `lore` | — | Dünya bilgisi, tarihçe, efsane. Bağımsız. |
| **2.4** | **Monster** | `monster` | — | Dünya-specific monster'lar (SRD'de olmayan). `location_ref` ile. |
| **2.5** | **NPC** | `npc` | location, class, species, background | NPC'ler mekana, sınıfa, ırka referans verir. |
| **2.6** | **Environmental Effect** | `environmental-effect` | location | Hava,折り, aura gibi çevresel etkiler. |
| **2.7** | **Trap** | `trap` | location | Tuzaklar mekana referans verir. |
| **2.8** | **Scene** | `scene` | location, npc | Sahne tanımları. NPC ve mekan referansı içerir. |
| **2.9** | **Encounter** | `encounter` | location, npc, monster, trap | Karşılaşmalar. Birden fazla entity'ye referans verir. |
| **2.10** | **Quest** | `quest` | location, npc, monster, encounter, trap, scene | Görevler. En çok bağımlılığı olan kategori. |

**Kontrol her sıradan sonra:**
1. Entity'nin `location_ref`'i bir `location` entity'sine mı işaret ediyor?
2. `npc_refs` veya `npc_ref`'ler mevcut mu?
3. `monster_refs`'ler mevcut mu?
4. Tüm `*_ref` alanlarının hedefleri oluşturulmuş mu?

---

### Tier 3 — Player Characters (blueprint.json)

PC'ler `blueprint.json`'a yazılır, `world-blueprint.json`'a DEĞİL.

**Önemli:** PC eklemeden önce tüm bağımlılıklar tam olmalıdır:

| Bağımlılık | Kaynak | Durum |
|-----------|--------|-------|
| Class | SRD Pack | ✅ Mevcut (D&D5e) |
| Species (Race) | SRD Pack | ✅ Mevcut |
| Background | SRD Pack | ✅ Mevcut |
| Alignment | Schema Lookup | ✅ Mevcut |
| Feats | SRD Pack | ✅ Mevcut (5e SRD) |
| Spells | SRD Pack | ✅ Mevcut |
| Equipment | SRD Pack | ✅ Mevcut |

**PC Formatı (blueprint.json):**
- Class/Background/Alignment `ref` formatında olmalı:
  ```json
  "class_refs": [{"lookup": "class", "match": "name", "value": "Bard"}]
  ```
- **Flat format kullanma** (`"class": "Bard"` → ❌)
- `imagePath` zorunlu değil ama medya varsa ekle

**Kontrol:**
1. Tüm PC'lerin class'ları SRD'de mevcut mu?
2. Species'ler mevcut mu?
3. Background'lar mevcut mu?
4. Spell'ler mevcut mu?
5. Equipment'ler mevcut mu?

---

### Tier 4 — Media & Packaging

| Sıra | İşlem | Açıklama |
|------|-------|----------|
| 4.1 | Media dosyalarını kopyala | `assets/worlds/{dir}/media/` altına token, map, handout |
| 4.2 | `manifest.json` oluştur | World metadata, media dosya listesi |
| 4.3 | `world-blueprint.json` oluştur | Tier 2 entity'leri |
| 4.4 | `blueprint.json` oluştur | Tier 3 PC'leri |
| 4.5 | `pubspec.yaml` güncelle | `assets/worlds/` declaration |
| 4.6 | `.pkg.json` üret | `convert_blueprint.dart` ile |

---

## Hızlı Referans: Ekleme Sırası

```
1. Schema kontrolü (Tier 0+1) ← SRD pack'de her şey var mı?
2. Campaign entity
3. Location'lar
4. Lore
5. Monster'lar (world-specific)
6. NPC'ler
7. Environmental Effects
8. Trap'ler
9. Scene'ler
10. Encounter'lar
11. Quest'ler
12. PC'ler (blueprint.json)
13. Media dosyaları
14. Manifest + packaging
```

---

## Eksik Kontrol Checklist

Her kategori eklenirken:

- [ ] Entity'nin tüm `_ref` alanlarının hedefleri mevcut mu?
- [ ] `location_ref` geçerli bir location'a mı işaret ediyor?
- [ ] `npc_refs` mevcut NPC'leri mi gösteriyor?
- [ ] `monster_refs` mevcut monster'ları mı gösteriyor?
- [ ] `encounter_refs` mevcut encounter'ları mı gösteriyor?
- [ ] `trap_refs` mevcut trap'leri mi gösteriyor?
- [ ] `scene_refs` mevcut scene'leri mi gösteriyor?
- [ ] `quest_refs` mevcut quest'leri mi gösteriyor?
- [ ] `image_path` dosyası media klasöründe mevcut mu?
- [ ] `tags` doğru mu?
- [ ] `description` dolu mu?

---

## Shadowdark Specific Notlar

Shadowdark için D&D5e SRD schema'sı kullanılır. Farklılıklar:

- **Class:** Bard, Cleric, Fighter, etc. SRD'de mevcut
- **Species:** Human SRD'de mevcut. Custom species (ör. "Djinn-born") eklenmeli
- **Background:** Entertainer, Soldier, etc. SRD'de mevcut
- **Feats:** SRD feat'leri yeterli olmayabilir — custom feat'ler eklenmeli
- **Monsters:** World-specific monster'lar (Cobra, Ghul-Bird, etc.) SRD'de yok —
  Tier 1 Monster kategorisine eklenmeli VEYA world-blueprint'te inline stat block
- **Alignment:** SRD'de mevcut (Chaotic Good, etc.)

**Tüm mundo-specific content için:** Önce Tier 1'e ekle, sonra Tier 2'de referans ver.
