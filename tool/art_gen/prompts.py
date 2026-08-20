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
STYLE = (
    "painted fantasy illustration, muted earthy palette, dramatic rim lighting, "
    "matte canvas texture, dark neutral background, centered composition, "
    "clean unmarked surface"
)

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

    return {
        "uuid": uuid,
        "type": t,
        "name": name,
        "prompt": f"{subject}. {FRAMING[t]}, {STYLE}",
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
