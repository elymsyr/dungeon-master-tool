#!/usr/bin/env python3
"""open5e pack'lerinden + built-in SRD pack'inden Flux prompt'u üretir.

Çıktı: art_jobs.jsonl — her satır {uuid, package, type, name, prompt, seed}.
Seed uuid'den türetilir → aynı entity her koşuda aynı görseli verir.

Stil katmanları (2026-08 yeniden düzenleme — "paketler arasında tarz değişsin"):
- ÇİZİM TARZI → pakete özel (PACKAGE_STYLE[pkg]). Her paketin kendi medyası.
- RENK PALETİ → (paket, kategori) ikilisine özel: paket baz paleti + kategori aksanı.
- ARKA PLAN → (paket, kategori) ikilisine özel: paket ışık yönü + kategori zemin.
Böylece aynı kategorinin görselleri bile paketten pakete farklı renk/zemin taşır.
Karanlık olmak zorunlu değil — paket adına ve kapak (banner) paletine göre bazı
paketler aydınlık, bazıları loş tutulur.
"""
from __future__ import annotations
import argparse, json, re, sys
from pathlib import Path

# Görsele değen tipler. creature-action / trait bir nesne değil, kural cümlesi.
ART_TYPES = {
    "monster", "spell", "magic-item", "subclass",
    "feat", "background", "subspecies", "species",
}

# ---------------------------------------------------------------------------
# Anti-AI skeleton — her paketin stilinin kuyruğu. Araştırma bulguları (2026-08):
# "digital art / concept art / render / masterpiece / clean / smooth / perfect /
# 8k" kelimeleri AI-default görünümünü TETİKLİYOR → hiçbir yerde kullanma.
# AI'nın en büyük tell'i "uniform micro-noise" (her yüzey aynı doku/ton) → ton
# oynaması + elle çizilmiş iz + hafif kusur bunu kırar. Negasyon yok (cfg 1.0).
# ---------------------------------------------------------------------------
STYLE_TAIL = (
    "subtle tonal variation across surfaces, "
    "slightly uneven hand-drawn edges, "
    "irregular handmade pigment density, "
    "classic fantasy tabletop roleplaying game art"
)

# Tam kare kaplama — en kritik kompozisyon talimatı. Flux "bust framing" gibi
# kelimeleri edge-to-edge talimatından güçlü yorumlayabiliyor, bu yüzden
# kompozisyonu subject'ten hemen sonra,olareksiz ve net veriyoruz.
FULL_BLEED = (
    "full-bleed square artwork, edge-to-edge composition, the illustration "
    "extends continuously to all four edges of the image, background reaches "
    "and touches every edge and corner of the canvas, no empty margins, no "
    "white space, no blank border, no frame, no vignette, no isolated "
    "character on a plain background, character and environment composition "
    "naturally cropped by the image boundaries"
)

# Her prompt'un başına eklenen D&D bağlamı — modelin bu görselin bir masa üstü
# rol yapma oyunu içeriği olduğunu anlamasını sağlar.
DND_CONTEXT = ("Dungeons & Dragons 5th edition tabletop roleplaying game illustration")

# Paket başına çizim tarzı. Medya somut adlandırılır; hepsi geleneksel araçlar
# olduğundan AI-default parlaklığına düşmez. Paket kimliği = tarz.
# "dnd uygun olmalı" istenen paketler DND_STYLE'a bağlanır.
DND_STYLE = ("hand-painted oil painting on canvas, expressive painterly "
             "brushstrokes, matte finish")
PACKAGE_STYLE = {
    "dnd5e-srd": DND_STYLE,
    "open5e-a5e-ag": "loose watercolor with fine ink linework on cold-press "
                     "paper, soft pigment granulation",
    "open5e-a5e-ddg": "charcoal and white chalk on toned grey paper, smudged "
                      "gestural edges",
    "open5e-a5e-gpg": "wood engraving print, crisp cross-hatched lines on aged "
                      "paper",
    "open5e-a5e-mm": DND_STYLE,
    "open5e-bfrd": "pen and ink with sepia wash on weathered parchment, nautical "
                   "chart hatching",
    "open5e-ccdx": "medieval bestiary woodcut, bold black outlines, dense "
                   "parallel hatching",
    "open5e-deepm": "luminous tempera with soft iridescent glazes, gently "
                    "glowing translucent layers",
    "open5e-deepmx": "silkscreen poster print, rich blocks of color, subtle "
                     "iridescent ink sheen, slight misregistration",
    "open5e-kp": "scratchboard, fine white lines scratched from solid black ink",
    "open5e-open5e": "soft colored pencil on textured paper, layered hatching",
    "open5e-spells-that-dont-suck": "hand-painted gouache illustration, warm "
                                    "cheerful colors, gentle lively brushwork",
    "open5e-tdcs": "tonal oil pastel, thick waxy strokes, loose atmospheric "
                   "blend",
    "open5e-tob": "mezzotint etching, rich tonal depth, roughened blacks",
    "open5e-tob-2023": "aquatint etching, granular tonal shading, textured plate",
    "open5e-tob2": "chalk and graphite study on blue-grey paper, soft blended "
                   "shading, renaissance study feel",
    "open5e-tob3": DND_STYLE,
    "open5e-toh": "illuminated manuscript miniature, gold leaf accents, "
                  "flattened perspective",
    "open5e-vom": "egg tempera icon painting, burnished gold leaf, jewel-tone "
                  "glazes",
    "open5e-wz": "two-color screen print on newsprint, halftone grain, bold "
                 "graphic shapes",
}

# Paket başına baz renk paleti — paket adı + kapak (banner) görselinin baskın
# tonlarından türetildi. Kasıtlı olarak karanlık değil: bazı paketler aydınlık.
PACKAGE_PALETTE = {
    "dnd5e-srd": "naturalistic color, each figure in its own natural hues, "
                 "deep earthy shadows",
    "open5e-a5e-ag": "mossy forest palette, olive, fern green, warm sunlight, "
                     "weathered stone, sun-warmed earth",
    "open5e-a5e-ddg": "underglow cavern palette, amber torchlight, slate, cold "
                      "blue shadow",
    "open5e-a5e-gpg": "newsprint palette, sage green, iron grey, paper cream",
    "open5e-a5e-mm": "naturalistic color, each figure in its own natural hues, "
                     "deep earthy shadows",
    "open5e-bfrd": "nautical palette, deep navy, sea foam, weathered rope tan, "
                   "storm green, sun-faded teal",
    "open5e-ccdx": "parchment and ink palette, sepia, iron-gall black, aged "
                   "paper",
    "open5e-deepm": "abyssal arcane palette, deep indigo, phosphor blue, "
                    "violet, soft cyan glow",
    "open5e-deepmx": "arcane palette, deep plum, muted violet, soft silver, "
                     "pale lilac, antique gold",
    "open5e-kp": "dragon-hoard palette, rust, amber, charcoal, ember red",
    "open5e-open5e": "adventurer palette, warm ochre, umber, sky blue, ivory",
    "open5e-spells-that-dont-suck": "vivid natural palette, spring green, "
                                     "sunshine yellow, warm coral, sky blue, "
                                     "fresh leaf green",
    "open5e-tdcs": "coastal city palette, sky blue, slate, sandstone, sea green",
    "open5e-tob": "wild creature palette, tawny browns, moss green, slate grey, "
                  "cream, varied natural hide colors",
    "open5e-tob-2023": "nocturnal creature palette, indigo shadow, bone, deep "
                       "teal, moss, muted amber, varied cool tones",
    "open5e-tob2": "deep-sea palette, steel blue, abyssal teal, driftwood grey, "
                   "sea green, pale aqua",
    "open5e-tob3": "naturalistic color, each figure in its own natural hues, "
                   "deep earthy shadows",
    "open5e-toh": "heraldic palette, royal blue, crimson, antique gold, ivory",
    "open5e-vom": "treasure-vault palette, deep emerald, sapphire, antique gold, "
                  "burgundy",
    "open5e-wz": "occult palette, blood red, black, bone white, sickly green",
}

# Paket başına ışık yönü — parlaklık burada değişir, kategori değil.
PACKAGE_LIGHT = {
    "dnd5e-srd": "dappled natural woodland light, forest clearing",
    "open5e-a5e-ag": "warm filtered daylight through trees, soft ambient "
                     "forest glow",
    "open5e-a5e-ddg": "flickering torchlight, deep cavern shadows",
    "open5e-a5e-gpg": "even overcast daylight",
    "open5e-a5e-mm": "soft natural daylight, wilderness environment",
    "open5e-bfrd": "harsh sea-light, overcast spray",
    "open5e-ccdx": "even manuscript light, pale parchment backdrop",
    "open5e-deepm": "dim underwater twilight, faint ambient arcane glow",
    "open5e-deepmx": "soft luminous haze, warm candlelit undertones",
    "open5e-kp": "ember glow, smoky dark",
    "open5e-open5e": "warm afternoon light, natural surroundings",
    "open5e-spells-that-dont-suck": "cheerful natural daylight, sunlit open "
                                    "field",
    "open5e-tdcs": "open sky, soft daylight",
    "open5e-tob": "dramatic side light, natural wilderness backdrop",
    "open5e-tob-2023": "gloomy twilight, rugged natural terrain",
    "open5e-tob2": "cold natural light, deep wilderness",
    "open5e-tob3": "dappled forest light, natural terrain",
    "open5e-toh": "stained-glass glow, ceremonial light",
    "open5e-vom": "velvet-dark vault, single museum spotlight",
    "open5e-wz": "harsh flash, stark contrast",
}

# Paket başlıkları (grid etiketi + metadata için).
PACKAGE_TITLE = {
    "dnd5e-srd": "D&D 5e SRD (Built-in)",
    "open5e-a5e-ag": "Adventurer's Guide",
    "open5e-a5e-ddg": "Dungeon Delver's Guide",
    "open5e-a5e-gpg": "Gate Pass Gazette",
    "open5e-a5e-mm": "Monstrous Menagerie",
    "open5e-bfrd": "Black Flag SRD",
    "open5e-ccdx": "Creature Codex",
    "open5e-deepm": "Deep Magic",
    "open5e-deepmx": "Deep Magic Extended",
    "open5e-kp": "Kobold Press Compilation",
    "open5e-open5e": "Open5e Originals",
    "open5e-spells-that-dont-suck": "Spells That Don't Suck",
    "open5e-tdcs": "Tal'dorei Campaign Setting",
    "open5e-tob": "Tome of Beasts",
    "open5e-tob-2023": "Tome of Beasts 1 (2023)",
    "open5e-tob2": "Tome of Beasts 2",
    "open5e-tob3": "Tome of Beasts 3",
    "open5e-toh": "Tome of Heroes",
    "open5e-vom": "Vault of Magic",
    "open5e-wz": "Warlock Zine",
}

DEFAULT_PACKAGE = "open5e-open5e"

# Kategori aksanları (paket baz paletine eklenen, kategoriye özgü renkler).
CATEGORY_PALETTE = {
    "monster":    "natural creature accents, varied natural coloring",
    "spell":      "arcane accents, violet, emerald, gold, crimson light",
    "magic-item": "antique accents, aged gold, burnished copper, deep ruby",
    "subclass":   "heraldic accents, crimson, royal blue, antique gold",
    "feat":       "heraldic accents, crimson, slate blue, antique gold",
    "background": "warm scene accents, amber, russet, deep brown",
    "subspecies": "ivory, amber, bronze tones",
    "species":    "ivory, amber, bronze tones",
}

# Kategori zemini (sahne tipi — parlaklık paketten gelir, burası sadece neyin
# arkada olduğu). "plain / empty / flat backdrop" ve "vignette" kelimeleri
# kullanılmaz: tekdüze boş zemin en büyük AI tell'idir; yerine doğal mekan verilir.
# "soft horizon" kullanılmaz — Flux bunu "kenarda boş alan bırak" olarak yorumlar.
CATEGORY_BG = {
    "monster":    "in its natural habitat, untamed wilderness terrain",
    "spell":      "swirling energy field",
    "magic-item": "on a rough-hewn stone surface, softly lit alcove",
    "subclass":   "heraldic banner",
    "feat":       "heraldic banner",
    "background": "lived-in scene, natural setting",
    "subspecies": "in a natural landscape",
    "species":    "in a natural landscape",
}

# Pakete özel zemin sözcükleri — CATEGORY_BG yerine geçer. Arka planda "o işi
# yapan şeyleri" (mesleğin/ortamın nesneleri) gösteren ipuçları ekler.
PACKAGE_BG = {
    "open5e-a5e-ddg": {
        "monster": "deep in a crumbling dungeon hall, scattered adventuring "
                   "gear, torches and rubble",
        "magic-item": "on a dusty stone altar in a looted crypt, among coils "
                      "of rope and pry bars",
        "background": "inside a dungeon-delver's camp, bedrolls, lanterns and "
                      "excavation tools",
    },
    "open5e-bfrd": {
        "monster": "on a storm-lashed ship deck, rigging and sea spray",
        "background": "aboard a sailing ship, coiled rope, charts and barrels",
    },
    "open5e-spells-that-dont-suck": {
        "spell": "a sunlit wildflower meadow, drifting petals",
        "magic-item": "on a mossy stone in a cheerful forest glade",
    },
    "open5e-a5e-ag": {
        "background": "in a deep forest clearing, ferns and old-growth trees",
    },
    "open5e-open5e": {
        "background": "at a roadside camp, bedroll, firewood and a stew pot",
        "subspecies": "in a village street, warm afternoon light",
        "species": "in a village street, warm afternoon light",
    },
}

# Sahne çeşitliliği — aynı kategorideki görsellerin birbirine benzemesini kırar.
# uuid ile deterministik seçilir. "resimler birbirine çok benziyor" şikayetleri
# bu listeyle çözülür (özellikle tekil betimlerde).
BG_FLAVOR = {
    "monster": ["close-up among dense foliage", "in an open clearing",
                "silhouetted at the edge of a forest", "framed by rocky "
                "outcrops", "among tall grass and low scrub"],
    "subclass": ["on a weathered war banner", "on a painted heraldic shield",
                 "on a tattered guild standard", "on a stone relief plaque"],
    "feat": ["on a weathered war banner", "on a painted heraldic shield",
             "on a tattered guild standard", "on a stone relief plaque"],
    "background": ["during a quiet morning", "during a rain-drenched day",
                   "at dusk, embers glowing", "in early spring light"],
}

# Her entity'ye deterministik atanan küçük stil farkları — medya-agnostik.
STYLE_FLAVOR = [
    "bold confident strokes",
    "loose sketchy marks",
    "soft blended edges",
    "crisp detailed lines",
    "gritty worn texture",
]

# Tipe göre çerçeveleme (stil değil, kompozisyon).
FRAMING = {
    "monster":    "full body creature portrait, three-quarter view",
    "spell":      "abstract magical effect, swirling arcane energy",
    "magic-item": "single object still life, dominant centerpiece",
    "subclass":   "heraldic emblem, symbolic icon",
    "feat":       "heraldic emblem, symbolic icon",
    "background": "atmospheric character scene",
    "subspecies": "character portrait, bust framing",
    "species":    "character portrait, bust framing",
}

# species/subspecies çerçevelemesi — kullanıcı: "tek bir birey (portre ya da
# boydan) GÖSTER; birden fazla farklı birey değil; ama bir KALABALIK olabilir."
# → deterministik karışım: ya tek birey ya da kalabalık, ikisinin ortası yok.
SPECIES_FRAMING = [
    "a single individual, character portrait, bust framing",
    "a single individual, full-body figure",
    "a single individual in profile, half-body framing",
    "a small crowd of the people, gathered together",
]

# description'ı saf mekanik olan tipler — sadece isimden prompt kurulur.
NAME_ONLY_TYPES = {
    "feat": "a martial or arcane talent",
    "subclass": "a fantasy adventurer archetype",
    "background": "a life before adventuring",
    # species/subspecies description'ı da mekanik ("Giant-blooded Medium folk with
    # a chosen ... Giant ancestry boon") — modele canon görünüş yerine kural
    # kelimelerini çizdiriyordu (Goliath -> dev). Canon görünüş subject_cache'ten gelir.
    "species": "a fantasy people",
    "subspecies": "a fantasy people",
}

# species/subspecies çapası — bunlar oynanabilir HALKLAR, canavar değil.
SPECIES_ANCHOR = ("a playable player-character ancestry of the world, "
                  "one ordinary humanoid person, everyday adventurer "
                  "proportions, seen at eye level")

# Subject'teki boy/ölçek ifadeleri model'e kıyas yaptırıyor: yanına minik bir
# kalabalık koyup figürü dev çiziyor (Goliath -> ogre). Boy bilgisi resimde
# zaten görünmez; species/subspecies'te temizlenir.
SCALE_RE = re.compile(
    r"\b(towering|colossal|gigantic|giant-?like|hulking|massive|immense|"
    r"imposing|looming|monstrous|standing (over |nearly |roughly |about )?"
    r"[\w-]+ (to [\w-]+ )?(feet|foot|ft) tall|"
    r"[\w-]+([- ]to[- ][\w-]+)?[- ](feet|foot|ft)([- ](tall|high|in height))?|"
    r"(head and shoulders|far) above [\w ]+)\b[,\s]*", re.I)

# Entity -> salt-görsel subject önbelleği (subject_gen.py doldurur). Kural/lore
# metni yerine modele "ne çizileceğini" net söyleyen görsel betim. Boşsa fallback'e
# düşülür. Prompt'u değil subject'i değiştirir; stil/renk/zemin katmanları aynı kalır.
_SUBJECT_CACHE: dict[str, str] = {}


def load_subject_cache(path: Path) -> None:
    global _SUBJECT_CACHE
    if path.is_file():
        try:
            _SUBJECT_CACHE = json.loads(path.read_text())
        except Exception:
            _SUBJECT_CACHE = {}

_MD = re.compile(r"[*_`#>|]|\[\[|\]\]")
_DICE = re.compile(r"\b\d+d\d+(\s*[+-]\s*\d+)?\b|\bDC\s*\d+\b|\b[+-]\d+\s+to hit\b", re.I)
_WS = re.compile(r"\s+")


def _hash(uuid: str, salt: int = 0) -> int:
    """UUID'den deterministik sayı — tire'lerden bağımsız, salt destekli."""
    return int("".join(uuid.replace("-", "")[salt % 24:][:6] or "0"), 16)


def clean_prose(text: str, max_words: int = 45) -> str:
    """Markdown ve kural notasyonunu at; modele tablo/sayı çizdirme."""
    for cut in ("At Higher Levels", "Cantrip Upgrade", "***", "\n\n**"):
        i = text.find(cut)
        if i > 40:
            text = text[:i]
    text = _MD.sub(" ", text)
    text = _DICE.sub(" ", text)
    text = _WS.sub(" ", text).strip()
    return " ".join(text.split()[:max_words])


def lookup(attrs: dict, key: str) -> str:
    v = attrs.get(key)
    return (v or {}).get("name", "") if isinstance(v, dict) else ""


def tidy_name(name: str) -> str:
    """'Aboleth, Nihilith' -> 'Nihilith Aboleth' (open5e varyant konvansiyonu)."""
    if name.count(",") == 1:
        base, variant = (p.strip() for p in name.split(","))
        if base and variant and len(variant.split()) <= 3:
            return f"{variant} {base}"
    return name


def monster_prompt(name: str, a: dict) -> str:
    """Pack canavarlarının %100'ünde description boş — yapısal alanlardan sentezle."""
    size, ctype = lookup(a, "size_ref"), lookup(a, "creature_type_ref")
    kind = f"{size.lower()} {ctype.lower()}".strip() or "creature"
    bits = [tidy_name(name), f"a {kind}"]

    if a.get("speed_fly_ft"):
        bits.append("winged, in flight" if not a.get("can_hover") else "hovering, winged")
    if a.get("speed_swim_ft"):
        bits.append("aquatic")
    if a.get("speed_burrow_ft"):
        bits.append("burrowing, earth-caked")
    if any(lookup(s, "sense_ref") == "Darkvision" for s in a.get("senses") or []):
        bits.append("glowing eyes")

    align = lookup(a, "alignment_ref").lower()
    if "evil" in align:
        bits.append("menacing, sinister")
    elif "good" in align:
        bits.append("noble bearing")

    try:
        cr = float(str(a.get("cr", "0")).split("/")[0] or 0)
    except ValueError:
        cr = 0.0
    bits.append("towering and legendary" if cr >= 15 else "formidable" if cr >= 5 else "")

    return ", ".join(b for b in bits if b)


def style_for(pkg: str) -> str:
    return PACKAGE_STYLE.get(pkg, PACKAGE_STYLE[DEFAULT_PACKAGE])


def palette_for(pkg: str, t: str) -> str:
    base = PACKAGE_PALETTE.get(pkg, PACKAGE_PALETTE[DEFAULT_PACKAGE])
    accent = CATEGORY_PALETTE[t]
    return f"{base}, {accent}"


def mood_for(pkg: str, t: str, uuid: str) -> str:
    light = PACKAGE_LIGHT.get(pkg, PACKAGE_LIGHT[DEFAULT_PACKAGE])
    if pkg in PACKAGE_BG and t in PACKAGE_BG[pkg]:
        bg = PACKAGE_BG[pkg][t]
    else:
        bg = CATEGORY_BG[t]
        flavor = BG_FLAVOR.get(t)
        if flavor:
            bg = f"{bg}, {flavor[_hash(uuid) % len(flavor)]}"
    return f"{light}, {bg}"


def build_prompt(uuid: str, pkg: str, row: dict) -> dict | None:
    t = row.get("type")
    if t not in ART_TYPES:
        return None
    name = (row.get("name") or "").strip()
    if not name:
        return None
    attrs = row.get("attributes") or {}
    raw_desc = row.get("description") or ""

    if t == "monster":
        subject = monster_prompt(name, attrs)
    elif t in NAME_ONLY_TYPES:
        # Bu tiplerin description'ı saf kural metni ("+1 to Wisdom") — resmedilemez.
        subject = f"{tidy_name(name)}, {NAME_ONLY_TYPES[t]}"
    else:
        desc = clean_prose(raw_desc)
        subject = f"{tidy_name(name)}, {desc}" if desc else tidy_name(name)
        if t == "spell":
            school = lookup(attrs, "school_ref")
            if school:
                subject += f", {school.lower()} magic"
        elif t == "magic-item":
            rarity = lookup(attrs, "rarity_ref")
            if rarity:
                subject += f", {rarity.lower()} artifact"

    cached = _SUBJECT_CACHE.get(uuid)
    if cached:
        subject = f"{tidy_name(name)}, {cached}"

    if t in ("species", "subspecies"):
        framing = SPECIES_FRAMING[_hash(uuid, 3) % len(SPECIES_FRAMING)]
    else:
        framing = FRAMING[t]

    pkg_title = PACKAGE_TITLE.get(pkg, pkg)
    subject_label = name
    if t in ("species", "subspecies"):
        # "Goliath" tek başına modele incil devini çizdiriyor. İsmi halk adı
        # olarak niteleyip pozitif bir insan-ölçeği çapası ekliyoruz (Flux'ta
        # negasyon ters teptiği için "dev değil" DEMİYORUZ, ne olduğunu diyoruz).
        subject_label = f"a person of the {tidy_name(name)} folk"
    header = (f"An image of {subject_label}, from category {t} "
              f"in package {pkg_title} from Dungeons and Dragons (DnD).")

    # Subject'ten name prefix'ini kaldır — header zaten name'i içeriyor.
    # LLM bazen subject'i de isimle başlatıyor ("Goliath A towering..."), o yüzden
    # tekrar eden her baş-isim soyulur; aksi halde isim tokenı iki kez ağırlık alır.
    subject_body = subject
    while True:
        stripped = re.sub(rf"^{re.escape(tidy_name(name))}[,:\s-]+", "",
                          subject_body, flags=re.I)
        if stripped == subject_body:
            break
        subject_body = stripped
    subject_body = subject_body.rstrip(". ")  # çift noktayı önle
    if t in ("species", "subspecies"):
        subject_body = SCALE_RE.sub("", subject_body).lstrip(", ")
        subject_body = f"{SPECIES_ANCHOR}, {subject_body}"

    style = f"{style_for(pkg)}, {STYLE_TAIL}"
    flavor = STYLE_FLAVOR[_hash(uuid, 5) % len(STYLE_FLAVOR)]
    return {
        "uuid": uuid,
        "package": pkg,
        "type": t,
        "name": name,
        "prompt": (f"{header}\n{subject_body}. {FULL_BLEED}, "
                   f"{DND_CONTEXT}, {framing}, "
                   f"{palette_for(pkg, t)}, {mood_for(pkg, t, uuid)}, "
                   f"{style}, {flavor}"),
        "seed": int(uuid[:8], 16),
    }


def load_jobs(packs_dirs: list[Path]) -> list[dict]:
    jobs, seen = [], set()
    for packs_dir in packs_dirs:
        if not packs_dir.is_dir():
            continue
        for pack in sorted(packs_dir.glob("*.pkg.json")):
            data = json.loads(pack.read_text())
            pkg = data.get("package_name") or pack.stem
            entities = data.get("entities", {})
            for uuid, row in entities.items():
                if uuid in seen:
                    continue
                job = build_prompt(uuid, pkg, row)
                if job:
                    seen.add(uuid)
                    jobs.append(job)
    return jobs


def self_check(jobs: list[dict]) -> None:
    assert jobs, "hiç job üretilmedi"
    header_re = re.compile(r"^An image of .+", re.M)
    for j in jobs:
        assert header_re.search(j["prompt"]), f"category header yok: {j['name']}"
        assert STYLE_TAIL in j["prompt"], f"stil kuyruğu yok: {j['name']}"
        assert FULL_BLEED in j["prompt"], f"full-bleed talimatı yok: {j['name']}"
        assert DND_CONTEXT in j["prompt"], f"D&D bağlamı yok: {j['name']}"
        assert any(f in j["prompt"] for f in STYLE_FLAVOR), f"flavor yok: {j['name']}"
        assert "\n" in j["prompt"], f"header newline eksik: {j['name']}"
        assert not re.search(r"[*_`#|]", j["prompt"]), f"markdown artığı: {j['name']}"
        assert j["seed"] == int(j["uuid"][:8], 16), "seed deterministik değil"
        assert 20 < len(j["prompt"]) < 2000, f"prompt boyu bozuk: {j['name']}"
        assert j["package"], f"paket yok: {j['name']}"
    by_type: dict[str, int] = {}
    for j in jobs:
        by_type[j["type"]] = by_type.get(j["type"], 0) + 1
    assert by_type.get("monster", 0) > 2000, "canavarlar eksik"
    print(f"OK — {len(jobs)} job, tipler: {by_type}", file=sys.stderr)


def main() -> None:
    base = Path(__file__).resolve().parent
    p = argparse.ArgumentParser()
    p.add_argument("--packs", type=Path, action="append",
                   default=[Path(__file__).resolve().parents[2] / "flutter_app/assets/open5e_packs",
                            base / "packs"])
    p.add_argument("--out", type=Path, default=base / "art_jobs.jsonl")
    p.add_argument("--sample", type=int, help="her tipten N örnek bas, dosya yazma")
    p.add_argument("--self-check", action="store_true")
    args = p.parse_args()

    load_subject_cache(base / "subject_cache.json")
    jobs = load_jobs(args.packs)

    if args.self_check:
        self_check(jobs)
        return

    if args.sample:
        per: dict[str, int] = {}
        for j in jobs:
            if per.get(j["type"], 0) < args.sample:
                per[j["type"]] = per.get(j["type"], 0) + 1
                print(f"[{j['package']}/{j['type']}] {j['name']}\n  {j['prompt']}\n")
        return

    with args.out.open("w") as f:
        for j in jobs:
            f.write(json.dumps(j, ensure_ascii=False) + "\n")
    by_type: dict[str, int] = {}
    for j in jobs:
        by_type[j["type"]] = by_type.get(j["type"], 0) + 1
    print(f"{len(jobs)} job → {args.out}\n{by_type}")


if __name__ == "__main__":
    main()
