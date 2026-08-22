#!/usr/bin/env python3
"""open5e pack'lerinden Flux prompt'u üretir.

Çıktı: art_jobs.jsonl — her satır {uuid, type, name, prompt, seed}.
Seed uuid'den türetilir → aynı entity her koşuda aynı görseli verir.
"""
import argparse, json, re, sys
from pathlib import Path

# Görsele değen tipler. creature-action / trait bir nesne değil, kural cümlesi.
ART_TYPES = {
    "monster", "spell", "magic-item", "subclass",
    "feat", "background", "subspecies", "species",
}

# Stil tutarlılığının ana kaldıracı: her prompt'a kelimesi kelimesine aynı blok.
# Flux'ta negatif prompt yok (cfg 1.0, distilled). "no text/no watermark" yazmak
# modelde tersine çalışıp filigran üretimini TETİKLİYOR — negasyon kullanma.
#
# Araştırma bulgularına göre (2026-08):
# - "digital art / concept art / render / masterpiece / clean / smooth" kelimeleri
#   AI-default görünümünü TETİKLİYOR — bunlardan kaçın.
# - AI'nın en büyük tell'i "uniform micro-noise": her yüzey aynı doku, aynı ton.
#   Çözüm: "subtle tonal variation across surfaces" — gerçek resimde düz alanda
#   bile ton oynaması var.
# - Waxy/sheen yüzeyler AI hissi verir → "matte finish".
# - Medyayı somut adlandır ("oil painting on canvas") + görünür fırça izi.
# - Kusur ipuçları ("slightly uneven hand-painted edges") insan eli hissi verir.
# - "classic fantasy tabletop roleplaying game art" D&D evreni çapasıdır.
# - PALET ve MOOD burada değil, tipe özeldir (aşağıda) — renk paletinin her yeri
#   kullanılır, her kategori tek bir muted banda sıkışmaz.
STYLE = (
    "hand-painted oil painting on canvas, expressive painterly brushstrokes, "
    "subtle tonal variation across surfaces, matte finish, "
    "slightly uneven hand-painted edges, "
    "classic fantasy tabletop roleplaying game art"
)

# Tipe özel renk paleti — D&D sanatı kategoriye göre değişir: büyü parlak,
# canavar zengin doğal, eşya altın/cevher. Kullanıcı isteği: paletin her yeri.
PALETTE = {
    "monster":    "rich natural palette, deep greens, slate blues, ochres, blood red accents",
    "spell":      "vivid arcane palette, violet, emerald, gold, crimson light",
    "magic-item": "rich antique palette, aged gold, burnished copper, deep ruby",
    "subclass":   "heraldic palette, deep crimson, royal blue, antique gold",
    "feat":       "heraldic palette, deep crimson, slate blue, antique gold",
    "background": "warm candlelit palette, amber, russet, deep brown",
    "subspecies": "warm portrait palette, ivory, amber, deep bronze",
    "species":    "warm portrait palette, ivory, amber, deep bronze",
}

# Tipe özel ışık ve zemin — kompozisyon gibi, stili bozmadan kategori kimliği.
MOOD = {
    "monster":    "dramatic chiaroscuro lighting, dark atmospheric background",
    "spell":      "radiant magical glow, luminous energy against deep twilight",
    "magic-item": "museum spotlight, velvet-dark backdrop",
    "subclass":   "ceremonial lighting, dark banner background",
    "feat":       "dramatic side-light, dark banner background",
    "background": "warm candlelight, moody tavern atmosphere",
    "subspecies": "soft window light, deep shadow backdrop",
    "species":    "soft window light, deep shadow backdrop",
}

# Her entity'ye deterministik atanan küçük stil farkları. Amaç: hepsi aynı aileden
# ama birebir karbon kopya olmasın. uuid'in sonraki 4 hex hanesiyle seçilir.
STYLE_FLAVOR = [
    "thick impasto highlights",
    "loose dry-brush texture",
    "soft glazing, sfumato edges",
    "layered palette-knife strokes",
    "gritty weathered surface detail",
]

# Tipe göre çerçeveleme (stil değil, kompozisyon).
FRAMING = {
    "monster":    "full body creature portrait, three-quarter view",
    "spell":      "abstract magical effect, swirling arcane energy, no human figures",
    "magic-item": "single object still life, museum lighting, floating against void",
    "subclass":   "heraldic emblem, symbolic icon",
    "feat":       "heraldic emblem, symbolic icon",
    "background": "atmospheric character scene, full bleed edge to edge",
    "subspecies": "character portrait, bust framing",
    "species":    "character portrait, bust framing",
}

# description'ı saf mekanik olan tipler — sadece isimden prompt kurulur.
NAME_ONLY_TYPES = {
    "feat": "a martial or arcane talent",
    "subclass": "a fantasy adventurer archetype",
    "background": "a life before adventuring",
}

_MD = re.compile(r"[*_`#>|]|\[\[|\]\]")
_DICE = re.compile(r"\b\d+d\d+(\s*[+-]\s*\d+)?\b|\bDC\s*\d+\b|\b[+-]\d+\s+to hit\b", re.I)
_WS = re.compile(r"\s+")


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


def build_prompt(uuid: str, row: dict) -> dict | None:
    t = row.get("type")
    if t not in ART_TYPES:
        return None
    name = (row.get("name") or "").strip()
    if not name:
        return None
    attrs = row.get("attributes") or {}

    if t == "monster":
        subject = monster_prompt(name, attrs)
    elif t in NAME_ONLY_TYPES:
        # Bu tiplerin description'ı saf kural metni ("+1 to Wisdom") — resmedilemez.
        # İsim tek başına çok daha iyi bir görsel ipucu.
        subject = f"{tidy_name(name)}, {NAME_ONLY_TYPES[t]}"
    else:
        desc = clean_prose(row.get("description") or "")
        subject = f"{tidy_name(name)}, {desc}" if desc else tidy_name(name)
        if t == "spell":
            school = lookup(attrs, "school_ref")
            if school:
                subject += f", {school.lower()} magic"
        elif t == "magic-item":
            rarity = lookup(attrs, "rarity_ref")
            if rarity:
                subject += f", {rarity.lower()} artifact"

    flavor = STYLE_FLAVOR[int(uuid[8:12], 16) % len(STYLE_FLAVOR)]
    return {
        "uuid": uuid,
        "type": t,
        "name": name,
        "prompt": f"{subject}. {FRAMING[t]}, {PALETTE[t]}, {MOOD[t]}, {STYLE}, {flavor}",
        "seed": int(uuid[:8], 16),
    }


def load_jobs(packs_dir: Path) -> list[dict]:
    jobs, seen = [], set()
    for pack in sorted(packs_dir.glob("*.pkg.json")):
        entities = json.loads(pack.read_text()).get("entities", {})
        for uuid, row in entities.items():
            if uuid in seen:
                continue
            job = build_prompt(uuid, row)
            if job:
                seen.add(uuid)
                jobs.append(job)
    return jobs


def self_check(jobs: list[dict]) -> None:
    assert jobs, "hiç job üretilmedi"
    for j in jobs:
        assert STYLE in j["prompt"], f"stil son-eki yok: {j['name']}"
        assert any(f in j["prompt"] for f in STYLE_FLAVOR), f"flavor yok: {j['name']}"
        assert not re.search(r"[*_`#|]", j["prompt"]), f"markdown artığı: {j['name']}"
        assert "\n" not in j["prompt"], f"newline kaldı: {j['name']}"
        assert j["seed"] == int(j["uuid"][:8], 16), "seed deterministik değil"
        assert 20 < len(j["prompt"]) < 1200, f"prompt boyu bozuk: {j['name']}"
    by_type: dict[str, int] = {}
    for j in jobs:
        by_type[j["type"]] = by_type.get(j["type"], 0) + 1
    assert by_type.get("monster", 0) > 2000, "canavarlar eksik"
    print(f"OK — {len(jobs)} job, tipler: {by_type}", file=sys.stderr)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--packs", type=Path,
                   default=Path(__file__).resolve().parents[2] / "flutter_app/assets/open5e_packs")
    p.add_argument("--out", type=Path, default=Path("art_jobs.jsonl"))
    p.add_argument("--sample", type=int, help="her tipten N örnek bas, dosya yazma")
    p.add_argument("--self-check", action="store_true")
    args = p.parse_args()

    jobs = load_jobs(args.packs)

    if args.self_check:
        self_check(jobs)
        return

    if args.sample:
        per: dict[str, int] = {}
        for j in jobs:
            if per.get(j["type"], 0) < args.sample:
                per[j["type"]] = per.get(j["type"], 0) + 1
                print(f"[{j['type']}] {j['name']}\n  {j['prompt']}\n")
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
