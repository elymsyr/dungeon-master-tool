# art_gen — Operasyon Rehberi

## Sunucu Durumu Kontrol

```bash
# ComfyUI API'nin çalışıp çalışmadığını kontrol et
curl -s http://192.168.1.12:8188/system_stats | python3 -m json.tool

# Kuyrukta job var mı?
curl -s http://192.168.1.12:8188/queue

# Son işlenen job'lar
curl -s "http://192.168.1.12:8188/history?max_items=5"
```

## ComfyUI Sunucusu

Sunucu `192.168.1.12:8188` adresinde, Docker içinde koşuyor.
Model: `flux1-schnell-fp8.safetensors` (~17GB, fp8 quantized).

### Durdurma / Başlatma

Sunucuya fiziksel erişim veya SSH gerekiyor. Docker komutları:

```bash
# Container'ı bul
docker ps -a | grep comfy

# Durdur (VRAM'i serbest bırakır)
docker stop <container_adi>

# Başlat (modeli VRAM'e yükler, ~30-60 sn)
docker start <container_adi>

# Tamamen silip sıfırdan başlatma
docker-compose down && docker-compose up -d
```

> **Not:** Container durdurulduğunda VRAM tamamen boşalır (~20GB).
> Başlatıldığında model otomatik yüklenir, ilk job'a kadar ~1-2 dk beklenir.

### Durum Kontörleri

| Durum | Anlamı |
|-------|--------|
| `vram_free` ~5GB | Model yüklü, hazır |
| `vram_free` ~20GB | Model yüklenmemiş veya durdurulmuş |
| `queue_running` boş | Job işleniyor |
| `queue_pending` boş | Kuyrukta job yok |

## Görsel Üretim Pipeline'ı

### 1. Prompt Üretimi (art_jobs.jsonl)

```bash
# built-in SRD 5.2.1 pack'ini Dart'tan dök (gitignored, yeniden üretilebilir)
(cd flutter_app && dart run tool/srd_art_dump/bin/dump_srd.dart ../tool/art_gen/packs/dnd5e-srd.pkg.json)

# Pack dosyalarından job listesi üret (open5e pack'leri + built-in SRD)
python3 tool/art_gen/prompts.py --out art_jobs.jsonl

# Doğrulama (self-check)
python3 tool/art_gen/prompts.py --self-check

# Tip başına örnek promptları göster
python3 tool/art_gen/prompts.py --sample 3
```

Çıktı: `art_jobs.jsonl` — her satır `{uuid, package, type, name, prompt, seed}`.
Tüm çıktılar `tool/art_gen/` içine düşer.

### 2. Görsel Üretimi (generate.py)

```bash
# Tüm job'ları üret
python3 tool/art_gen/generate.py \
  --host http://192.168.1.12:8188 \
  --jobs tool/art_gen/art_jobs.jsonl \
  --out tool/art_gen/out

# Sadece belirli tipler
python3 tool/art_gen/generate.py \
  --host http://192.168.1.12:8188 \
  --types monster,spell \
  --limit 200

# Her N'inci job (hızlı test)
python3 tool/art_gen/generate.py \
  --host http://192.168.1.12:8188 \
  --every 10
```

### Önemli Parametreler

| Parametre | Varsayılan | Açıklama |
|-----------|------------|----------|
| `--host` | `http://192.168.1.12:8188` | ComfyUI sunucu adresi |
| `--jobs` | `art_jobs.jsonl` | Job listesi dosyası |
| `--out` | `out` | Çıktı klasörü (webp dosyaları) |
| `--ckpt` | `flux1-schnell-fp8.safetensors` | Model checkpoint |
| `--size` | `1024` | Üretim boyutu (px) |
| `--quality` | `82` | Webp kalitesi |
| `--crop` | `0.05` | Kenar kırpma oranı (filigran temizliği) |
| `--limit` | — | Sadece ilk N job |
| `--types` | — | Tip filtresi (virgüllü) |
| `--every` | `1` | Her N'inci job |
| `--timeout` | `300` | Job başına timeout (sn) |

### Resume Desteği

Script resume edilebilir: `out/` içinde `.webp` dosyası olan job'lar atlanır.
Yarıda kalırsanız same komutu tekrar çalıştırmanız yeterli.

## Stil Tutarlılığı

Stil üç katmanda değişir (2026-08 yeniden düzenleme — "paketler arasında tarz
değişsin"):

1. **Çizim tarzı pakete özeldir** — `PACKAGE_STYLE[pkg]` her pakete farklı bir
   geleneksel medya atar (yağlı boya, suluboya+ink, gravür, linocut, tempera +
   altın varak, risograph…). Ortak anti-AI kuyruk `STYLE_TAIL` (ton oynaması +
   elle çizilmiş kenar + D&D çapası) tüm paketlerde aynıdır.
2. **Renk paleti (paket, kategori) ikilisine özeldir** — `PACKAGE_PALETTE[pkg]`
   (paket adı + kapak/banner tonlarından) + `CATEGORY_PALETTE[cat]` aksanı.
   Karanlık zorunlu değil; pakete göre aydınlık/loş karışık.
3. **Arka plan/ışık (paket, kategori) ikilisine özeldir** — `PACKAGE_LIGHT[pkg]`
   + `CATEGORY_BG[cat]`.

`STYLE_FLAVOR` entity'nin uuid `[8:12]` hanesiyle deterministik seçilir; seed
`uuid[:8]`'den türetilir → aynı entity her zaman aynı görseli üretir.

### Paket grid testi (package_grid.py)

Her paket ve içindeki her kategoriden `--per-type` (varsayılan 2) entity seçilir,
üretilir ve paket başına tek grid resminde birleştirilir. Sütun = kategori.

```bash
python3 tool/art_gen/package_grid.py --dry-run                 # seçimi gör
python3 tool/art_gen/package_grid.py --variant pkg             # tüm paketler
python3 tool/art_gen/package_grid.py --variant v1 --packages dnd5e-srd,open5e-tob3
```

Çıktı `tool/art_gen/grids/<variant>_s<seed>/` altına: `<package>.png` (paket
başına grid), `manifest.json`, `_overview.png` (tüm paketlerin dikey birleşimi).
Hücreler `out/<variant>/<uuid>.webp` altında cache'lenir — yarıda kalırsa aynı
komut resume eder.

### Tek stil grid testi (prompt_grid.py)

Her kategoriden rastgele N içerik seçilir, üretilir ve tek grid resminde
birleştirilir. Aynı `--seed` ile farklı `--style`/`--palette`/`--mood` denenerek
stiller yan yana karşılaştırılır. Çıktı `tool/art_gen/grids/` altına düşer.

```bash
python3 tool/art_gen/prompt_grid.py --variant deneme1
python3 tool/art_gen/prompt_grid.py --variant deneme2 --style "<yeni stil>"
python3 tool/art_gen/prompt_grid.py --variant deneme3 --palette "vivid fiery palette, ruby, orange, gold"
python3 tool/art_gen/prompt_grid.py --dry-run   # üretmeden örnek seti gör
```

## Sorun Giderme

| Sorun | Çözüm |
|-------|-------|
| `Connection refused` | Sunucu durmuş, Docker'ı başlat |
| `TimeoutError` | `--timeout` değerini artır veya sunucuyu kontrol et |
| Filigran görünüyor | `--crop` değerini artır (varsayılan %5) |
| Yanlış görsel | Seed deterministik — aynı prompt = aynı sonuç |
| VRAM yetersiz | Diğer GPU uygulamalarını kapat |
