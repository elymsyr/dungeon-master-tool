#!/usr/bin/env python3
"""Secili kartlari tek bir job dosyasina ayirir ve varsa eski gorsellerini siler.

Tek kart duzeltip yeniden uretmenin kisa yolu:

    python3 pick.py "location|Votumar" "npc|Mine"
    python3 aegis_generate.py --jobs one.jsonl --out out_new

Anahtar bicimi "kategori|ad" (aegis_polish.py ile ayni). Yanlis anahtar sessizce
yutulmaz, hata verir.
"""
from __future__ import annotations
import argparse, json, sys
from pathlib import Path

BASE = Path(__file__).resolve().parent


def main() -> None:
    p = argparse.ArgumentParser(description="kategori|ad -> tek job dosyasi")
    p.add_argument("keys", nargs="+", help='ornek: "location|Votumar"')
    p.add_argument("--jobs", type=Path, default=BASE / "art_jobs_final.jsonl")
    p.add_argument("--out", type=Path, default=BASE / "one.jsonl")
    p.add_argument("--out-dir", type=Path, default=BASE / "out_new",
                   help="eski gorsellerin silinecegi klasor")
    p.add_argument("--keep", action="store_true", help="gorselleri silme")
    a = p.parse_args()

    want = set(a.keys)
    rows = [l for l in a.jobs.read_text().splitlines(True) if l.strip()]
    picked = [l for l in rows
              if f"{json.loads(l)['category']}|{json.loads(l)['name']}" in want]

    found = {f"{json.loads(l)['category']}|{json.loads(l)['name']}" for l in picked}
    if missing := want - found:
        print("HATA: bulunamayan anahtar(lar): " + ", ".join(sorted(missing)),
              file=sys.stderr)
        sys.exit(1)

    a.out.write_text("".join(picked))
    for l in picked:
        d = json.loads(l)
        img = a.out_dir / f"{d['uuid']}.webp"
        if img.exists() and not a.keep:
            img.unlink()
            print(f"silindi: {img}", file=sys.stderr)
        print(f"{d['category']}|{d['name']}", file=sys.stderr)
    print(f"{len(picked)} job -> {a.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
