#!/usr/bin/env python3
"""Kart görseli / arka plan karşılaştırma gridi.

Her sütun bir kart: üstte ad, altında kart görseli, onun altında BG.
Sütunlar --cols kadar bloklara bölünür.

  python3 aegis_bg_compare.py --category lore --out compare_lore.jpg
"""
from __future__ import annotations

import argparse, json, re, unicodedata
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

BASE = Path(__file__).resolve().parent
ARTWORK = (BASE.parents[1] / "flutter_app/assets/worlds/aegis/aegis-act1/media/Artwork")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
BG = (28, 26, 24)
FG = (232, 226, 214)


def slug(name: str) -> str:
    """Kart adı -> Artwork dosya adı: kesme işareti düşer, kalan harf/rakam dışı her şey tek tire."""
    return re.sub(r"[^0-9A-Za-zÇĞİÖŞÜçğıöşü]+", "-", name.replace("'", "")).strip("-")


def card_path(card_dir: Path, job: dict) -> Path:
    """Ada göre (Artwork), ad çakışınca kategori önekli, yoksa uuid'e göre (out/)."""
    for cand in (f"{slug(job['name'])}.webp",
                 f"{job['category']}-{slug(job['name'])}.webp"):
        if (card_dir / cand).exists():
            return card_dir / cand
    return card_dir / f"{job['card_uuid']}.webp"


def fit(text: str, font, width: int) -> str:
    """Sığmıyorsa kısalt."""
    if font.getlength(text) <= width:
        return text
    while text and font.getlength(text + "…") > width:
        text = text[:-1]
    return text + "…"


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--jobs", type=Path, default=BASE / "art_bg_jobs.jsonl")
    p.add_argument("--card-dir", type=Path, default=ARTWORK)
    p.add_argument("--bg-dir", type=Path, default=BASE / "out_bg")
    p.add_argument("--category", default="lore")
    p.add_argument("--cols", type=int, default=5)
    p.add_argument("--cell", type=int, default=384)
    p.add_argument("--out", type=Path, default=BASE / "compare_lore.jpg")
    a = p.parse_args()

    rows = [j for j in map(json.loads, a.jobs.open(encoding="utf-8"))
            if j["category"] == a.category]
    if not rows:
        raise SystemExit(f"{a.category} için job yok")

    font = ImageFont.truetype(FONT, 20)
    pad, head = 8, 34
    cell = a.cell
    blocks = [rows[i:i + a.cols] for i in range(0, len(rows), a.cols)]
    block_h = head + cell * 2 + pad * 3
    W = a.cols * (cell + pad) + pad
    H = len(blocks) * block_h + pad

    canvas = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(canvas)

    for bi, block in enumerate(blocks):
        y0 = pad + bi * block_h
        for ci, job in enumerate(block):
            x = pad + ci * (cell + pad)
            draw.text((x, y0), fit(job["name"], font, cell), font=font, fill=FG)
            for ri, path in enumerate((card_path(a.card_dir, job),
                                       a.bg_dir / f"{job['uuid']}.webp")):
                y = y0 + head + ri * (cell + pad)
                if path.exists():
                    canvas.paste(Image.open(path).convert("RGB")
                                 .resize((cell, cell), Image.LANCZOS), (x, y))
                else:
                    draw.rectangle([x, y, x + cell, y + cell], outline=(90, 80, 70))
                    draw.text((x + 12, y + 12), "yok", font=font, fill=(150, 120, 100))

    canvas.save(a.out, quality=88)
    print(f"{len(rows)} kart -> {a.out} ({W}x{H})")


if __name__ == "__main__":
    main()
