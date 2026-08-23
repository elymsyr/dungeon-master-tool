# Content Export Kuralları

## Amaç
Bu dizin, uygulama marketplace'ine eklenecek içerik modüllerini barındırır.
Modüller kullanıcılara oynaması için sunulur.

## İş Akışı (İki Aşamalı)

### Aşama 1 — Lisans Kontrolü ve Manifest Hazırlama
Her export işlemi lisans kontrolü ile başlar:
1. İçerik dosyaları dizine kopyalanır (değiştirilmez)
2. `manifest.json` oluşturulur — tüm metadata burada tutulur
3. Orijinal dosya yapısı korunur

### Aşama 2 — İçerik Aktarımı
Orijinal içerik, uygulamamızdaki formata dönüştürülür:
- **Karakter Aktarımı**: Kaynak karakter alanları → uygulama karakter kartı alanları eşleştirilir, `blueprint.json` oluşturulur
- **Campaign → World Aktarımı**: Kaynak campaign kategorileri → uygulama world entity kategorileri eşleştirilir, `world blueprint.json` oluşturulur

Tüm çıktılar markdown formatında dokümante edilir.

## Kurallar

### Kural 1 — İçerik Değiştirilemez
İçerik noktası virgülüne, kelimesi kelimesine aynı kalmalıdır.
Hiçbir dosya (PDF, görsel, karakter dosyası) üzerinde düzenleme yapılmaz.
Yalnızca `manifest.json` ve `blueprint.json` oluşturulur.

### Kural 2 — Manifest İçeriğe Referans Verir
Metadata (başlık, yayıncı, lisans vb.) `manifest.json`'da tutulur.
İçerik dosyaları olduğu gibi paketlenir, manifest'te tekrar edilmez.

### Kural 3 — Dosya Yolları Relative Olmalıdır
Tüm dosya referansları modül dizinine göreceli olmalı.

### Kural 4 — Orijinal Dizin Yapısı Korunur
Mevcut klasör isimleri (`media/`, `Maps/`, `Handouts/` vb.) değişmez.

## Modül Formatı

```
tool/content/<modul-adı>/
├── manifest.json              # Aşama 1: Metadata
├── blueprint.json             # Aşama 2: Karakter aktarım planı
├── world-blueprint.json       # Aşama 2: World aktarım planı (varsa)
├── <ana-dosya>.pdf
└── media/
    ├── maps/
    ├── handouts/
    ├── tokens/
    └── gcs-characters/
```

## Aşama 1: Manifest Şablonu

```json
{
  "slug": "99-devils-of-uzrahs-palace-shadowdark",
  "title": "99 Devils of Uzrah's Palace",
  "system": "shadowdark",
  "publisher": "",
  "author": "",
  "license": "",
  "attribution": "",
  "source_url": "",
  "version": "1.0.0",
  "description": "",
  "files": {
    "pdf": "99-Devils-of-Uzrahs-Palace-Shadowdark.pdf",
    "cover_image": "media/Title-Image.webp",
    "media": {
      "maps": [],
      "handouts": [],
      "tokens": [],
      "gcs_characters": []
    }
  }
}
```

## Aşama 2: Karakter Aktarım Blueprint'i

Orijinal içerikteki karakterler, uygulamamızdaki `player-character` kategorisine dönüştürülür.
Her karakter için `blueprint.json` oluşturulur.

### Eşleme Kuralları

> [!important] Alan sözleşmesinin tamamı: [character-blueprint.md](character-blueprint.md)
> Orada her alanın tam JSON şekli, tipi, default'u ve hangi kaynaktan
> doldurulduğu (sihirbaz / resolver / manuel) yazılı. Aşağıdaki tablo kısa özettir.

Kaynak karakter alanları → Uygulama alanları:

| Kaynak Alan | Uygulama Alanı | Not |
|---|---|---|
| Name | `name` | Entity name |
| Race/Species | `species_ref` | `relation` → species entity (tek id) |
| Class | `class_refs` | `relation` list → class entity |
| Level | `class_levels` | `levelTable` `{classEntityId: level}` — anahtar sınıfın **id**'si; blueprint'te isim yazılır, importer `class_refs` ile çözer |
| Subclass | `subclass_refs` / `subclass_id` | relation list / resolver girdisi |
| Alignment | `alignment_ref` | `relation` → alignment lookup |
| Background | `background_ref` | `relation` → background entity |
| STR/DEX/CON/INT/WIS/CHA | `stat_block` | `statBlock` map, int değerler: `{"STR":16, ...}` |
| HP | `combat_stats.hp`, `combat_stats.max_hp` | `combatStats` int |
| AC | `combat_stats.ac` | `combatStats` int |
| Speed | `combat_stats.speed` | `combatStats` **text** — `"30 ft"` |
| Skills | `skills` | `proficiencyTable` — satırlar preset üstüne isimle merge edilir |
| Saving Throws | `saving_throws` | `proficiencyTable` (6 satır) |
| Proficiencies | `tool_proficiencies`, `languages`, `weapon_proficiency_categories`, `armor_trainings`, `weapon_masteries` | `relation` listeleri |
| Equipment | `inventory` | `relation` list → `{id, equipped}` satırları |
| Spells | `spells_known` | `relation` list → `{id, equipped}` (equipped = hazırlanmış) |
| Spell Slots | `spell_slots` | `{max:{seviye:adet}, remaining:{...}}` |
| Features/Traits | `trait_refs`, `action_refs`, `bonus_action_refs`, `reaction_refs` | `relation` listeleri |
| Personality | `personality_traits`, `ideals`, `bonds`, `flaws` | `markdown` |
| Backstory / Appearance | `backstory`, `appearance`, `allies_organizations` | `markdown` |
| Money | `cp` / `sp` / `ep` / `gp` / `pp` | `integer` |

### Blueprint Formatı

```json
{
  "version": "1.0.0",
  "source_system": "shadowdark",
  "app_schema": "builtin-dnd5e-default-v2",
  "characters": [
    {
      "source_name": "Karakter Adı",
      "source_file": "media/GURPS GCS Characters/Example.gcs",
      "mapping": {
        "name": "Karakter Adı",
        "species_ref": {
          "lookup": "species",
          "match": "name",
          "value": "Human"
        },
        "class_refs": [
          {
            "lookup": "class",
            "match": "name",
            "value": "Fighter"
          }
        ],
        "class_levels": {
          "Fighter": 5
        },
        "stat_block": {
          "STR": 16,
          "DEX": 12,
          "CON": 14,
          "INT": 10,
          "WIS": 13,
          "CHA": 8
        },
        "combat_stats": {
          "hp": 35,
          "max_hp": 35,
          "ac": 18,
          "speed": "30 ft",
          "level": 5,
          "initiative": "+1",
          "cr": "",
          "xp": 6500
        },
        "skills": {
          "rows": [
            {"name": "Athletics", "ability": "STR", "proficient": true},
            {"name": "Intimidation", "ability": "CHA", "proficient": true}
          ]
        },
        "inventory": [
          {
            "lookup": "weapon",
            "match": "name",
            "value": "Longsword",
            "equipped": true
          },
          {
            "lookup": "armor",
            "match": "name",
            "value": "Chain Mail",
            "equipped": true
          }
        ],
        "personality_traits": "Cesur ve kararlı bir savaşçı.",
        "backstory": "Köyünden ayrılarak maceraya atıldı..."
      },
      "notes": "El yapımı karakter, SRD dışı"
    }
  ]
}
```

### Eşleme Stratejileri

**`match` türleri:**
- `"name"` — İsim ile eşle (en yaygın)
- `"slug"` — Slug ile eşle
- `"abbreviation"` — Kısaltma ile eşle (ability scores için)
- `"manual"` — Manuel değer (kaynakta karşılığı yoksa)

**`lookup` kategorileri:**
Karakterler genellikle şu Tier-0/Tier-1 kategorilerine referans verir:
- `species`, `class`, `subclass`, `background`, `alignment`
- `weapon`, `armor`, `adventuring-gear`, `magic-item`
- `spell`, `feat`, `trait`, `creature-action`
- `skill`, `language`, `tool`, `sense`, `condition`

**Eşleşmeyen alanlar:**
Kaynak içerikte karşılığı olmayan uygulama alanları `blueprint.json`'a yazılmaz.
Uygulama varsayılan değerler kullanır (örn: `stat_block` → `{STR:10, DEX:10, ...}`).

## Aşama 2: Campaign → World Aktarım Blueprint'i

Orijinal campaign/setting içeriği, uygulamamızdaki world kategorilerine dönüştürülür.
Her entity türü için `world-blueprint.json` oluşturulur.

### World Kategorileri (Tier-2 DM)

| Kategori | Slug | Kullanım |
|---|---|---|
| NPC | `npc` | Campaign'deki tüm NPC'ler |
| Location | `location` | Mekanlar, binalar, bölgeler |
| Quest | `quest` | Görevler, macera arc'ları |
| Encounter | `encounter` | Savaş encounter'ları |
| Scene | `scene` | Sahne/akt planları |
| Trap | `trap` | Tuzaklar |
| Curse | `curse` | Lanetler |
| Poison | `poison` | Zehirler |
| Environmental Effect | `environmental-effect` | Çevresel etkiler |
| Hireling | `hireling` | Kiralık askerler |
| Service | `service` | Hizmetler |

### World Blueprint Formatı

```json
{
  "version": "1.0.0",
  "source_system": "shadowdark",
  "app_schema": "builtin-dnd5e-default-v2",
  "categories": {
    "npc": [
      {
        "source_name": "NPC Adı",
        "source_type": "person",
        "mapping": {
          "name": "NPC Adı",
          "species_ref": {
            "lookup": "species",
            "match": "name",
            "value": "Human"
          },
          "class_refs": [
            {
              "lookup": "class",
              "match": "name",
              "value": "Wizard"
            }
          ],
          "stat_block": {
            "STR": 10,
            "DEX": 14,
            "CON": 12,
            "INT": 18,
            "WIS": 13,
            "CHA": 15
          },
          "combat_stats": {
            "hp": 30,
            "max_hp": 30,
            "ac": 15,
            "speed": 30
          },
          "attitude_ref": {
            "lookup": "attitude",
            "match": "name",
            "value": "Friendly"
          },
          "description": "Yaşlı bir bilge, partinin rehberi."
        }
      }
    ],
    "location": [
      {
        "source_name": "Location Adı",
        "source_type": "place",
        "mapping": {
          "name": "Location Adı",
          "description": "Karanlık bir mağara, girişinde taş bir kapı var.",
          "danger_level_ref": {
            "lookup": "danger-level",
            "match": "name",
            "value": "Medium"
          },
          "illumination_ref": {
            "lookup": "illumination",
            "match": "name",
            "value": "Darkness"
          },
          "maps": ["media/Maps/Cave-Map.webp"]
        }
      }
    ],
    "quest": [
      {
        "source_name": "Quest Adı",
        "source_type": "quest",
        "mapping": {
          "name": "Quest Adı",
          "description": "Köylüleri kurtarmak için mağaraya girilmeli.",
          "status": "active",
          "objective": "Köylüleri kurtar ve eve dön.",
          "xp_reward": 500,
          "gold_reward": 200
        }
      }
    ],
    "encounter": [
      {
        "source_name": "Encounter Adı",
        "source_type": "combat",
        "mapping": {
          "name": "Encounter Adı",
          "location_ref": {
            "lookup": "location",
            "match": "name",
            "value": "Location Adı"
          },
          "difficulty": "medium",
          "monster_refs": [
            {
              "lookup": "monster",
              "match": "name",
              "value": "Goblin",
              "count": 4
            }
          ],
          "xp_budget": 800
        }
      }
    ]
  },
  "cross_references": [
    {
      "from_category": "npc",
      "from_name": "NPC Adı",
      "from_field": "location_ref",
      "to_category": "location",
      "to_name": "Location Adı"
    }
  ]
}
```

### Eşleme Kuralları (Campaign → World)

| Kaynak Tür | Uygulama Kategorisi | Not |
|---|---|---|
| Person/Character | `npc` |faction liderleri, mağazacılar, rehberler |
| Place/Region | `location` | Mekanlar, harita noktaları |
| Quest/Mission | `quest` | Görevler, arc'lar |
| Combat/Encounter | `encounter` | Savaş planları |
| Scene/Beat | `scene` | Senaryo akışı |
| Trap/Hazard | `trap` | Tuzaklar |
| Magic Item | → `magic-item` (Tier-1) | World'e eklenen özel eşyalar |
| Monster | → `monster` (Tier-1) | Özel yaratıklar |

### Cross-Referanslar

`cross_references` dizisi, entity'ler arası ilişkileri tanımlar:
- `from_category` / `from_name`: Kaynak entity
- `from_field`: Hangi alan referans veriyor
- `to_category` / `to_name`: Hedef entity

Bu referanslar, aktarım sonrası uygulama içinde otomatik olarak bağlanır.

## Export Scripti

```powershell
# Modülü paketle
powershell -ExecutionPolicy Bypass -File tool/content/export_module.ps1 -ModulePath "tool/content/<modul-adı>"
```

Script şu işlemleri yapar:
1. Manifest'i doğrular (zorunlu alanlar, dosya varlığı)
2. Tüm dosyaları zip paketine toplar
3. Özeti yazdırır

## Aktarım Sonrası Kontrol

Her blueprint dosyası için:
1. `blueprint.json` → Karakter alanları doğru mu?
2. `world-blueprint.json` → Entity kategorileri doğru mu?
3. Cross-referanslar tutarlı mı?
4. Eşleşmeyen alanlar için varsayılanlar uygun mu?

Aktarım tamamlandıktan sonra blueprint dosyaları `tool/content/<modul-adı>/` dizininde kalır.
Uygulamaya entegrasyon gerektiğinde bu dosyalar okunarak entity'ler oluşturulur.
