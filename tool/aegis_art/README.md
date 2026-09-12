# Aegis Art Pipeline

Aegis dünyasının bütün kartları (**146 entity, 16 kategori**) için D&D 5e tarzı
yağlı boya görsel üretir. Girdi `world-blueprint.json`, çıktı
`aegis-act1/media/Artwork/` altına kopyalanan `.webp` dosyaları.

İki ayrı kol var:

| Kol | Ne üretir | Job dosyası | Çıktı |
|---|---|---|---|
| **Kart görseli** | Kartın kendi resmi — sahnenin *eli* | `art_jobs_final.jsonl` (146) | `out/{uuid}.webp` |
| **Arka plan (BG)** | Aynı sahnenin **boş odası**: bir adım geri, ana nesne yok, orta kare sakin — üstüne kart metni basılabilsin diye | `art_bg_jobs.jsonl` (38: lore + location) | `out_bg/{uuid}.webp` |

---

## 0. Ön koşullar

```bash
python3 --version          # 3.10+
python3 -c "import PIL"    # Pillow — webp yazımı ve karşılaştırma gridi için
```

- **ComfyUI** ağda erişilebilir olmalı. Varsayılan host `http://192.168.1.12:8188`,
  `--host` ile değiştirilir. Kontrol:

  ```bash
  curl -s http://192.168.1.12:8188/system_stats | head -c 200
  ```

- Sunucuda **Z-Image-Turbo** dosyaları (varsayılan): `z_image_turbo_bf16.safetensors`,
  `qwen_3_4b.safetensors`, `ae.safetensors`. Flux'a geçmek için
  `--loader checkpoint --ckpt flux1-schnell-fp8.safetensors`.
- **`GEMINI_API_KEY`** yalnızca 2. adım (subject cache) için gerekir. Cache dosyası
  zaten repoda; normal akışta bu adımı çalıştırmana gerek yok.

---

## 1. Pipeline — beş aşama

```
world-blueprint.json
   │  aegis_prompts.py          ham konu cümleleri
   ▼
art_jobs.jsonl
   │  aegis_subject_gen.py      Gemini ile zengin görsel betimleme
   ▼                            (aegis_subject_cache.json)
   │  aegis_merge.py            ikisini birleştir
   ▼
art_jobs_final.orig.jsonl       ← elle düzeltmelerin KAYNAĞI
   │  aegis_polish.py           kart başına ışık + çerçeveleme + düzeltilmiş konular
   ▼
art_jobs_final.jsonl
   │  aegis_generate.py         ComfyUI
   ▼
out/{uuid}.webp
   │  aegis_integrate.py        blueprint + manifest + media/Artwork
   ▼
uygulamaya giren dünya
```

| Script | Girdi | Çıktı |
|---|---|---|
| `aegis_prompts.py` | `world-blueprint.json` | `art_jobs.jsonl` |
| `aegis_subject_gen.py` | `art_jobs.jsonl` + Gemini API | `aegis_subject_cache.json` |
| `aegis_merge.py` | ikisi | `art_jobs_final.jsonl` |
| `aegis_polish.py` | `art_jobs_final.orig.jsonl` | `art_jobs_final.jsonl` |
| `aegis_generate.py` | `art_jobs_final.jsonl` | `out/{uuid}.webp` |
| `pick.py` | `art_jobs_final.jsonl` + `kategori|ad` | `one.jsonl` (tek kart yeniden üretimi) |
| `aegis_bg.py` | (elle yazılmış tablo) | `art_bg_jobs.jsonl` |
| `aegis_bg_compare.py` | kart + BG görselleri | `compare_*.jpg` |
| `aegis_integrate.py` | `out/` | `media/Artwork/` + blueprint + manifest |

> ⚠️ **`aegis_merge.py` çalıştırırsan `art_jobs_final.jsonl`'i ezer ve
> `aegis_polish.py`'nin bütün elle düzeltmeleri gider.** Merge'den sonra sıra
> her zaman: `merge → cp art_jobs_final.jsonl art_jobs_final.orig.jsonl → polish`.

---

## 2. Sıfırdan tam akış

```bash
cd tool/aegis_art

# Yedek al — jsonl'ler elle düzeltme taşıyor
mkdir -p backup/$(date +%Y%m%d-%H%M%S) && cp *.jsonl $_

# 1) Blueprint → ham job'lar
python3 aegis_prompts.py

# 2) Gemini subject cache (yalnızca blueprint'e yeni kart eklendiyse)
export GEMINI_API_KEY=...
python3 aegis_subject_gen.py                    # eksikleri üretir, cache'i korur

# 3) Birleştir, sonra polish'in kaynağını tazele
python3 aegis_merge.py --self-check
cp art_jobs_final.jsonl art_jobs_final.orig.jsonl

# 4) Elden geçir — asıl kalite buradan geliyor
python3 aegis_polish.py --check                 # doğrula, dosya yazma
python3 aegis_polish.py                         # art_jobs_final.jsonl yaz

# 5) Üret
python3 aegis_generate.py --limit 5 --out out_new   # önce pilot
python3 aegis_generate.py --out out_new             # tamamı (~15 sn/görsel, ~35 dk)

# 6) Uygulamaya al
python3 aegis_integrate.py                      # kuru çalıştır
python3 aegis_integrate.py --apply --check
```

---

## 3. `aegis_polish.py` — prompt'ların asıl yazıldığı yer

Merge'in ürettiği prompt'ta iki yapısal sorun vardı, ikisi de burada çözülüyor:

1. **Işık kategoriye sabitti.** Bütün location'lar *"flat overcast daylight"*,
   bütün NPC'ler *"warm hearth glow"* alıyordu — 146 kartın arka planı
   birbirinin aynı çıkıyordu. Artık ışık/atmosfer **kart başına** yazılır.
2. **Prompt'ta `{isim}, Aegis {kategori}` başlığı vardı.** `Mine` (maden),
   `Fare`, `Kandil` gibi adlar text encoder'da yanlış anlam üretiyordu. Başlık
   kaldırıldı; kimlik zaten jsonl alanlarında.

### Üretilen prompt'un anatomisi

```
{SUBJECT}                                       ← 1. satır: ne çizilecek
{FRAMING}, {LIGHT}, [{ERA}], {DND}, {FULL_BLEED}, {STYLE}, {TAIL}, {flavor}
```

| Parça | Nereden gelir |
|---|---|
| `SUBJECT` | `SUBJECT` sözlüğünde varsa oradan, yoksa `.orig.jsonl`'in 1. satırı |
| `FRAMING` | `FRAMING` (kart özel) → `FRAMING_BY_CATEGORY` (kategori) |
| `LIGHT` | `LIGHT` sözlüğü — 146/146 kart elle yazılmış |
| `ERA` | Yalnızca çevre gören kategorilerde (`ERA_CATEGORIES`) — anakronizm freni |
| `flavor` | uuid'den deterministik seçilir, fırça çeşitliliği için |

Anahtar biçimi her zaman **`kategori|ad`** (`location|Votumar`). Ad birden fazla
kategoride geçebiliyor (`Sayım` hem trait hem creature-action), o yüzden ikili.
Yanlış yazılmış anahtar sessizce yutulmaz — script hata verip durur:

```bash
python3 aegis_polish.py --check
# HATA: karsiligi olmayan anahtar(lar):
#   location|Votumar Kalesi
```

### Tek kartı düzeltme tarifi

```bash
# 1) Mevcut prompt'u gör
python3 aegis_polish.py --show "location|Votumar"

# 2) aegis_polish.py içinde SUBJECT ve/veya LIGHT sözlüğünü düzenle

# 3) Doğrula ve yaz
python3 aegis_polish.py --check && python3 aegis_polish.py

# 4) Kartı ayır — eski görselini de siler
python3 pick.py "location|Votumar"

# 5) Yeniden üret
python3 aegis_generate.py --jobs one.jsonl --out out_new
```

`pick.py` birden fazla anahtar alır ve yanlış yazılmış anahtarda hata verir:

```bash
python3 pick.py "npc|Mine" "scene|Susan Kule" "location|Rıhtım"
python3 pick.py "location|Votumar" --keep          # görseli silme
python3 pick.py "location|Votumar" --out-dir out   # başka çıktı klasörü
```

---

## 4. `aegis_generate.py` — üretim

`out/` içinde dosyası olan job **atlanır**, yani kesilirse kaldığı yerden devam
eder. Bir kartı yeniden üretmek istiyorsan önce `.webp`'sini sil.

```bash
python3 aegis_generate.py                                   # tamamı → out/
python3 aegis_generate.py --out out_new                     # başka klasöre
python3 aegis_generate.py --limit 5                         # pilot
python3 aegis_generate.py --categories npc,monster          # kategori filtresi
python3 aegis_generate.py --every 10                        # her 10'uncu job (çeşitlilik taraması)
python3 aegis_generate.py --host http://192.168.1.12:8188   # başka sunucu
python3 aegis_generate.py --size 1024 --quality 82 --crop 0.05
python3 aegis_generate.py --loader checkpoint --ckpt flux1-schnell-fp8.safetensors
```

Uzun süreceği için oturumdan bağımsız çalıştır:

```bash
nohup python3 aegis_generate.py --out out_new > gen_new.log 2>&1 &
tail -f gen_new.log
ls out_new | wc -l
```

Eksik/hatalı kalanı bulmak:

```bash
python3 -c "
import json, os
have = {f[:-5] for f in os.listdir('out_new')}
for l in open('art_jobs_final.jsonl'):
    d = json.loads(l)
    if d['uuid'] not in have:
        print('EKSIK:', d['category'], '|', d['name'], d['uuid'])
"
```

**Sampler notu:** `cfg = 1.0` ve negatif prompt boş — yani **negatif prompt
çalışmıyor.** İstemediğin şeyi "no X" diye yazma, ters teper; onun yerine
istediğini olumlu ve somut yaz (*"no crane anywhere"* değil, *"every load moved
by hand"*). Aynı sebeple `--crop 0.05` var: model köşeye sahte filigran koyma
eğiliminde, kırpmak tek deterministik çözüm.

---

## 5. Arka plan kolu (BG)

BG prompt'ları Gemini'den gelmez; `aegis_bg.py` içindeki `BG_BY_CATEGORY`
tablosunda **elle** yazılıdır (şu an lore + location = 38 kart).

```bash
python3 aegis_bg.py --sample 2                  # örnek bas, yazma
python3 aegis_bg.py --categories lore           # filtre
python3 aegis_bg.py                             # art_bg_jobs.jsonl yaz

python3 aegis_generate.py --jobs art_bg_jobs.jsonl --out out_bg
```

### `ref/` — referansa sadık BG

`ref/<kart adı>.<uzantı>` varsa (`ref/Votumar.jpg`, `ref/Lucid-Triton.jpg`) o kart
**img2img** ile üretilir: boş latent yerine referansın latenti kullanılır ve
üstüne `denoise = 0.30` kadar boyanır — kompozisyon referansta kalır, fırça
Aegis stiline döner. Eşleşme kart adına göre yapılır (kesme işareti düşer,
harf/rakam dışı her şey tire olur).

> `ref/` klasörü **yalnızca** bu img2img eşleşmesi için. Kart görseli kolunda
> (`art_jobs_final.jsonl`) kullanılmaz; oraya referans görsel verilmez.

### Kart / BG karşılaştırma gridi

Her sütun bir kart: üstte ad, altında kart görseli, altında BG.

```bash
python3 aegis_bg_compare.py --category lore     --out compare_lore.jpg
python3 aegis_bg_compare.py --category location --out compare_location.jpg --cols 6 --cell 448
```

---

## 6. `aegis_integrate.py` — uygulamaya alma

`out/{uuid}.webp` dosyalarını `aegis-act1/media/Artwork/` altına okunur adlarla
kopyalar, `world-blueprint.json`'daki `imagePath` alanlarını ve `manifest.json`'u
günceller.

> ⚠️ **Kaynak klasör `out/` olarak sabit — `--out` bayrağı yok.** Görselleri
> başka bir klasöre ürettiysen (`out_new/` gibi) entegrasyondan önce yerine koy:
>
> ```bash
> mv out out_eski && mv out_new out
> ```

```bash
python3 aegis_integrate.py                 # kuru çalıştır — hiçbir şey yazmaz
python3 aegis_integrate.py --apply         # uygula
python3 aegis_integrate.py --apply --check # uygula + convert_blueprint --check
```

Elle doğrulama:

```bash
cd ../..   # repo kökü
dart run tool/content/convert_blueprint.dart --dir flutter_app/assets/worlds/aegis/aegis-act1 --check
```

---

## 7. Kategoriler

| Kategori | Adet | Kartın konusu nereden çıkar |
|---|---|---|
| npc | 34 | appearance, mannerisms, species_ref, location_ref |
| lore | 20 | description |
| location | 18 | environment + description_long |
| trait | 15 | benefits, trait_kind |
| creature-action | 12 | description, attack_kind, damage_type_ref |
| scene | 11 | description, beats, location_ref |
| background | 9 | description, granted_skill_refs, granted_tool_refs |
| adventuring-gear | 8 | description, weight_lb, consumable |
| trinket | 7 | description |
| monster | 4 | description, size_ref, creature_type_ref, stat_block |
| quest | 2 | description |
| subclass | 2 | description, features |
| campaign | 1 | description |
| curse | 1 | description, trigger, effect, mechanical_notes |
| encounter | 1 | description, setup, difficulty, location_ref |
| animal | 1 | description, stat_block |

`resource-pool` atlanır — çizilecek bir nesnesi yok (`SKIP_CATEGORIES`).

---

## 8. Stil sözleşmesi

Bütün kartlarda ortak:

- **Yağlı boya**: `hand-painted oil painting on canvas, expressive painterly
  brushstrokes, matte finish`
- **Anti-AI iskeleti**: `digital art`, `concept art`, `render`, `masterpiece`
  gibi kelimeler **yasak** — tetikleyici, görüntüyü plastikleştiriyor.
- **Full-bleed kare**: kenarlık, çerçeve, vinyet yok; sahne dört kenara taşar.
- **Dönem çapası**: çevre gören kartlarda `medieval fantasy world of timber,
  stone, sail and horse`. Bu olmadan model limanlara buharlı gemi ve lokomotif,
  atölyelere çelik kule vinci koyuyor.

Kart başına değişen: **ışık/atmosfer** ve **çerçeveleme**. Aegis'in rengi artık
tek bir palet cümlesinden değil, her kartın kendi ışığından geliyor.

---

## 9. Bilinen tuzaklar

| Tuzak | Sonuç | Çare |
|---|---|---|
| `aegis_merge.py` polish'ten sonra çalıştırılır | Elle yazılmış 146 ışık + 41 konu gider | Merge sonrası `.orig.jsonl`'i tazele, polish'i tekrar çalıştır |
| Prompt'ta olumsuzlama (`no X`, `without X`) | cfg 1.0'da negatif yok; X çizilir | Olumlu ve somut yaz |
| Yakın planda mekanik nesne (vinç, ayna, lamba) | Çelik kule vinci, el aynası, modern masa lambası | Malzemeyi yaz: *"wooden treadwheel crane of oak beams and hemp rope"*, *"clay oil lamp"*, *"polished bronze signal disc on an iron swivel frame"* |
| Kart adı prompt'a girerse | `Mine` → maden ocağı, `Fare` → yol ücreti | Başlık zaten kaldırıldı, geri ekleme |
| Görsel var ama prompt değişti | `generate` o kartı atlar, eski görsel kalır | Önce `.webp`'yi sil |
| Blueprint'e yeni kart eklendi | uuid yeni; cache, jobs ve polish sözlükleri onu bilmez | 1→3 adımları tekrarla, `--check` eksik ışığı zaten uyarır |
