# Content Export — Aktarım Süreci

Kaynak (PDF + medya) → `assets/worlds/<dir>/` → `.pkg.json`.
Bu dosya **süreci** anlatır. Alan sözleşmeleri ayrı:
[world-blueprint.md](world-blueprint.md) (Tier-2 entity alanları),
[character-blueprint.md](character-blueprint.md) (PC alanları),
[WORLD_CONTENT_ORDER.md](WORLD_CONTENT_ORDER.md) (ekleme sırası + Tier kuralları).

## 0. Değişmez kural: eksiksiz ve değiştirilmemiş

Kaynaktaki **her cümle** dünyaya girer. Özetleme, yeniden yazma, "kendi
cümlelerinle anlat" **yok** — metin birebir taşınır, sadece markdown biçimi ve
entity link'i eklenir.

Bu kuralın gerekçesi somut: bu depodaki ilk 99 Devils aktarımı `--check`'ten
temiz geçmişti ama PDF metninin **%0**'ını içeriyordu; anlatı katmanı baştan
sona uydurulmuştu (PDF'te olmayan mekanlar, yanlış tür/rol verilen NPC'ler).
`--check` şema ve referans doğrular, **içerik sadakatini doğrulamaz**. O yüzden
adım 5'teki kapsam denetimi zorunludur.

Uydurma yasağı: kaynakta olmayan mekan/NPC/olay **ekleme**. Kaynak bir alanı
(ör. `danger_level`) söylemiyorsa alanı boş bırak, tahmin etme.

## 1. Metni çıkar

```bash
pdftotext -enc UTF-8 adventure.pdf source.txt      # okuma sırası — DOĞRU
```

`-layout` **kullanma**: iki sütunlu sayfalarda stat block'ları cümlelerin
ortasına sokar. `-enc UTF-8` şart, yoksa çıktı bozuk kodlanır.

Görsel sayfalar (handout, el yazması, harita üstü yazı) `pdftotext`'e düşmez —
sayfayı **görsel olarak oku** ve metni elle transkript et. Bunları atlamak
kapsam denetiminde görünmez, çünkü kaynak metinde de yoklar; sayfa sayfa
kontrol et.

## 2. Kategorilere böl

Eşleme tablosu: [world-blueprint.md § 6.1](world-blueprint.md).
Kabaca: numaralı oda/alan → `location` (**başlığı PDF'te yazdığı gibi**,
`"14. Hall of Discoveries"`), anlatı akışı → `scene`, el yazması → `lore`,
kural kutusu → `trap` / `environmental-effect`, giriş+arka plan+lisans →
`campaign.pages`.

Stat block'lar: SRD'de birebir aynı isimle varsa referans ver, yoksa entity
oluştur; **stat block metnini ayrıca `traits_md`'ye birebir yapıştır** —
kaynak sistem (Shadowdark, OSR…) 5e alanlarına birebir oturmaz, sayı uydurmak
yerine ham blok korunur.

## 3. Blueprint'i yaz

Sıra ve bağımlılıklar: [WORLD_CONTENT_ORDER.md](WORLD_CONTENT_ORDER.md).

1. **Önce entity, sonra referans** — referans verilecek her şey önce kendi
   kategorisinde entity olmalı. Ne SRD'de ne blueprint'te olan isim build'i kırar.
2. **Ref zarfı** — `{"lookup": "<hedef kategori>", "match": "name", "value": "<ad>"}`.
   `lookup` **hedefin** slug'ı. `{"slug": ..., "name": ...}` yazımı hatadır.
3. **Hedef kategori alanla uyuşmalı** — şema her relation alanı için izinli
   kategorileri belirtir (`encounter.monsters_refs` → `monster`/`animal`; oraya
   `npc` koyarsan satır düşer). Uymuyorsa **alanı değiştir**, entity'yi zorlama.
4. **Alan adları şemadan gelir** — şemada olmayan anahtar sessizce kaybolur
   (`spells_known` ✓ / `spell_refs` ✗ PC'de).
5. **Serbest metin listenin yerine geçmez** — `equipment_md` kaynağı korur ama
   listeyi doldurmaz; aynı içerik **ayrıca** `*_refs` olarak bağlanmalı.
6. **PC'ler `blueprint.json`'a** — world entity'si değil; `world-blueprint.json`'a
   yazılan PC hiçbir ekranda görünmez.
7. **Lookup değerleri seed listesinden** — `Dim` (`Dim Light` değil), `Neutral`
   (alignment) / `Indifferent` (attitude), `Trivial|Low|Moderate|High|Deadly`.
8. **Medya** — yollar modül dizinine relative **ve** `manifest.json` → `files`
   içinde listeli olmalı; installer sadece orada listelenenleri diske çıkarır.

## 4. Entity link'i bırak (uygulamanın kazancı)

Bir metin başka bir entity'den bahsediyorsa link bırak:

```json
"description_long": "Kapıyı @[Rafiq al-Sayyid](entity:npc/Rafiq al-Sayyid) açar."
```

Biçim `@[Görünen Ad](entity:<kategori-slug>/<Entity Adı>)`; converter bunu entity
id'sine çevirir, uygulamada tıklanabilir olur. Hedef **aynı blueprint'te** tanımlı
olmalı, yoksa build hata verir (SRD/Tier-0 satırlarına link verilemez — id'leri
başka namespace'ten gelir). Hem `world-blueprint.json` hem `blueprint.json` için
geçerli. İlk anlamlı geçişte link ver, her tekrarında değil.

## 5. Doğrula — ikisi de zorunlu

```bash
cd flutter_app
# a) şema + referans + medya
dart run tool/content/convert_blueprint.dart --dir assets/worlds/<dir> --check
# b) içerik sadakati
python tool/content/audit_coverage.py source.txt assets/worlds/<dir>
```

(a) tek çözülemeyen ref / şema dışı alan / eksik medyada non-zero döner ve hangi
entity'nin hangi alanı bozuk yazar.

(b) kaynağın her cümlesini blueprint metninde arar, eşiğin altındakileri listeler.
**Hedef %95+.** Kalan her satırı tek tek `grep`le doğrula — normal kalıntılar:
iki sütunlu sayfa başlıkları, ham stat sayı satırları (`16 +3 9 -1 …`), link
sınırına denk gelen kelimeler. Bunların dışında bir şey listeleniyorsa o metin
gerçekten aktarılmamıştır. (Referans: eski hatalı aktarım %0.0, düzeltilmiş
aktarım %97.7 verir.)

CI: `test/domain/services/bundled_worlds_blueprint_test.dart` (a)'yı
`assets/worlds/` altındaki her dünya için tekrarlar.

Temiz `--check` + %95 kapsam alınmadan aktarım bitmiş sayılmaz.

## 6. Paketle

```bash
dart run tool/content/convert_blueprint.dart --dir assets/worlds/<dir>   # → <slug>.pkg.json
```

`pubspec.yaml` → `assets/worlds/` deklarasyonunu ve `manifest.json` → `files`
listesini güncellemeyi unutma.

## Kontrol listesi

- [ ] `pdftotext -enc UTF-8` (layout'suz) + görsel sayfalar elle transkript
- [ ] Her entity'de `source` dolu
- [ ] Numaralı alanlar PDF'teki adıyla, hiyerarşi `parent_location_ref` ile kurulu
- [ ] SRD'de olan içerik tekrar yazılmadı, referans verildi
- [ ] Bahsedilen entity'lere `@[...](entity:slug/Ad)` link'i bırakıldı
- [ ] `--check` temiz
- [ ] `audit_coverage.py` %95+ ve kalan satırlar tek tek doğrulandı
