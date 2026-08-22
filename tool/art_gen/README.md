# art_gen — içerik görselleri üretimi

open5e pack'lerindeki ve built-in SRD 5.2.1 pack'indeki entity'lere AI ile görsel
üretir. Hedef: her paketin kendi çizim tarzı, her kategorinin kendi renk paleti
ve arka planı — ama hepsi D&D estetiğinde ve AI görünümünden uzak.

## Kapsam

Open5e pack'leri + built-in SRD pack'inde **6.760** entity görsele değer.
Dışarıda kalanlar `creature-action` ve `trait` — bunlar bir nesne değil, kural
cümlesi ("Bite. Melee Weapon Attack: +7", "Amphibious."). Kapsam `ART_TYPES`
ile belirlenir.

## Kullanım

Built-in SRD pack'i (Dart'ta el yazımı `srd_core`) önce `.pkg.json`'a dökülür,
sonra prompt'lar tüm pack'lerden üretilir:

```bash
# built-in SRD 5.2.1 pack'ini dök (gitignored, yeniden üretilebilir)
(cd flutter_app && dart run tool/srd_art_dump/bin/dump_srd.dart ../tool/art_gen/packs/dnd5e-srd.pkg.json)

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

## Paket grid testi (paket × kategori)

Her paket ve içindeki her görsel üretilen kategoriden `--per-type` (varsayılan 2)
entity seçilir, üretilir ve **paket başına tek grid** resminde birleştirilir.
Sütun = kategori, satır = o kategoriden seçilen örnekler. Paket başlığı ve
stili grid başlığında yazar; paketler arası tarz farkı bu yüzden bir bakışta
okunur.

```bash
python3 tool/art_gen/package_grid.py --dry-run                        # seçimi gör
python3 tool/art_gen/package_grid.py --variant pkg                    # tüm paketler
python3 tool/art_gen/package_grid.py --variant v1 --packages dnd5e-srd,open5e-tob3
```

Çıktı: `grids/<variant>_s<seed>/<package>.png` (paket başına grid) +
`grids/<variant>_s<seed>/manifest.json` (seçilen örnekler). Hücreler
`out/<variant>/<uuid>.webp` altında cache'lenir; yarıda kalırsa aynı komut
resume eder.

## Prompt varyantlarını karşılaştırma (tek stil grid testi)

Eski tek-stil karşılaştırması `prompt_grid.py` duruyor: her kategoriden rastgele
2 içerik seçip tek grid resminde birleştirir; `--style`/`--palette`/`--mood` ile
varyant dener.

```bash
python3 tool/art_gen/prompt_grid.py --variant deneme1
python3 tool/art_gen/prompt_grid.py --variant deneme2 --style "<yeni stil>"
```

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
2. **Çizim tarzı pakete özeldir** (`PACKAGE_STYLE[pkg]`). Her paketin kendi
   medyası vardır (yağlı boya, suluboya+ink, gravür, linocut, tempera+altın
   varak, risograph…). Hepsi somut geleneksel araçlar olduğundan AI-default
   parlaklığına düşmez; ortak anti-AI kuyruk (`STYLE_TAIL`) tüm paketlerde aynı.
3. **Renk paleti (paket, kategori) ikilisine özeldir** — paket baz paleti
   (`PACKAGE_PALETTE`, paket adı + kapak/banner görselinin baskın tonlarından
   türetilir) + kategori aksanı (`CATEGORY_PALETTE`). Karanlık zorunlu değil:
   tob3 aydınlık teal/aqua, "Spells That Don't Suck" parlak, a5e-ag gün ışığı.
4. **Arka plan/ışık (paket, kategori) ikilisine özeldir** — paket ışık yönü
   (`PACKAGE_LIGHT`) + kategori zemini (`CATEGORY_BG`).
5. `STYLE_FLAVOR` — entity'nin uuid'inin `[8:12]` hanesiyle deterministik seçilen
   küçük, medya-agnostik stil farkları. Aynı paket içinde karbon kopya olmasın.
6. `seed = int(uuid[:8], 16)` — aynı entity her koşuda aynı görsel; beğenilmeyeni
   tek tek yeniden üretmek mümkün.
7. Tipe özel `FRAMING` — stili değil, yalnızca kompozisyonu değiştirir.

## Stil neden böyle (2026-08 araştırması)

Eski stil ("painted fantasy illustration, matte canvas texture, dramatic rim
lighting, clean unmarked surface, centered composition") Flux'un **AI-default**
görünümünü tetikleyen jenerik terimlerdi: pürüzsüz doku, kusursuz ışık, simetrik
kompozisyon. Araştırmadan çıkan kurallar:

- `digital art / concept art / render / masterpiece / clean / smooth / perfect /
  8k` → AI görünümünü TETİKLER; kullanma.
- AI'nın en büyük tell'i **uniform micro-noise**: her yüzey aynı doku, aynı ton.
  Gerçek resimde düz alanda bile ton oynaması vardır → "subtle tonal variation
  across surfaces".
- AI varsayılanı yumuşak/yönsüz ışıktır → **yönlü ışık** (nereden geldiği belli)
  ve sert gölge iste.
- Simetri/AI-kusursuzluğu kır → hafif kompozisyon kusuru, elle çizilmiş kenar.
- Waxy/sheen yüzeyler AI hissi verir → boyalı medyada "matte finish".
- Medyayı somut adlandır ("oil painting on canvas") + görünür fırça izi.
- "classic fantasy tabletop roleplaying game art" D&D evreni çapasıdır.
- Paleti tek banda sıkıştırma: palet artık pakete göre değişir ve aydınlık
  olabilir.

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
