#!/usr/bin/env python3
"""art_jobs.jsonl'den üretilecek her şeyin envanterini INVENTORY.md'ye yazar.

Elle yazılmaz — kaynak art_jobs.jsonl (+ subject_cache.json, out/*.webp).
    python3 tool/art_gen/inventory.py [--out INVENTORY.md]
"""
import argparse, json
from collections import Counter, defaultdict
from pathlib import Path

BASE = Path(__file__).resolve().parent


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--jobs", type=Path, default=BASE / "art_jobs.jsonl")
    ap.add_argument("--out", type=Path, default=BASE / "INVENTORY.md")
    a = ap.parse_args()

    jobs = [json.loads(l) for l in a.jobs.read_text().splitlines() if l.strip()]
    cache = json.loads((BASE / "subject_cache.json").read_text())
    done = {p.stem for p in (BASE / "out").rglob("*.webp")}

    types = sorted({j["type"] for j in jobs})
    per_pkg = defaultdict(Counter)
    for j in jobs:
        per_pkg[j["package"]][j["type"]] += 1
    subj = Counter(j["package"] for j in jobs if j["uuid"] in cache)
    img = Counter(j["package"] for j in jobs if j["uuid"] in done)

    L = [f"# Art Inventory\n",
         f"`inventory.py` tarafından üretildi — elle düzenleme.\n",
         f"Kaynak: `{a.jobs.name}` · **{len(jobs)}** iş · "
         f"{len(per_pkg)} paket · subject: {subj.total()}/{len(jobs)}"
         f" · görsel: {img.total()}/{len(jobs)}\n",
         "| Paket | " + " | ".join(types) + " | Toplam | Subject | Görsel |",
         "|" + "---|" * (len(types) + 4)]
    for pkg in sorted(per_pkg, key=lambda p: -per_pkg[p].total()):
        c = per_pkg[pkg]
        L.append(f"| {pkg} | " + " | ".join(str(c.get(t, 0) or "") for t in types)
                 + f" | {c.total()} | {subj[pkg]} | {img[pkg]} |")
    tot = Counter()
    for c in per_pkg.values():
        tot += c
    L.append("| **Toplam** | " + " | ".join(f"**{tot.get(t,0)}**" for t in types)
             + f" | **{len(jobs)}** | **{subj.total()}** | **{img.total()}** |")

    a.out.write_text("\n".join(L) + "\n")
    print(f"{a.out} — {len(jobs)} iş, {len(per_pkg)} paket")


if __name__ == "__main__":
    main()
