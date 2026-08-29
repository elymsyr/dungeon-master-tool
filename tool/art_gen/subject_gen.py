#!/usr/bin/env python3
"""Entity görsel özniteliği üretir — sunucudaki opencode (opencode-go/mimo-v2.5).

Sorun: difüzyon modeli entity'yi (örn. halfling, Aboleth) "bilmiyor"; prompt'a
verilen kural/lore metni de görselleştirilemez. Bu betik her entity için KISA,
salt GÖRSEL bir "subject" cümleciği üretir ve subject_cache.json'a
(uuid -> subject) yazar. prompts.py build_prompt'ta bu önbelleği kural metni
yerine kullanır.

Üretim yalnızca önbellekte OLMAYAN uuid'ler için yapılır (incremental). Grid testi
için package_grid'ın yazdığı manifest.json'a (seçilen entity'ler) sınırlamak istersen
--manifest verilir; böylece 6760 entity'nin tamamı değil, yalnızca seçilenler işlenir.

Örnek:
    python3 subject_gen.py --manifest grids/pkg_s1234/manifest.json
    python3 subject_gen.py --limit 5 --force     # önbelleği görmezden gel, 5 üret
"""
from __future__ import annotations
import argparse, base64, json, re, subprocess, sys, threading, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prompts import (NAME_ONLY_TYPES, clean_prose, lookup, monster_prompt,
                     tidy_name)

# Sunucudaki opencode erişimi. Zen free tier (mimo-v2.5-free) yanıt vermiyordu;
# ücretli opencode-go provider'ı kullanılıyor. Bu provider --variant desteklemiyor.
SSH_HOST = "sadektech@192.168.1.12"
SSH_PORT = "8772"
OPCODE = "/home/sadektech/.opencode/bin/opencode"
MODEL = "opencode-go/mimo-v2.5"

# Kategoriye göre görsel odak — LLM'e hangi yönleri betimleyeceğini söyler.
CATEGORY_GUIDE = {
    "monster": "body shape, size, skin, scales, fur or feathers, colors, limbs, "
               "notable anatomical features, posture",
    "spell": "the visible magical effect: energy, color, motion, form. No people.",
    "magic-item": "the object's shape, material, surface, ornament, color.",
    "subclass": "a symbolic heraldic emblem representing this adventurer archetype",
    "feat": "a symbolic heraldic emblem representing this talent",
    "background": "a person's appearance: clothing, gear, demeanor",
    "subspecies": "this people's stature, build, skin, hair and eye color, facial "
                  "features, distinguishing traits, typical dress",
    "species": "this people's stature, build, skin, hair and eye color, facial "
               "features, distinguishing traits, typical dress",
}

SYS = (
    "You are a fantasy art director writing the VISUAL SUBJECT description for a "
    "Dungeons & Dragons 5th edition illustration. The painter draws ONLY what you "
    "describe — anything you omit is invented wrongly. Output ONLY the physical "
    "appearance of the subject.\n"
    "Research rule (MOST IMPORTANT): first recall the canonical appearance of "
    "this entity from D&D, Pathfinder, mythology, or its source book. If the "
    "entity is well-known (e.g. Blemmyes, Aboleth, Gnoll, Displacer Beast), "
    "you MUST use its established canonical look — never invent a generic "
    "substitute. Examples of canon: Blemmyes = headless giant with its face on "
    "its chest; Aboleth = huge three-eyed fish with four tentacles, vertical "
    "mouth; Displacer Beast = six-legged panther with two shoulder tentacles. "
    "If you truly have no canonical knowledge, derive the most distinctive "
    "look consistent with the name and description.\n"
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
    "- Output a single comma-separated visual phrase, 40 to 90 words, no markdown, "
    "no quotes, no trailing period.\n"
    "For this subject focus on: {guide}\n"
    "Entity: {name}\n"
    "Category: {category}\n"
    "Package: {package}\n"
    "Game: Dungeons and Dragons 5th Edition (Dnd 5e)\n"
    "Description: {desc}\n"
)

_WS = re.compile(r"\s+")

# LLM reddi / plan-mode gevezeliği — bunlar subject değil, cache'e girmemeli.
_REFUSAL = re.compile(
    r"(\*\*|Question:|\bI (can|could|would|am|will|'m|'ll)\b|"
    r"\bI can'?t\b|as an AI|plan mode|please provide|let me know|"
    r"\bHowever, I\b|clarify|I need to|"
    r"Based on the|here is the visual|VISUAL SUBJECT DESCRIPTION|"
    r"I'?ll research|before creating|the canonical appearance)", re.I)


def valid_subject(text: str) -> bool:
    """subject gerçekten görsel betim mi? (red/sohbet/markdown ele)"""
    if not text or _REFUSAL.search(text):
        return False
    words = len(text.split())
    return 8 <= words <= 120


def entity_input(row: dict) -> tuple[str, str, str, str]:
    """build_prompt ile aynı girdiyi üretir (LLM'e verilecek metin).
    Döndürür: (type, name, desc, package)."""
    t = row.get("type")
    name = (row.get("name") or "").strip()
    attrs = row.get("attributes") or {}
    pkg = row.get("_package", "")
    if t == "monster":
        desc = monster_prompt(name, attrs)
    elif t in NAME_ONLY_TYPES:
        desc = NAME_ONLY_TYPES[t]
    else:
        desc = clean_prose(row.get("description") or "")
        if t == "spell":
            s = lookup(attrs, "school_ref")
            if s:
                desc += f", {s.lower()} magic"
        elif t == "magic-item":
            r = lookup(attrs, "rarity_ref")
            if r:
                desc += f", {r.lower()} artifact"
    return t, name, desc, pkg


def load_packs(packs_dirs: list[Path]) -> dict[str, dict]:
    """uuid -> row haritası (paketlerden ham satırlar). '_package' eklenir."""
    out = {}
    for packs_dir in packs_dirs:
        if not packs_dir.is_dir():
            continue
        for pack in sorted(packs_dir.glob("*.pkg.json")):
            data = json.loads(pack.read_text())
            pkg_title = data.get("package_name") or pack.stem
            for uuid, row in (data.get("entities") or {}).items():
                if row.get("type") not in NAME_ONLY_TYPES and row.get("type") not in (
                        "monster", "spell", "magic-item", "background",
                        "subspecies", "species"):
                    continue
                row["_package"] = pkg_title
                out.setdefault(uuid, row)
    return out


def build_message(t: str, name: str, desc: str, pkg: str) -> str:
    return SYS.format(guide=CATEGORY_GUIDE[t], name=name, category=t,
                      package=pkg, desc=desc or name)


def remote_subject(prompt_text: str, timeout: int = 180) -> str:
    """Sunucudaki opencode'a tek atış gönderir, temiz metni döner.
    Sunucuda çalışıyorsa SSH yerine doğrudan opencode çağırır."""
    import socket
    try:
        hostname = socket.gethostname()
        on_server = "sadektech" in hostname or \
                     socket.gethostbyname(hostname) == "192.168.1.12"
    except Exception:
        on_server = False

    b64 = base64.b64encode(prompt_text.encode()).decode()
    remote_cmd = (
        "p=$(base64 -d <<'B64E'\n" + b64 + "\nB64E\n) && "
        f"{OPCODE} run -m {MODEL} --format json \"$p\""
    )
    if on_server:
        r = subprocess.run(["bash", "-c", remote_cmd],
                           capture_output=True, text=True, timeout=timeout)
    else:
        ssh = ["ssh", "-p", SSH_PORT, "-o", "ConnectTimeout=10", SSH_HOST, remote_cmd]
        r = subprocess.run(ssh, capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        raise RuntimeError((r.stderr or r.stdout)[-500:])
    return extract_text(r.stdout)


def extract_text(stdout: str) -> str:
    parts = []
    for line in stdout.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except Exception:
            continue
        if ev.get("type") == "text":
            parts.append((ev.get("part") or {}).get("text", ""))
    text = " ".join(parts).strip()
    text = re.sub(r"[*_`#>|]|\[\[|\]\]", " ", text)  # markdown artığı at
    text = re.sub(r"\s+", " ", text).strip(" ,.")
    return text


def main() -> None:
    base = Path(__file__).resolve().parent
    p = argparse.ArgumentParser()
    p.add_argument("--packs", type=Path, action="append",
                   default=[Path(__file__).resolve().parents[2] / "flutter_app/assets/open5e_packs",
                            base / "packs"])
    p.add_argument("--cache", type=Path, default=base / "subject_cache.json")
    p.add_argument("--manifest", type=Path, help="package_grid'ın manifest.json'u "
                                                 "(yalnızca seçilen uuid'ler)")
    p.add_argument("--uuids", type=Path, help="satır başına bir uuid içeren dosya")
    p.add_argument("--limit", type=int, help="en fazla N entity üret")
    p.add_argument("--force", action="store_true", help="önbelleği görmezden gel")
    p.add_argument("--retries", type=int, default=2)
    p.add_argument("--workers", type=int, default=4,
                   help="paralel SSH+LLM isteği sayısı")
    args = p.parse_args()

    cache: dict[str, str] = {}
    if args.cache.is_file():
        try:
            cache = json.loads(args.cache.read_text())
        except Exception:
            cache = {}

    rows = load_packs(args.packs)

    wanted: set[str] = set()
    if args.manifest:
        man = json.loads(args.manifest.read_text())
        wanted = {m["uuid"] for m in man}
    elif args.uuids:
        wanted = {l.strip() for l in args.uuids.read_text().splitlines() if l.strip()}
    else:
        wanted = set(rows)

    todo = [u for u in wanted if args.force or u not in cache]
    if args.limit:
        todo = todo[: args.limit]

    if not todo:
        print(f"önbellekte hepsi var ({len(cache)}). Üretilecek yok.", file=sys.stderr)
        return

    from concurrent.futures import ThreadPoolExecutor, as_completed

    print(f"{len(todo)} entity üretilecek (önbellek={len(cache)}, "
          f"workers={args.workers}).", file=sys.stderr)

    t0 = time.time()

    def generate(uuid: str) -> tuple[str, str, str, str, str]:
        """Tek uuid için subject üretir; başarısızda subject boş döner."""
        row = rows.get(uuid)
        if not row:
            return uuid, "", "", "", "satır bulunamadı"
        t, name, desc, pkg = entity_input(row)
        msg = build_message(t, name, desc, pkg)
        subject = ""
        last_err: Exception | None = None
        for _ in range(args.retries + 1):
            try:
                subject = remote_subject(msg)
                if valid_subject(subject):
                    break
                subject = ""
            except Exception as e:  # noqa: BLE001
                last_err = e
        err = "" if subject else str(last_err)
        return uuid, t, name, subject, err

    lock = threading.Lock()
    done = 0
    errors = 0
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(generate, u) for u in todo]
        for fut in as_completed(futures):
            uuid, t, name, subject, err = fut.result()
            with lock:
                if subject:
                    cache[uuid] = subject
                else:
                    errors += 1
                    print(f"!!! HATA {name}: {err[:200]}", file=sys.stderr)
                done += 1
                if done % 10 == 0 or done == len(todo):
                    args.cache.write_text(
                        json.dumps(cache, ensure_ascii=False, indent=1))
            print(f"[{done}/{len(todo)}] {t} {name} -> {subject[:80]}",
                  file=sys.stderr)

    args.cache.write_text(json.dumps(cache, ensure_ascii=False, indent=1))
    print(f"bitti: {len(cache)} subject -> {args.cache} "
          f"({time.time() - t0:.0f}s, hata={errors})", file=sys.stderr)


if __name__ == "__main__":
    main()