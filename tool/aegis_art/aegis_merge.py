#!/usr/bin/env python3
"""art_jobs.jsonl + aegis_subject_cache.json → art_jobs_final.jsonl

Gemini subject cache'teki görsel betimlemeyi alıp final Flux prompt'unu
yapılandırılmış bölümlerle üretir:

    Giriş cümlesi: {name}, Aegis {category}
    Çizim konusu: {Gemini subject}  (veya fallback: raw subject)
    Çizim tarzı:  hand-painted oil painting ...
    Kısıtlamalar: full-bleed square artwork ...

Kullanım:
    python3 aegis_merge.py                              # varsayılan dosyalar
    python3 aegis_merge.py --cache subject_cache.json   # özel cache
    python3 aegis_merge.py --sample 5                   # 5 örnek bas, yazma
"""
from __future__ import annotations
import argparse, json, re, sys, uuid as _uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from aegis_prompts import (
    AEGIS_LIGHT, AEGIS_PALETTE, AEGIS_STYLE, BLUEPRINT, DND_CONTEXT,
    FULL_BLEED, STYLE_TAIL, STYLE_FLAVOR, entity_uuid, extract_subject,
    load_blueprint,
)

# ---------------------------------------------------------------------------
# Structured prompt builder
# ---------------------------------------------------------------------------

def build_final_prompt(
    uid: str,
    category: str,
    name: str,
    subject_body: str,
    use_gemini: bool,
) -> str:
    """Yapılandırılmış final prompt üretir.

    Bölümler:
        1. Giriş cümlesi — entity adı, kategori, dünya
        2. Çizim konusu — Gemini cevabı (veya fallback: raw subject)
        3. Çizim tarzı — yağlı boya palet
        4. Kısıtlamalar — full-bleed, anti-AI, D&D bağlamı
    """
    header = f"{name}, Aegis {category}"

    # Subject body — name prefix'ini kaldır (header zaten ismi içeriyor)
    body = subject_body
    escaped = re.escape(name)
    while True:
        stripped = re.sub(rf"^{escaped}[,:\s-]+", "", body, flags=re.I)
        if stripped == body:
            break
        body = stripped
    body = body.rstrip(". ")

    style = f"{AEGIS_STYLE}, {STYLE_TAIL}"
    flavor = STYLE_FLAVOR[int(uid[:8], 16) % len(STYLE_FLAVOR)]

    return (
        f"{body}\n"
        f"{header}, {FULL_BLEED}, {DND_CONTEXT}, "
        f"{AEGIS_PALETTE}, {AEGIS_LIGHT}, {style}, {flavor}"
    )


# ---------------------------------------------------------------------------
# Merge
# ---------------------------------------------------------------------------

def merge(
    jobs: list[dict],
    cache: dict[str, str],
    blueprint_data: dict | None = None,
) -> list[dict]:
    """Her job için Gemini cache varsa onu, yoksa fallback subject'i kullanır."""
    results = []
    for job in jobs:
        uid = job["uuid"]
        name = job["name"]
        category = job["category"]

        # 1. tercih: Gemini cache
        gemini_subject = cache.get(uid)
        if gemini_subject:
            final = build_final_prompt(uid, category, name, gemini_subject, use_gemini=True)
            results.append({
                "uuid": uid,
                "category": category,
                "name": name,
                "prompt": final,
                "seed": job.get("seed", int(uid[:8], 16)),
                "source": "gemini",
            })
            continue

        # 2. tercih: blueprint'ten raw subject (fallback)
        if blueprint_data:
            raw_subject = _extract_raw_subject(blueprint_data, category, name)
            if raw_subject:
                final = build_final_prompt(uid, category, name, raw_subject, use_gemini=False)
                results.append({
                    "uuid": uid,
                    "category": category,
                    "name": name,
                    "prompt": final,
                    "seed": job.get("seed", int(uid[:8], 16)),
                    "source": "blueprint",
                })
                continue

        # Hiçbiri yoksa — atla
        print(f"UYARI: subject yok, atlanıyor: {category}/{name}", file=sys.stderr)

    return results


def _extract_raw_subject(bp: dict, category: str, name: str) -> str:
    """Blueprint'ten ham subject çıkarır (aegis_prompts.extract_subject ile aynı mantık)."""
    for cat_name, entities in bp.get("categories", {}).items():
        if cat_name != category:
            continue
        for e in entities:
            ename = e["mapping"].get("name", e.get("source_name", ""))
            if ename == name:
                return extract_subject(name, category, e["mapping"])
    return ""


# ---------------------------------------------------------------------------
# Self-check
# ---------------------------------------------------------------------------

def self_check(jobs: list[dict]) -> None:
    assert jobs, "hiç job yok"
    for j in jobs:
        p = j["prompt"]
        assert "hand-painted oil painting" in p, f"yağlı boya stili yok: {j['name']}"
        assert "full-bleed square artwork" in p, f"full-bleed yok: {j['name']}"
        assert "Dungeons & Dragons" in p, f"D&D bağlamı yok: {j['name']}"
        assert not re.search(r"[*_`#|]", p), f"markdown artığı: {j['name']}"
    by_src: dict[str, int] = {}
    for j in jobs:
        by_src[j.get("source", "?")] = by_src.get(j.get("source", "?"), 0) + 1
    print(f"OK — {len(jobs)} job, kaynaklar: {by_src}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    base = Path(__file__).resolve().parent
    p = argparse.ArgumentParser(description="art_jobs + subject_cache → final prompts")
    p.add_argument("--jobs", type=Path, default=base / "art_jobs.jsonl",
                   help="aegis_prompts.py çıktısı")
    p.add_argument("--cache", type=Path, default=base / "aegis_subject_cache.json",
                   help="aegis_subject_gen.py cache çıktısı")
    p.add_argument("--blueprint", type=Path, default=BLUEPRINT,
                   help="world-blueprint.json (fallback)")
    p.add_argument("--out", type=Path, default=base / "art_jobs_final.jsonl",
                   help="çıktı dosyası")
    p.add_argument("--sample", type=int,
                   help="N örnek bas, dosya yazma")
    p.add_argument("--self-check", action="store_true")
    p.add_argument("--category", type=str,
                   help="yalnızca belirli kategori")
    p.add_argument("--limit", type=int)
    args = p.parse_args()

    # Jobs
    if not args.jobs.is_file():
        print(f"HATA: jobs dosyası yok: {args.jobs}", file=sys.stderr)
        sys.exit(1)
    jobs = [json.loads(line) for line in args.jobs.read_text().splitlines() if line.strip()]

    # Cache
    cache: dict[str, str] = {}
    if args.cache.is_file():
        try:
            cache = json.loads(args.cache.read_text())
        except Exception:
            cache = {}
    print(f"cache: {len(cache)} subject yüklendi", file=sys.stderr)

    # Blueprint (fallback)
    bp = None
    if args.blueprint.is_file():
        bp = json.loads(args.blueprint.read_text())

    # Filtre
    if args.category:
        jobs = [j for j in jobs if j["category"] == args.category]
    if args.limit:
        jobs = jobs[:args.limit]

    # Merge
    results = merge(jobs, cache, bp)

    if args.self_check:
        self_check(results)
        return

    if args.sample:
        gemini_count = sum(1 for r in results if r["source"] == "gemini")
        bp_count = sum(1 for r in results if r["source"] == "blueprint")
        print(f"Toplam: {len(results)} (gemini={gemini_count}, blueprint={bp_count})\n")
        for r in results[:args.sample]:
            print(f"[{r['source']}] [{r['category']}] {r['name']}")
            print(r["prompt"])
            print()
        return

    # Yaz
    with args.out.open("w") as f:
        for r in results:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    gemini_count = sum(1 for r in results if r["source"] == "gemini")
    bp_count = sum(1 for r in results if r["source"] == "blueprint")
    print(f"{len(results)} job → {args.out} (gemini={gemini_count}, blueprint={bp_count})")


if __name__ == "__main__":
    main()
