# Karakter Yaratma ve Level Sistemi — Gap Analizi ve Yol Haritası

**Kapsam:** Mevcut Flutter wizard (`character_creation_wizard_screen.dart`) ile
karakter editörünün (`character_editor_screen.dart`) SRD 5.2.1
(`docs/SRD_CC_v5.2.1.pdf`, s. 19–27) karşısında çıkardığı boşlukları belgeler ve
deneyimi geliştirecek somut iyileştirmeler önerir.

**Referans kaynaklar**
- SRD 5.2.1 — *Character Creation* (s. 19–22), *Level Advancement* (s. 23),
  *Starting at Higher Levels* (s. 24), *Multiclassing* (s. 24–26),
  *Trinkets* (s. 26–27).
- Mevcut uygulama: [flutter_app/lib/presentation/screens/characters/wizard/](../flutter_app/lib/presentation/screens/characters/wizard/),
  [character_editor_screen.dart](../flutter_app/lib/presentation/screens/characters/character_editor_screen.dart),
  [class_level_up_table.dart](../flutter_app/lib/presentation/widgets/class_level_up_table.dart).
- Şema: [domain/entities/schema/builtin/content.dart](../flutter_app/lib/domain/entities/schema/builtin/content.dart).
- Önceki denetim: [srd_5e_mechanic_audit.md](srd_5e_mechanic_audit.md) §D.2.

---

## 1. Yönetici Özeti

İki temel sorun var:

1. **Karakter yaratma wizard'ı SRD'nin Step 1–5'inin yaklaşık %40'ını kapsıyor.**
   Ana eksenler (ad, ırk, sınıf, alt-sınıf, background, ekipman, ability,
   review) yerinde; fakat SRD'nin "Choose Your Character" ve "Step 5 Details"
   bölümlerinin ana çoğunluğu (skill/language/tool/feat/fighting style/cantrip
   seçimleri, kişilik soruları, trinket, yüksek seviye başlangıç ekipmanı,
   multiclass) wizard'da hiç yok. Şema bu seçimleri çoktan modelliyor
   (`skill_proficiency_choice_count`, `granted_language_count`,
   `origin_feat_ref`, `cantrips_known_by_level` vb.) — UI tarafı atlanmış.

2. **Level değişimi tamamen pasif.** Editörde `level` alanı bir number
   field. Kullanıcı 3'ten 4'e çıkardığında uygulama:
   - HP'yi yeniden hesaplamıyor, hit dice eklemiyor,
   - Proficiency bonus alanını güncellemiyor,
   - Yeni class/subclass feature'ı için onay/seçim sormuyor,
   - ASI/Feat seçim noktalarını (4, 8, 12, 16, 19) tetiklemiyor,
   - Spell slot tablosunu güncellemiyor,
   - Oyuncuya hiçbir bildirim göstermiyor.

   `ClassLevelUpTable` widget'ı eklenmiş (yeni, untracked), bu pasif önizleme
   için iyi bir temel — fakat etkileşimli level-up akışı yok.

İki sorun da **şema seviyesinde data var**, eksiklik **etkileşimli UI ve
mutation pipeline** tarafında. Yol haritası buna göre tasarlandı.

---

## 2. Karakter Yaratma — SRD vs Mevcut

### 2.1 SRD Adım Akışı (s. 19, §1.1)

```
1. Choose Class
2. Determine Origin   (background + species + 2 languages)
3. Determine Ability Scores
4. Choose Alignment
5. Fill in Details    (record class features, skills, AC, HP, attacks, spells)
```

### 2.2 Mevcut Wizard (`character_creation_wizard_screen.dart:188-263`)

```
1. Identity      (name, world, template, level, alignment, portrait)
2. Race/Species
3. Class
4. Subclass
5. Background
6. Equipment
7. Abilities     (Standard Array / Point Buy / 4d6 / Manual + racial)
8. Review
```

### 2.3 Adım-bazlı Karşılaştırma

| SRD Adımı | Wizard Karşılığı | Durum |
|---|---|---|
| Class → primary ability hatırlatması | Class step (kart listesi) | **Var, ama primary ability hint'i yok.** Standard Array suggestion'ı (s. 21) gösterilmiyor. |
| Origin: background | Background step | **Kısmi.** Optional; SRD'de zorunlu. Origin feat (`origin_feat_ref`) seçimi gerekmiyor — sadece seed'e kopyalanıyor. |
| Origin: species + traits | Race/Species step | **Var ama yüzeysel.** Size & Speed otomatik düşmüyor (combat_stats seed'de `speed: '30 ft'` sabit). Lineage/sub-race seçimi yok. |
| Origin: 2 language | Yok | **Eksik.** Şemada `granted_language_count` ve `language_refs` var, UI hiç sormuyor. |
| Skill proficiency seçimi (class + background) | Yok | **Eksik.** Class şemada `skill_proficiency_choice_count` + `skill_proficiency_options` tanımlı, background `granted_skill_refs` veriyor. Wizard hiç seçim sormuyor; resolver muhtemelen "all options" kabul ediyor. |
| Tool proficiency seçimi | Yok | **Eksik.** `tool_proficiency_count` / `tool_proficiency_options` tanımlı, UI yok. |
| Origin feat seçimi (background veriyor) | Yok | **Eksik.** Wizard `featIds`'e background'ın `origin_feat_ref`'ini implicit ekliyor. Feat'in alt seçimleri (Magic Initiate: hangi cantrip/spell? Skilled: hangi skill?) için `originFeatChoices` field'ı var ama UI yok. |
| Ability Scores generation | Abilities step | **Yerinde.** 4 yöntem mevcut. Eksik: Standard Array by Class önerisi (SRD s. 21), point-buy budget validasyonu zaten var. |
| Background ASI (2024 SRD: +2/+1 veya +1/+1/+1) | "Racial" dropdown (per ability +0..+3) | **Yanlış adlandırma + zayıf validasyon.** 2024'te ASI background'tan geliyor, "Racial" değil. Toplam +3 sınırını UI zorlamıyor; kullanıcı 6×+3=+18 yazabilir. |
| Alignment | Identity step dropdown | **Var.** |
| Fill in Details: passive perception, init, AC, atk bonus, spell DC | `_buildSeedFields` hesaplıyor | **Kısmi.** Hesap var, ama UI bunları wizard'da göstermiyor. Review step'te sadece ability scores listeleniyor. |
| HP: level 1 by class | `_buildSeedFields:391` (`hitDie + conMod`) | **Var.** Fakat HP method (fixed/rolled) seçimi yok. |
| Class features auto-record | `subclass_step.dart` içine gömülü preview tablo | **Kısmi.** Seçim gerektiren feature'lar (Fighting Style, Sorcerous Origin spell list) sorulmuyor. |
| Spellcasting setup: cantrips + prepared spells | Yok | **Eksik (kritik).** Şema `cantrips_known_by_level`, `prepared_spells_by_level` veriyor, wizard hiç sormuyor. Spellcaster bir Wizard yaratıp boş spell listesiyle bitiriyor. |
| Starting Equipment item list → inventory | Equipment step | **Kısmi.** Seçim doğru, ama seçilen item'lar PC inventory'sine yazılmıyor; sadece `equipment_choices` map'inde tutuluyor. Gold alternatifi `gold_gp` görünür ama coin'e dönüştürülmüyor. |
| Trinket (d100 roll) | Yok | **Eksik (opsiyonel).** Lezzet, kolay eklenebilir. |
| Personality: Traits/Ideals/Bonds/Flaws + 7 backstory sorusu | Yok | **Eksik.** SRD s. 20 "Imagine Your Past and Present" — RP omurgası. |
| Starting at Higher Levels: ek gold + magic items | Yok | **Eksik.** Wizard level > 1 seçildiğinde sadece daha çok HP hesaplıyor. SRD s. 24 tablosu uygulanmıyor (örn. L5: 500 GP + 1d10×25 + 1 Common + 1 Uncommon magic item). |
| Multiclass desteği | Yok | **Eksik.** Wizard tek class. SRD s. 24–26 prereq + HP + slot tablosu gerekecek. |
| Subclass timing (Cleric L1, Wizard L2, Fighter L3 vb.) | Subclass step her zaman gösteriliyor | **Hata.** SRD'de subclass class'ın belirttiği seviyede alınıyor. Şu an Fighter L1 karakteri Champion seçmeye zorlanıyor (level <granted_at_level seçimi mantıksız). |

### 2.4 Detaylı Sorunlar

#### 2.4.1 "Racial bonus" UI'ı
Mevcut `_AbilityRow` (`character_creation_wizard_screen.dart:1014-1027`):
her ability için `0..3` dropdown'u. Toplamı sınırlayan global validator yok.
Yardım yazısı `_RacialBonusHint:966-971` "distribute +3" diyor ama UI bunu
zorlamıyor.

**Etki:** Kullanıcı tüm ability'lere +3 verebilir → +18 net buff, hiçbir
hata mesajı yok. Seed'e direkt giriyor.

**Çözüm:** `racialBonuses` toplam +3'e cap, seçim "+2/+1" veya "+1/+1/+1"
moduyla; "2 ability'ye +2 verme" gibi kuralları görsel olarak hatırlat.

#### 2.4.2 Subclass adımı her zaman gösteriliyor
`character_creation_wizard_screen.dart:224-230` koşulsuz `SubclassStep`.
SubclassStep içinde altsınıf eşleşmesi bulunamazsa "No subclasses available"
gösteriyor — fakat *bulunsa bile* level granted_at_level'in altındaysa
seçim mantıksız (oyuncuya henüz açık değil).

**Çözüm:** Eğer `draft.level < class.subclass_granted_at_level` ise step'i
"locked" duruma getir: "Bu sınıfın altsınıfı seviye 3'te seçilir. Karakter
seviye 3'e çıkınca açılır." mesajıyla.

#### 2.4.3 Equipment seçimi inventory'ye akmıyor
`EquipmentStep` sadece `equipment_choices` map'i (`{group_id: option_id}`)
yazıyor. Karakter editörü bu map'i okuyup gerçek item'ları PC'nin envanterine
koymuyor (`combat_stats` veya bir inventory field yok). Sonuç: oyuncu wizard'da
"Greataxe + Handaxes" seçiyor, editörde envanter boş.

**Çözüm:** Commit sırasında seçili option'ın `items[]` listesini PC entity'sinin
`equipment_refs` (var ise) veya yeni bir `starting_inventory` field'ına
expansion ile yaz. Coin tarafı için `gold_gp` → `coin_purse` (gp).

#### 2.4.4 Spellcaster akışı yok
Class şemada `caster_kind`, `casting_ability_ref`, `cantrips_known_by_level`
mevcut. Wizard tarafında hiçbir spell adımı yok. Wizard, Sorcerer, Cleric vs.
hepsi tamamen boş spell listesiyle başlıyor. Oyuncu editörde manuel ekleyene
kadar büyü yapamaz.

**Çözüm:** Class step'in ardına (subclass'tan sonra) koşullu **Spells** step
ekle:
- `caster_kind != 'None'` ise göster.
- L1'de `cantrips_known_by_level[1]` adet cantrip seç.
- `prepared_spells_by_level[1]` adet (varsa) L1 spell seç (filter:
  `class_refs`).
- Pact Magic (Warlock) için ayrıca slot/known eğrisi.

---

## 3. Level Advancement — SRD vs Mevcut

### 3.1 SRD Level-up 5 Adımı (s. 23)

```
1. Choose a Class                (multiclass durumu)
2. Adjust HP & Hit Dice          (fixed value veya 1 hit die roll + CON; min 1)
3. Record New Class Features     (yeni feature'lar, choice varsa seç)
4. Adjust Proficiency Bonus      (5/9/13/17. seviyede +1)
5. Adjust Ability Modifiers      (Feat/ASI L4, 8, 12, 16, 19; CON artarsa
                                  geçmiş seviyeler retroaktif HP +1/level)
```

Ek kurallar:
- **XP tablosu** (s. 23): L1→0, L2→300, L3→900, … L20→355,000.
- **Tier of Play** (s. 23–24): 1–4, 5–10, 11–16, 17–20.
- **Extra Attack**: class verisinde gömülü ama level'a bağlı bir feature.
- **Spellcasting upgrade**: slots/cantrips/prepared spell sayısı tablosu.

### 3.2 Mevcut Davranış

[character_editor_screen.dart](../flutter_app/lib/presentation/screens/characters/character_editor_screen.dart) `level` field'ı
generic `FieldWidgetFactory` üzerinden render ediliyor (number input). Kullanıcı
3'ten 4'e çıkardığında:

- `level` field'ı güncelleniyor (autosave 1.2 sn sonra disk'e yazıyor).
- `class_levels` map'i — eğer şemada varsa — wizard tarafından L1 değeriyle
  set edildi; editörde güncellenmiyor.
- `_renderLevelUpTable` (s. 670–708) sadece read-only preview gösteriyor.
- HP/PB/HD/feature, hiçbiri hesaplanmıyor.
- Toast/banner/dialog yok.

### 3.3 Kritik Eksikler

| SRD Adımı | Mevcut Davranış | Eksik |
|---|---|---|
| 1. Choose class | Tek class, sabit | Multiclass akışı; prereq validation. |
| 2. Adjust HP & HD | Hiçbir şey | Fixed/Rolled toggle; HP yeni değeri; hit_dice_total artımı. |
| 3. New features | Pasif preview | "Şu feature'ı kazandın" bildirim; choice gerektiriyorsa modal (Fighting Style, subclass-grant level vb.). |
| 4. PB adjust | Yok | `proficiency_bonus` field auto-update; PB'ye bağlı tüm türetilmiş alanlar (skill mod, save mod, spell DC, atk bonus) re-derive. |
| 5. ASI/Feat | Yok | L4, 8, 12, 16, 19'da modal: "+2 single / +1+1 / Feat". Feat seçildiyse feat seçici + choice gruplar. |
| XP | Field yok / 0 sabit | XP track, threshold geçildiğinde "Level Up!" prompt. |
| CON+1 retro HP | Yok | CON artışında geçmiş seviyelerin HP'sini +1/level retroaktif düzelt. |
| Spell slot update | Yok | Caster için `spell_slots_by_level[newLevel]` farkını uygula. |

### 3.4 Editör UX Eksikleri

- "Hit Dice" track yok (kısa dinlenmede HD harcamak için gerekli).
- Class resources (Rage, Bardic Inspiration, Channel Divinity, Ki) yok.
- Spell slot tracker yok.
- "What's New" log yok — geçmiş level-up'larda neler kazanıldığını
  hatırlamak için faydalı.

---

## 4. Önerilen Yol Haritası

### Sprint A — Wizard'ı SRD'ye Hizalama

| # | İş | Etki | Tahmini Maliyet |
|---|---|---|---|
| A1 | Skill/Tool/Language seçim adımları (class + background birleşimi) | Yüksek | Orta |
| A2 | Subclass step'ini level-gate et (`granted_at_level` kontrolü) | Yüksek | Düşük |
| A3 | Spells step (caster_kind != None) — cantrip + L1 prepared/known seçimi | Yüksek | Orta-Yüksek |
| A4 | Origin Feat alt-seçimleri için UI (Magic Initiate, Skilled, vb.) | Yüksek | Orta |
| A5 | Ability racial bonus widget'ını **+3 total cap** + 2024 SRD presetlerine (+2/+1, +1/+1/+1) bağla; etiketi "Background ASI" yap | Orta | Düşük |
| A6 | Speed & Size'ı species'ten otomatik türet, `combat_stats`'a yansıt | Orta | Düşük |
| A7 | Equipment commit sırasında seçili `items[]`'ı PC envanterine yaz, `gold_gp` → coin field | Yüksek | Orta |
| A8 | Personality step: Traits/Ideals/Bonds/Flaws + 7 backstory sorusu (background'ın `personality_traits` / `ideals` / `bonds` / `flaws` field'ı varsa pre-fill; yoksa serbest text) | Orta | Düşük |
| A9 | Trinket step (opsiyonel d100 roll) | Düşük | Düşük |
| A10 | Review step'i: hesaplanmış passive perception, AC, init, atk bonus, spell DC tabloları ile zenginleştir | Orta | Düşük |
| A11 | Starting at Higher Levels: level > 1 seçildiğinde SRD s. 24 tablosuna göre ek gold + magic item önerisi göster | Düşük | Orta |

### Sprint B — Etkileşimli Level-Up Akışı

Yeni bir **Level-Up Wizard** akışı (modal/full-screen, karakter editöründen
"Level Up" butonuyla tetiklenir):

| Adım | İçerik |
|---|---|
| 1. Class seçimi | Mevcut class'a 1 level ekle (default) veya multiclass için class picker (prereq kontrol). |
| 2. HP rolü | Toggle: "Fixed value" (class.hit_die'in average+1, örn. d10 → 6) veya "Roll 1dX + CON" (in-app dice + manuel sonuç). Min 1 zorlamasını uygula. |
| 3. Yeni feature'lar | Class+subclass'tan `features[level]` listele. Her feature için: bilgi kartı + (varsa) choice picker (Fighting Style, Maneuver, Metamagic, Druid Circle spell preset vb.). |
| 4. PB adjust | Bilgi: "Proficiency Bonus +X → +Y (no change)" veya "+X → +X+1". |
| 5. ASI/Feat (4,8,12,16,19) | 3 chip: "+2 to one ability" / "+1 to two abilities" / "Feat". Feat seçildiyse feat listesi + choice modalı. |
| 6. Spellcaster güncellemesi | Yeni cantrip (varsa), yeni prepared/known spell (sayı diff), yeni slot seviyesi bildirimi. |
| 7. Özet | "Şunları kazandın: +8 HP, +1 Hit Die (d10), Action Surge (1/SR), 3. seviye spell slotu (×2)". |

**Mutation pipeline:**
- Tek `LevelUpCommit` payload'ı: `levelChange`, `hpDelta`, `hdDelta`,
  `pbDelta`, `featuresGranted`, `asiOrFeat`, `spellsLearned`,
  `spellSlotChanges`.
- `CharacterRepo`'da idempotent uygulama (aynı commit iki kez uygulanmaz —
  history log).

### Sprint C — Editör Görselleştirmesi

| # | İş |
|---|---|
| C1 | App bar'da "Level Up" CTA butonu (XP threshold geçildiyse veya manuel) |
| C2 | XP track field + ilerleme barı (next-level threshold gösterimi, SRD s. 23 tablosu) |
| C3 | "Class Resources" panel: Rage, Bardic Inspiration, Channel Divinity, Ki, Sorcery Points (class şemasından türet, level'a bağlı limit) |
| C4 | Spell Slot tracker (level → max → used) |
| C5 | Hit Dice tracker (current/max, kısa dinlenme harcama UI'ı) |
| C6 | "Recent Gains" timeline — her level-up commit'in özetini sakla (`character.entity.fields['level_up_history']: []`) |
| C7 | Subclass timing rozeti: "Subclass selection unlocks at level 3" gibi (class L < granted_at_level ise) |
| C8 | Tier of Play badge'i (T1/T2/T3/T4, SRD s. 23–24) header'a |

### Sprint D — Multiclass (Geri Plana Alınabilir)

SRD s. 24–26. Önce A+B+C tamamlanmalı; multiclass cross-cut bir çok hesabı
karmaşıklaştırır (Spell Slot tablosu farklı, PB combined level üzerinden,
Extra Attack stack etmez vb.).

---

## 5. Veri/Şema Tarafı Notları

Çoğu eksik UI tarafında — şema yeterli:

- ✅ `class.skill_proficiency_choice_count`, `skill_proficiency_options`
- ✅ `class.tool_proficiency_count`, `tool_proficiency_options`
- ✅ `class.caster_kind`, `casting_ability_ref`, `*_by_level` tabloları
- ✅ `class.features` (per-level list, choice support için
  `classFeatures` field tipinde encode edildi)
- ✅ `subclass.granted_at_level`, `subclass.features`
- ✅ `background.granted_skill_refs`, `granted_language_count`,
  `origin_feat_ref`
- ✅ `feat.effects` (typed DSL)
- ✅ `class.multiclass_prereq_*`

**Eklenecekler:**

| Alan | Konum | Amaç |
|---|---|---|
| `asi_or_feat_levels: List<int>` | class | Yapay zekâ değil — hesaplamayı kolaylaştırmak için açık liste (default `[4, 8, 12, 16, 19]`). |
| `extra_attack_at: List<int>` | class | Fighter L11, L20 stack'i için. |
| `subclass_choice_level: int` | class | Mevcut `granted_at_level` subclass tarafında; class tarafına da aynası gerekli (UI gating için). |
| `hp_fixed_value: int` | class | Hit die average+1 (d6→4, d8→5, d10→6, d12→7). Şu an UI tarafında hesaplanıyor; data'ya taşımak şüpheyi kaldırır. |
| `personality_traits / ideals / bonds / flaws: List<String>` | background | SRD §1 details adımına Random tablo desteği için. |
| `lineage_choice` | species | Half-Elf vs. Elf alt-lineage'leri için (gelecek). |
| `inventory_items: List<{ref, qty}>` veya `starting_inventory: List` | player-character kategori | Equipment step seçimini envantere yazmak için. |
| `coin_purse: {gp, sp, cp, ...}` | player-character | Equipment gold alternatifi + lifestyle. |
| `xp: int` | player-character | Şu an `combat_stats.xp` var ama PC seviye için generic field daha temiz. |
| `hit_dice_remaining: int` | player-character | Kısa dinlenme tracker. |
| `level_up_history: List<{level, summary, timestamp}>` | player-character | Sprint C C6. |

---

## 6. Risk ve Bağımlılıklar

- **Veri-driven feature choices.** Class feature'larının çoğu "şunu seç"
  istiyor (Fighting Style, Metamagic, Maneuver, Eldritch Invocation,
  Patron Boon). Bunlar zaten `classFeatures` field tipinde mi? Eğer choice
  payload'ı tanımlanmadıysa Sprint B Adım 3 zayıf düşer. Önce SRD core
  pack'teki class entity dosyalarını incelemek gerek.
- **Resolver dokunuşu.** `CharacterResolver` muhtemelen wizard
  seçimlerinden bazılarını (skills, languages, vb.) "all options" varsayıyor.
  Sprint A'dan önce resolver davranışı doğrulanmalı (test coverage).
- **Migration.** Mevcut karakterlerde yeni field'lar (xp, hit_dice_remaining,
  level_up_history) yok. Editör read sırasında default'larla doldurmalı,
  yeni karakterler seed'de.
- **Eski karakterleri ASI/feat retroaktif uygulamak istemiyoruz.** Level-up
  wizard sadece *ileri* commit'leri yönetsin; geçmiş level'lar olduğu gibi
  bırakılsın.
- **i18n.** Wizard ve level-up dialog metinleri TR/EN/DE/FR — yeni
  step'ler için strings güncellenmeli ([app_localizations.dart](../flutter_app/lib/presentation/l10n/)).

---

## 7. Önerilen Sıralama

1. **A2** (Subclass level-gate) — küçük, görünür, hızlı kazanç.
2. **A5** (Ability racial bonus düzeltmesi) — yanlış davranıştan kurtul.
3. **A1** (Skill/Tool/Language step'leri) — en yüksek SRD uyum kazancı.
4. **A7** (Equipment → inventory) — şu an oyuncu wizard sonunda envantersiz.
5. **A3** (Spells step) — spellcaster oynanabilir hale gelsin.
6. **C2 + C1** (XP track + Level Up CTA) — Sprint B'ye giriş kapısı.
7. **Sprint B** (Level-Up Wizard) — sırasıyla B1→B7.
8. **A4, A8, A9, A10, A11** — polish.
9. **C3–C7** (Tracker'lar) — uzun vadeli oynanabilirlik.
10. **Sprint D** (Multiclass) — opsiyonel.

İlk PR önerisi: **A2 + A5** birleştirilebilir (UI-only, schema değişikliği
yok, resolver dokunmadan ve test başına eklenebilir).
