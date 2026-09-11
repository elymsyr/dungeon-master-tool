#!/usr/bin/env python3
"""Aegis world blueprint'inden Flux prompt'u üretir.

Blueprint formatındaki tüm 126 entity'i (14 kategori) kapsar.
Çıktı: aegis_art_jobs.jsonl — her satır {uuid, category, name, prompt, seed}.

Kullanım:
    python3 aegis_prompts.py                           # tüm entity'ler
    python3 aegis_prompts.py --sample 2                # her tipten 2 örnek
    python3 aegis_prompts.py --category npc --limit 5  # yalnızca NPC'ler
"""
from __future__ import annotations
import argparse, json, re, sys, uuid as _uuid
from pathlib import Path

# ---------------------------------------------------------------------------
# Blueprint yolu
# ---------------------------------------------------------------------------
BLUEPRINT = (Path(__file__).resolve().parents[2]
             / "flutter_app/assets/worlds/aegis/aegis-act1/world-blueprint.json")

# ---------------------------------------------------------------------------
# UUIDv5 — category/source_name'den stabil, deterministik UUID üretir.
# ---------------------------------------------------------------------------
_NAMESPACE = _uuid.UUID("a1e5a150-0000-5000-8000-0000a15e0000")

def entity_uuid(category: str, source_name: str) -> str:
    return str(_uuid.uuid5(_NAMESPACE, f"{category}/{source_name}"))

# ---------------------------------------------------------------------------
# Anti-AI skeleton — prompts.py ile aynı prensip.
# "digital art / concept art / render / masterpiece" gibi kelimeler TETİKLEYİCİ.
# ---------------------------------------------------------------------------
STYLE_TAIL = (
    "subtle tonal variation across surfaces, "
    "slightly uneven hand-drawn edges, "
    "irregular handmade pigment density, "
    "classic fantasy tabletop roleplaying game art"
)

FULL_BLEED = (
    "full-bleed square artwork, edge-to-edge composition, "
    "no margins, no border, no frame, no vignette, "
    "environment extends to all edges"
)

DND_CONTEXT = "Dungeons & Dragons 5th edition tabletop roleplaying game illustration"

# ---------------------------------------------------------------------------
# Aegis世界 — tek paket, tek stil.
# D&D 5e SRD oil painting tarzı aynen kullanılır.
# ---------------------------------------------------------------------------
AEGIS_STYLE = (
    "hand-painted oil painting on canvas, "
    "expressive painterly brushstrokes, matte finish"
)

AEGIS_PALETTE = (
    "deep earthy tones, weathered parchment hues, "
    "warm amber and cool slate, muted jewel accents"
)

AEGIS_LIGHT = (
    "warm filtered light through old windows, "
    "soft candlelit shadows, dusty golden hour"
)

# ---------------------------------------------------------------------------
# Metin temizleme — markdown, kural notasyonu, referansları at.
# ---------------------------------------------------------------------------
_MD = re.compile(r"[*_`#>|]|\[\[|\]\]")
_REFS = re.compile(r"@\[[^\]]*\]\([^)]*\)")
_DICE = re.compile(r"\b\d+d\d+(\s*[+-]\s*\d+)?\b|\bDC\s*\d+\b|\b[+-]\d+\s+to hit\b", re.I)
_WS = re.compile(r"\s+")


def clean_text(text: str, max_words: int = 60) -> str:
    """Markdown ve referans notasyonunu at; modelo salt görsel metin ver."""
    # Mekanik/kural bloklarını kes — en yüksek öncelik
    for cut in ("**Açtığı kapı", "**Açtığı kapılar", "Açtığı kapı",
                "**Mekanik", "Mekanik etki", "**Kural", "Bu kural",
                "**Taktik", "Taktik yok", "**Dönüşmüş", "İlk turunda",
                "**Kesik Kesik", "Masanın", "kurtarma şansı yok",
                "yarısının altına düştüğünde",
                "*Yakın dövüş saldırısı:", "**Vuruş:",
                "Kapıların:", "Bedelin:", "Bedel:", "Açtığı kapılar:",
                "Satırların arasındaki boşluğu"):
        i = text.find(cut)
        if i >= 0:
            text = text[:i]
    # Kural kalıntılarını temizle
    text = _REFS.sub("", text)
    text = _MD.sub(" ", text)
    text = _DICE.sub(" ", text)
    # "X ft", "X cp", "X gp" gibi ölçü birimlerini temizle
    text = re.sub(r"\b\d+\s*(?:ft|cp|gp|lb|lbs)\b", "", text, flags=re.I)
    # Mekanik terimleri temizle — "yarı" hariç (yarı-elf gibi ırk adlarında kullanılır)
    text = re.sub(r"\b(?:isabet|hasar|ertesi|turunda|zarı|zarını|"
                  r"kurtarma|başarısızlıkta|hedefle|tetikle|yürürler|"
                  r"alırlar|kaçırır|vurur|kritik|atağı)\b",
                  "", text, flags=re.I)
    # "(" ile başlayan parça numaralarını temizle (örn. "7)." veya "ort. 7)")
    text = re.sub(r"\(?\bort\.?\s*\d+\)?", "", text)
    text = re.sub(r"\b\d+\)\.?\s*", "", text)
    text = _WS.sub(" ", text).strip()
    # Markdown artığı: baştaki tek tireyi temizle (örn. "*Yarı-elf" → "-elf" → "elf")
    text = re.sub(r"^-+\s*", "", text)
    # Çok kısa kaldıysa (saf kural metni) boş dön
    words = text.split()
    if len(words) < 5:
        return ""
    return " ".join(words[:max_words])


def extract_subject(name: str, category: str, mapping: dict) -> str:
    """Entity'den salt görsel subject cümleciği üretir.

    Her kategoride yalnızca kullanıcının seçtiği alanlar kullanılır.
    """
    # -- campaign / lore / quest / trinket → sadece description
    if category in ("campaign", "lore", "quest", "trinket"):
        return clean_text(mapping.get("description", ""), max_words=50)

    # -- location → environment + description_long
    if category == "location":
        env = (mapping.get("environment") or "").strip()
        desc_long = (mapping.get("description_long") or "").strip()
        combined = f"{env}. {desc_long}" if env else desc_long
        return clean_text(combined, max_words=50)

    # -- npc → appearance (birincil) + mannerisms, description, faction,
    #           species_ref, location_ref (bağlam için)
    if category == "npc":
        appearance = (mapping.get("appearance") or "").strip()
        if appearance:
            subject = clean_text(appearance, max_words=50)
        else:
            subject = clean_text(mapping.get("description", ""), max_words=50)
        # Bağlam ekleri — subject'in sonuna, görselliği bozmadan
        extras = []
        m = (mapping.get("mannerisms") or "").strip()
        if m:
            cleaned_m = clean_text(m, max_words=20)
            if cleaned_m:
                extras.append(cleaned_m)
        species = (mapping.get("species_ref") or {}).get("value", "")
        if species and species.lower() not in subject.lower():
            extras.append(f"{species.lower()} person")
        loc = (mapping.get("location_ref") or {}).get("value", "")
        if loc:
            extras.append(f"from {loc}")
        if extras:
            subject = f"{subject}, {', '.join(extras)}"
        return subject

    # -- monster → description + size_ref, creature_type_ref, stat_block
    if category == "monster":
        desc = (mapping.get("description") or "").strip()
        parts = []
        if desc:
            parts.append(clean_text(desc, max_words=45))
        size = (mapping.get("size_ref") or {}).get("value", "")
        ctype = (mapping.get("creature_type_ref") or {}).get("value", "")
        if size and ctype:
            parts.append(f"a {size.lower()} {ctype.lower()}")
        stat = mapping.get("stat_block") or {}
        if stat:
            # En yüksek stat'ı ekle (görsel ipucu)
            top_stat = max(stat.items(), key=lambda x: x[1] if isinstance(x[1], int) else 0)
            if top_stat[1] >= 16:
                parts.append(f"strong {top_stat[0].lower()}")
        return ", ".join(parts) if parts else name

    # -- creature-action → description + attack_kind, damage_type_ref
    if category == "creature-action":
        desc = (mapping.get("description") or "").strip()
        # Görsel cümleleri ayıkla (kural metnini at)
        parts = [p.strip() for p in re.split(r"[.]\s*", desc) if p.strip()]
        visual_parts = []
        for part in parts:
            if re.search(r"\d+d\d+|\+[\d]+|isabet|hasar|erişim|\d+\s*ft|"
                         r"tek hedef|yakın dövüş|ort\.\s*\d", part, re.I):
                continue
            visual_parts.append(part)
        if visual_parts:
            cleaned = clean_text(". ".join(visual_parts), max_words=40)
            if len(cleaned.split()) >= 3:
                # attack_kind ve damage_type_ref ekle
                kind = (mapping.get("attack_kind") or "").strip()
                dmg = (mapping.get("damage_type_ref") or {}).get("value", "")
                extras = []
                if kind:
                    extras.append(f"{kind.lower()} attack")
                if dmg:
                    extras.append(f"{dmg.lower()} damage")
                if extras:
                    cleaned = f"{cleaned}, {', '.join(extras)}"
                return cleaned
        # Fallback
        kind = (mapping.get("attack_kind") or "melee").strip()
        dmg = (mapping.get("damage_type_ref") or {}).get("value", "")
        suffix = f", {dmg.lower()} damage" if dmg else ""
        return f"a {kind.lower()} claw attack, feral and brutal{suffix}"

    # -- trait → description + benefits + trait_kind
    if category == "trait":
        benefits = (mapping.get("benefits") or "").strip()
        desc = (mapping.get("description") or "").strip()
        kind = (mapping.get("trait_kind") or "").strip()
        # Önce benefits'i dene (meta-anlatım)
        cleaned_b = clean_text(benefits, max_words=40)
        if len(cleaned_b.split()) >= 5:
            if kind:
                cleaned_b = f"{cleaned_b}, {kind.lower()} ability"
            return cleaned_b
        # Sonra description
        cleaned_d = clean_text(desc, max_words=40)
        if len(cleaned_d.split()) >= 5:
            if kind:
                cleaned_d = f"{cleaned_d}, {kind.lower()} ability"
            return cleaned_d
        # Fallback: tag'lardan görsel ipucu
        tags = mapping.get("tags", [])
        if "blight" in tags or "dönüşmüş" in tags:
            return "dark corrupted magical energy, blight corruption, ominous supernatural effect"
        return f"a {kind.lower()} magical effect, abstract symbol" if kind else "a magical effect, abstract symbol"

    # -- curse → description + trigger + effect + mechanical_notes + removed_by
    if category == "curse":
        fields = ["description", "trigger", "effect", "mechanical_notes", "removed_by"]
        combined = ". ".join(
            (mapping.get(f) or "").strip()
            for f in fields if mapping.get(f)
        )
        return clean_text(combined, max_words=60)

    # -- scene → description + beats + location_ref
    if category == "scene":
        desc = (mapping.get("description") or "").strip()
        beats = (mapping.get("beats") or "").strip()
        loc = (mapping.get("location_ref") or {}).get("value", "")
        combined = f"{desc}. {beats}" if beats else desc
        if loc:
            combined = f"{combined} (at {loc})"
        return clean_text(combined, max_words=60)

    # -- encounter → description + setup + tactics + difficulty + location_ref + monsters_refs
    if category == "encounter":
        fields = ["description", "setup"]
        parts = [(mapping.get(f) or "").strip() for f in fields if mapping.get(f)]
        # difficulty ve location_ref'den sahne kur
        diff = (mapping.get("difficulty") or "").strip()
        loc = (mapping.get("location_ref") or {}).get("value", "")
        if diff:
            parts.append(f"a {diff.lower()} encounter")
        if loc:
            parts.append(f"at {loc}")
        combined = ". ".join(parts)
        return clean_text(combined, max_words=50)

    # -- adventuring-gear → description + weight_lb + consumable
    if category == "adventuring-gear":
        desc = (mapping.get("description") or "").strip()
        parts = [clean_text(desc, max_words=45)]
        w = mapping.get("weight_lb")
        if w:
            parts.append(f"weighs {w} lb")
        c = mapping.get("consumable")
        if c is True:
            parts.append("consumable item")
        return ", ".join(parts)

    # -- background → description + granted_skill_refs, granted_tool_refs
    if category == "background":
        desc = (mapping.get("description") or "").strip()
        cleaned = clean_text(desc, max_words=45)
        # Skill/tool referencia isimlerini ekle (görsel ipucu)
        skills = mapping.get("granted_skill_refs") or []
        skill_names = [s.get("value", "") for s in skills if s.get("value")]
        tools = mapping.get("granted_tool_refs") or []
        tool_names = [t.get("value", "") for t in tools if t.get("value")]
        extras = skill_names[:2] + tool_names[:1]
        if extras:
            cleaned = f"{cleaned}, skilled in {', '.join(extras)}"
        return cleaned

    # -- fallback
    return clean_text(mapping.get("description", ""), max_words=50)


# ---------------------------------------------------------------------------
# Deterministik hash — UUID'den küçük sayı üretir (flavor seçimleri için).
# ---------------------------------------------------------------------------
def _hash(uid: str, salt: int = 0) -> int:
    return int("".join(uid.replace("-", "")[salt % 24:][:6] or "0"), 16)


# ---------------------------------------------------------------------------
# Prompt inşaatı
# ---------------------------------------------------------------------------
STYLE_FLAVOR = [
    "bold confident strokes",
    "loose sketchy marks",
    "soft blended edges",
    "crisp detailed lines",
    "gritty worn texture",
]


def build_prompt(uid: str, category: str, name: str, mapping: dict) -> dict | None:
    """Tek bir entity için Flux prompt üretir."""
    if not name:
        return None

    subject = extract_subject(name, category, mapping)
    if not subject:
        return None

    header = f"{name}, Aegis {category}"

    # Subject'ten name prefix'ini kaldır (header zaten ismi içeriyor)
    subject_body = subject
    escaped = re.escape(name)
    while True:
        stripped = re.sub(rf"^{escaped}[,:\s-]+", "", subject_body, flags=re.I)
        if stripped == subject_body:
            break
        subject_body = stripped
    subject_body = subject_body.rstrip(". ")

    style = f"{AEGIS_STYLE}, {STYLE_TAIL}"
    flavor = STYLE_FLAVOR[_hash(uid, 5) % len(STYLE_FLAVOR)]

    prompt = (
        f"{header}\n"
        f"{subject_body}. "
        f"{FULL_BLEED}, "
        f"{DND_CONTEXT}, "
        f"{AEGIS_PALETTE}, "
        f"{AEGIS_LIGHT}, "
        f"{style}, "
        f"{flavor}"
    )

    return {
        "uuid": uid,
        "category": category,
        "name": name,
        "prompt": prompt,
        "seed": int(uid[:8], 16),
    }


# ---------------------------------------------------------------------------
# Blueprint okuma
# ---------------------------------------------------------------------------
def load_blueprint(path: Path) -> list[dict]:
    """Blueprint'ten tüm entity'leri okur, art_jobs formatında döner."""
    data = json.loads(path.read_text())
    categories = data.get("categories", {})
    jobs = []

    for cat_name, entities in categories.items():
        for entity in entities:
            source_name = entity.get("source_name", "")
            mapping = entity.get("mapping", {})
            display_name = mapping.get("name", source_name)
            uid = entity_uuid(cat_name, source_name)

            job = build_prompt(uid, cat_name, display_name, mapping)
            if job:
                jobs.append(job)

    return jobs


# ---------------------------------------------------------------------------
# Self-check
# ---------------------------------------------------------------------------
def self_check(jobs: list[dict]) -> None:
    assert jobs, "hiç job üretilmedi"
    header_re = re.compile(r"^.+, Aegis \w+", re.M)
    by_cat: dict[str, int] = {}
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
        by_cat[j["category"]] = by_cat.get(j["category"], 0) + 1
    print(f"OK — {len(jobs)} job, kategoriler: {by_cat}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    p = argparse.ArgumentParser(description="Aegis blueprint → art prompts")
    p.add_argument("--blueprint", type=Path, default=BLUEPRINT,
                   help="world-blueprint.json yolu")
    p.add_argument("--out", type=Path,
                   help="çıktı dosyası (varsayılan: bu dizin/art_jobs.jsonl)")
    p.add_argument("--sample", type=int,
                   help="her kategoriden N örnek bas, dosya yazma")
    p.add_argument("--category", type=str,
                   help="yalnızca belirli bir kategori (örn: npc)")
    p.add_argument("--limit", type=int,
                   help="en fazla N entity üret")
    p.add_argument("--self-check", action="store_true")
    args = p.parse_args()

    if not args.blueprint.is_file():
        print(f"HATA: blueprint bulunamadı: {args.blueprint}", file=sys.stderr)
        sys.exit(1)

    jobs = load_blueprint(args.blueprint)

    if args.category:
        jobs = [j for j in jobs if j["category"] == args.category]

    if args.limit:
        jobs = jobs[:args.limit]

    if args.self_check:
        self_check(jobs)
        return

    if args.sample:
        per: dict[str, int] = {}
        for j in jobs:
            if per.get(j["category"], 0) < args.sample:
                per[j["category"]] = per.get(j["category"], 0) + 1
                print(f"[{j['category']}] {j['name']}\n  {j['prompt']}\n")
        return

    out = args.out or (Path(__file__).resolve().parent / "art_jobs.jsonl")
    with out.open("w") as f:
        for j in jobs:
            f.write(json.dumps(j, ensure_ascii=False) + "\n")

    by_cat: dict[str, int] = {}
    for j in jobs:
        by_cat[j["category"]] = by_cat.get(j["category"], 0) + 1
    print(f"{len(jobs)} job → {out}\n{by_cat}")


if __name__ == "__main__":
    main()
