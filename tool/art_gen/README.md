# art_gen — İçerik Görselleri Üretimi Pipeline'ı

open5e pack'lerindeki ve built-in SRD 5.2.1 pack'indeki entity'lere AI ile görsel
üretir. Her paketin kendi çizim tarzı, her kategorinin kendi renk paleti ve
arkaplanı — ama hepsi D&D estetiğinde ve AI görünümünden uzak.

## Kapsam

`ART_TYPES` ile belirlenir: `monster`, `spell`, `magic-item`, `subclass`,
`feat`, `background`, `subspecies`, `species`. Dışarıda kalanlar
`creature-action` ve `trait` — bunlar bir nesne değil, kural cümlesi.

## Pipeline Adımları

Pipeline beş aşamadan oluşur, her biri bir öncekinin çıktısıyla beslenir:

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. pkg.json Dökümü   ──►  2. Manifest Oluşturma  ──►             │
│  3. Subject Cache      ──►  4. Prompt Listesi       ──►  5. Görsel │
└─────────────────────────────────────────────────────────────────────┘
```

---

### Adım 1 — pkg.json Dökümü

Built-in SRD 5.2.1 pack'i (Dart'ta el yazımı `srd_core`) `.pkg.json` formatına
dökülür. Open5e pack'leri zaten bu formattadır.

```bash
# built-in SRD pack'ini dök (gitignored, yeniden üretilebilir)
(cd flutter_app && dart run tool/srd_art_dump/bin/dump_srd.dart \
  ../tool/art_gen/packs/dnd5e-srd.pkg.json)
```

**Çıktı:** `packs/` altında `.pkg.json` dosyaları. Her dosya:
```json
{
  "package_name": "dnd5e-srd",
  "metadata": { ... },
  "entities": {
    "uuidv5-...": {
      "type": "monster",
      "name": "Aboleth",
      "description": "",
      "attributes": { "size_ref": {...}, "cr": "10", ... }
    }
  }
}
```

---

### Adım 2 — Manifest Oluşturma

Manifest, hangi entity'lerin görsel üretiminin yapılacağını seçen **seçim listesidir**.
`package_grid.py` tarafından üretilir.

#### Sıralama

Manifest sıralaması katmanlıdır:

1. **Paket sırası** — `PACKAGE_ORDER` listesinde tanımlı sabit sırayla:
   `dnd5e-srd`, `open5e-a5e-ag`, `open5e-a5e-ddg`, ... `open5e-wz`.
2. **Tip sırası** — `TYPE_ORDER` listesinde tanımlı sabit sırayla:
   `monster`, `spell`, `magic-item`, `subclass`, `feat`, `background`,
   `subspecies`, `species`.
3. **Entity seçimi** — Her `(paket, tip)` ikilisi için `per_type` (varsayılan 2)
   entity seçilir. Seçim **deterministiktir**: `random.Random(f"{seed}:{pkg}:{type}")`
   ile shuffle yapılır, ilk N tanesi alınır. Aynı seed = aynı seçim.

`generate.py` ise job'ları JSONL dosyasındaki **dosya sırasıyla** işler — yeniden
sıralama yapmaz. Aynı entity her zaman aynı seed'i aldığından (`int(uuid[:8], 16)`)
aynı görseli üretir.

#### Üretim

```bash
# Seçimi gör (üretim yapmadan)
python3 tool/art_gen/package_grid.py --dry-run

# Tüm paketler için manifest + grid üret
python3 tool/art_gen/package_grid.py --variant pkg

# Belirli paketler
python3 tool/art_gen/package_grid.py --variant v1 --packages dnd5e-srd,open5e-tob3

# Farklı seed ile farklı örnekler
python3 tool/art_gen/package_grid.py --variant v2 --seed 5678
```

**Çıktı:** `grids/<variant>_s<seed>/manifest.json` — JSON array:
```json
[
  {"package": "dnd5e-srd", "type": "monster", "name": "Aboleth", "uuid": "...", "seed": 12345},
  {"package": "dnd5e-srd", "type": "spell",   "name": "Fireball", "uuid": "...", "seed": 12345}
]
```

Aynı zamanda `grids/<variant>_s<seed>/<package>.png` grid resimleri üretilir.

---

### Adım 3 — Subject Cache Oluşturma

Difüzyon modeli entity'leri (örn. Aboleth, Gnoll) "bilmiyor". Pack'teki kural/lore
metni de görselleştirilemez. `subject_gen.py` her entity için **LLM'e kısa, salt
görsel bir "subject" cümleciği** yazdırır ve `subject_cache.json`'a kaydeder.

#### Akış

1. **Manifest veya tüm pack'ler** — `--manifest` ile bir grid manifest'i, `--uuids`
   ile bir uuid listesi, veya varsayılan olarak tüm pack'lerdeki entity'ler.
2. **Incremental** — Mevcut `subject_cache.json` yüklenir; yalnızca önbekte
   olmayan uuid'ler işlenir (`--force` ile hepsi yeniden üretilir).
3. **LLM çağrısı** — Her entity için `prompts.py`'nin `build_prompt` ile aynı
   girdiyi üretir (`entity_input()`), LLM system prompt'uyla sarmalar, sunucudaki
   opencode'a (mimo-v2.5-free, high variant) SSH ile gönderir. 4 paralel worker.
4. **Doğrulama** — Çıktı 8-120 kelime olmalı, red/sohbet yanıtı olmamalı.
   Başarısızsa boş döner ve hata loglanır.

#### Kullanım

```bash
# Tüm entity'ler için (büyük işlem, saatler sürebilir)
python3 tool/art_gen/subject_gen.py

# Belirli bir manifest'teki entity'ler için (grid testi)
python3 tool/art_gen/subject_gen.py --manifest grids/pkg_s1234/manifest.json

# Sadece 5 entity üret
python3 tool/art_gen/subject_gen.py --limit 5

# Önbelleği görmezden gel, hepsini yeniden üret
python3 tool/art_gen/subject_gen.py --force

# Hata sayısını azaltmak için retry ve worker sayısı
python3 tool/art_gen/subject_gen.py --retries 3 --workers 6
```

**Çıktı:** `subject_cache.json` — `dict[uuid, subject_text]`:
```json
{
  "uuidv5-...": "large three-eyed fish-like aberration, four thick tentacles, vertical mouth, slimy translucent skin, pale bioluminescent blue"
}
```

---

### Adım 4 — Prompt Listesi Oluşturma (art_jobs.jsonl)

`prompts.py` subject cache'i ve pack verilerini birleştirerek her entity için
nihai Flux prompt'unu üretir.

#### Prompt Katmanları

Her prompt altı katmandan oluşur:

```
{subject}. {DND_CONTEXT}, {framing}, {FULL_BLEED}, {palette}, {mood}, {style}, {flavor}
```

| Katman | Kaynak | Açıklama |
|--------|--------|----------|
| **subject** | `monster_prompt()` / `NAME_ONLY_TYPES` / `clean_prose()` + `_SUBJECT_CACHE` | Ne çizileceği. Cache varsa subject cache override eder. |
| **DND_CONTEXT** | Sabit | "Dungeons & Dragons 5th edition tabletop roleplaying game illustration" |
| **framing** | `FRAMING[type]` veya `SPECIES_FRAMING` | Kompozisyon (portre, nesne, heraldik, vs.) |
| **FULL_BLEED** | Sabit | Kenar-boya kompozisyon talimatı |
| **palette** | `PACKAGE_PALETTE[pkg]` + `CATEGORY_PALETTE[type]` | Renk paleti |
| **mood** | `PACKAGE_LIGHT[pkg]` + `CATEGORY_BG[type]` / `PACKAGE_BG[pkg][type]` + `BG_FLAVOR` | Işık + arka plan |
| **style** | `PACKAGE_STYLE[pkg]` + `STYLE_TAIL` | Çizim medyası + anti-AI kuyruk |
| **flavor** | `STYLE_FLAVOR` (deterministik, uuid[8:12]) | Küçük medya-agnostik fark |

**Seed:** `int(uuid[:8], 16)` — aynı entity her zaman aynı görseli üretir.

#### Kullanım

```bash
# Tüm pack'lerden prompt üret
python3 tool/art_gen/prompts.py --out art_jobs.jsonl

# Doğrulama
python3 tool/art_gen/prompts.py --self-check

# Tip başına örnek promptları göster
python3 tool/art_gen/prompts.py --sample 3
```

**Çıktı:** `art_jobs.jsonl` — her satır bir JSON:
```json
{"uuid": "uuidv5-...", "package": "dnd5e-srd", "type": "monster", "name": "Aboleth", "prompt": "large three-eyed fish-like aberration... oil painting on canvas...", "seed": 25264934}
```

**Sıralama:** Pack'ler alfabetik (`sorted(glob("*.pkg.json"))`), entity'ler JSON dict
insertion order'ıyla sıralanır. İlk görülen uuid kazanır (deduplication).

---

### Adım 5 — Görsel Üretimi

`generate.py` `art_jobs.jsonl`'daki her job'ı ComfyUI API'sine gönderir.

#### Akış

1. **Filtreleme** — `--types`, `--every`, `--limit` ile job filtreleme.
2. **Resume** — `out/` içinde `.webp` dosyası olan job atlanır.
3. **Workflow** — Seçilen modele göre ComfyUI workflow'u oluşturulur:
   - `checkpoint` (Flux.1 schnell): tek checkpoint, 4 adım, cfg 1.0
   - `diffusion` (Z-Image-Turbo): ayrı UNET/CLIP/VAE, 8 adım, cfg 1.0
4. **API çağrısı** — POST `/prompt`, ardından polling `/history/{prompt_id}`.
5. **Post-processing** — `%5` kenar kırpma (sahte filigran temizliği), WebP'e dönüştürme.

#### Kullanım

```bash
# Tüm job'ları üret
python3 tool/art_gen/generate.py \
  --host http://192.168.1.12:8188 \
  --jobs tool/art_gen/art_jobs.jsonl \
  --out tool/art_gen/out

# Sadece belirli tipler
python3 tool/art_gen/generate.py --types monster,spell --limit 200

# Her N'inci job (hızlı test)
python3 tool/art_gen/generate.py --every 10

# Farklı model
python3 tool/art_gen/generate.py --loader checkpoint --ckpt flux1-schnell-fp8.safetensors
```

**Çıktı:** `out/{uuid}.webp` — entity başına tek görsel.

---

## Hızlı Başlangıç (Sıfırdan)

```bash
# 1. SRD pack'ini dök
(cd flutter_app && dart run tool/srd_art_dump/bin/dump_srd.dart \
  ../tool/art_gen/packs/dnd5e-srd.pkg.json)

# 2. Prompt listesi üret
python3 tool/art_gen/prompts.py --out tool/art_gen/art_jobs.jsonl

# 3. Subject cache üret ( grid testi için manifest ile )
python3 tool/art_gen/package_grid.py --dry-run   # önce seçimi gör
python3 tool/art_gen/subject_gen.py --manifest tool/art_gen/grids/pkg_s1234/manifest.json

# 4. Prompt listesini subject cache ile yeniden üret
python3 tool/art_gen/prompts.py --out tool/art_gen/art_jobs.jsonl

# 5. Görselleri üret
python3 tool/art_gen/generate.py \
  --host http://192.168.1.12:8188 \
  --jobs tool/art_gen/art_jobs.jsonl \
  --out tool/art_gen/out
```

---

## Stil Tutarlılığının Kaldıraçları

1. **Tek model, sabit ayarlar** — STEPS/CFG/SAMPLER/SCHEDULER job başına değişmez.
2. **Çizim tarzı pakete özel** (`PACKAGE_STYLE[pkg]`). Her paketin kendi medyası.
3. **Renk paleti (paket, kategori) ikilisine özel** — paket baz paleti + kategori aksanı.
4. **Arka plan/ışık (paket, kategori) ikilisine özel** — paket ışık yönü + kategori zemini.
5. `STYLE_FLAVOR` — uuid[8:12] ile deterministik, aynı paket içinde karbon kopya olmasın.
6. `seed = int(uuid[:8], 16)` — aynı entity her koşuda aynı görsel.
7. Tipe özel `FRAMING` — stili değil, yalnızca kompozisyonu değiştirir.

---

## Paket Grid Testi

Her paket ve içindeki her kategoriden `--per-type` (varsayılan 2) entity seçilir,
üretilir ve paket başına tek grid resminde birleştirilir. Sütun = kategori, satır =
seçilen örnekler.

```bash
python3 tool/art_gen/package_grid.py --dry-run
python3 tool/art_gen/package_grid.py --variant pkg
python3 tool/art_gen/package_grid.py --variant v1 --packages dnd5e-srd,open5e-tob3
```

Çıktı: `grids/<variant>_s<seed>/<package>.png` + `manifest.json`.

---

## Tek Stil Grid Testi

`prompt_grid.py` her kategoriden rastgele N içerik seçip tek grid'de
birleştirir. `--style`/`--palette`/`--mood` ile varyant denenir.

```bash
python3 tool/art_gen/prompt_grid.py --variant deneme1
python3 tool/art_gen/prompt_grid.py --variant deneme2 --style "<yeni stil>"
python3 tool/art_gen/prompt_grid.py --dry-run
```

---

## Üretim Ortamı

ComfyUI + Flux.1-schnell fp8 (17GB) veya Z-Image-Turbo, Docker içinde, tek GPU.

| Parametre | Varsayılan | Açıklama |
|-----------|------------|----------|
| `--host` | `http://192.168.1.12:8188` | ComfyUI sunucu |
| `--size` | `1024` | Üretim boyutu (px) |
| `--quality` | `82` | WebP kalitesi |
| `--crop` | `0.05` | Kenar kırpma oranı |
| `--timeout` | `300` | Job başına timeout (sn) |

Resume edilebilir: `out/` içinde `.webp` dosyası olan job atlanır.

---

## Öğrenilenler

- **Flux'ta negasyon kullanma.** cfg 1.0 distilled model, negatif prompt yok.
  "no text, no watermark" filigranı önlemiyor, aksine tetikliyor.
- **Canavarlarda `description` yok.** Prompt yapısal alanlardan sentezleniyor.
- **Yapısal sentez isim sadakati için yetmiyor.** Çözen: LLM'e görsel subject
  yazdırmak (`subject_gen.py`).
- **Kural metni prompt'a girmemeli.** `NAME_ONLY_TYPES` ile yalnızca isim + bağlam.
- **"vignette" kelimesi** literal beyaz çerçeveli madalyon çizdiriyor.

---

## Sorun Giderme

| Sorun | Çözüm |
|-------|-------|
| `Connection refused` | Sunucu durmuş, Docker'ı başlat |
| `TimeoutError` | `--timeout` değerini artır |
| Filigran görünüyor | `--crop` değerini artır (varsayılan %5) |
| Yanlış görsel | Seed deterministik — aynı prompt = aynı sonuç |
| VRAM yetersiz | Diğer GPU uygulamalarını kapat |
| Subject cache boş kalıyor | `--force` ile yeniden üret, SSH bağlantısını kontrol et |
