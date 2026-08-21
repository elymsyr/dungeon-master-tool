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

### 1. Prompt Üretimi (prompt_jobs.jsonl)

```bash
# Pack dosyalarından job listesi üret
python3 tool/art_gen/prompts.py --out art_jobs.jsonl

# Doğrulama (self-check)
python3 tool/art_gen/prompts.py --self-check

# Tip başına örnek promptları göster
python3 tool/art_gen/prompts.py --sample 3
```

Çıktı: `art_jobs.jsonl` — her satır `{uuid, type, name, prompt, seed}`.

### 2. Görsel Üretimi (generate.py)

```bash
# Tüm job'ları üret
python3 tool/art_gen/generate.py \
  --host http://192.168.1.12:8188 \
  --jobs art_jobs.jsonl \
  --out out

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

Tüm görsellerde aynı stil kullanılır:

```
painted fantasy illustration, muted earthy palette, dramatic rim lighting,
matte canvas texture, dark neutral background, centered composition,
clean unmarked surface
```

Seed `uuid[:8]`'den türetilir → aynı entity her zaman aynı görseli üretir.

## Sorun Giderme

| Sorun | Çözüm |
|-------|-------|
| `Connection refused` | Sunucu durmuş, Docker'ı başlat |
| `TimeoutError` | `--timeout` değerini artır veya sunucuyu kontrol et |
| Filigran görünüyor | `--crop` değerini artır (varsayılan %5) |
| Yanlış görsel | Seed deterministik — aynı prompt = aynı sonuç |
| VRAM yetersiz | Diğer GPU uygulamalarını kapat |
