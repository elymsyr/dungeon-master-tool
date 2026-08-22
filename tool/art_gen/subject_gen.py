#!/usr/bin/env python3
"""Entity görsel özniteliği üretir — sunucudaki opencode (mimo-v2.5-free, low).

Sorun: difüzyon modeli entity'yi (örn. halfling, Aboleth) "bilmiyor"; prompt'a
verilen kural/lore metni de görselleştirilemez. Bu betik her entity için KISA, salt
GÖRSEL bir "subject" cümleciği üretir ve subject_cache.json'a (uuid -> subject)
yazar. prompts.py build_prompt'ta bu önbelleği kural metni yerine kullanır.

Üretim yalnızca önbellekte OLMAYAN uuid'ler için yapılır (incremental). Grid testi
için package_grid'ın yazdığı manifest.json'a (seçilen entity'ler) sınırlamak istersen
--manifest verilir; böylece 6760 entity'nin tamamı değil, yalnızca seçilenler işlenir.

Örnek:
    python3 subject_gen.py --manifest grids/pkg_s1234/manifest.json
    python3 subject_gen.py --limit 5 --force     # önbelleği görmezden gel, 5 üret
"""
import argparse, base64, json, re, subprocess, sys, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prompts import (NAME_ONLY_TYPES, clean_prose, lookup, monster_prompt,
                     tidy_name)

# Sunucudaki opencode erişimi. Model / variant "low" (ucuz, hızlı).
SSH_HOST = "sadektech@192.168.1.12"
SSH_PORT = "8772"
OPCODE = "/home/sadektech/.opencode/bin/opencode"
MODEL = "opencode/mimo-v2.5-free"
VARIANT = "low"

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
    "You are a field naturalist writing an OBJECTIVE EXTERNAL APPEARANCE analysis "
    "for a fantasy bestiary. Output ONLY the physical appearance of the subject, "
    "as neutral factual notes.\n"
    "Rules:\n"
    "- State observable attributes only: body shape, size, proportions, skin, scales, "
    "fur or feathers, hair and eye color, number and kind of limbs, notable "
    "anatomical features, typical posture.\n"
    "- NEVER mention artistic style, medium, quality, or rendering. Banned words: "
    "photorealistic, realistic, cinematic, hyperreal, detailed, sharp, crisp, vivid, "
    "glossy, shiny, polished, glossy, reflective, render, HDR, studio, lighting, "
    "shadow, dramatic.\n"
    "- NEVER make aesthetic judgments, and NEVER mention background, scene, or "
    "lighting (the painterly style is applied separately).\n"
    "- NEVER mention rules, stats, combat, spells, lore, or story.\n"
    "- Output a single comma-separated visual phrase, at most 40 words, no markdown, "
    "no quotes, no trailing period.\n"
    "For this subject focus on: {guide}\n"
    "Entity: {name}\n"
    "Description: {desc}\n"
)

_WS = re.compile(r"\s+")


def entity_input(row: dict) -> tuple[str, str, str]:
    """build_prompt ile aynı girdiyi üretir (LLM'e verilecek metin)."""
    t = row.get("type")
    name = (row.get("name") or "").strip()
    attrs = row.get("attributes") or {}
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
    return t, name, desc


def load_packs(packs_dirs: list[Path]) -> dict[str, dict]:
    """uuid -> row haritası (paketlerden ham satırlar)."""
    out = {}
    for packs_dir in packs_dirs:
        if not packs_dir.is_dir():
            continue
        for pack in sorted(packs_dir.glob("*.pkg.json")):
            data = json.loads(pack.read_text())
            for uuid, row in (data.get("entities") or {}).items():
                if row.get("type") not in NAME_ONLY_TYPES and row.get("type") not in (
                        "monster", "spell", "magic-item", "background",
                        "subspecies", "species"):
                    continue
                out.setdefault(uuid, row)
    return out


def build_message(t: str, name: str, desc: str) -> str:
    return SYS.format(guide=CATEGORY_GUIDE[t], name=name, desc=desc or name)


def remote_subject(prompt_text: str, timeout: int = 180) -> str:
    """Sunucudaki opencode'a tek atış gönderir, temiz metni döner."""
    b64 = base64.b64encode(prompt_text.encode()).decode()
    remote_cmd = (
        "p=$(base64 -d <<'B64E'\n" + b64 + "\nB64E\n) && "
        f"{OPCODE} run -m {MODEL} --variant {VARIANT} --format json \"$p\""
    )
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
    text = re.sub(r"\s+", " ", text).strip(" ,")
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

    print(f"{len(todo)} entity üretilecek (önbellek={len(cache)}). "
          f"~8s/entity → tahmini {len(todo) * 8 // 60}dk.", file=sys.stderr)

    t0 = time.time()
    for i, uuid in enumerate(todo, 1):
        row = rows.get(uuid)
        if not row:
            continue
        t, name, desc = entity_input(row)
        msg = build_message(t, name, desc)
        subject = ""
        for attempt in range(args.retries + 1):
            try:
                subject = remote_subject(msg)
                if subject:
                    break
            except Exception as e:
                last_err = e
        if subject:
            cache[uuid] = subject
            print(f"[{i}/{len(todo)}] {t} {name} -> {subject[:80]}", file=sys.stderr)
        else:
            print(f"!!! HATA {name}: {getattr(last_err, 'strerror', last_err)}",
                  file=sys.stderr)
        if i % 10 == 0 or i == len(todo):
            args.cache.write_text(json.dumps(cache, ensure_ascii=False, indent=1))
        time.sleep(0.3)

    args.cache.write_text(json.dumps(cache, ensure_ascii=False, indent=1))
    print(f"bitti: {len(cache)} subject -> {args.cache} "
          f"({time.time() - t0:.0f}s)", file=sys.stderr)


if __name__ == "__main__":
    main()