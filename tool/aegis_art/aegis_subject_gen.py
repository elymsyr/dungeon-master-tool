#!/usr/bin/env python3
"""Aegis entity'leri için Gemini tabanlı subject cache üretir.

art_jobs.jsonl'daki her entity için Gemini API'den salt görsel subject
cümlesi üretir ve aegis_subject_cache.json'a yazar.

Kullanım:
    python3 aegis_subject_gen.py                           # eksikleri üret
    python3 aegis_subject_gen.py --limit 5 --dry-run       # 5 tane test et
    python3 aegis_subject_gen.py --force                    # cache'i görmezden gel
"""
from __future__ import annotations
import argparse, json, os, re, sys, time
import urllib.error, urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from aegis_prompts import BLUEPRINT, load_blueprint, extract_subject

# ---------------------------------------------------------------------------
# Gemini config
# ---------------------------------------------------------------------------
GEMINI_MODEL = "gemini-3.5-flash-lite"
GEMINI_URL = ("https://generativelanguage.googleapis.com/v1beta/models/"
              "{model}:generateContent")

# ---------------------------------------------------------------------------
# Kategoriye göre LLM'e söylenen odak — neyi betimleyeceğini yönlendirir.
# ---------------------------------------------------------------------------
CATEGORY_GUIDE = {
    "campaign":        "panoramic landscape, key landmarks, dominant terrain, sky conditions, atmosphere of the world",
    "lore":            "symbolic imagery representing the concept, iconographic elements, visual metaphor for the idea",
    "location":        "architecture style and materials, terrain type, spatial layout, dominant features (columns, doorways, trees), atmospheric particles (dust, fog, smoke)",
    "npc":             "facial structure and expression, hair style and color, clothing layers and fabrics, jewelry or scars or tattoos, posture and stance, species-specific traits (ears, horns, skin tone), held items or weapons",
    "monster":         "body proportions and silhouette, limb count and shape, skin texture (scales, fur, chitin, hide), head shape and jaw, teeth/horns/claws, tail, wings, color pattern, size relative to frame",
    "creature-action":  "dynamic pose mid-motion, weapon or limb in action, motion blur lines, impact point, body tension, attack angle",
    "trait":           "abstract symbol or emblem, heraldic or natural motif, magical energy pattern, visual representation of the ability's effect",
    "curse":           "dark imagery, corruption visuals on skin or environment, ominous symbols, cracked or decayed surfaces, unnatural coloring",
    "scene":           "figures in the scene, environment details, action being performed, mood of the moment, spatial relationships between characters, key objects",
    "encounter":       "combatants and their positions, environment features, tactical layout, tension indicators (raised weapons, defensive stances), scale of threat",
    "quest":           "symbolic imagery of the journey or goal, visual metaphors, path or destination, key artifacts involved",
    "adventuring-gear": "object shape and proportions, material (wood, metal, leather, cloth), surface details (scratches, engravings, stitching), color, wear and age, scale relative to hand",
    "trinket":         "object shape, material and texture, ornamentation, surface detail and patina, color, scale in palm",
    "background":      "person in their professional setting, tools of the trade, clothing appropriate to role, environment that reflects the background, posture suggesting their occupation",
}

# ---------------------------------------------------------------------------
# System prompt
# ---------------------------------------------------------------------------
SYS = (
    "You are a fantasy art director writing the VISUAL SUBJECT description for a "
    "Dungeons & Dragons 5th edition illustration. The painter draws ONLY what you "
    "describe — anything you omit is invented wrongly. Output ONLY the physical "
    "appearance of the subject.\n"
    "Detail rule: give CONCRETE visual facts, not abstractions. Name exact "
    "body parts, their number, size relative to the body, and their colors. "
    "Prefer 'six spindly legs, glossy black carapace, glowing amber eyes' over "
    "'insectoid creature'.\n"
    "Distinctive-feature rule (MANDATORY): the description MUST name the "
    "entity's signature, identity-defining features — the things that make "
    "someone say 'that is unmistakably a <name>'. Horns, mane, tail shape, "
    "wing span, weapon, crown, scars, extra heads, glowing eyes, rune "
    "markings, weapon or gear — whatever sets THIS entity apart from a generic "
    "member of its kind. A subject with no distinguishing feature is a failed "
    "answer; never produce a bland generic description.\n"
    "Composition rule: describe the subject as seen from waist-up or full-body, "
    "framed to fill a square canvas. The subject must touch or nearly touch at "
    "least two edges of the frame. Never describe a face-only close-up or a "
    "tiny figure floating in empty space.\n"
    "Rules:\n"
    "- State observable attributes only: body shape, size, proportions, skin, "
    "scales, fur or feathers, hair and eye color, number and kind of limbs, "
    "notable anatomical features, typical posture.\n"
    "- NEVER mention artistic style, medium, quality, or rendering. Banned words: "
    "photorealistic, realistic, cinematic, hyperreal, detailed, sharp, crisp, vivid, "
    "glossy, shiny, polished, reflective, render, HDR, studio, lighting, "
    "shadow, dramatic, ethereal, spectral, luminescent, luminescence, radiant, "
    "iridescent, shimmering, celestial, misty, swirling.\n"
    "- NEVER make aesthetic judgments, and NEVER mention background, scene, or "
    "lighting (the painterly style is applied separately).\n"
    "- NEVER mention rules, stats, combat, spells, lore, or story.\n"
    "- Output a single comma-separated visual phrase, 40 to 100 words, no markdown, "
    "no quotes, no trailing period.\n"
    "Examples of BAD vs GOOD descriptions:\n"
    "BAD: 'A fearsome dragon with glowing eyes and ethereal wings, dramatic "
    "lighting casting shadows across its majestic form' — uses banned words "
    "(glowing, ethereal, dramatic, majestic), vague, no concrete parts.\n"
    "GOOD: 'A massive red-scaled dragon, three horns per side curving backward, "
    "tattered leathery wings twice the width of its body, smoke curling from "
    "nostrils, thick muscular neck, yellow slit-pupiled eyes, clawed forelimbs "
    "as thick as tree trunks' — concrete, numbered, colored, sized, no banned words.\n"
    "BAD: 'A mysterious elf woman with a beautiful presence' — empty, generic, "
    "no specifics.\n"
    "GOOD: 'A tall moon elf woman, silver-white hair cropped at the jaw, angular "
    "cheekbones, pale blue skin, pointed ears adorned with thin gold hoops, "
    "wearing a deep-blue hooded cloak over layered leather armor, one hand "
    "resting on a curved shortsword hilt' — every detail is observable.\n"
    "For this subject focus on: {guide}\n"
    "Entity: {name}\n"
    "Category: {category}\n"
    "World: Aegis (homebrew D&D 5e setting)\n"
    "Description: {desc}\n"
)

_REFUSAL = re.compile(
    r"(\*\*|Question:|\bI (can|could|would|am|will|'m|'ll)\b|"
    r"\bI can'?t\b|as an AI|plan mode|please provide|let me know|"
    r"\bHowever, I\b|clarify|I need to|"
    r"Based on the|here is the visual|VISUAL SUBJECT DESCRIPTION|"
    r"I'?ll research|before creating)", re.I)


def valid_subject(text: str) -> bool:
    if not text or _REFUSAL.search(text):
        return False
    words = len(text.split())
    return 8 <= words <= 130


def gemini_subject(prompt_text: str, model: str, timeout: int = 120) -> str:
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        raise RuntimeError("GEMINI_API_KEY tanımlı değil")
    body = json.dumps({
        "contents": [{"parts": [{"text": prompt_text}]}],
        "generationConfig": {"temperature": 0.9, "maxOutputTokens": 2048},
    }).encode()
    req = urllib.request.Request(
        GEMINI_URL.format(model=model), data=body,
        headers={"content-type": "application/json", "x-goog-api-key": key})
    for _ in range(6):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                data = json.loads(r.read())
            break
        except urllib.error.HTTPError as e:
            msg = e.read()[:400].decode(errors="replace")
            if e.code not in (429, 503):
                raise RuntimeError(f"HTTP {e.code}: {msg}")
            m = re.search(r'"?retryDelay"?:?\s*"?(\d+(?:\.\d+)?)s', msg)
            time.sleep(min(float(m.group(1)) if m else 20, 60) + 1)
    else:
        raise RuntimeError("429: kota beklemesi 6 kez aşıldı")
    text = " ".join(
        part.get("text", "")
        for c in data.get("candidates", [])
        for part in (c.get("content") or {}).get("parts", []))
    text = re.sub(r"[*_`#>|]|\[\[|\]\]", " ", text)
    return re.sub(r"\s+", " ", text).strip(" ,.")


def build_subject_prompt(job: dict) -> str:
    """Tek bir job için Gemini'ye gönderilecek完整 prompt üretir."""
    name = job["name"]
    category = job["category"]
    guide = CATEGORY_GUIDE.get(category, "visual appearance, distinguishing features")

    # Blueprint'ten ham description'ı al (clean_text öncesi)
    bp = json.load(open(BLUEPRINT))
    for cat_name, entities in bp["categories"].items():
        if cat_name != category:
            continue
        for e in entities:
            if e["mapping"].get("name", e.get("source_name")) == name:
                mapping = e["mapping"]
                # Tüm ilgili alanları topla
                fields = ["description", "appearance", "environment",
                          "description_long", "mannerisms", "benefits",
                          "setup", "beats", "trigger", "effect",
                          "mechanical_notes", "objective", "weight_lb"]
                desc_parts = []
                for f in fields:
                    val = mapping.get(f)
                    if val and isinstance(val, str) and val.strip():
                        desc_parts.append(val.strip())
                # Ref'leri de ekle
                for f in ["species_ref", "location_ref", "damage_type_ref",
                          "size_ref", "creature_type_ref"]:
                    val = mapping.get(f)
                    if isinstance(val, dict) and val.get("value"):
                        desc_parts.append(val["value"])
                desc = ". ".join(desc_parts) if desc_parts else name
                return SYS.format(guide=guide, name=name, category=category, desc=desc)
    return SYS.format(guide=guide, name=name, category=category, desc=name)


def main() -> None:
    base = Path(__file__).resolve().parent
    p = argparse.ArgumentParser()
    p.add_argument("--jobs", type=Path, default=base / "art_jobs.jsonl")
    p.add_argument("--cache", type=Path, default=base / "aegis_subject_cache.json")
    p.add_argument("--limit", type=int, help="en fazla N entity üret")
    p.add_argument("--force", action="store_true", help="önbelleği görmezden gel")
    p.add_argument("--dry-run", action="store_true", help="sadece prompt'ları göster")
    p.add_argument("--model", default=GEMINI_MODEL)
    p.add_argument("--workers", type=int, default=4)
    p.add_argument("--retries", type=int, default=2)
    args = p.parse_args()

    # Job listesini oku
    jobs = [json.loads(line) for line in args.jobs.read_text().splitlines() if line.strip()]

    # Cache
    cache: dict[str, str] = {}
    if args.cache.is_file():
        try:
            cache = json.loads(args.cache.read_text())
        except Exception:
            cache = {}

    todo = [j for j in jobs if args.force or j["uuid"] not in cache]
    if args.limit:
        todo = todo[:args.limit]

    if not todo:
        print(f"önbellekte hepsi var ({len(cache)}). Üretilecek yok.")
        return

    if args.dry_run:
        for j in todo[:10]:
            prompt = build_subject_prompt(j)
            print(f"--- {j['category']}/{j['name']} ---")
            print(prompt[:500])
            print()
        return

    print(f"{len(todo)} üretilecek (önbellek={len(cache)}, workers={args.workers})")
    t0 = time.time()

    def generate(job: dict) -> tuple[str, str, str]:
        uid = job["uuid"]
        prompt = build_subject_prompt(job)
        subject = ""
        last_err = None
        for _ in range(args.retries + 1):
            try:
                subject = gemini_subject(prompt, args.model)
                if valid_subject(subject):
                    break
                subject = ""
            except Exception as e:
                last_err = e
        return uid, job["name"], subject if subject else str(last_err)

    lock = __import__("threading").Lock()
    done = 0
    errors = 0
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(generate, j) for j in todo]
        for fut in as_completed(futures):
            uid, name, result = fut.result()
            with lock:
                if not result.startswith("HTTP") and not result.startswith("429"):
                    cache[uid] = result
                else:
                    errors += 1
                    print(f"!!! HATA {name}: {result[:200]}", file=sys.stderr)
                done += 1
                if done % 10 == 0 or done == len(todo):
                    args.cache.write_text(
                        json.dumps(cache, ensure_ascii=False, indent=1))
            print(f"[{done}/{len(todo)}] {name} -> {result[:80]}")

    args.cache.write_text(json.dumps(cache, ensure_ascii=False, indent=1))
    print(f"bitti: {len(cache)} subject -> {args.cache} "
          f"({time.time() - t0:.0f}s, hata={errors})")


if __name__ == "__main__":
    main()
