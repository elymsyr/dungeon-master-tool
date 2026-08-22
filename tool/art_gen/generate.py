#!/usr/bin/env python3
"""art_jobs.jsonl -> ComfyUI HTTP API -> out/{uuid}.webp

Resume edilebilir: out/ içinde dosyası olan job atlanır.
Aynı script hem uzaktan (test) hem server üstünde (toplu koşu) çalışır.
"""
import argparse, json, sys, time, urllib.parse, urllib.request
from pathlib import Path

# Ortak sampler ayarları. cfg 1.0: hem Flux schnell hem Z-Image-Turbo distilled,
# negatif prompt yok. Adım sayısı loader'a göre değişir (aşağıda).
CFG, SAMPLER, SCHEDULER = 1.0, "euler", "simple"
FLUX_STEPS, ZIMAGE_STEPS = 4, 8


def flux_workflow(ckpt: str, prompt: str, seed: int, size: int) -> dict:
    """Flux.1 (schnell/dev) — tek checkpoint dosyası, clip+vae checkpoint'ten."""
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
              "inputs": {"seed": seed, "steps": FLUX_STEPS, "cfg": CFG,
                         "sampler_name": SAMPLER, "scheduler": SCHEDULER, "denoise": 1.0,
                         "model": ["1", 0], "positive": ["2", 0],
                         "negative": ["3", 0], "latent_image": ["4", 0]}},
        "6": {"class_type": "VAEDecode",
              "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveImage",
              "inputs": {"images": ["6", 0], "filename_prefix": "dmt"}},
    }


def zimage_workflow(model: str, text_encoder: str, vae: str,
                    prompt: str, seed: int, size: int) -> dict:
    """Z-Image-Turbo — ayrı diffusion/text_encoder/vae dosyaları (resmî örnek)."""
    return {
        "1": {"class_type": "UNETLoader",
              "inputs": {"unet_name": model, "weight_dtype": "default"}},
        # device="cpu": 20GB kartta bf16 diffusion (12.3GB) + bf16 text encoder
        # (8GB) VRAM'e birlikte sığmaz; text encoder CPU'da encode edilir.
        "2": {"class_type": "CLIPLoader",
              "inputs": {"clip_name": text_encoder, "type": "lumina2",
                         "device": "cpu"}},
        "3": {"class_type": "VAELoader",
              "inputs": {"vae_name": vae}},
        "4": {"class_type": "CLIPTextEncode",
              "inputs": {"text": prompt, "clip": ["2", 0]}},
        "5": {"class_type": "CLIPTextEncode",
              "inputs": {"text": "", "clip": ["2", 0]}},
        "6": {"class_type": "EmptySD3LatentImage",
              "inputs": {"width": size, "height": size, "batch_size": 1}},
        "7": {"class_type": "KSampler",
              "inputs": {"seed": seed, "steps": ZIMAGE_STEPS, "cfg": CFG,
                         "sampler_name": SAMPLER, "scheduler": SCHEDULER, "denoise": 1.0,
                         "model": ["1", 0], "positive": ["4", 0],
                         "negative": ["5", 0], "latent_image": ["6", 0]}},
        "8": {"class_type": "VAEDecode",
              "inputs": {"samples": ["7", 0], "vae": ["3", 0]}},
        "9": {"class_type": "SaveImage",
              "inputs": {"images": ["8", 0], "filename_prefix": "dmt"}},
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


def run_job(host: str, job: dict, model: str, text_encoder: str, vae: str,
            size: int, timeout: int, loader: str = "diffusion") -> bytes:
    if loader == "checkpoint":
        wf = flux_workflow(model, job["prompt"], job["seed"], size)
        out_node = "7"
    else:
        wf = zimage_workflow(model, text_encoder, vae, job["prompt"], job["seed"], size)
        out_node = "9"
    pid = post(host, "/prompt", {"prompt": wf})["prompt_id"]
    deadline = time.time() + timeout
    while time.time() < deadline:
        hist = json.loads(get(host, f"/history/{pid}"))
        if pid in hist:
            imgs = hist[pid]["outputs"][out_node]["images"][0]
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
    p.add_argument("--loader", choices=["diffusion", "checkpoint"], default="diffusion",
                   help="diffusion: Z-Image-Turbo (varsayılan), checkpoint: Flux")
    p.add_argument("--model", default="z_image_turbo_bf16.safetensors",
                   help="diffusion_models/ adı (loader=diffusion)")
    p.add_argument("--text-encoder", default="qwen_3_4b.safetensors",
                   help="text_encoders/ adı (loader=diffusion)")
    p.add_argument("--vae", default="ae.safetensors",
                   help="vae/ adı (loader=diffusion)")
    p.add_argument("--ckpt", default="flux1-schnell-fp8.safetensors",
                   help="checkpoints/ adı (loader=checkpoint)")
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
            model = args.model if args.loader == "diffusion" else args.ckpt
            png = run_job(args.host, job, model, args.text_encoder, args.vae,
                          args.size, args.timeout, args.loader)
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
