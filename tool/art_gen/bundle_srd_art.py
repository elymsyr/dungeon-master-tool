#!/usr/bin/env python3
"""out/ içindeki SRD görsellerini yeniden sıkıştırıp app bundle'ına kopyalar.

Sadece `dnd5e-srd` paketinin işleri alınır (1247 adet); geri kalan paketlerin
görselleri R2 catalog'una gider (bkz. publish_art.sh). Boyut değişmez (922px),
yalnızca webp kalitesi düşürülür — q82 → q50 bundle'ı ~116 MB'den ~51 MB'ye
indiriyor ve 1:1'de fırça dokusu korunuyor (q40'ta gözle görülür yumuşama var).

  python3 tool/art_gen/bundle_srd_art.py [--quality 50] [--force]

Resume edilebilir: hedefte dosya varsa atlanır (--force ile yeniden kodlanır).
"""
import argparse, json, sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent
DEST = ROOT.parent.parent / "flutter_app" / "assets" / "art" / "srd"
PACKAGE = "dnd5e-srd"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--jobs", type=Path, default=ROOT / "art_jobs.jsonl")
    ap.add_argument("--src", type=Path, default=ROOT / "out")
    ap.add_argument("--dest", type=Path, default=DEST)
    ap.add_argument("--quality", type=int, default=50)
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()

    uuids = [
        j["uuid"]
        for j in (json.loads(l) for l in a.jobs.read_text().splitlines() if l.strip())
        if j["package"] == PACKAGE
    ]
    a.dest.mkdir(parents=True, exist_ok=True)
    done = skipped = missing = 0
    total_bytes = 0
    for i, u in enumerate(uuids, 1):
        src, dst = a.src / f"{u}.webp", a.dest / f"{u}.webp"
        if not src.exists():
            print(f"EKSİK {u}", file=sys.stderr)
            missing += 1
            continue
        if dst.exists() and not a.force:
            skipped += 1
            total_bytes += dst.stat().st_size
            continue
        Image.open(src).convert("RGB").save(
            dst, "WEBP", quality=a.quality, method=6
        )
        total_bytes += dst.stat().st_size
        done += 1
        if i % 100 == 0:
            print(f"  {i}/{len(uuids)}", flush=True)
    print(
        f"{done} kodlandı, {skipped} atlandı, {missing} eksik → "
        f"{a.dest} ({total_bytes / 1e6:.1f} MB)"
    )
    if missing:
        sys.exit(1)


if __name__ == "__main__":
    main()
