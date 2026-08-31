# Content Export Rehberi

Bu dosya, agent'lar tarafından içerik aktarımı yapılırken kullanılacak yönergedir.

## Genel Kurallar

1. **İçerik değiştirilmez** — Orijinal dosyalar (PDF, görsel, karakter dosyası) aynen paketlenir.
2. **Blueprint'ler oluşturulur** — `manifest.json`, `blueprint.json`, `world-blueprint.json` hazırlanır.
3. **Built-in paket tekrar eklenmez** — SRD 5.2.1'de **birebir aynı isimle** var olan içerik (canavar, sihir, eşya vb.) referans olarak kullanılır, yeniden oluşturulmaz.
4. **Önce entity, sonra referans** — Referans verilecek her şey önce kendi kategorisinde
   bir entity olarak var olmalı. Bir ekipmanı envantere koyacaksan önce `weapon` /
   `armor` / `adventuring-gear` / `magic-item` olarak ekle, sonra `inventory`'ye
   referans ver. Aynı kural trait, feat, spell, language, background için de geçerli.
   SRD'de yoksa ve blueprint'te de yoksa referans **sessizce düşer** — build bunu hata sayar.
5. **Dosya yolları relative** — Tüm referanslar modül dizinine göreceli olmalı.
6. **Medya doğru eşleştirilir** — Battlemap'ler location'a, token'lar encounter'a, handout'lar lore'a bağlanır.
   Her medya yolu `manifest.json`'ın `files` bloğunda listelenmeli; installer yalnız orada
   listelenen dosyaları diske çıkarır ve `image_path`'i mutlak yola çevirir.
7. **Alan adları şemadan gelir** — `mapping` içindeki her anahtar kategori şemasında
   tanımlı olmalı. Şemada olmayan bir anahtar (`spell_refs` yerine `spells_known`,
   `traits` yerine `traits_md`) hiçbir widget tarafından okunmaz; veri sessizce kaybolur.

## Doğrulama — her aktarımdan sonra çalıştır

```bash
cd flutter_app
dart run tool/content/convert_blueprint.dart --dir assets/worlds/<dir> --check
```

Çözülemeyen tek bir ref, şemada olmayan tek bir alan, eksik tek bir medya dosyası
bile **non-zero exit** demektir ve rapor tam olarak hangi entity'nin hangi alanının
bozuk olduğunu yazar. Temiz çıktı alınmadan aktarım bitmiş sayılmaz.
`--check`'i düşürünce aynı komut `.pkg.json` üretir.

`test/domain/services/bundled_worlds_blueprint_test.dart` aynı doğrulamayı
`assets/worlds/` altındaki her dünya için CI'da tekrarlar.

## Aktarım Adımları

### 1. PDF'i Oku ve Anla
- PDF'i open5e veya benzeri araçlarla parse et
- İçeriği kategorilere ayır: canavarlar, mekanlar, encounter'lar,NPC'ler, tuzaklar, öğeler
- Hangi içeriğin SRD'de olduğunu kontrol et

### 2. World Blueprint Oluştur
`world-blueprint.json` dosyasında şu kategorileri doldur:

| Kategori | Ne Zaman Kullanılır |
|---|---|
| `npc` |faction liderleri, mağazacılar, rehberler, önemli karakterler |
| `location` | Mekanlar, binalar, bölgeler (hiyerarşik) |
| `encounter` | Savaş planları, canavar grupları |
| `quest` | Görevler, macera arc'ları |
| `scene` | Senaryo akışı, beat listesi |
| `trap` | Tuzaklar ve mekanikler |
| `environmental-effect` | Çevresel etkiler |
| `lore` | Dünya bilgisi, el yazmaları |
| `campaign` | Genel kampanya notları |

### 3. Karakter Blueprint Oluştur
`blueprint.json` dosyasında PC'leri tanımla.

### 4. Medyayı Eşleştir
- **Battlemap'ler** → `location.map` veya `location.battlemaps`
- **Token/resimler** → `npc.imagePath` veya `encounter.monsters_refs`
- **PDF'ler** → `lore.pdfs` veya `campaign.pdfs`
- **Handout'lar** → `lore.pages` (markdown olarak)

### 5. Kaynak Bilgisi Ekle
Her entity'ye `source` alanını doldur:
```json
"source": "99 Devils of Uzrah's Palace, Shadowdark"
```

### 6. Cross-Referansları Kur
Entity'ler arası ilişkileri `cross_references` dizisinde tanımla.

## Karar Verme Noktaları

Agent olarak şu kararları sen vermelisin:

1. **İçerik eşleme** — PDF'teki bir tablo NPC mi, encounter mı, location mu?
2. **Medya atama** — Bir görsel hangi entity'ye ait?
3. **SRD kontrolü** — Bu canavar zaten SRD'de var mı?
4. **Hiyerarşi** — Location'lar nasıl sıralanmalı?
5. **Açıklama yazımı** — Entity için kısa ve net açıklama

## Blueprint Formatı

Detaylar için:
- [world-blueprint.md](world-blueprint.md) — World entity alanları
- [character-blueprint.md](character-blueprint.md) — PC alanları

## Örnek Eşleme

### World Kategorileri

| PDF İçeriği | Uygulama Kategorisi | Medya | Örnek |
|---|---|---|---|
| Canavar stat block'u | `monster` (SRD'de yoksa) | Token → `encounter.monsters_refs` | "Dodecaphage" |
| Mekan açıklaması + harita | `location` | `map` alanına battlemap | "The Gate Hall" → `media/Maps/Upper-Level.webp` |
| Encounter notları | `encounter` | `monsters_refs` + `trap_refs` | "Gate Hall Ambush" |
| NPC portresi | `npc` | `imagePath` → `media/Tokens/NPC.webp` | "The White Shark of Basra" |
| El yazması metin | `lore` | `pages` (markdown) + `pdfs` | "The History of Uzrah's Palace" |
| Tuzak mekaniği | `trap` | — | "Collapsing Ceiling" |
| Quest açıklaması | `quest` | — | "Reach the Palace" |
| Sahne akışı | `scene` | `beats` (markdown) | "The Efreet's Revelation" |
| Lanet | `curse` | `mechanical_notes` | "Mummy's Rot" |
| Zehir | `poison` | `poison_kind` zorunlu | "Assassin's Blood" |
| Çevre etkisi | `environmental-effect` | `damage_dice` + `effect` | "Efreet's Fire Aura" |
| Kampanya özeti | `campaign` | `pdfs` | "99 Devils of Uzrah's Palace" |

### Karakter Alanları

| PDF İçeriği | Uygulama Alanı | Format |
|---|---|---|
| İsim | `name` | Entity name |
| Irk/Species | `species_ref` | relation→species |
| Sınıf | `class_refs` | relation→class |
| Seviye | `class_levels` | `{classId: level}` |
| Background | `background_ref` | relation→background |
| Hizalama | `alignment_ref` | relation→alignment |
| Yetenek değerleri | `stat_block` | `{STR:16, DEX:14, ...}` |
| Can puanı | `combat_stats.hp/max_hp` | int |
| Zırh sınıfı | `combat_stats.ac` | int |
| Hız | `combat_stats.speed` | text `"30 ft"` |
| Beceriler | `skills` | proficiencyTable |
| Kurtulma taslakları | `saving_throws` | proficiencyTable |
| Eşyalar | `inventory` | relation list → `weapon` / `armor` / `adventuring-gear` / `magic-item` |
| Büyüler | `spells_known` | relation list → `spell` (`spell_refs` **değil**) |
| Yetenekler / özellikler | `trait_refs` | relation list → `trait` |
| Feat'ler | `feats` | relation list → `feat` |
| Alet yetkinlikleri | `tool_proficiencies` | relation list → `tool` |
| Duyular | `senses` | relation list → `sense` |
| Portre | `imagePath` | `media/Tokens/…` |
| Kişilik | `personality_traits` | markdown |
| Geçmiş | `backstory` | markdown |

## Kontrol Listesi

- [ ] Tüm SRD dışı içerik blueprint'e eklendi
- [ ] Medya dosyaları doğru entity'lere atandı
- [ ] `source` alanları dolduruldu
- [ ] Cross-referanslar tutarlı
- [ ] Built-in paket tekrar eklenmedi
- [ ] Location hiyerarşisi doğru kuruldu
- [ ] Encounter'lar doğru canavarlara bağlandı
- [ ] Her referansın hedefi ya SRD'de ya blueprint'te var
- [ ] `--check` temiz çıktı verdi