# Aegis Art Pipeline

Aegis dünyasındaki tüm entity'ler (125 adet, 14 kategori) için D&D 5e SRD yağlı boya tarzında görsel üretir.

## Amaç

Aegis world blueprint'indeki her entity için ComfyUI/Flux ile görsel üretim. Beş aşamalı bir pipeline:

1. **Prompt üretimi** (`aegis_prompts.py`) — Blueprint'ten her entity için ham Flux prompt'u oluşturur. Entity'nin alanları (appearance, description, benefits vb.) salt görsel subject cümleciğine dönüştürülür, kural metni temizlenir. Çıktı: `art_jobs.jsonl`.
2. **Subject cache** (`aegis_subject_gen.py`) — Gemini API ile her entity için profesyonel görsel betimleme üretilir. Ham blueprint içeriğini zengin, somut görsel betimlemeye dönüştürür. Çıktı: `aegis_subject_cache.json`.
3. **Merge** (`aegis_merge.py`) — `art_jobs.jsonl` + `aegis_subject_cache.json` birleştirilir. Final prompt'ta raw blueprint içeriği yerine Gemini cevabı kullanılır. Çıktı: `art_jobs_final.jsonl`.
4. **Elden geçirme** (`aegis_polish.py`) — `art_jobs_final.jsonl`'i yeniden derler: konu metni
   + **kart başına ışık/atmosfer** + kategori/kart bazlı çerçeveleme. Kaynağı
   `art_jobs_final.orig.jsonl` (merge çıktısının kopyası); konusu yeniden yazılan kartlar
   script içindeki `SUBJECT` sözlüğünde. Çıktı: `art_jobs_final.jsonl`.
5. **Görsel üretimi** (`aegis_generate.py`) — ComfyUI ile `art_jobs_final.jsonl` → `out/{uuid}.webp`.

## Kullanım

```bash
# 1. Prompt üretimi (125 job → art_jobs.jsonl)
python3 aegis_prompts.py
python3 aegis_prompts.py --sample 2                # her kategoriden 2 örnek
python3 aegis_prompts.py --category npc --limit 5   # sadece NPC'ler

# 2. Subject cache üretimi (GEMINI_API_KEY gerekli → aegis_subject_cache.json)
python3 aegis_subject_gen.py                          # eksikleri üret
python3 aegis_subject_gen.py --dry-run --limit 5      # prompt'ları göster
python3 aegis_subject_gen.py --force                   # tümünü yeniden üret

# 3. Merge (art_jobs.jsonl + aegis_subject_cache.json → art_jobs_final.jsonl)
python3 aegis_merge.py                                 # birleştir
python3 aegis_merge.py --sample 5                      # 5 örnek bas
python3 aegis_merge.py --self-check                    # doğrula
python3 aegis_merge.py --category npc                  # sadece NPC'ler

# 4. Elden geçirme (art_jobs_final.orig.jsonl → art_jobs_final.jsonl)
python3 aegis_polish.py --check                        # doğrula, yazma
python3 aegis_polish.py --show "location|Votumar"      # tek kartın prompt'u
python3 aegis_polish.py                                # yaz

# 5. Görsel üretimi (ComfyUI gerekli → out/{uuid}.webp)
python3 aegis_generate.py                                    # tüm job'lar
python3 aegis_generate.py --limit 5                          # pilot: ilk 5
python3 aegis_generate.py --categories npc,monster            # filtre
python3 aegis_generate.py --loader checkpoint --ckpt flux1-schnell-fp8.safetensors
python3 aegis_generate.py --host http://192.168.1.12:8188
```

## Kategoriler

| Kategori | Adet | Subject alanları |
|---|---|---|
| campaign | 1 | description |
| lore | 20 | description |
| location | 18 | environment + description_long |
| npc | 34 | appearance, mannerisms, species_ref, location_ref |
| monster | 4 | description, size_ref, creature_type_ref, stat_block |
| creature-action | 4 | description, attack_kind, damage_type_ref |
| trait | 5 | benefits, trait_kind |
| curse | 1 | description, trigger, effect, mechanical_notes, removed_by |
| scene | 11 | description, beats, location_ref |
| encounter | 1 | description, setup, difficulty, location_ref |
| quest | 2 | description |
| adventuring-gear | 8 | description, weight_lb, consumable |
| trinket | 7 | description |
| background | 9 | description, granted_skill_refs, granted_tool_refs |

## Final prompt yapısı

`art_jobs_final.jsonl`'deki her satır yapılandırılmış prompt taşır:

```
[Subject — Gemini visual description]
{Gemini'nin ürettiği somut görsel betimleme — 40-100 kelime}

[Style]
{name}, Aegis {category}
{full-bleed}, {D&D context}, {Aegis palet}, {ışık}, {yağlı boya stili}, {flavor}
```

Gemini cache yoksa `[Subject — blueprint extract]` etiketiyle ham blueprint içeriği kullanılır.

## Stil

`aegis_merge.py` her karta kategori sabiti bir ışık veriyordu (bütün location'lar
"flat overcast daylight", bütün NPC'ler "hearth glow") — sonuçta her kartın arka planı
birbirinin aynı çıkıyordu. `aegis_polish.py` ışığı/atmosferi **kart başına** verir ve
prompt'tan `{isim}, Aegis {kategori}` başlığını çıkarır (Mine/Fare gibi adlar text
encoder'da yanlış anlam üretiyordu). Ortak kalanlar:
- D&D 5e SRD yağlı boya (hand-painted oil painting on canvas)
- Aegis paleti (deep earthy tones, weathered parchment, warm amber, cool slate)
- Anti-AI skeleton (digital art / concept art / render gibi tetikleyici kelimeler yasak)
- Full-bleed square composition

## Bağımlılıklar

- Python 3.10+
- `GEMINI_API_KEY` ortam değişkeni (subject cache için)
