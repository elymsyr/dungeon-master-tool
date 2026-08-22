#!/usr/bin/env python3
"""Her kategoriden rastgele N içerik seçer, görsellerini üretir ve bunları tek
bir grid resminde birleştirir. Amaç: farklı prompt varyantlarını (STYLE son-eki,
FRAMING) küçük bir örnek set üzerinde hızlıca deneyip yan yana karşılaştırmak.

Örnek set deterministiktir (--seed): aynı seed ile farklı --style değerleri
denenirse, grid'ler birebir aynı entity'leri gösterir ve görsel karşılaştırma
anlamlı olur. Üretilen webp'ler out/<variant>/ altında tutulur; yarıda kalırsa
aynı komut tekrar çalıştırılarak resume edilir.

Kullanım:
  python3 tool/art_gen/prompt_grid.py                          # prod stili, seed 1234
  python3 tool/art_gen/prompt_grid.py --style "<yeni stil>"    # stili değiştir
  python3 tool/art_gen/prompt_grid.py --seed 7 --size 1024     # farklı örnek set
  python3 tool/art_gen/prompt_grid.py --dry-run                # üretmeden örnek seç
"""
import argparse, json, random, sys, time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate import run_job, to_webp
from prompts import ART_TYPES, STYLE, STYLE_FLAVOR, MOOD, PALETTE, load_jobs

BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

TYPE_ORDER = ["monster", "spell", "magic-item", "subclass",
              "feat", "background", "subspecies", "species"]


def sample_jobs(jobs: list[dict], per_type: int, seed: int) -> dict[str, list[dict]]:
    """Her tipten rastgele per_type job seç; deterministik (seed'li)."""
    rng = random.Random(seed)
    by_type: dict[str, list[dict]] = {}
    for j in jobs:
        by_type.setdefault(j["type"], []).append(j)
    out: dict[str, list[dict]] = {}
    for t in TYPE_ORDER:
        group = list(by_type.get(t, []))
        if not group:
            continue
        rng.shuffle(group)
        out[t] = group[:per_type]
    return out


def apply_variant(prompt: str, t: str, style: str, palette: str | None,
                  mood: str | None) -> str:
    """Prompt'taki PALETTE/MOOD/STYLE+flavor bloklarını variant değerlerle değiştir."""
    for f in STYLE_FLAVOR:
        suffix = f", {STYLE}, {f}"
        if prompt.endswith(suffix):
            prompt = prompt[: -len(suffix)]
            break
    else:
        suffix = ", " + STYLE
        if prompt.endswith(suffix):
            prompt = prompt[: -len(suffix)]
    if palette is not None:
        prompt = prompt.replace(f", {PALETTE[t]},", f", {palette},")
    if mood is not None:
        prompt = prompt.replace(f", {MOOD[t]},", f", {mood},")
    return f"{prompt}, {style}"


def generate_cell(host: str, job: dict, style: str, palette: str | None,
                  mood: str | None, model: str, text_encoder: str, vae: str,
                  size: int, timeout: int, loader: str) -> bytes:
    """Webp üret (prompt'a variant stilini uygulayarak)."""
    job = dict(job)
    job["prompt"] = apply_variant(job["prompt"], job["type"], style, palette, mood)
    png = run_job(host, job, model, text_encoder, vae, size, timeout, loader)
    return to_webp(png, 90, 0.02)


def square_thumb(data: bytes, px: int) -> Image.Image:
    """Merkezden kare kırp, px'e küçült."""
    im = Image.open(__import__("io").BytesIO(data)).convert("RGB")
    w, h = im.size
    s = min(w, h)
    im = im.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2))
    return im.resize((px, px), Image.LANCZOS)


def compose_grid(cells: dict[str, list[tuple[str, Image.Image]]],
                 title: str, thumb: int, pad: int) -> Image.Image:
    """Sütun = kategori, satır = o kategoriden seçilen örnekler."""
    cols = [t for t in TYPE_ORDER if t in cells]
    rows = max(len(v) for v in cells.values())
    title_h, header_h, label_h = 52, 38, 26
    W = pad + len(cols) * (thumb + pad)
    H = title_h + header_h + rows * (thumb + label_h + pad) + pad
    canvas = Image.new("RGB", (W, H), (30, 30, 32))
    draw = ImageDraw.Draw(canvas)

    draw.text((pad, 10), title, font=ImageFont.truetype(BOLD, 24), fill=(240, 240, 240))

    for ci, t in enumerate(cols):
        cx = pad + ci * (thumb + pad)
        draw.text((cx, title_h + 6), t,
                  font=ImageFont.truetype(BOLD, 18), fill=(255, 205, 120))
        for ri, (name, im) in enumerate(cells[t]):
            y = title_h + header_h + ri * (thumb + label_h + pad)
            canvas.paste(im, (cx, y))
            label = name[:26] + ("…" if len(name) > 26 else "")
            draw.text((cx + 2, y + thumb + 3), label,
                      font=ImageFont.truetype(REG, 13), fill=(200, 200, 200))
    return canvas


def main() -> None:
    base = Path(__file__).resolve().parent
    p = argparse.ArgumentParser()
    p.add_argument("--host", default="http://192.168.1.12:8188")
    p.add_argument("--jobs", type=Path, default=base / "art_jobs.jsonl")
    p.add_argument("--packs", type=Path,
                   default=Path(__file__).resolve().parents[2] / "flutter_app/assets/open5e_packs")
    p.add_argument("--out", type=Path, default=base / "out")
    p.add_argument("--grids", type=Path, default=base / "grids")
    p.add_argument("--ckpt", default="flux1-schnell-fp8.safetensors")
    p.add_argument("--loader", choices=["diffusion", "checkpoint"], default="diffusion",
                   help="diffusion: Z-Image-Turbo (varsayılan), checkpoint: Flux")
    p.add_argument("--model", default="z_image_turbo_bf16.safetensors")
    p.add_argument("--text-encoder", default="qwen_3_4b.safetensors")
    p.add_argument("--vae", default="ae.safetensors")
    p.add_argument("--style", default=STYLE, help="STYLE bloğu (variant)")
    p.add_argument("--palette", help="PALETTE bloğunu geçersiz kıl (tüm tipler için)")
    p.add_argument("--mood", help="MOOD bloğunu geçersiz kıl (tüm tipler için)")
    p.add_argument("--variant", default="prod", help="çıktı klasörü/etiketi")
    p.add_argument("--per-type", type=int, default=2)
    p.add_argument("--seed", type=int, default=1234, help="örnek seçim seed'i")
    p.add_argument("--size", type=int, default=512, help="üretim boyutu (grid için 512 yeterli)")
    p.add_argument("--thumb", type=int, default=384)
    p.add_argument("--timeout", type=int, default=300)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    jobs_path = args.jobs
    if not jobs_path.exists():
        print(f"{jobs_path} yok, pack'lerden üretiliyor…", file=sys.stderr)
        jobs = load_jobs(args.packs)
        jobs_path.parent.mkdir(parents=True, exist_ok=True)
        jobs_path.write_text("\n".join(json.dumps(j, ensure_ascii=False) for j in jobs) + "\n")
    else:
        jobs = [json.loads(l) for l in jobs_path.read_text().splitlines() if l.strip()]

    sample = sample_jobs(jobs, args.per_type, args.seed)
    flat = [(t, j) for t in TYPE_ORDER for j in sample.get(t, [])]
    print(f"{len(flat)} görsel seçildi (seed={args.seed}, per-type={args.per_type})", file=sys.stderr)

    variant_dir = args.out / args.variant
    variant_dir.mkdir(parents=True, exist_ok=True)
    args.grids.mkdir(parents=True, exist_ok=True)

    manifest = [{"type": t, "name": j["name"], "uuid": j["uuid"], "seed": j["seed"]}
                for t, j in flat]
    (args.grids / f"{args.variant}_s{args.seed}.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False))

    if args.dry_run:
        for t, j in flat:
            print(f"  [{t}] {j['name']}  {j['uuid']}")
        print("dry-run: üretim yapılmadı", file=sys.stderr)
        return

    cells: dict[str, list[tuple[str, Image.Image]]] = {}
    t0, done = time.time(), 0
    model = args.model if args.loader == "diffusion" else args.ckpt
    for t, j in flat:
        webp = variant_dir / f"{j['uuid']}.webp"
        try:
            if not webp.exists():
                webp.write_bytes(generate_cell(args.host, j, args.style, args.palette,
                                               args.mood, model, args.text_encoder,
                                               args.vae, args.size, args.timeout, args.loader))
            cells.setdefault(t, []).append((j["name"], square_thumb(webp.read_bytes(), args.thumb)))
            done += 1
            print(f"  [{t}] {j['name']}  {time.time() - t0:.0f}s", file=sys.stderr)
        except Exception as e:
            print(f"HATA [{t}] {j['name']}: {e}", file=sys.stderr)

    grid = compose_grid(cells, f"{args.variant}  s{args.seed}  size={args.size}",
                        args.thumb, 12)
    out_png = args.grids / f"{args.variant}_s{args.seed}.png"
    grid.save(out_png)
    print(f"{done} görsel -> {out_png}", file=sys.stderr)


if __name__ == "__main__":
    main()