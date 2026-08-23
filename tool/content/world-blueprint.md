# World Blueprint — `campaign → world` Alan Referansı

> Bu dosya, campaign/setting içeriğinden uygulamaya aktarılacak **Tier-2 DM
> kategorilerinin** tek yetkili alan sözleşmesidir. Bir modülün (PDF adventure,
> setting kitabı, campaign dosyası) world entity'lerine dönüştürülmesi için
> buradaki alan adları, tipleri ve JSON şekilleri kullanılır.
> Kaynak kod: `flutter_app/lib/domain/entities/schema/builtin/dm.dart` → `buildTier2Dm`.
> Karakter aktarımı ayrıdır: [character-blueprint.md](character-blueprint.md).

## 1. World entity nedir?

Her world öğesi, `categorySlug`'u Tier-2 slug'larından biri olan bir `Entity`'dir
(`flutter_app/lib/domain/entities/entity.dart`). Tip-spesifik veri `fields`
map'inde saklanır; kartın temeli:

```json
{
  "id": "<uuid>",
  "name": "Öğe Adı",
  "categorySlug": "<tier-2 slug>",
  "description": "markdown metin",
  "tags": [],
  "imagePath": "",
  "dmNotes": "",
  "source": "",
  "fields": { "...aşağıdaki alanlar..." }
}
```

Tier-2 slug'ları (kanonik sıra, `dm.dart:14`): `npc`, `player-character`,
`applied-condition`, `location`, `scene`, `quest`, `encounter`, `trap`,
`poison`, `curse`, `environmental-effect`, `hireling`, `service`, `lore`,
`campaign`.

## 2. Alanlar nasıl doldurulur?

- **Enum alanları** kapalı liste taşır; blueprint'e **listedeki string'in
  aynısı** yazılmalıdır (ör. `danger_level: "Medium"`, `difficulty: "Moderate"`).
  Liste dışı değer importer tarafından reddedilir.
- **Relation alanları** blueprint'te `{"lookup", "match", "value"}` nesnesi
  veya bu nesnelerin listesi olarak yazılır; importer hedef kategorideki
  entity'yi bulup `fields`'e **id** yazar. `match` türleri: `"name"` (varsayılan),
  `"slug"`, `"abbreviation"`, `"manual"`.
- **DM-only alanlar** (`npc.secrets`, `location.secrets`, `quest.secrets`,
  `encounter.tactics`) oyuncu ekranında gizlenir; değerleri normal yazılır.
- **Medya alanları** (`map`, `battlemaps`, `map_per_era`, `pdfs`) modül dizinine
  **relative** dosya yolu taşır (`media/Maps/Cave.webp` gibi).
- Yazılmayan alanlar şema default'unu alır; alanın karşılığı yoksa yazma.

## 3. Kategori sözleşmeleri

Kısaltmalar: **T** = FieldType, **Z** = zorunlu, **D** = default.

### 3.1 NPC — `npc`

| key | T | Z | D | İçerik (tam şekil) |
|---|---|---|---|---|
| `species_ref` | relation→`species` | | — | Tek uuid string. |
| `class_refs` | relation→`class` (list) | | `[]` | `["<class-uuid>", ...]` |
| `level` | integer | | — | 1..20. |
| `background_ref` | relation→`background` | | — | Tek uuid string. |
| `alignment_ref` | relation→`alignment` | | — | Tek uuid string. |
| `attitude_ref` | relation→`attitude` | ✓ | — | Tek uuid string (lookup: Hostile/Friendly/Neutral...). |
| `location_ref` | relation→`location` | | — | NPC'nin bulunduğu mekan. |
| `faction` | text | | `''` | Serbest metin. |
| `stat_block` | statBlock | | `{STR:10,...}` | Altı anahtarın tamamı int: `{"STR":10,"DEX":12,...}` |
| `combat_stats` | combatStats | | boş string'li map | `{hp:int, max_hp:int, ac:int, speed:text, level:int, initiative:dice, cr:text, xp:int}` |
| `proficiency_bonus` | integer | | `2` | 2..9. |
| `initiative_modifier` | integer | | `0` | İmzalı int. |
| `saving_throws` | proficiencyTable | | 6 preset satır | `{rows:[{name,ability,proficient,expertise,misc}]}` |
| `skills` | proficiencyTable | | 18 preset satır | Aynı şekil. |
| `resistance_refs` / `vulnerability_refs` / `damage_immunity_refs` | relation→`damage-type` (list) | | `[]` | `["<uuid>", ...]` |
| `condition_immunity_refs` | relation→`condition` (list) | | `[]` | `["<uuid>", ...]` |
| `senses` | relation→`sense` (list) | | `[]` | `["<uuid>", ...]` |
| `passive_perception` | integer | | `10` | 0..30. |
| `language_refs` | relation→`language` (list) | | `[]` | `["<uuid>", ...]` |
| `telepathy_ft` | integer | | — | ≥ 0. |
| `trait_refs` | relation→`trait` (list) | | `[]` | `["<uuid>", ...]` |
| `action_refs` / `special_action_refs` | relation→`creature-action` (list) | | `[]` | `["<uuid>", ...]` |
| `equipment_refs` | relation list→`weapon`,`armor`,`tool`,`adventuring-gear`,`ammunition`,`pack`,`mount`,`vehicle`,`trinket`,`magic-item` | | `[]` | `["<uuid>", ...]` |
| `spell_refs` | relation→`spell` (list) | | `[]` | `["<uuid>", ...]` |
| `goals` / `appearance` / `mannerisms` | markdown | | `''` | Serbest metin. |
| `secrets` | markdown | | `''` | **DM-only.** |

### 3.2 Player Character — `player-character`

Sözleşmenin tamamı [character-blueprint.md](character-blueprint.md) — dünya
blueprint'inde PC aktarılmaz; karakterler `blueprint.json`'a gider.

### 3.3 Applied Condition — `applied-condition`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `condition_ref` | relation→`condition` | ✓ | — | Tek uuid string. |
| `source_entity_ref` | relation→`npc`,`player-character`,`monster`,`animal` | | — | Tek uuid string. |
| `duration_rounds` | integer | | — | ≥ 0; yoksa süresiz. |
| `save_dc` | integer | | — | 1..30. |
| `save_ability_ref` | relation→`ability` | | — | Tek uuid string. |
| `save_frequency` | enum | | — | `none` / `start-of-turn` / `end-of-turn` / `when-damaged` |
| `notes` | textarea | | `''` | Serbest metin. |

### 3.4 Location — `location`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `danger_level` | enum | | — | `Safe` / `Low` / `Medium` / `High` / `Deadly` |
| `environment` | text | | `''` | Serbest metin (ör. "Yeraltı mağarası"). |
| `parent_location_ref` | relation→`location` | | — | Üst mekan (hiyerarşi). |
| `plane_ref` | relation→`plane` | | — | Tek uuid string. |
| `illumination_ref` | relation→`illumination` | | — | Tek uuid string (lookup: Bright/Dim/Darkness...). |
| `hazard_refs` | relation→`hazard` (list) | | `[]` | `["<uuid>", ...]` |
| `description_long` | markdown | | `''` | Mekan açıklaması. |
| `secrets` | markdown | | `''` | **DM-only.** |
| `map` | image (battleMap) | | — | Tek asset yolu: `media/Maps/Cave.webp` |
| `map_per_era` | imagePerEra (battleMap) | | — | `Map<eraId, assetRef>` — era başına harita varyantı. |
| `battlemaps` | image list (battleMap) | | `[]` | `["media/Maps/A1.webp", ...]` |

### 3.5 Scene — `scene`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `location_ref` | relation→`location` | | — | Tek uuid string. |
| `status` | enum | | — | `Planned` / `Active` / `Completed` / `Skipped` |
| `illumination_ref` | relation→`illumination` | | — | Tek uuid string. |
| `travel_pace_ref` | relation→`travel-pace` | | — | Tek uuid string (lookup: Slow/Normal/Fast...). |
| `beats` | markdown | | `''` | Sahne akışı / beat listesi. |
| `npc_refs` | relation→`npc` (list) | | `[]` | Sahnede yer alan NPC'ler. |
| `quest_refs` | relation→`quest` (list) | | `[]` | Bağlı quest'ler. |

### 3.6 Quest — `quest`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `status` | enum | | — | `Not Started` / `Active` / `Completed` / `Failed` |
| `giver_ref` | relation→`npc` | | — | Quest veren NPC. |
| `reward_item_refs` | relation list→`magic-item`,`adventuring-gear`,`weapon`,`armor`,`trinket` | | `[]` | Ödül eşyalar (bitişte otomatik verilir). |
| `reward_xp` | integer | | — | ≥ 0. |
| `reward_gp` | integer | | — | ≥ 0. |
| `reward` | markdown | | `''` | Narrative ödül. |
| `objective` | markdown | | `''` | Görev tanımı. |
| `secrets` | markdown | | `''` | **DM-only.** |

### 3.7 Encounter — `encounter`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `location_ref` | relation→`location` | | — | Tek uuid string. |
| `difficulty` | enum | | — | `Trivial` / `Low` / `Moderate` / `High` / `Deadly` |
| `monsters_refs` | relation→`monster`,`animal` (list) | | `[]` | Savaşçı yaratıklar. |
| `npcs_refs` | relation→`npc` (list) | | `[]` | Savaşa katılan NPC'ler. |
| `environmental_effect_refs` | relation→`environmental-effect` (list) | | `[]` | Aktif çevre etkileri. |
| `trap_refs` | relation→`trap` (list) | | `[]` | Aktif tuzaklar. |
| `setup` | markdown | | `''` | Encounter girişi / sahne kurulumu. |
| `tactics` | markdown | | `''` | **DM-only.** |
| `xp_budget` | integer | | — | ≥ 0. |

### 3.8 Trap — `trap`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `trigger_kind` | enum | | — | `Pressure` / `Tripwire` / `Proximity` / `Sound` / `Magical` / `Touch` / `Other` |
| `trigger` | markdown | | `''` | Narrative tetikleyici. |
| `save_dc` | integer | | — | 1..30. |
| `save_ability_ref` | relation→`ability` | | — | Tek uuid string. |
| `damage_dice` | dice | | — | Zar notasyonu string: `"2d6"`, `"1d20+5"` |
| `damage_type_ref` | relation→`damage-type` | | — | Tek uuid string. |
| `applied_condition_refs` | relation→`condition` (list) | | `[]` | `["<uuid>", ...]` |
| `detection_dc` | integer | | — | 1..30. |
| `disable_dc` | integer | | — | 1..30. |
| `disable_ability_ref` | relation→`ability` | | — | Tek uuid string. |
| `countermeasures` | markdown | | `''` | Narrative karşı önlemler. |

### 3.9 Poison — `poison`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `poison_kind` | enum | ✓ | — | `Contact` / `Ingested` / `Inhaled` / `Injury` |
| `save_dc` | integer | | — | 1..30. |
| `save_ability_ref` | relation→`ability` | | — | Tek uuid string. |
| `damage_dice` | dice | | — | `"2d6"` gibi. |
| `damage_type_ref` | relation→`damage-type` | | — | Tek uuid string. |
| `applied_condition_refs` | relation→`condition` (list) | | `[]` | `["<uuid>", ...]` |
| `duration_rounds` | integer | | — | ≥ 0. |
| `effect` | markdown | | `''` | Narrative etki. |
| `cost_gp` | integer | | — | ≥ 0. |

### 3.10 Curse — `curse`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `trigger` | markdown | | `''` | Narrative tetikleyici. |
| `applied_condition_refs` | relation→`condition` (list) | | `[]` | `["<uuid>", ...]` |
| `removed_by_spell_refs` | relation→`spell` (list) | | `[]` | Kaldıran büyüler. |
| `mechanical_notes` | textarea | | `''` | Satır başına bir mekanik kural; düz metin. |
| `effect` | markdown | | `''` | Narrative etki. |
| `removed_by` | markdown | | `''` | Narrative kaldırma koşulu. |

### 3.11 Environmental Effect — `environmental-effect`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `damage_dice` | dice | | — | `"1d10"` gibi. |
| `damage_type_ref` | relation→`damage-type` | | — | Tek uuid string. |
| `applied_condition_refs` | relation→`condition` (list) | | `[]` | `["<uuid>", ...]` |
| `mechanical_notes` | textarea | | `''` | Satır başına bir mekanik kural; düz metin. |
| `effect` | markdown | | `''` | Narrative etki. |
| `save_dc` | integer | | — | 1..30. |
| `save_ability_ref` | relation→`ability` | | — | Tek uuid string. |

### 3.12 Hireling — `hireling`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `skill_ref` | relation→`skill` | | — | Tek uuid string. |
| `daily_cost_cp` | integer | ✓ | — | ≥ 0. |
| `skilled` | boolean | ✓ | — | `true` / `false` |

### 3.13 Service — `service`

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `kind` | enum | ✓ | — | `Spellcasting` / `Transport` / `Shelter` / `Other` |
| `cost_cp` | integer | ✓ | — | ≥ 0. |
| `availability` | text | | `''` | Serbest metin. |

### 3.14 Lore — `lore` / 3.15 Campaign — `campaign`

Referans doküman kategorileri; harita/encounter katılımcısı değildir.

| key | T | Z | D | İçerik |
|---|---|---|---|---|
| `pages` | markdown (list) | | `[]` | Sayfa metinleri listesi. |
| `pdfs` | pdf (list) | | `[]` | Relative PDF yolları listesi. |

## 4. Blueprint JSON formatı (world aktarımı)

Blueprint, kaynak campaign → uygulama kategorisi eşlemesini tanımlar. **Yalnızca
kaynakta karşılığı olan alanlar yazılır**; yazılmayan alanlar şema default'unu alır.
Importer şu dönüşümleri uygular:

1. `{"lookup", "match", "value"}` → hedef kategori entity'sini bul, relation
   alanına **id** yaz (list ise listeye ekle).
2. Enum alanları birebir string eşleşmesiyle yazılır (bkz. §3 kapalı listeler).
3. `stat_block` / `combat_stats` / sayısal alanlar aynen kopyalanır.
4. `combat_stats.speed` **text** olarak yazılmalıdır: `"30 ft"`.
5. Dice alanları string: `"2d6"`.
6. Medya alanları modül dizinine relative yol taşır.
7. `cross_references` kayıtları, blueprint içinde isimle referans verilip
   `cross_references` dizisinde çözülememiş ilişkileri taşır (bkz. §5).

### Örnek world blueprint

```json
{
  "version": "1.0.0",
  "source_system": "shadowdark",
  "app_schema": "builtin-dnd5e-default-v2",
  "categories": {
    "npc": [
      {
        "source_name": "Amara the Pale",
        "mapping": {
          "name": "Amara the Pale",
          "species_ref": {"lookup": "species", "match": "name", "value": "Human"},
          "class_refs": [{"lookup": "class", "match": "name", "value": "Wizard"}],
          "level": 9,
          "alignment_ref": {"lookup": "alignment", "match": "name", "value": "Neutral"},
          "attitude_ref": {"lookup": "attitude", "match": "name", "value": "Friendly"},
          "location_ref": {"lookup": "location", "match": "name", "value": "Uzrah's Palace"},
          "stat_block": {"STR": 8, "DEX": 14, "CON": 12, "INT": 18, "WIS": 13, "CHA": 15},
          "combat_stats": {"hp": 44, "max_hp": 44, "ac": 12, "speed": "30 ft"},
          "description": "Sarayın son kütüphanecisi, partiye rehberlik eder.",
          "secrets": "Aslında dev kralın torunu."
        }
      }
    ],
    "location": [
      {
        "source_name": "Uzrah's Palace",
        "mapping": {
          "name": "Uzrah's Palace",
          "danger_level": "Deadly",
          "environment": "Dev harabeleri",
          "illumination_ref": {"lookup": "illumination", "match": "name", "value": "Dim Light"},
          "description_long": "Çölün ortasında, 99 şeytanın beklediği saray.",
          "map": "media/Maps/Uzrahs-Palace-1.webp"
        }
      },
      {
        "source_name": "The Gate Hall",
        "mapping": {
          "name": "The Gate Hall",
          "danger_level": "High",
          "parent_location_ref": {"lookup": "location", "match": "name", "value": "Uzrah's Palace"},
          "description_long": "Giriş holü; tavan 60 ft."
        }
      }
    ],
    "scene": [
      {
        "source_name": "Arrival at the Gate",
        "mapping": {
          "name": "Arrival at the Gate",
          "status": "Planned",
          "location_ref": {"lookup": "location", "match": "name", "value": "The Gate Hall"},
          "beats": "1. Kapı gıcırdar ve kapanır.\n2. Parti feneri fark eder.\n3. İlk şeytan görünür.",
          "npc_refs": [{"lookup": "npc", "match": "name", "value": "Amara the Pale"}]
        }
      }
    ],
    "quest": [
      {
        "source_name": "Break the Binding",
        "mapping": {
          "name": "Break the Binding",
          "status": "Not Started",
          "giver_ref": {"lookup": "npc", "match": "name", "value": "Amara the Pale"},
          "objective": "Sarayın 99 bağını kır ve kralı serbest bırak.",
          "reward_xp": 2500,
          "reward_gp": 800,
          "secrets": "Son bağ ancak birinin kendini feda etmesiyle kırılır."
        }
      }
    ],
    "encounter": [
      {
        "source_name": "Gate Hall Ambush",
        "mapping": {
          "name": "Gate Hall Ambush",
          "location_ref": {"lookup": "location", "match": "name", "value": "The Gate Hall"},
          "difficulty": "Moderate",
          "monsters_refs": [
            {"lookup": "monster", "match": "name", "value": "Imp", "count": 4}
          ],
          "trap_refs": [{"lookup": "trap", "match": "name", "value": "Gate Spikes"}],
          "setup": "Parti holün ortasına vardığında imps gölgelerden çıkar.",
          "tactics": "İmpler önce büyücüye odaklanır, iki turda bir geri çekilir.",
          "xp_budget": 800
        }
      }
    ],
    "trap": [
      {
        "source_name": "Gate Spikes",
        "mapping": {
          "name": "Gate Spikes",
          "trigger_kind": "Pressure",
          "trigger": "Giriş holünün orta taşına basılınca.",
          "save_dc": 14,
          "save_ability_ref": {"lookup": "ability", "match": "name", "value": "Dexterity"},
          "damage_dice": "3d10",
          "damage_type_ref": {"lookup": "damage-type", "match": "name", "value": "Piercing"},
          "detection_dc": 15,
          "disable_dc": 13,
          "disable_ability_ref": {"lookup": "ability", "match": "name", "value": "Intelligence"}
        }
      }
    ],
    "environmental-effect": [
      {
        "source_name": "Wailing Winds",
        "mapping": {
          "name": "Wailing Winds",
          "effect": "Saray avlusunda sürekli uluyan rüzgar.",
          "mechanical_notes": "Uzun menzilli saldırılar disadvantage.\nFısıldamak işitilmez."
        }
      }
    ]
  },
  "cross_references": []
}
```

## 5. Cross-referanslar

Blueprint içinde **isimle** referans verilmiş ilişkiler `cross_references`
dizisinde taşınmaz — importer blueprint içi isimleri aynı blueprint'te çözer.
`cross_references`, **başka bir blueprint dosyasına** (ör. `blueprint.json`'daki
bir karakter → NPC) veya aktarım sırasına bağlı harici ilişkileri taşır:

```json
{
  "cross_references": [
    {
      "from_category": "npc",
      "from_name": "Amara the Pale",
      "from_field": "source_entity_ref",
      "to_category": "player-character",
      "to_name": "Jamal the Black Spear"
    }
  ]
}
```

- `from_category` / `from_name`: Kaynak entity
- `from_field`: Hangi alan referans veriyor
- `to_category` / `to_name`: Hedef entity

## 6. Kısa eşleme tablosu (campaign → world)

| Kaynak Tür | Uygulama Kategorisi | Not |
|---|---|---|
| Person / Character | `npc` | Faction liderleri, mağazacılar, rehberler |
| Place / Region | `location` | Mekanlar, harita noktaları; hiyerarşi `parent_location_ref` |
| Scene / Beat | `scene` | Senaryo akışı; `beats` markdown |
| Quest / Mission | `quest` | Görevler, arc'lar; ödül `reward_*` alanları |
| Combat / Encounter | `encounter` | Savaş planları; `monsters_refs` + `difficulty` |
| Trap / Hazard | `trap` | Tuzaklar; `trigger_kind` + DC'ler |
| Poison | `poison` | `poison_kind` zorunlu |
| Curse | `curse` | Mekanikler `mechanical_notes` düz metin |
| Environmental hazard | `environmental-effect` | Çevre etkileri |
| Hireling | `hireling` | `daily_cost_cp` + `skilled` zorunlu |
| Service | `service` | `kind` + `cost_cp` zorunlu |
| Handout / lore | `lore` | `pages` markdown listesi |
| Campaign guide | `campaign` | `pages` + `pdfs` |
| Magic Item | → `magic-item` (Tier-1) | World'e eklenen özel eşyalar |
| Monster | → `monster` (Tier-1) | Özel yaratıklar |
