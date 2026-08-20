#!/usr/bin/env python3
"""art_jobs.jsonl -> ComfyUI HTTP API -> out/{uuid}.webp

Resume edilebilir: out/ içinde dosyası olan job atlanır.
Aynı script hem uzaktan (test) hem server üstünde (toplu koşu) çalışır.
"""
import argparse, json, sys, time, urllib.parse, urllib.request
from pathlib import Path

# Flux schnell: cfg 1.0 zorunlu (distilled, negative prompt yok), 4 adım yeter.
# Bu değerler stil tutarlılığının parçası — job başına DEĞİŞMEZ.
STEPS, CFG, SAMPLER, SCHEDULER = 4, 1.0, "euler", "simple"


def workflow(ckpt: str, prompt: str, seed: int, size: int) -> dict:
    return {
        "1": {"class_type": "CheckpointLoaderSimple",
              "inputs": {"ckpt_name": ckpt}},
        "2": {"class_type": "CLIPTextEncode",
              "inputs": {"text": prompt, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode",
              "inputs": {"text": "", "clip": ["1", 1]}},
        "4": {"class_type": "EmptySD3LatentImage",
              "inputs": {"width": size, "height": size, "batch_size": 1}},
        "5": {"class_type": "KSampler",
              "inputs": {"seed": seed, "steps": STEPS, "cfg": CFG,
                         "sampler_name": SAMPLER, "scheduler": SCHEDULER, "denoise": 1.0,
                         "model": ["1", 0], "positive": ["2", 0],
                         "negative": ["3", 0], "latent_image": ["4", 0]}},
        "6": {"class_type": "VAEDecode",
              "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveImage",
              "inputs": {"images": ["6", 0], "filename_prefix": "dmt"}},
    }


def post(host: str, path: str, payload: dict) -> dict:
    req = urllib.request.Request(
        f"{host}{path}", data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def get(host: str, path: str) -> bytes:
    with urllib.request.urlopen(f"{host}{path}", timeout=60) as r:
        return r.read()


def run_job(host: str, job: dict, ckpt: str, size: int, timeout: int) -> bytes:
    pid = post(host, "/prompt",
               {"prompt": workflow(ckpt, job["prompt"], job["seed"], size)})["prompt_id"]
    deadline = time.time() + timeout
    while time.time() < deadline:
        hist = json.loads(get(host, f"/history/{pid}"))
        if pid in hist:
            imgs = hist[pid]["outputs"]["7"]["images"][0]
            q = urllib.parse.urlencode(
                {"filename": imgs["filename"], "subfolder": imgs["subfolder"],
                 "type": imgs["type"]})
            return get(host, f"/view?{q}")
        time.sleep(0.4)
    raise TimeoutError(f"{job['uuid']} {timeout}s içinde bitmedi")


def to_webp(png: bytes, quality: int, crop: float) -> bytes:
    """Kenarlardan crop kadar kırp, sonra webp'e yaz.

    Flux tabloyu imzalama eğiliminde ve sahte filigranı hep kenara/köşeye
    koyuyor; negatif prompt yok (cfg 1.0) ve "no watermark" demek tersine
    çalışıyor. Kırpmak tek deterministik çözüm.
    """
    from io import BytesIO
    from PIL import Image
    im = Image.open(BytesIO(png))
    if crop > 0:
        w, h = im.size
        dx, dy = int(w * crop), int(h * crop)
        im = im.crop((dx, dy, w - dx, h - dy))
    buf = BytesIO()
    im.save(buf, "WEBP", quality=quality, method=6)
    return buf.getvalue()


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--host", default="http://192.168.1.12:8188")
    p.add_argument("--jobs", type=Path, default=Path("art_jobs.jsonl"))
    p.add_argument("--out", type=Path, default=Path("out"))
    p.add_argument("--ckpt", default="flux1-schnell-fp8.safetensors")
    p.add_argument("--size", type=int, default=1024)
    p.add_argument("--quality", type=int, default=82)
    p.add_argument("--crop", type=float, default=0.05,
                   help="her kenardan kırpılacak oran (sahte filigran temizliği)")
    p.add_argument("--limit", type=int, help="sadece ilk N job (pilot)")
    p.add_argument("--types", help="virgüllü tip filtresi, ör. monster,spell")
    p.add_argument("--every", type=int, default=1, help="her N'inci job (çeşitlilik için)")
    p.add_argument("--timeout", type=int, default=300)
    args = p.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    jobs = [json.loads(l) for l in args.jobs.read_text().splitlines() if l.strip()]
    if args.types:
        want = set(args.types.split(","))
        jobs = [j for j in jobs if j["type"] in want]
    jobs = jobs[::args.every]
    if args.limit:
        jobs = jobs[:args.limit]

    todo = [j for j in jobs if not (args.out / f"{j['uuid']}.webp").exists()]
    print(f"{len(todo)}/{len(jobs)} job kaldı", file=sys.stderr)

    t0, done = time.time(), 0
    for i, job in enumerate(todo, 1):
        try:
            png = run_job(args.host, job, args.ckpt, args.size, args.timeout)
            (args.out / f"{job['uuid']}.webp").write_bytes(to_webp(png, args.quality, args.crop))
            done += 1
        except Exception as e:
            print(f"HATA {job['uuid']} {job['name']}: {e}", file=sys.stderr)
            continue
        if i % 10 == 0 or i == len(todo):
            rate = (time.time() - t0) / done if done else 0
            eta = rate * (len(todo) - i) / 3600
            print(f"{i}/{len(todo)}  {rate:.1f}s/görsel  kalan ~{eta:.1f}s saat",
                  file=sys.stderr)
    print(f"bitti: {done} görsel -> {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
