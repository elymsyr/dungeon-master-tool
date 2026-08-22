# art_gen — içerik görselleri üretimi

open5e pack'lerindeki entity'lere AI ile görsel üretir. Stil tutarlılığı hedefi:
tüm görseller tek bir çizim tarzında ve D&D estetiğinde olmalı.

## Kapsam

22.192 pack entity'sinin **5.513'ü** görsele değer. Dışarıda kalanlar
`creature-action` (10.229) ve `trait` (6.434) — bunlar bir nesne değil, kural
cümlesi ("Bite. Melee Weapon Attack: +7", "Amphibious."). Kapsam
`ART_TYPES` ile belirlenir.

## Kullanım

```bash
python3 tool/art_gen/prompts.py --self-check          # doğrulama
python3 tool/art_gen/prompts.py --sample 3            # tip başına örnek prompt
python3 tool/art_gen/prompts.py --out art_jobs.jsonl

python3 tool/art_gen/generate.py \
  --host http://<server>:8188 --jobs art_jobs.jsonl --out out \
  [--types monster,spell] [--limit 200]
```

`generate.py` resume edilebilir: `out/` içinde dosyası olan job atlanır.
Aynı script hem uzaktan hem ComfyUI'nin koştuğu makinede çalışır. Tüm çıktılar
(`art_jobs.jsonl`, `out/`, `grids/`) `tool/art_gen/` içinde tutulur.

## Prompt varyantlarını karşılaştırma (grid testi)

Toplu üretimden önce her kategoriden rastgele 2 içerik seçilip tek grid
resminde birleştirilir. Aynı `--seed` ile farklı `--style` denenirse grid'ler
birebir aynı entity'leri gösterir — stil farkını yan yana okumak mümkün.

```bash
python3 tool/art_gen/prompt_grid.py --variant deneme1              # prod stil
python3 tool/art_gen/prompt_grid.py --variant deneme2 --style "<yeni stil>"
python3 tool/art_gen/prompt_grid.py --seed 7 --size 1024           # farklı örnek set
```

Çıktı: `out/<variant>/<uuid>.webp` (hücreler) + `grids/<variant>_s<seed>.png`
(tek resim) + `grids/<variant>_s<seed>.json` (örnek manifesti).

## Üretim ortamı

ComfyUI + Flux.1-schnell fp8 (17GB, tek dosya checkpoint), Docker içinde,
tek GPU'ya kilitli. ~8 sn/görsel, 1024² üretim → %5 kenar kırpma → 922² webp.

Kurulumda iki tuzak:
- ComfyUI **v0.7.0**'a sabitli. Sonraki sürümler `comfy_kitchen` üzerinden
  torch ≥2.7 istiyor; elimizdeki image'da torch 2.6.0 var.
- Bağımlılıklar `pip install --user` ile mount'lu `/root/.local`'a kurulur,
  yoksa her container açılışında kaybolur.

## Stil tutarlılığının kaldıraçları

1. Tek model, sabit `STEPS/CFG/SAMPLER/SCHEDULER` — job başına asla değişmez.
2. `STYLE` bloğu (medya + doku + D&D çapası) her prompt'ta aynıdır.
   **En büyük etkiyi bu yapar.**
3. `PALETTE` ve `MOOD` **tipe özeldir** — büyü parlak, canavar zengin doğal, eşya
   altın/cevher, karakter sıcak. Tek muted banda sıkışmaz, D&D paletinin her yeri
   kullanılır.
4. `STYLE_FLAVOR` — entity'nin uuid'inin `[8:12]` hanesiyle deterministik seçilen
   küçük stil farkları (impasto/dry-brush/glazing/palette-knife). Hepsi aynı
   aileden ama karbon kopya değil.
5. `seed = int(uuid[:8], 16)` — aynı entity her koşuda aynı görsel; beğenilmeyeni
   tek tek yeniden üretmek mümkün.
6. Tipe özel `FRAMING` — stili değil, yalnızca kompozisyonu değiştirir.

## Stil neden böyle (2026-08 araştırması)

Eski stil ("painted fantasy illustration, matte canvas texture, dramatic rim
lighting, clean unmarked surface, centered composition") Flux'un **AI-default**
görünümünü tetikleyen jenerik terimlerdi: pürüzsüz doku, kusursuz ışık, simetrik
kompozisyon. Araştırmadan çıkan kurallar:

- `digital art / concept art / render / masterpiece / clean / smooth` → AI
  görünümünü TETİKLER; kullanma.
- AI'nın en büyük tell'i **uniform micro-noise**: her yüzey aynı doku, aynı ton.
  Gerçek resimde düz alanda bile ton oynaması vardır → "subtle tonal variation
  across surfaces".
- Waxy/sheen yüzeyler AI hissi verir → "matte finish".
- Medyayı somut adlandır ("oil painting on canvas") + görünür fırça izi.
- Kusur ipuçları ("slightly uneven hand-painted edges") insan eli hissi verir.
- "classic fantasy tabletop roleplaying game art" D&D evreni çapasıdır.
- Paleti tek banda sıkıştırma: `PALETTE` kategoriye göre değişir.

## Öğrenilenler (tekrar keşfetmeye değmez)

**Flux'ta negasyon kullanma.** cfg 1.0 distilled model, negatif prompt yok.
Pozitif prompt'a "no text, no watermark" yazmak filigranı önlemiyor, aksine
üretimini tetikliyor. Sahte imza için tek deterministik çözüm kenar kırpma
(`--crop`, varsayılan %5) — imzalar her zaman kenara/köşeye düşüyor.

**Canavarlarda `description` yok.** Pack'teki 2.885 monster'ın %100'ünde boş
(hand-authored `srd_core` içindeki 248'i istisna). Prompt yapısal alanlardan
sentezleniyor: `size_ref` + `creature_type_ref` + `alignment_ref` + `cr` +
uçuş/yüzme/kazma hızları + Darkvision.

**Yapısal sentez isim sadakati için yetmiyor.** "large aberration, aquatic,
glowing eyes" Flux'a aboleth çizdirmiyor, jenerik kanatlı yaratık veriyor.
Prompt'a "well-known Dungeons and Dragons monster" eklemek de çözmüyor.
Çözen: **bir LLM'e yaratığın fiziksel tanımını yazdırmak.** Sunucudaki
Ollama (`llama3.1:8b`) obskür Tome of Beasts yaratıklarında bile makul tanım
üretiyor. Bu pass henüz script'e bağlanmadı — bağlanınca `monster_prompt`
öncesinde çalışmalı ve çıktısı cache'lenmeli.

**Kural metni prompt'a girmemeli.** feat/subclass/background'ın açıklaması saf
mekanik; `NAME_ONLY_TYPES` ile yalnızca isim + bağlam kullanılıyor.

**"vignette" kelimesi** modele literal beyaz çerçeveli madalyon çizdiriyor,
koyu zemin kuralını bozuyor.

## Bilinen açık konu

Karakter konulu tiplerde (`background`, `species`, `subspecies`) Flux açık bej
zemin veriyor ve `STYLE`'daki "dark neutral background" eziliyor — diğer
tiplerle arasında görünür bir sapma kalıyor. Prompt ağırlığı ayarı gerekiyor.
