#!/usr/bin/env python3
"""Paket basina grid testi."""
import argparse, json, random, sys, time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate import run_job, to_webp
from prompts import PACKAGE_TITLE, load_jobs

BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

TYPE_ORDER = ["monster", "spell", "magic-item", "subclass",
              "feat", "background", "subspecies", "species"]

PACKAGE_ORDER = [
    "dnd5e-srd",
    "open5e-a5e-ag", "open5e-a5e-ddg", "open5e-a5e-gpg", "open5e-a5e-mm",
    "open5e-bfrd", "open5e-ccdx", "open5e-deepm", "open5e-deepmx",
    "open5e-kp", "open5e-open5e", "open5e-spells-that-dont-suck",
    "open5e-tdcs", "open5e-tob", "open5e-tob-2023", "open5e-tob2",
    "open5e-tob3", "open5e-toh", "open5e-vom", "open5e-wz",
]


def sample_packages(jobs, per_type, seed, packages):
    by_pkg = {}
    for j in jobs:
        by_pkg.setdefault(j["package"], {}).setdefault(j["type"], []).append(j)
    want = packages if packages is not None else [
        p for p in PACKAGE_ORDER if p in by_pkg]
    out = {}
    for pkg in want:
        out[pkg] = {}
        for t in TYPE_ORDER:
            group = list(by_pkg.get(pkg, {}).get(t, []))
            if not group:
                continue
            rng = random.Random("%s:%s:%s" % (seed, pkg, t))
            rng.shuffle(group)
            out[pkg][t] = group[:per_type]
    return out


def square_thumb(data, px):
    import io
    im = Image.open(io.BytesIO(data)).convert("RGB")
    w, h = im.size
    s = min(w, h)
    im = im.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2))
    return im.resize((px, px), Image.LANCZOS)


def compose_package_grid(pkg, cells, thumb, pad):
    cols = [t for t in TYPE_ORDER if t in cells]
    rows = max(len(v) for v in cells.values())
    title_h, header_h, label_h = 44, 34, 24
    W = pad + len(cols) * (thumb + pad)
    H = title_h + header_h + rows * (thumb + label_h + pad) + pad
    canvas = Image.new("RGB", (W, H), (30, 30, 32))
    draw = ImageDraw.Draw(canvas)
    title = "%s  --  %s" % (pkg, PACKAGE_TITLE.get(pkg, pkg))
    draw.text((pad, 8), title, font=ImageFont.truetype(BOLD, 20), fill=(240, 240, 240))
    for ci, t in enumerate(cols):
        cx = pad + ci * (thumb + pad)
        draw.text((cx, title_h + 4), t, font=ImageFont.truetype(BOLD, 16),
                  fill=(255, 205, 120))
        for ri, (name, im) in enumerate(cells[t]):
            y = title_h + header_h + ri * (thumb + label_h + pad)
            canvas.paste(im, (cx, y))
            label = name[:24] + ("..." if len(name) > 24 else "")
            draw.text((cx + 2, y + thumb + 3), label,
                      font=ImageFont.truetype(REG, 12), fill=(200, 200, 200))
    return canvas


def main():
    base = Path(__file__).resolve().parent
    p = argparse.ArgumentParser()
    p.add_argument("--host", default="http://192.168.1.12:8188")
    p.add_argument("--jobs", type=Path, default=base / "art_jobs.jsonl")
    p.add_argument("--packs", type=Path, action="append",
                   default=[Path(__file__).resolve().parents[2] / "flutter_app/assets/open5e_packs",
                            base / "packs"])
    p.add_argument("--out", type=Path, default=base / "out")
    p.add_argument("--grids", type=Path, default=base / "grids")
    p.add_argument("--variant", default="pkg")
    p.add_argument("--packages", help="virgullu paket filtresi (bos=tumu)")
    p.add_argument("--per-type", type=int, default=2)
    p.add_argument("--seed", type=int, default=1234)
    p.add_argument("--size", type=int, default=512)
    p.add_argument("--thumb", type=int, default=320)
    p.add_argument("--timeout", type=int, default=300)
    p.add_argument("--model", default="z_image_turbo_bf16.safetensors")
    p.add_argument("--text-encoder", default="qwen_3_4b.safetensors")
    p.add_argument("--vae", default="ae.safetensors")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    jobs_path = args.jobs
    if not jobs_path.exists():
        print("%s yok, pack'lerden uretiliyor..." % jobs_path, file=sys.stderr)
        jobs = load_jobs(args.packs)
        jobs_path.parent.mkdir(parents=True, exist_ok=True)
        jobs_path.write_text("\n".join(json.dumps(j, ensure_ascii=False) for j in jobs) + "\n")
    else:
        jobs = [json.loads(l) for l in jobs_path.read_text().splitlines() if l.strip()]

    pkgs = args.packages.split(",") if args.packages else None
    sample = sample_packages(jobs, args.per_type, args.seed, pkgs)

    grid_dir = args.grids / ("%s_s%d" % (args.variant, args.seed))
    variant_dir = args.out / args.variant
    grid_dir.mkdir(parents=True, exist_ok=True)
    variant_dir.mkdir(parents=True, exist_ok=True)

    manifest = []
    total = 0
    for pkg in sorted(sample, key=lambda x: PACKAGE_ORDER.index(x) if x in PACKAGE_ORDER else 999):
        for t in TYPE_ORDER:
            for j in sample[pkg].get(t, []):
                manifest.append({"package": pkg, "type": t, "name": j["name"],
                                 "uuid": j["uuid"], "seed": j["seed"]})
                total += 1
    (grid_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
    print("%d gorsel secildi (paket=%d, seed=%d)" % (total, len(sample), args.seed),
          file=sys.stderr)

    if args.dry_run:
        for m in manifest:
            print("  [%s/%s] %s  %s" % (m["package"], m["type"], m["name"], m["uuid"]))
        print("dry-run: uretim yapilmadi", file=sys.stderr)
        return

    t0 = time.time()
    done = 0
    for pkg in sorted(sample, key=lambda x: PACKAGE_ORDER.index(x) if x in PACKAGE_ORDER else 999):
        cells = {}
        for t in TYPE_ORDER:
            for j in sample[pkg].get(t, []):
                webp = variant_dir / ("%s.webp" % j["uuid"])
                try:
                    if not webp.exists():
                        png = run_job(args.host, j, args.model, args.text_encoder,
                                      args.vae, args.size, args.timeout, "diffusion")
                        webp.write_bytes(to_webp(png, 90, 0.02))
                    cells.setdefault(t, []).append((j["name"], square_thumb(webp.read_bytes(), args.thumb)))
                    done += 1
                    print("  [%s/%s] %s  %.0fs" % (pkg, t, j["name"], time.time() - t0),
                          file=sys.stderr)
                except Exception as e:
                    print("HATA [%s/%s] %s: %s" % (pkg, t, j["name"], e), file=sys.stderr)
        if cells:
            grid = compose_package_grid(pkg, cells, args.thumb, 12)
            grid.save(grid_dir / ("%s.png" % pkg))
    print("bitti: %d gorsel -> %s" % (done, grid_dir), file=sys.stderr)


if __name__ == "__main__":
    main()
